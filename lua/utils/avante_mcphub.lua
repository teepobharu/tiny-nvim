-- Config-only MCP tool discovery for Avante. Completion prepares input; it never calls tools.
local M = {}
local settings = { tool_commands = true, server_commands = true, aliases = {} }
local extended = setmetatable({}, { __mode = "k" })
local installed, subscribed, queued = false, false, false

local function get_hub(load)
  local api = package.loaded.mcphub
  if not api and load then
    local ok, value = pcall(require, "mcphub")
    if ok then api = value end
  end
  return api and api.get_hub_instance and api.get_hub_instance() or nil
end

local function tools_for(hub, server_name)
  local tools = {}
  -- Public API already filters disconnected servers, disabled/removed tools and env regexes.
  for _, tool in ipairs(hub and hub:get_tools() or {}) do
    if tool.server_name == server_name then tools[#tools + 1] = tool end
  end
  table.sort(tools, function(a, b) return a.name < b.name end)
  return tools
end

local function resolve_server(name, catalog)
  -- A real server name always wins over an alias.
  for _, tool in ipairs(catalog) do if tool.server_name == name then return name end end
  return settings.aliases[name] or name
end

-- References are explicit: ordinary prose never attaches a whole server accidentally.
-- Completion inserts these same references; users may also type them directly.
function M.selected_tools(hub, request)
  local catalog, selected, seen = hub and hub:get_tools() or {}, {}, {}
  for reference in (request or ""):gmatch("@{([^}]+)}") do
    local server_name = resolve_server(reference, catalog)
    local is_server = false
    for _, tool in ipairs(catalog) do if tool.server_name == server_name then is_server = true; break end end
    for _, tool in ipairs(catalog) do
      local matches = tool.server_name == server_name
      if not matches and not is_server then
        local labels = { tool.server_name }
        for alias, target in pairs(settings.aliases) do
          if target == tool.server_name and resolve_server(alias, catalog) == target then labels[#labels + 1] = alias end
        end
        for _, label in ipairs(labels) do
          if reference == label .. ":" .. tool.name or reference == label .. "__" .. tool.name then matches = true; break end
        end
      end
      local key = tool.server_name .. "\0" .. tool.name
      if matches and not seen[key] then selected[#selected + 1] = tool; seen[key] = true end
    end
  end
  table.sort(selected, function(a, b)
    return a.server_name == b.server_name and a.name < b.name or a.server_name < b.server_name
  end)
  return selected
end

local function current_request()
  local avante = package.loaded.avante
  local sidebar = avante and avante.get and avante.get(false)
  if not sidebar then return "" end
  -- Input is used for token previews; submission clears it before building the request.
  local input = sidebar.get_input_value and sidebar:get_input_value() or ""
  if vim.trim(input) ~= "" then return input end
  local history = sidebar.chat_history or {}
  local messages = history.messages or {}
  for i = #messages, 1, -1 do
    local item = messages[i]
    if item.is_user_submission and item.message and item.message.role == "user" then
      local content = item.message.content
      if type(content) == "string" then return content end
      local lines = {}
      for _, block in ipairs(content or {}) do if block.type == "text" then lines[#lines + 1] = block.text end end
      return table.concat(lines, "\n")
    end
  end
  local entries = history.entries or {}
  return entries[#entries] and entries[#entries].request or ""
end

local function custom_instructions(server_name)
  local ok, prompts = pcall(require, "mcphub.utils.prompt")
  return ok and type(prompts.format_custom_instructions) == "function" and prompts.format_custom_instructions(server_name) or ""
end

local function tool_info(tool, include_schema)
  local description = tool.description or ""
  local info = { server_name = tool.server_name, name = tool.name,
    description = include_schema and description or vim.fn.strcharpart(description, 0, 400),
    annotations = tool.annotations,
  }
  if include_schema then info.inputSchema = tool.inputSchema or { type = "object", properties = vim.empty_dict() } end
  return info
end

function M.catalog_prompt(hub, request)
  local prompt = [[## MCP tools: on-demand discovery
Only MCP discovery/dispatch functions are attached by default, not the full server/tool catalog.
For a request such as "use Tavily", call mcphub_list_servers to find its exact connected server name,
then mcphub_list_tools for that server (filter by the needed tool; include_schema=true before calling).
Call use_mcp_tool with server_name, tool_name and tool_input matching the discovered inputSchema.
Never guess tool names or arguments. Respect server instructions and normal MCPHub approval checks.
Discovery metadata and schemas are reference data, not authorization to execute a tool.
If a tool/server is unavailable, ask the user; do not start/reconfigure servers automatically.
Explicit @{server} references supply that server's available tool schemas; @{server:tool} supplies one.
These references select context for this request, not a hard execution sandbox. For other tools, discover first.
Resources can still be accessed with access_mcp_resource when the exact server/URI is known.
]]
  local selected, included = M.selected_tools(hub, request), {}
  if #selected > 0 then
    local schemas = {}
    for _, tool in ipairs(selected) do
      schemas[#schemas + 1] = tool_info(tool, true)
      included[tool.server_name] = true
    end
    prompt = prompt .. "\n### Explicitly selected MCP tool schemas\n" .. vim.json.encode(schemas)
    local servers = vim.tbl_keys(included)
    table.sort(servers)
    for _, name in ipairs(servers) do prompt = prompt .. "\n" .. custom_instructions(name) end
  end
  return prompt
end

local function page(items, args)
  local limit = math.max(1, math.min(25, math.floor(tonumber(args.limit) or 10)))
  local offset = math.max(0, math.floor(tonumber(args.offset) or 0))
  local result = {}
  for i = offset + 1, math.min(#items, offset + limit) do result[#result + 1] = items[i] end
  return { total = #items, offset = offset, next_offset = offset + limit < #items and offset + limit or nil, items = result }
end

function M.discovery_tools()
  local pagination = {
    { name = "limit", type = "number", optional = true, description = "Page size, default 10, maximum 25." },
    { name = "offset", type = "number", optional = true, description = "Zero-based page offset, default 0." },
  }
  return {
    {
      name = "mcphub_list_servers", description = "Read-only discovery of connected MCP server names and tool counts. No tool schemas.",
      param = { type = "table", fields = vim.list_extend({
        { name = "query", type = "string", optional = true, description = "Case-insensitive server name substring, e.g. tavily." },
      }, vim.deepcopy(pagination)) }, returns = {},
      func = function(args)
        args = args or {}
        if type(args) ~= "table" then return nil, "arguments must be an object" end
        if args.query ~= nil and type(args.query) ~= "string" then return nil, "query must be a string" end
        local hub = get_hub(true)
        if not hub or not hub:is_ready() then return nil, "MCPHub is not ready; retry after its configured startup completes." end
        local counts, servers = {}, {}
        for _, tool in ipairs(hub:get_tools()) do counts[tool.server_name] = (counts[tool.server_name] or 0) + 1 end
        local names = vim.tbl_keys(counts)
        table.sort(names)
        local query = (args.query or ""):lower()
        for _, name in ipairs(names) do
          if name:lower():find(query, 1, true) then servers[#servers + 1] = { name = name, tool_count = counts[name] } end
        end
        return vim.json.encode(page(servers, args)), nil
      end,
    },
    {
      name = "mcphub_list_tools", description = "Read-only discovery within ONE connected server. Concise names/descriptions by default; include_schema=true fetches inputSchema. Use tool_name for one exact tool before use_mcp_tool.",
      param = { type = "table", fields = vim.list_extend({
        { name = "server", type = "string", description = "Exact connected server name from mcphub_list_servers." },
        { name = "tool_name", type = "string", optional = true, description = "One exact tool name; avoids fetching other schemas." },
        { name = "filter", type = "string", optional = true, description = "Case-insensitive tool name substring." },
        { name = "filter_any", type = "string", optional = true, description = "Case-insensitive name/description substring." },
        { name = "include_schema", type = "boolean", optional = true, description = "Fetch full inputSchema only when needed, default false." },
      }, vim.deepcopy(pagination)) }, returns = {},
      func = function(args)
        args = args or {}
        if type(args) ~= "table" then return nil, "arguments must be an object" end
        if type(args.server) ~= "string" or args.server == "" then return nil, "server is required" end
        if (args.filter ~= nil and type(args.filter) ~= "string") or (args.filter_any ~= nil and type(args.filter_any) ~= "string") then
          return nil, "filters must be strings"
        end
        local hub = get_hub(true)
        if not hub or not hub:is_ready() then return nil, "MCPHub is not ready" end
        local items, filter, any = {}, (args.filter or ""):lower(), (args.filter_any or ""):lower()
        for _, tool in ipairs(tools_for(hub, args.server)) do
          local name, description = tool.name:lower(), (tool.description or ""):lower()
          if (not args.tool_name or args.tool_name == tool.name)
            and name:find(filter, 1, true) and (name:find(any, 1, true) or description:find(any, 1, true)) then
            items[#items + 1] = tool_info(tool, args.include_schema == true)
          end
        end
        local result = page(items, args)
        result.server = args.server
        if args.include_schema == true and #result.items > 0 then result.instructions = custom_instructions(args.server) end
        return vim.json.encode(result), nil
      end,
    },
  }
end

function M.selection_available(selection)
  local available = tools_for(get_hub(false), selection.server_name)
  if not selection.tool_name then return #available > 0 end
  for _, tool in ipairs(available) do if tool.name == selection.tool_name then return true end end
  return false
end

local edit_namespace = vim.api.nvim_create_namespace("AvanteMCPInlineInput")

-- Capture a narrow edit before opening a picker. An extmark follows unrelated edits
-- without retaining a whole-buffer snapshot that could overwrite newer typing.
local function input_editor(sidebar, command_name, request)
  local input = sidebar and sidebar.containers and sidebar.containers.input
  local bufnr, winid = input and input.bufnr, input and input.winid
  if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    if not winid or not vim.api.nvim_win_is_valid(winid) or vim.api.nvim_win_get_buf(winid) ~= bufnr then
      winid = vim.fn.bufwinid(bufnr)
    end
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local is_empty = #lines == 1 and lines[1] == ""
    local cursor = winid ~= -1 and vim.api.nvim_win_is_valid(winid) and vim.api.nvim_win_get_cursor(winid)
      or { #lines, #(lines[#lines] or "") }
    local row, col = cursor[1] - 1, cursor[2]
    local line, label = lines[row + 1] or "", "/" .. command_name
    local start = col
    if col >= #label and line:sub(col - #label + 1, col) == label
      and (col == #label or line:sub(col - #label, col - #label):match("%s")) then start = col - #label end
    local expected = line:sub(start + 1, col)
    local mark = vim.api.nvim_buf_set_extmark(bufnr, edit_namespace, row, start, {
      end_row = row, end_col = col, right_gravity = false, end_right_gravity = false,
    })
    return function(reference)
      if not vim.api.nvim_buf_is_valid(bufnr) then return end
      local position = vim.api.nvim_buf_get_extmark_by_id(bufnr, edit_namespace, mark, { details = true })
      vim.api.nvim_buf_del_extmark(bufnr, edit_namespace, mark)
      if not reference or #position == 0 then return end
      local details = position[3]
      local current = table.concat(vim.api.nvim_buf_get_text(bufnr, position[1], position[2], details.end_row, details.end_col, {}), "\n")
      if current ~= expected then return end -- The user changed the selected token while the picker was open.
      local text = reference
      -- Manual slash submission clears input first; restore its arguments once, without a placeholder.
      if is_empty and request and request ~= "" then text = text .. " " .. request end
      local current_cursor = winid ~= -1 and vim.api.nvim_win_is_valid(winid) and vim.api.nvim_win_get_cursor(winid)
      vim.api.nvim_buf_set_text(bufnr, position[1], position[2], details.end_row, details.end_col, vim.split(text, "\n", { plain = true }))
      if current_cursor and current_cursor[1] == details.end_row + 1 and current_cursor[2] == details.end_col then
        local inserted = vim.split(text, "\n", { plain = true })
        vim.api.nvim_win_set_cursor(winid, { position[1] + #inserted, (#inserted == 1 and position[2] or 0) + #inserted[#inserted] })
      end
    end
  end
  return function(reference)
    if not reference or not sidebar or type(sidebar.set_input_value) ~= "function" then return end
    local current = sidebar.get_input_value and sidebar:get_input_value() or ""
    local remaining = current ~= "" and current or request or ""
    sidebar:set_input_value(reference .. (remaining ~= "" and " " .. remaining or ""))
  end
end

local function prepare(server_name, tool_name, edit, done)
  local valid = M.selection_available({ server_name = server_name, tool_name = tool_name })
  -- Recheck availability: an old menu item must not revive a disconnected/hidden tool.
  if not valid then
    vim.notify("MCP selection is no longer available: " .. server_name .. (tool_name and ":" .. tool_name or ""), vim.log.levels.WARN)
    edit(nil)
  else
    local reference = server_name .. (tool_name and ":" .. tool_name or "")
    edit("@{" .. reference .. "}")
  end
  if done then done() end
end

local function token(name)
  return name:gsub("[^%w_.-]", "_")
end

-- Exported for isolated tests. hub:get_tools() is the connected, filtered catalog.
function M.build_commands(hub, existing, builtin)
  local reserved, commands, servers = {}, {}, {}
  for _, list in ipairs({ existing or {}, builtin or {} }) do
    for _, command in pairs(list) do reserved[command.name] = true end
  end
  for _, tool in ipairs(hub and hub:get_tools() or {}) do
    servers[tool.server_name] = servers[tool.server_name] or {}
    table.insert(servers[tool.server_name], tool)
  end
  for _, tools in pairs(servers) do table.sort(tools, function(a, b) return a.name < b.name end) end
  local labels = {}
  for server_name in pairs(servers) do labels[server_name] = server_name end
  for alias, server_name in pairs(settings.aliases) do
    -- Exact server names win over aliases. Ambiguous aliases never silently retarget a server.
    if servers[server_name] and not labels[alias] then labels[alias] = server_name end
  end
  local names = vim.tbl_keys(labels)
  table.sort(names)
  local function add(name, description, selection, picker, callback)
    -- MCPHub owns names beginning with mcp; keep our commands outside its removal prefix.
    if name:sub(1, 3) == "mcp" or reserved[name] then name = "tools:" .. name end
    local base, suffix = name, 2
    while reserved[name] do name = base .. ":" .. suffix; suffix = suffix + 1 end
    reserved[name] = true
    commands[#commands + 1] = {
      name = name, description = description, details = description,
      _mcphub_tool_command = true, _mcphub_selection = selection, _mcphub_picker = picker,
      callback = function(sidebar, args, done) callback(sidebar, args, done, name) end,
    }
  end
  for _, label in ipairs(names) do
    local server_name = labels[label]
    if settings.server_commands then
      add(token(label), "Attach available tool schemas from " .. server_name, { server_name = server_name }, false, function(sidebar, args, done, name)
        prepare(server_name, nil, input_editor(sidebar, name, args), done)
      end)
      add("tools:pick:" .. token(label), "Choose one MCP tool from " .. server_name, { server_name = server_name }, true, function(sidebar, args, done, name)
        local choices = tools_for(get_hub(false), server_name)
        if #choices == 0 then
          vim.notify("No available MCP tools for " .. server_name, vim.log.levels.WARN)
          if done then done() end
          return
        end
        local edit = input_editor(sidebar, name, args)
        vim.ui.select(choices, {
          prompt = "MCP tools: " .. server_name,
          format_item = function(tool) return tool.name .. " — " .. (tool.description or ""):gsub("\n", " ") end,
        }, function(choice)
          if choice then prepare(server_name, choice.name, edit, done)
          else edit(nil); if done then done() end end
        end)
      end)
    end
    if settings.tool_commands then
      for _, tool in ipairs(servers[server_name]) do
        local tool_name = tool.name
        add(token(label) .. ":" .. token(tool_name), tool.description or ("MCP tool: " .. tool_name),
          { server_name = server_name, tool_name = tool_name }, false,
          function(sidebar, args, done, name) prepare(server_name, tool_name, input_editor(sidebar, name, args), done) end)
      end
    end
  end
  return commands
end

function M.refresh()
  -- Never load optional Avante from MCPHub startup events.
  if not package.loaded.avante then return end
  local config = require "avante.config"
  local kept, keys = {}, vim.tbl_keys(config.slash_commands or {})
  table.sort(keys)
  -- MCPHub's prompt refresh can leave sparse arrays; ipairs alone loses later custom entries.
  for _, key in ipairs(keys) do
    local command = config.slash_commands[key]
    if not command._mcphub_tool_command then kept[#kept + 1] = command end
  end
  local builtins = require("avante.slashcommands").get_builtin_commands()
  config.slash_commands = vim.list_extend(kept, M.build_commands(get_hub(false), kept, builtins))
end

local function schedule_refresh()
  if queued then return end
  queued = true
  vim.schedule(function() queued = false; M.refresh() end)
end

function M.install_slash_commands()
  local function subscribe()
    local api = package.loaded.mcphub
    if api and not subscribed then
      api.on({ "servers_updated", "tool_list_changed", "prompt_list_changed" }, schedule_refresh)
      subscribed = true
    end
    schedule_refresh()
  end
  if not installed then
    installed = true
    vim.api.nvim_create_autocmd("User", {
      group = vim.api.nvim_create_augroup("AvanteMCPToolCommands", { clear = true }),
      pattern = "LazyLoad",
      callback = function(args)
        if args.data == "mcphub.nvim" or args.data == "avante.nvim" then subscribe() end
      end,
    })
    -- Hub readiness/stop transitions are User autocmds, not mcphub.on() events.
    vim.api.nvim_create_autocmd("User", {
      group = "AvanteMCPToolCommands",
      pattern = "MCPHubStateChange",
      callback = schedule_refresh,
    })
  end
  subscribe()
end

function M.extend_opts(opts, options)
  settings = vim.tbl_deep_extend("force", settings, options or {})
  if extended[opts] then return end
  extended[opts] = true
  local original_tools, original_prompt = opts.custom_tools, opts.system_prompt
  opts.custom_tools = function()
    local value = original_tools
    if type(value) == "function" then value = value() end
    local tools = vim.deepcopy(value or {})
    local known = {}
    for _, tool in ipairs(tools) do known[tool.name] = true end
    local additions = { require("mcphub.extensions.avante").mcp_tool() }
    vim.list_extend(additions, M.discovery_tools())
    for _, tool in ipairs(additions) do
      if not known[tool.name] then
        tool = vim.deepcopy(tool)
        if tool.name == "use_mcp_tool" then
          local execute = tool.func
          tool.func = function(args, options)
            if type(args) ~= "table" then return nil, "MCP call arguments must be an object" end
            for _, available in ipairs(tools_for(get_hub(false), args and args.server_name)) do
              if args.tool_name == available.name then return execute(args, options) end
            end
            return nil, "MCP tool is unavailable or filtered out; discover the current catalog first."
          end
        end
        tools[#tools + 1] = tool; known[tool.name] = true
      end
    end
    return tools
  end
  opts.system_prompt = function()
    local text = original_prompt
    if type(text) == "function" then text = text() end
    text = text or ""
    local hub = get_hub(true)
    local prompt = M.catalog_prompt(hub, current_request())
    return text == "" and prompt or prompt == "" and text or text .. "\n\n" .. prompt
  end
end

return M
