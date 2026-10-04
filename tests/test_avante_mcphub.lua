local bridge = require "utils.avante_mcphub"
local assertions = 0
local function check(value, message)
  assertions = assertions + 1
  assert(value, message)
end
local function eq(expected, actual, message)
  check(vim.deep_equal(expected, actual), message .. ": " .. vim.inspect(actual))
end
local function command(list, name)
  for _, item in ipairs(list) do if item.name == name then return item end end
end
local function decode_result(value) return vim.json.decode(value) end

-- Worktree-profile clean runtime: no plugin startup, gateway calls or personal files.
local catalog = {
  { server_name = "ag-slack", name = "read_tool", description = "Read a test message", inputSchema = {
    required = { "channel" }, properties = { channel = { type = "string", description = "Channel ID" } },
  } },
  { server_name = "ag-slack", name = "search", description = "Search test messages", inputSchema = {
    type = "object", properties = { query = { type = "string" } }, required = { "query" },
  } },
  { server_name = "init", name = "read" },
  { server_name = "mcphub", name = "get_info" },
  { server_name = "other", name = "lookup", inputSchema = { properties = { UNRELATED_SCHEMA = { type = "string" } } } },
}
local ready = true
local hub = {
  is_ready = function() return ready end,
  get_tools = function() return ready and vim.deepcopy(catalog) or {} end,
  get_active_servers_prompt = function() error("full catalog must never be attached") end,
  call_tool = function() error("completion must never execute tools") end,
}
local listeners, subscriptions = {}, 0
local api = {
  get_hub_instance = function() return hub end,
  on = function(events, callback)
    subscriptions = subscriptions + 1
    for _, event in ipairs(events) do listeners[event] = callback end
  end,
}
local dispatched = 0
package.loaded["mcphub.utils.prompt"] = { format_custom_instructions = function(name) return "INSTRUCTIONS_FOR_" .. name end }
package.loaded["mcphub.extensions.avante"] = { mcp_tool = function()
  return { name = "use_mcp_tool", func = function()
    dispatched = dispatched + 1
    return "DISPATCHED", nil
  end }, { name = "access_mcp_resource" }
end }
local opts = {
  custom_tools = function() return { { name = "google_search" }, { name = "use_mcp_tool" } } end,
  system_prompt = function() return "EXISTING_PROMPT" end,
}
bridge.extend_opts(opts, { aliases = { slack = "ag-slack", other = "ag-slack" } })
eq(nil, package.loaded.mcphub, "opts wrapping does not load MCPHub")
eq(nil, package.loaded.avante, "opts wrapping does not load Avante")
bridge.install_slash_commands()
eq(nil, package.loaded.mcphub, "watcher installation does not load MCPHub")
eq(nil, package.loaded.avante, "watcher installation does not load Avante")
local tools = opts.custom_tools()
eq(5, #tools, "discovery and dispatch tools merge without duplicates")
eq("google_search", tools[1].name, "existing custom tool survives")
eq(opts.custom_tools()[2].func, tools[2].func, "existing user-owned dispatcher is preserved")
check(opts.custom_tools() ~= tools, "tool table rebuilt per request")
bridge.extend_opts(opts)
eq(5, #opts.custom_tools(), "wrapping is idempotent")
package.loaded.mcphub = api
vim.api.nvim_exec_autocmds("User", { pattern = "LazyLoad", data = "mcphub.nvim" })
eq(1, subscriptions, "late MCPHub load subscribes without opening Avante")
local initial_prompt = bridge.catalog_prompt(hub, "use tavily search openai news")
eq("EXISTING_PROMPT\n\n" .. initial_prompt, opts.system_prompt(), "lean instructions append existing text")
check(not initial_prompt:find('"inputSchema"', 1, true), "plain prose does not attach schemas")
check(not initial_prompt:find("UNRELATED_SCHEMA", 1, true), "unrelated schema absent initially")
check(not initial_prompt:find("INSTRUCTIONS_FOR_", 1, true), "all server instructions not attached initially")
eq(2, #bridge.selected_tools(hub, "@{slack} Search test messages"), "server reference selects its available tools")
eq(1, #bridge.selected_tools(hub, "@{slack:read_tool}"), "tool reference selects one schema")
eq(1, #bridge.selected_tools(hub, "@{slack__read_tool}"), "CodeCompanion-style tool separator also supported")
eq(2, #bridge.selected_tools(hub, "@{slack} @{ag-slack:read_tool}"), "overlapping references deduplicate")
eq("other", bridge.selected_tools(hub, "@{other}")[1].server_name, "real server wins over ambiguous alias")
eq({}, bridge.selected_tools(hub, "@{disconnected:missing}"), "hidden/disconnected tool cannot attach schemas")
local saved_catalog = catalog
catalog = { { server_name = "foo", name = "bar" }, { server_name = "foo:bar", name = "actual_tool" } }
eq({ catalog[2] }, bridge.selected_tools(hub, "@{foo:bar}"), "exact server identity wins over a colliding tool reference")
catalog = saved_catalog
local scoped_prompt = bridge.catalog_prompt(hub, "@{slack:read_tool}")
check(scoped_prompt:find('"inputSchema"', 1, true), "selected schema supplied behind visible reference")
check(scoped_prompt:find("Channel ID", 1, true), "complete selected schema retained")
check(scoped_prompt:find("INSTRUCTIONS_FOR_ag-slack", 1, true), "selected server instructions retained")
check(not scoped_prompt:find("UNRELATED_SCHEMA", 1, true), "selected tool does not attach another server")
check(not scoped_prompt:find('"name":"search"', 1, true), "single-tool reference does not attach sibling schemas")
local original_catalog = catalog
catalog = {}
for i = 1, 500 do catalog[#catalog + 1] = { server_name = "huge-" .. i, name = "tool", inputSchema = { secret = "not-for-initial-context" } } end
eq(initial_prompt, bridge.catalog_prompt(hub, "use tavily search openai news"), "initial prompt size independent of catalog size")
catalog = original_catalog

local discovery = bridge.discovery_tools()
local servers = decode_result(command(discovery, "mcphub_list_servers").func({ query = "AG-SLACK" }))
eq({ { name = "ag-slack", tool_count = 2 } }, servers.items, "server discovery case-insensitive and concise")
local list_tools = command(discovery, "mcphub_list_tools").func
local concise = decode_result(list_tools({ server = "ag-slack" }))
eq(2, concise.total, "server-scoped discovery returns only its tools")
eq(nil, concise.items[1].inputSchema, "discovery omits schemas by default")
eq(nil, concise.instructions, "discovery omits server instructions by default")
local one = decode_result(list_tools({ server = "ag-slack", tool_name = "read_tool", include_schema = true }))
eq(1, one.total, "exact tool discovery fetches only one schema")
eq(catalog[1].inputSchema, one.items[1].inputSchema, "inputSchema retained without lossy conversion")
eq("INSTRUCTIONS_FOR_ag-slack", one.instructions, "schema discovery includes relevant server instructions")
eq(1, decode_result(list_tools({ server = "ag-slack", filter_any = "test message", filter = "read" })).total,
  "discovery filters AND together")
eq(0, decode_result(list_tools({ server = "missing", include_schema = true })).total, "unknown server has no schemas")
local _, argument_error = list_tools({})
check(argument_error ~= nil, "missing server fails clearly")
local _, filter_error = list_tools({ server = "ag-slack", filter = false })
check(filter_error ~= nil, "malformed discovery filter fails clearly")
local _, query_error = command(discovery, "mcphub_list_servers").func({ query = 42 })
check(query_error ~= nil, "malformed discovery query fails clearly")
catalog = {}
for i = 1, 30 do catalog[#catalog + 1] = { server_name = "large", name = ("tool_%02d"):format(i), description = string.rep("x", 800) } end
local paged = decode_result(list_tools({ server = "large", limit = 1000 }))
eq(25, #paged.items, "discovery results bounded even with excessive limit")
eq(25, paged.next_offset, "discovery provides next page offset")
eq(400, #paged.items[1].description, "concise descriptions bounded")
eq(5, #decode_result(list_tools({ server = "large", offset = paged.next_offset })).items, "remaining tools can be paged")
catalog = original_catalog
ready = false
local _, readiness_error = list_tools({ server = "ag-slack" })
check(readiness_error ~= nil, "unready hub fails discovery clearly")
ready = true

local commands = bridge.build_commands(hub, { { name = "custom" } }, { { name = "init" } })
check(command(commands, "ag-slack"), "actual server command exists")
check(command(commands, "slack:read_tool"), "explicit alias creates tool command")
check(command(commands, "ag-slack:read_tool"), "actual tool name remains available")
check(command(commands, "tools:init"), "builtin collision gets safe prefix")
check(command(commands, "tools:mcphub"), "MCP-owned prefix is avoided")
check(command(commands, "other:lookup"), "real server wins over colliding alias")
check(not command(commands, "other:read_tool"), "colliding alias does not retarget server")
local names = {}
for _, item in ipairs(commands) do
  check(not names[item.name], "generated names unique")
  names[item.name] = true
end

local sidebar = { set_input_value = function(self, value) self.input = value end }
local done = 0
command(commands, "slack:read_tool").callback(sidebar, "Read the synthetic test channel", function() done = done + 1 end)
check(sidebar.input:find("@{ag-slack:read_tool}", 1, true), "alias resolves to exact tool reference")
check(sidebar.input:find("Read the synthetic test channel", 1, true), "typed request preserved")
check(not sidebar.input:find("Channel ID", 1, true), "visible input is compact; schema supplied separately")
eq(1, done, "completion finalized once")
command(commands, "slack").callback(sidebar, "Choose the best tool", function() done = done + 1 end)
eq("@{ag-slack} Choose the best tool", sidebar.input, "server command selects all server schemas without explanatory text")
eq(2, done, "server selection finalized once")
local old_select, old_notify = vim.ui.select, vim.notify
local warnings = 0
vim.notify = function() warnings = warnings + 1 end
vim.ui.select = function(items, _, callback) callback(items[2]) end
command(commands, "tools:pick:slack").callback(sidebar, nil, function() done = done + 1 end)
check(sidebar.input:find("@{ag-slack:search}", 1, true), "explicit picker prepares selected tool")
eq(3, done, "picker completion finalized once")
vim.ui.select = function(_, _, callback) callback(nil) end
local before = sidebar.input
command(commands, "tools:pick:slack").callback(sidebar, nil, function() done = done + 1 end)
eq(before, sidebar.input, "cancelled picker does not alter request")
eq(4, done, "cancelled picker completion finalized")
catalog = {}
command(commands, "slack:read_tool").callback(sidebar, nil, function() done = done + 1 end)
eq(before, sidebar.input, "stale tool cannot prepare a request")
eq(1, warnings, "stale tool warns")
eq({}, bridge.build_commands(hub), "empty catalog removes tool entries")
vim.ui.select, vim.notify = old_select, old_notify

-- Preserve sparse MCP prompt lists and refresh both filtered tools and disconnects.
catalog = { { server_name = "ag-slack", name = "read_tool" } }
local config = { slash_commands = {
  [1] = { name = "custom" }, [3] = { name = "mcp:skills:workflow" },
} }
package.loaded["avante.config"] = config
package.loaded["avante.slashcommands"] = { get_builtin_commands = function() return { { name = "init" } } end }
bridge.install_slash_commands()
eq(nil, package.loaded.avante, "watchers never force Avante startup")
package.loaded.avante = { get = function() return sidebar end }
sidebar.get_input_value = function(self) return self.input or "" end
sidebar.input = "@{ag-slack:read_tool}"
check(opts.system_prompt():find('"name":"read_tool"', 1, true), "input preview attaches explicitly selected schema")
sidebar.input = ""
sidebar.chat_history = { messages = {
  { is_user_submission = true, message = { role = "user", content = "@{ag-slack:read_tool}" } },
  { message = { role = "assistant", content = "@{other}" } },
} }
check(opts.system_prompt():find('"name":"read_tool"', 1, true), "submitted reference read from current chat")
check(not opts.system_prompt():find("UNRELATED_SCHEMA", 1, true), "assistant content never selects tool context")
sidebar.chat_history.messages[#sidebar.chat_history.messages + 1] = {
  is_user_submission = true, message = { role = "user", content = "plain follow-up" },
}
eq("EXISTING_PROMPT\n\n" .. initial_prompt, opts.system_prompt(), "references scoped to latest request, not accumulated")
sidebar.chat_history = { messages = {} }
eq("EXISTING_PROMPT\n\n" .. initial_prompt, opts.system_prompt(), "new chat does not inherit tool selection")
bridge.install_slash_commands()
eq(1, subscriptions, "event listeners registered once")
check(listeners.tool_list_changed and listeners.servers_updated, "relevant events subscribed")
bridge.refresh()
check(command(config.slash_commands, "custom"), "custom commands preserved")
check(command(config.slash_commands, "mcp:skills:workflow"), "sparse MCP prompt command preserved")
check(command(config.slash_commands, "slack:read_tool"), "fresh tool command registered")
local count = #config.slash_commands
bridge.refresh()
eq(count, #config.slash_commands, "refresh does not duplicate commands")
catalog = { { server_name = "ag-slack", name = "new_tool" } }
listeners.tool_list_changed()
check(vim.wait(1000, function() return command(config.slash_commands, "slack:new_tool") ~= nil end), "tool event refreshes commands")
check(not command(config.slash_commands, "slack:read_tool"), "old capability removed")
catalog = {}
vim.api.nvim_exec_autocmds("User", { pattern = "MCPHubStateChange" })
check(vim.wait(1000, function() return #config.slash_commands == 2 end), "disconnect removes generated commands only")
check(command(config.slash_commands, "mcp:skills:workflow"), "disconnect preserves unrelated prompts")
local nil_opts = { custom_tools = function() return nil end, system_prompt = function() return nil end }
bridge.extend_opts(nil_opts)
eq(4, #nil_opts.custom_tools(), "nil-producing custom tools supported")
eq(initial_prompt, nil_opts.system_prompt(), "nil-producing existing prompt supported")
catalog = { { server_name = "ag-slack", name = "read_tool" } }
local dispatcher = command(nil_opts.custom_tools(), "use_mcp_tool").func
eq("DISPATCHED", dispatcher({ server_name = "ag-slack", tool_name = "read_tool", tool_input = {} }), "available tool delegates to original approval-aware dispatcher")
eq(1, dispatched, "original dispatcher executed once")
local _, unavailable_error = dispatcher({ server_name = "ag-slack", tool_name = "hidden_tool", tool_input = {} })
check(unavailable_error ~= nil, "filtered/stale tools rejected before dispatch")
eq(1, dispatched, "rejected tool cannot bypass approval-aware dispatcher")
local _, invalid_error = dispatcher(42)
check(invalid_error ~= nil, "invalid dispatcher arguments fail before executing")
print(("Avante MCPHub tests passed (%d assertions)"):format(assertions))
