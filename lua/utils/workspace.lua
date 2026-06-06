require("utils.workspace.schema")

local M = {}

local uv = vim.uv or vim.loop
local MAX_WORKSPACE_FILES = 50

local function notify_workspace(message, level)
  vim.print(message)
  vim.notify(message, level or vim.log.levels.INFO)
end

local function expand(path)
  return vim.fn.expand(path)
end

local function join(root, rel)
  return root:gsub("/$", "") .. "/" .. rel:gsub("^/", "")
end

local function is_file(path)
  local stat = uv.fs_stat(path)
  return stat and stat.type == "file"
end

local function is_dir(path)
  local stat = uv.fs_stat(path)
  return stat and stat.type == "directory"
end

local function is_excluded(path)
  if path:find("/node_modules/", 1, true)
    or path:find("/__screenshots__/", 1, true)
    or path:find("/__tests__/", 1, true)
    or path:find("/__componentTests__/", 1, true)
    or path:find(".test.", 1, true)
    or path:find(".spec.", 1, true)
    or path:find(".stories.", 1, true)
    or path:find(".storybook", 1, true)
  then
    return true
  end

  return false
end

local function relative_to(root, path)
  root = root:gsub("/$", "")
  return path:gsub("^" .. vim.pesc(root) .. "/", "")
end

local function within_max_depth(root, path, max_depth)
  if not max_depth then
    return true
  end

  local rel = relative_to(root, path)
  local depth = 0

  for _ in rel:gmatch("/") do
    depth = depth + 1
  end

  return depth <= max_depth
end

local function grep_files(root, pattern)
  if vim.fn.executable("rg") == 1 and is_dir(root) then
    local cmd = { "rg", "--files", "--glob", pattern }

    local result = vim.system(cmd, { cwd = root, text = true }):wait()
    if result.code == 0 and result.stdout and result.stdout ~= "" then
      local files = {}

      for rel in result.stdout:gmatch("[^\r\n]+") do
        table.insert(files, join(root, rel))
      end

      return files
    end
  end

  return vim.fn.glob(join(root, pattern), false, true)
end

local function set_tab_name(name)
  vim.t.workspace_tab_name = name
  vim.t.tab_name = name

  local ok, bufferline = pcall(require, "bufferline")
  if ok and bufferline and bufferline.rename_tab then
    pcall(bufferline.rename_tab, { vim.api.nvim_get_current_tabpage(), name })
  end
end

local function add_file(files, seen, path)
  path = expand(path)

  if seen[path] or not is_file(path) or is_excluded(path) then
    return false
  end

  seen[path] = true
  table.insert(files, path)
  return true
end

---@param root string
---@param specs WorkspaceFileSpec[]
---@param opts? { quickfix?: boolean }
---@return string[]
local function collect_files(root, specs, opts)
  opts = opts or {}
  local files, seen = {}, {}

  for _, spec in ipairs(specs or {}) do
    local include_spec = opts.quickfix or not spec.quickfix_only

    if include_spec and spec.file then
      add_file(files, seen, join(root, spec.file))
    elseif include_spec and spec.abs then
      add_file(files, seen, spec.abs)
    elseif include_spec and spec.first then
      for _, rel in ipairs(spec.first) do
        if add_file(files, seen, join(root, rel)) then
          break
        end
      end
    elseif include_spec and spec.grep then
      local matches = grep_files(root, spec.grep)
      table.sort(matches)

      local added = 0
      for _, path in ipairs(matches) do
        if within_max_depth(root, path, spec.max_depth) and add_file(files, seen, path) then
          added = added + 1
        end

        if added >= (spec.max or 99) then
          break
        end
      end
    elseif include_spec and spec.glob then
      local matches = vim.fn.glob(join(root, spec.glob), false, true)
      table.sort(matches)

      local added = 0
      for _, path in ipairs(matches) do
        if spec.include_dirs or is_file(path) then
          if add_file(files, seen, path) then
            added = added + 1
          end
        end

        if added >= (spec.max or 99) then
          break
        end
      end
    end
  end

  return files
end

local function set_quickfix(files, title)
  local items = vim.tbl_map(function(path)
    return { filename = path, lnum = 1, col = 1, text = vim.fn.fnamemodify(path, ":~:.") }
  end, files)

  vim.fn.setqflist({}, " ", { title = title, items = items })
  vim.cmd "copen"
end

local function open_file_in_tab(tabpage, path, cmd)
  if not vim.api.nvim_tabpage_is_valid(tabpage) then
    return
  end

  pcall(vim.api.nvim_set_current_tabpage, tabpage)
  vim.cmd((cmd or "edit") .. " " .. vim.fn.fnameescape(path))
end

---@param group WorkspaceTabConfig
---@param root string
---@param files? string[]
local function open_tab(group, root, files)
  files = files or collect_files(root, group.specs, { quickfix = false })

  if #files == 0 then
    notify_workspace("Workspace: no files for " .. group.name, vim.log.levels.WARN)
    return files
  end

  vim.cmd("tabnew " .. vim.fn.fnameescape(files[1]))
  local tabpage = vim.api.nvim_get_current_tabpage()

  if group.cwd and is_dir(join(root, group.cwd)) then
    vim.cmd("tcd " .. vim.fn.fnameescape(join(root, group.cwd)))
  elseif is_dir(root) then
    vim.cmd("tcd " .. vim.fn.fnameescape(root))
  end

  set_tab_name(group.name)
  vim.cmd("wincmd =")

  for i = 2, #files do
    local path = files[i]
    local cmd = i % 2 == 0 and "vsplit" or "split"
    vim.defer_fn(function()
      open_file_in_tab(tabpage, path, cmd)
      vim.cmd("wincmd =")
    end, (i - 1) * 25)
  end

  return files
end

---@param config WorkspaceConfig
---@return string[]
local function collect_workspace_files(config)
  local root = type(config.root) == "function" and config.root() or config.root
  root = expand(root)

  local all_files = {}
  for _, group in ipairs(config.tabs or {}) do
    vim.list_extend(all_files, collect_files(root, group.specs, { quickfix = true }))
  end

  return all_files
end

---@param config WorkspaceConfig
---@param root string
---@param opts? { quickfix?: boolean }
---@return { group: WorkspaceTabConfig, files: string[] }[], string[]
local function collect_workspace_plan(config, root, opts)
  opts = opts or {}
  local plan, all_files = {}, {}

  for _, group in ipairs(config.tabs or {}) do
    local files = collect_files(root, group.specs, { quickfix = opts.quickfix })
    table.insert(plan, { group = group, files = files })
    vim.list_extend(all_files, files)
  end

  return plan, all_files
end

---@param config WorkspaceConfig
---@param opts? { quickfix_only?: boolean }
function M.open_workspace(config, opts)
  opts = opts or {}
  local started_at = uv.hrtime()
  local elapsed_ms = function()
    return (uv.hrtime() - started_at) / 1e6
  end

  local root = type(config.root) == "function" and config.root() or config.root
  root = expand(root)

  if opts.quickfix_only then
    local _, files = collect_workspace_plan(config, root, { quickfix = true })
    if #files > MAX_WORKSPACE_FILES then
      notify_workspace(
        string.format("Workspace: refusing to load %d files for %s (limit %d)", #files, config.command, MAX_WORKSPACE_FILES),
        vim.log.levels.ERROR
      )
      return
    end

    set_quickfix(files, config.command)
    notify_workspace(string.format("Workspace: loaded quickfix with %d files for %s in %.1fms", #files, config.command, elapsed_ms()))
    return
  end

  local plan, all_files = collect_workspace_plan(config, root, { quickfix = false })
  if #all_files > MAX_WORKSPACE_FILES then
    notify_workspace(
      string.format("Workspace: refusing to load %d files for %s (limit %d)", #all_files, config.command, MAX_WORKSPACE_FILES),
      vim.log.levels.ERROR
    )
    return
  end

  local tab_count = #plan
  local finish_delay = math.max((tab_count - 1) * 140, 0)

  for tab_index, item in ipairs(plan) do
    finish_delay = math.max(finish_delay, (tab_index - 1) * 140 + math.max(#item.files - 1, 0) * 25)

    vim.defer_fn(function()
      open_tab(item.group, root, item.files)
    end, (tab_index - 1) * 140)
  end

  vim.defer_fn(function()
    set_quickfix(all_files, config.command)
    notify_workspace(
      string.format(
        "Workspace: opened %d tabs and %d files for %s in %.1fms",
        tab_count,
        #all_files,
        config.command,
        elapsed_ms()
      )
    )
  end, finish_delay + 150)
end

---@param spec WorkspaceFileSpec
---@return string
local function format_spec(spec)
  if spec.file then
    return "file: " .. spec.file
  elseif spec.abs then
    return "abs: " .. spec.abs
  elseif spec.first then
    return "first: " .. table.concat(spec.first, " | ")
  elseif spec.grep then
    return string.format("grep: %s max_depth=%s max=%s", spec.grep, tostring(spec.max_depth), tostring(spec.max))
  elseif spec.glob then
    return string.format("glob: %s max=%s", spec.glob, tostring(spec.max))
  end

  return vim.inspect(spec)
end

---@param config WorkspaceConfig
---@param module_name? string
---@return string
local function workspace_preview(config, module_name)
  local lines = {
    "# Workspace Config",
    "",
    "- Command: `" .. config.command .. "`",
    "- Description: " .. (config.desc or ""),
  }

  if module_name then
    table.insert(lines, "- Module: `" .. module_name .. "`")
  end

  local ok, root = pcall(function()
    return type(config.root) == "function" and config.root() or config.root
  end)
  table.insert(lines, "- Root: `" .. tostring(ok and root or config.root) .. "`")
  table.insert(lines, "")
  table.insert(lines, "## Tabs")

  for _, group in ipairs(config.tabs or {}) do
    table.insert(lines, "")
    table.insert(lines, "### " .. group.name)
    if group.cwd then
      table.insert(lines, "- cwd: `" .. group.cwd .. "`")
    end

    for _, spec in ipairs(group.specs or {}) do
      table.insert(lines, "- " .. format_spec(spec))
    end
  end

  table.insert(lines, "")
  table.insert(lines, "## Schema")
  table.insert(lines, "")
  table.insert(lines, "- `file`: exact file path relative to workspace root")
  table.insert(lines, "- `abs`: exact absolute or expandable file path")
  table.insert(lines, "- `first`: first existing workspace-root relative file from candidates")
  table.insert(lines, "- `grep`: ripgrep file glob via `rg --files --glob`; file discovery, not content search")
  table.insert(lines, "- `glob`: Vim glob via `vim.fn.glob()`")
  table.insert(lines, "- `max_depth`: maximum directory depth for `grep` Lua filtering")
  table.insert(lines, "- `max`: maximum files to add for `glob` or `grep`")
  table.insert(lines, "- `quickfix_only`: include only for `:Command!` or `:Command qf`")

  return table.concat(lines, "\n")
end

---@param configs WorkspaceConfigList
function M.pick_config(configs)
  local ok, snacks = pcall(require, "snacks")
  if not ok or not snacks.picker then
    notify_workspace("Workspace: snacks picker is not available", vim.log.levels.WARN)
    return
  end

  local items = {}
  for index, config in ipairs(configs or {}) do
    local module_name = config.module or config.command
    table.insert(items, {
      text = string.format("%s %s", config.command, config.desc or ""),
      command = config.command,
      desc = config.desc or "",
      config = config,
      idx = index,
      preview = { text = workspace_preview(config, module_name), ft = "markdown", loc = false },
    })
  end

  snacks.picker.pick {
    source = "workspace_configs",
    title = "Workspace Configs",
    items = items,
    format = function(item)
      local command = string.format("%-44s", item.command or item.text or "")
      return {
        { command, "Title" },
        { item.desc ~= "" and item.desc or "No description", "Comment" },
      }
    end,
    preview = "preview",
    actions = {
      confirm = function(picker, item)
        if not item or not item.config then
          return
        end

        picker:close()
        M.open_workspace(item.config)
      end,
      quickfix = function(picker, item)
        if not item or not item.config then
          return
        end

        picker:close()
        M.open_workspace(item.config, { quickfix_only = true })
      end,
    },
    win = {
      input = {
        keys = {
          ["<C-q>"] = { "quickfix", mode = { "n", "i" }, desc = "Open quickfix only" },
        },
      },
    },
  }
end

---@param configs WorkspaceConfigList
function M.register(configs)
  for _, config in ipairs(configs) do
    vim.api.nvim_create_user_command(config.command, function(args)
      local arg = vim.trim(args.args or "")
      M.open_workspace(config, { quickfix_only = args.bang or arg == "qf" or arg == "quickfix" })
    end, {
      bang = true,
      nargs = "?",
      complete = function()
        return { "qf", "quickfix" }
      end,
      desc = config.desc or ("Open " .. config.command),
      force = true,
    })
  end
end

return M
