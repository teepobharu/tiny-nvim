-- Centralized plugin disable mechanism
-- Reads vim.g.disabled_plugins and returns { "plugin/name", enabled = false } specs
-- Lazy.nvim spec merging: this overrides `enabled` in core plugin specs from plugins/*.lua
--
-- Set in mydefault-nvim-config.lua (global defaults) or .nvim-config.lua (per-project override)
-- Load order: .nvim-config.lua (1st) -> mydefault-nvim-config.lua (2nd, uses `or` guard) -> lazy.setup
--
-- Usage:
--   vim.g.disabled_plugins = { "echasnovski/mini.pick", "jellydn/tiny-term.nvim" }
--
-- Commands:
--   :DisabledPlugins            - Show currently disabled plugins
--   :ProjectSettingEditPicker   - Snacks picker with two modes (M-s to switch):
--     Mode 1 (default): vim.g.disabled_plugins — browse all lazy plugins
--     Mode 2 (M-s):     vim.g.enable_extra_plugins — browse plugins/extra/ files
--
--     Shared keys:
--       <Tab>/<C-a>  select items     <CR>   copy selected names
--       <C-y>        copy as config   <C-w>  write to .nvim-config.lua
--       <C-e>        open config      <M-s>  switch mode
--       <M-o>        open dir/file    <C-d>/<C-n>  filter disabled/enabled
--       <C-x>        reset filter
--     Mode 1 only:
--       <M-g>        open GitHub page   <M-r>  open GitHub releases
--       <M-k>        open DeepWiki page

local disabled = vim.g.disabled_plugins or {}

-- Build specs that disable each listed plugin
local specs = {}
for _, name in ipairs(disabled) do
  table.insert(specs, { name, enabled = false })
end

-- :DisabledPlugins — list what's currently disabled
vim.api.nvim_create_user_command("DisabledPlugins", function()
  if #disabled == 0 then
    vim.notify("No plugins disabled via vim.g.disabled_plugins", vim.log.levels.INFO)
    return
  end
  local lines = { "Disabled plugins (vim.g.disabled_plugins):" }
  for _, name in ipairs(disabled) do
    table.insert(lines, "  - " .. name)
  end
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end, { desc = "Show currently disabled plugins" })

-- ═══════════════════════════════════════════════════════════════════════════════
-- Shared helpers
-- ═══════════════════════════════════════════════════════════════════════════════

--- Scan lua/plugins/extra/ for available .lua files (returns list of base names)
local function scan_extras_dir()
  local extras_dir = vim.fn.stdpath "config" .. "/lua/plugins/extra"
  local names = {}
  local handle = vim.loop.fs_scandir(extras_dir)
  if handle then
    while true do
      local name, type = vim.loop.fs_scandir_next(handle)
      if not name then
        break
      end
      if type == "file" and name:match "%.lua$" then
        local base = name:gsub("%.lua$", "")
        table.insert(names, base)
      end
    end
  end
  table.sort(names)
  return names
end

--- Get .nvim-config.lua path in cwd
local function get_config_path()
  return vim.fn.getcwd() .. "/.nvim-config.lua"
end

--- Open .nvim-config.lua in a vertical split
---@param filepath string
local function open_config_in_vsplit(filepath)
  vim.cmd("vsplit " .. vim.fn.fnameescape(filepath))
end

--- Write a vim.g assignment block into .nvim-config.lua
--- Appends or replaces the vim.g.<var_name> block
---@param var_name string e.g. "disabled_plugins" or "enable_extra_plugins"
---@param values string[] list of plugin names
local function write_config_block(var_name, values)
  local filepath = get_config_path()
  local full_var = "vim.g." .. var_name

  -- Build the new block
  local block_lines = { full_var .. " = {" }
  for _, v in ipairs(values) do
    table.insert(block_lines, '  "' .. v .. '",')
  end
  table.insert(block_lines, "}")
  local new_block = table.concat(block_lines, "\n")

  -- Read existing content
  local existing = nil
  local f = io.open(filepath, "r")
  if f then
    existing = f:read "*a"
    f:close()
  end

  local new_content
  local initialized_via_project_settings = false
  if existing and existing ~= "" then
    -- Try to find and replace existing vim.g.<var_name> = { ... } block
    -- Pattern: vim.g.<var_name> = {\n...\n}
    local pattern = vim.pesc(full_var) .. "%s*=%s*%b{}"
    -- TODO: revise if still want this behavior to override whole block
    -- does also modified commented block
    local replaced = false and existing:gsub(pattern, function()
      return new_block
    end)
    if replaced and replaced ~= existing then
      new_content = replaced
    else
      -- Not found, append at end
      new_content = existing:gsub("%s*$", "") .. "\n\n" .. new_block .. "\n"
    end
  else
    -- New file: initialize with full ProjectSettings template, then append our block.
    -- :ProjectSettings creates .nvim-config.lua with marker-based reference + opens it in edit + .ignore vsplit.
    -- We run it first, then re-read and append the config block, then reload the buffer.
    vim.cmd "ProjectSettings"
    -- Re-read the file that ProjectSettings just created
    local f2 = io.open(filepath, "r")
    if f2 then
      existing = f2:read "*a"
      f2:close()
      new_content = existing:gsub("%s*$", "") .. "\n\n" .. new_block .. "\n"
    else
      -- Fallback if ProjectSettings didn't create the file
      new_content = "-- Project-specific Neovim configuration\n\n" .. new_block .. "\n"
    end
    initialized_via_project_settings = true
  end

  local out = io.open(filepath, "w")
  if not out then
    vim.notify("Failed to write " .. filepath, vim.log.levels.ERROR)
    return false
  end
  out:write(new_content)
  out:close()

  if initialized_via_project_settings then
    -- :ProjectSettings already opened the file + .ignore vsplit; just reload and go to end
    vim.cmd("edit " .. vim.fn.fnameescape(filepath))
    vim.cmd "normal! G"
  else
    open_config_in_vsplit(filepath)
    vim.cmd "normal! G"
  end
  return true
end

--- Get selected names from picker (falls back to current item)
local function get_selected_names(picker)
  local sel = picker:selected { fallback = true }
  local names = {}
  for _, item in ipairs(sel) do
    if item.data then
      table.insert(names, item.data)
    end
  end
  return names
end

--- Derive GitHub URL from a plugin name like "owner/repo" or a .git URL
---@param plugin_name string e.g. "folke/snacks.nvim"
---@return string|nil url e.g. "https://github.com/folke/snacks.nvim"
local function github_url_for(plugin_name)
  if not plugin_name then
    return nil
  end
  -- Already a full URL
  if plugin_name:match "^https?://" then
    return (plugin_name:gsub("%.git$", ""))
  end
  -- owner/repo format
  if plugin_name:match "^[%w%-_.]+/[%w%-_.]+$" then
    return "https://github.com/" .. plugin_name
  end
  return nil
end

--- Derive DeepWiki URL from a plugin name like "owner/repo"
---@param plugin_name string e.g. "folke/snacks.nvim"
---@return string|nil url e.g. "https://deepwiki.com/folke/snacks.nvim"
local function deepwiki_url_for(plugin_name)
  if not plugin_name then
    return nil
  end
  if plugin_name:match "^[%w%-_.]+/[%w%-_.]+$" then
    return "https://deepwiki.com/" .. plugin_name
  end
  return nil
end

-- Forward declaration for cross-referencing between the two pickers
local open_extras_plugins_picker

-- ═══════════════════════════════════════════════════════════════════════════════
-- Disabled plugins picker (mode 1: vim.g.disabled_plugins)
-- ═══════════════════════════════════════════════════════════════════════════════

local function open_disabled_plugins_picker()
  local ok, lazy = pcall(require, "lazy")
  if not ok then
    vim.notify("lazy.nvim not loaded yet", vim.log.levels.ERROR)
    return
  end

  -- Build disabled lookup (vim.g.disabled_plugins uses owner/repo format)
  local disabled_set = {}
  for _, d in ipairs(disabled) do
    disabled_set[d] = true
  end

  local filter_mode = nil -- nil = all, "disabled", "enabled"

  Snacks.picker.pick {
    source = "project_setting_disabled",
    title = "vim.g.disabled_plugins",
    finder = function()
      -- Collect all plugins: enabled (from lazy.plugins()) + disabled (from spec.disabled)
      -- Three disable states:
      --   "disabled"      = in vim.g.disabled_plugins (user-configurable via this picker)
      --   "disabled(spec)"= disabled by spec `enabled = false` in plugin files (not user-configurable)
      --   "enabled"       = active
      local all_plugins = {} -- { name = owner/repo, short_name = short, dir = path, from_spec_disabled = bool }
      local seen = {}

      -- Enabled plugins from lazy.plugins()
      for _, p in ipairs(lazy.plugins()) do
        local name = p[1] or p.name
        if name and not seen[name] then
          seen[name] = true
          table.insert(all_plugins, { name = name, short_name = p.name, dir = p.dir, from_spec_disabled = false })
        end
      end

      -- Disabled plugins from lazy spec (not in lazy.plugins())
      -- This includes both vim.g.disabled_plugins entries AND plugins with `enabled = false` in their spec
      local spec_disabled = require("lazy.core.config").spec
      if spec_disabled and spec_disabled.disabled then
        for _, p in pairs(spec_disabled.disabled) do
          local name = p[1] or p.name
          if name and not seen[name] then
            seen[name] = true
            table.insert(all_plugins, { name = name, short_name = p.name, dir = p.dir, from_spec_disabled = true })
          end
        end
      end

      table.sort(all_plugins, function(a, b)
        return a.name < b.name
      end)

      local items = {}
      for _, plugin in ipairs(all_plugins) do
        local name = plugin.name
        local is_user_disabled = disabled_set[name] ~= nil
        local is_spec_disabled = plugin.from_spec_disabled and not is_user_disabled
        local is_disabled = is_user_disabled or is_spec_disabled
        local dir_exists = plugin.dir and vim.loop.fs_stat(plugin.dir) ~= nil
        local is_missing = not dir_exists

        local status_label, status_hl
        if is_user_disabled and is_missing then
          status_label = "disabled ~missing"
          status_hl = "DiagnosticWarn"
        elseif is_user_disabled then
          status_label = "disabled"
          status_hl = "DiagnosticError"
        elseif is_spec_disabled and is_missing then
          status_label = "disabled(spec) ~missing"
          status_hl = "DiagnosticWarn"
        elseif is_spec_disabled then
          status_label = "disabled(spec)"
          status_hl = "DiagnosticHint"
        elseif is_missing then
          status_label = "enabled ~missing"
          status_hl = "DiagnosticWarn"
        else
          status_label = "enabled"
          status_hl = "DiagnosticOk"
        end

        -- Filter: "disabled" shows both user-disabled and spec-disabled
        local show = true
        if filter_mode == "disabled" then
          show = is_disabled
        elseif filter_mode == "enabled" then
          show = not is_disabled
        end

        if show then
          table.insert(items, {
            text = name .. " -- " .. status_label,
            data = name,
            plugin_name = name,
            plugin_dir = plugin.dir,
            is_disabled = is_disabled,
            is_user_disabled = is_user_disabled,
            is_spec_disabled = is_spec_disabled,
            is_missing = is_missing,
            status_label = status_label,
            status_hl = status_hl,
          })
        end
      end
      return items
    end,
    format = function(item)
      local name = item.plugin_name or item.data or item.text
      return {
        { name, "Normal" },
        { " -- ", "Comment" },
        { item.status_label, item.status_hl },
      }
    end,
    layout = {
      preset = "select",
      layout = { width = 0.5, height = 0.6 },
    },
    confirm = function(picker)
      local names = get_selected_names(picker)
      if #names == 0 then
        return
      end
      local text = table.concat(names, "\n")
      vim.fn.setreg("+", text)
      picker:close()
      Snacks.notify("Copied " .. #names .. " plugin name(s)", { title = "disabled_plugins" })
    end,
    actions = {
      copy_config = function(picker)
        local names = get_selected_names(picker)
        if #names == 0 then
          Snacks.notify("No plugins selected", { title = "disabled_plugins", level = "WARN" })
          return
        end
        local lines = { "vim.g.disabled_plugins = {" }
        for _, name in ipairs(names) do
          table.insert(lines, '  "' .. name .. '",')
        end
        table.insert(lines, "}")
        local text = table.concat(lines, "\n")
        vim.fn.setreg("+", text)
        picker:close()
        Snacks.notify("Copied config block:\n```lua\n" .. text .. "\n```", { title = "disabled_plugins" })
      end,
      write_config = function(picker)
        local names = get_selected_names(picker)
        if #names == 0 then
          Snacks.notify("No plugins selected", { title = "disabled_plugins", level = "WARN" })
          return
        end
        picker:close()
        if write_config_block("disabled_plugins", names) then
          Snacks.notify(
            "Wrote " .. #names .. " plugins to " .. get_config_path() .. "\nRestart Neovim to apply.",
            { title = "disabled_plugins" }
          )
        end
      end,
      open_config = function(picker)
        picker:close()
        vim.cmd("edit " .. vim.fn.fnameescape(get_config_path()))
      end,
      open_github = function(picker)
        local item = picker:current()
        if not item or not item.data then
          return
        end
        local url = github_url_for(item.data)
        if url then
          vim.ui.open(url)
        else
          Snacks.notify("No GitHub URL for: " .. item.data, { title = "disabled_plugins", level = "WARN" })
        end
      end,
      open_releases = function(picker)
        local item = picker:current()
        if not item or not item.data then
          return
        end
        local url = github_url_for(item.data)
        if url then
          vim.ui.open(url .. "/releases")
        else
          Snacks.notify("No GitHub URL for: " .. item.data, { title = "disabled_plugins", level = "WARN" })
        end
      end,
      open_deepwiki = function(picker)
        local item = picker:current()
        if not item or not item.data then
          return
        end
        local url = deepwiki_url_for(item.data)
        if url then
          vim.ui.open(url)
        else
          Snacks.notify("No DeepWiki URL for: " .. item.data, { title = "disabled_plugins", level = "WARN" })
        end
      end,
      open_dir = function(picker)
        local item = picker:current()
        if not item or not item.plugin_dir then
          Snacks.notify("No plugin directory available", { title = "disabled_plugins", level = "WARN" })
          return
        end
        if not vim.loop.fs_stat(item.plugin_dir) then
          Snacks.notify("Directory does not exist: " .. item.plugin_dir, { title = "disabled_plugins", level = "WARN" })
          return
        end
        picker:close()
        vim.cmd("edit " .. vim.fn.fnameescape(item.plugin_dir))
      end,
      switch_mode = function(picker)
        picker:close()
        vim.schedule(open_extras_plugins_picker)
      end,
      filter_disabled = function(picker)
        filter_mode = filter_mode == "disabled" and nil or "disabled"
        local label = filter_mode and ("filter: " .. filter_mode) or "filter: all"
        Snacks.notify(label, { title = "disabled_plugins" })
        picker:find()
      end,
      filter_enabled = function(picker)
        filter_mode = filter_mode == "enabled" and nil or "enabled"
        local label = filter_mode and ("filter: " .. filter_mode) or "filter: all"
        Snacks.notify(label, { title = "disabled_plugins" })
        picker:find()
      end,
      filter_reset = function(picker)
        filter_mode = nil
        Snacks.notify("filter: all", { title = "disabled_plugins" })
        picker:find()
      end,
    },
    win = {
      input = {
        keys = {
          ["<C-y>"] = { "copy_config", mode = { "n", "i" }, desc = "Copy as config block" },
          ["<C-w>"] = { "write_config", mode = { "n", "i" }, desc = "Write to .nvim-config.lua" },
          ["<C-e>"] = { "open_config", mode = { "n", "i" }, desc = "Open .nvim-config.lua" },
          ["<M-o>"] = { "open_dir", mode = { "n", "i" }, desc = "Open plugin dir in editor" },
          ["<M-g>"] = { "open_github", mode = { "n", "i" }, desc = "Open GitHub page" },
          ["<M-r>"] = { "open_releases", mode = { "n", "i" }, desc = "Open GitHub releases" },
          ["<M-k>"] = { "open_deepwiki", mode = { "n", "i" }, desc = "Open DeepWiki page" },
          ["<M-s>"] = { "switch_mode", mode = { "n", "i" }, desc = "Switch to extras mode" },
          ["<C-d>"] = { "filter_disabled", mode = { "n", "i" }, desc = "Filter: disabled" },
          ["<C-n>"] = { "filter_enabled", mode = { "n", "i" }, desc = "Filter: enabled" },
          ["<C-x>"] = { "filter_reset", mode = { "n", "i" }, desc = "Filter: reset" },
        },
        footer = "M-s switch, M-o dir, C-d/n/x filter, C-w write, C-y copy, M-g/r/k gh/rel/dws",
        footer_pos = "center",
      },
      list = {
        keys = {
          ["<C-y>"] = { "copy_config", mode = { "n" }, desc = "Copy as config block" },
          ["<C-w>"] = { "write_config", mode = { "n" }, desc = "Write to .nvim-config.lua" },
          ["<C-e>"] = { "open_config", mode = { "n" }, desc = "Open .nvim-config.lua" },
          ["<M-o>"] = { "open_dir", mode = { "n" }, desc = "Open plugin dir in editor" },
          ["<M-g>"] = { "open_github", mode = { "n" }, desc = "Open GitHub page" },
          ["<M-r>"] = { "open_releases", mode = { "n" }, desc = "Open GitHub releases" },
          ["<M-k>"] = { "open_deepwiki", mode = { "n" }, desc = "Open DeepWiki page" },
          ["<M-s>"] = { "switch_mode", mode = { "n" }, desc = "Switch to extras mode" },
          ["<C-d>"] = { "filter_disabled", mode = { "n" }, desc = "Filter: disabled" },
          ["<C-n>"] = { "filter_enabled", mode = { "n" }, desc = "Filter: enabled" },
          ["<C-x>"] = { "filter_reset", mode = { "n" }, desc = "Filter: reset" },
        },
      },
    },
  }
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- Extras plugins picker (mode 2: vim.g.enable_extra_plugins)
-- ═══════════════════════════════════════════════════════════════════════════════

open_extras_plugins_picker = function()
  -- Scan available files in plugins/extra/
  local available_on_disk = scan_extras_dir()
  local disk_set = {}
  for _, name in ipairs(available_on_disk) do
    disk_set[name] = true
  end

  -- Current enabled extras from vim.g
  local enabled_extras = vim.g.enable_extra_plugins or {}
  local enabled_set = {}
  for _, name in ipairs(enabled_extras) do
    enabled_set[name] = true
  end

  -- Build combined list: all on-disk files + any vim.g entries missing from disk
  local all_names_set = {}
  local all_names = {}
  for _, name in ipairs(available_on_disk) do
    if not all_names_set[name] then
      all_names_set[name] = true
      table.insert(all_names, name)
    end
  end
  for _, name in ipairs(enabled_extras) do
    if not all_names_set[name] then
      all_names_set[name] = true
      table.insert(all_names, name)
    end
  end
  table.sort(all_names)

  local filter_mode = nil -- nil = all, "enabled", "disabled", "missing"

  Snacks.picker.pick {
    source = "project_setting_extras",
    title = "vim.g.enable_extra_plugins",
    finder = function()
      local items = {}
      for _, name in ipairs(all_names) do
        local is_enabled = enabled_set[name] ~= nil
        local exists_on_disk = disk_set[name] ~= nil
        local is_missing = is_enabled and not exists_on_disk

        -- Status: enabled + exists -> "enabled", enabled + !exists -> "missing!",
        --         !enabled + exists -> "disabled"
        local status_label, status_hl
        if is_missing then
          status_label = "missing!"
          status_hl = "DiagnosticWarn"
        elseif is_enabled then
          status_label = "enabled"
          status_hl = "DiagnosticOk"
        else
          status_label = "disabled"
          status_hl = "DiagnosticError"
        end

        -- Apply filter
        local show = true
        if filter_mode == "enabled" then
          show = is_enabled and not is_missing
        elseif filter_mode == "disabled" then
          show = not is_enabled
        elseif filter_mode == "missing" then
          show = is_missing
        end

        if show then
          table.insert(items, {
            text = name .. " -- " .. status_label,
            data = name,
            plugin_name = name,
            is_enabled = is_enabled,
            is_missing = is_missing,
            exists_on_disk = exists_on_disk,
            status_label = status_label,
            status_hl = status_hl,
          })
        end
      end
      return items
    end,
    format = function(item)
      local name = item.plugin_name or item.data or item.text
      return {
        { name, "Normal" },
        { " -- ", "Comment" },
        { item.status_label, item.status_hl },
      }
    end,
    layout = {
      preset = "select",
      layout = { width = 0.5, height = 0.6 },
    },
    confirm = function(picker)
      local names = get_selected_names(picker)
      if #names == 0 then
        return
      end
      local text = table.concat(names, "\n")
      vim.fn.setreg("+", text)
      picker:close()
      Snacks.notify("Copied " .. #names .. " extra plugin name(s)", { title = "enable_extra_plugins" })
    end,
    actions = {
      copy_config = function(picker)
        local names = get_selected_names(picker)
        if #names == 0 then
          Snacks.notify("No plugins selected", { title = "enable_extra_plugins", level = "WARN" })
          return
        end
        local lines = { "vim.g.enable_extra_plugins = {" }
        for _, name in ipairs(names) do
          table.insert(lines, '  "' .. name .. '",')
        end
        table.insert(lines, "}")
        local text = table.concat(lines, "\n")
        vim.fn.setreg("+", text)
        picker:close()
        Snacks.notify("Copied config block:\n```lua\n" .. text .. "\n```", { title = "enable_extra_plugins" })
      end,
      write_config = function(picker)
        local names = get_selected_names(picker)
        if #names == 0 then
          Snacks.notify("No plugins selected", { title = "enable_extra_plugins", level = "WARN" })
          return
        end
        picker:close()
        if write_config_block("enable_extra_plugins", names) then
          Snacks.notify(
            "Wrote " .. #names .. " extras to " .. get_config_path() .. "\nRestart Neovim to apply.",
            { title = "enable_extra_plugins" }
          )
        end
      end,
      open_config = function(picker)
        picker:close()
        vim.cmd("edit " .. vim.fn.fnameescape(get_config_path()))
      end,
      open_dir = function(picker)
        local item = picker:current()
        if not item or not item.data then
          return
        end
        local extras_dir = vim.fn.stdpath "config" .. "/lua/plugins/extra"
        local filepath = extras_dir .. "/" .. item.data .. ".lua"
        if vim.loop.fs_stat(filepath) then
          picker:close()
          vim.cmd("edit " .. vim.fn.fnameescape(filepath))
        else
          Snacks.notify("File does not exist: " .. filepath, { title = "enable_extra_plugins", level = "WARN" })
        end
      end,
      switch_mode = function(picker)
        picker:close()
        vim.schedule(open_disabled_plugins_picker)
      end,
      filter_disabled = function(picker)
        filter_mode = filter_mode == "disabled" and nil or "disabled"
        local label = filter_mode and ("filter: " .. filter_mode) or "filter: all"
        Snacks.notify(label, { title = "enable_extra_plugins" })
        picker:find()
      end,
      filter_enabled = function(picker)
        filter_mode = filter_mode == "enabled" and nil or "enabled"
        local label = filter_mode and ("filter: " .. filter_mode) or "filter: all"
        Snacks.notify(label, { title = "enable_extra_plugins" })
        picker:find()
      end,
      filter_reset = function(picker)
        filter_mode = nil
        Snacks.notify("filter: all", { title = "enable_extra_plugins" })
        picker:find()
      end,
    },
    win = {
      input = {
        keys = {
          ["<C-y>"] = { "copy_config", mode = { "n", "i" }, desc = "Copy as config block" },
          ["<C-w>"] = { "write_config", mode = { "n", "i" }, desc = "Write to .nvim-config.lua" },
          ["<C-e>"] = { "open_config", mode = { "n", "i" }, desc = "Open .nvim-config.lua" },
          ["<M-o>"] = { "open_dir", mode = { "n", "i" }, desc = "Open extra file in editor" },
          ["<M-s>"] = { "switch_mode", mode = { "n", "i" }, desc = "Switch to disabled mode" },
          ["<C-d>"] = { "filter_disabled", mode = { "n", "i" }, desc = "Filter: disabled" },
          ["<C-n>"] = { "filter_enabled", mode = { "n", "i" }, desc = "Filter: enabled" },
          ["<C-x>"] = { "filter_reset", mode = { "n", "i" }, desc = "Filter: reset" },
        },
        footer = "M-s switch, M-o open, C-w:write C-y:copy filter(C-d,n,x)",
        footer_pos = "center",
      },
      list = {
        keys = {
          ["<C-y>"] = { "copy_config", mode = { "n" }, desc = "Copy as config block" },
          ["<C-w>"] = { "write_config", mode = { "n" }, desc = "Write to .nvim-config.lua" },
          ["<C-e>"] = { "open_config", mode = { "n" }, desc = "Open .nvim-config.lua" },
          ["<M-o>"] = { "open_dir", mode = { "n" }, desc = "Open extra file in editor" },
          ["<M-s>"] = { "switch_mode", mode = { "n" }, desc = "Switch to disabled mode" },
          ["<C-d>"] = { "filter_disabled", mode = { "n" }, desc = "Filter: disabled" },
          ["<C-n>"] = { "filter_enabled", mode = { "n" }, desc = "Filter: enabled" },
          ["<C-x>"] = { "filter_reset", mode = { "n" }, desc = "Filter: reset" },
        },
      },
    },
  }
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- Command registration
-- ═══════════════════════════════════════════════════════════════════════════════

-- Keep old command as alias
vim.api.nvim_create_user_command("DisablePluginsPicker", function()
  vim.schedule(open_disabled_plugins_picker)
end, { desc = "Browse plugins to disable/enable (snacks picker)" })

-- New unified command
vim.api.nvim_create_user_command("ProjectSettingEditPicker", function()
  vim.schedule(open_disabled_plugins_picker)
end, { desc = "Edit project plugin settings (disabled/extras) via snacks picker" })

-- Map localleader mappings (normal mode)
vim.keymap.set(
  "n",
  "<localleader>rsd",
  ":ProjectSettingEditPicker<CR>",
  { noremap = true, silent = true, desc = "ProjectSettingEditPicker (disabled/extras)" }
)
vim.keymap.set(
  "n",
  "<localleader>rsN",
  ":ProjectSettings<CR>",
  { noremap = true, silent = true, desc = "ProjectSettings Init/Update" }
)

return specs
