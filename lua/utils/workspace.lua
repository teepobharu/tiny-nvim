require("utils.workspace.schema")

local M = {}

local uv = vim.uv or vim.loop

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
local function open_tab(group, root)
  local files = collect_files(root, group.specs, { quickfix = false })

  if #files == 0 then
    vim.notify("Workspace: no files for " .. group.name, vim.log.levels.WARN)
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
---@param opts? { quickfix_only?: boolean }
function M.open_workspace(config, opts)
  opts = opts or {}

  if opts.quickfix_only then
    set_quickfix(collect_workspace_files(config), config.command)
    return
  end

  local root = type(config.root) == "function" and config.root() or config.root
  root = expand(root)
  local all_files = {}
  local tab_count = #(config.tabs or {})

  for tab_index, group in ipairs(config.tabs or {}) do
    vim.defer_fn(function()
      local files = open_tab(group, root)
      vim.list_extend(all_files, files)

      if tab_index == tab_count then
        vim.defer_fn(function()
          set_quickfix(all_files, config.command)
        end, 100)
      end
    end, (tab_index - 1) * 140)
  end
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
