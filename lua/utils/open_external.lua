-- Open files/dirs in external editors and apps.
-- Usage: require("utils.open_external").pick(path)
--        require("utils.open_external").pick_current()

local M = {}

local is_mac = jit.os == "OSX"

-- Settings-profiles plugin in template vault already points to the profiles dir;
-- rsync copies it so new vaults auto-attach. Nothing to set here.
local OBSIDIAN_TEMPLATE_VAULT = "/Users/tharutaipree/Personal/mynotes"
local SETTINGS_PROFILES_PLUGIN_ID = "settings-profiles"
local OBSIDIAN_SEED_EXCLUDES = {
  "workspace",
  "workspace.json",
  "workspace-mobile.json",
  "workspaces.json",
  "cache",
  "*.json.bak",
  "copilot-index-*.json",
}

-- Encode path for obsidian:// URIs
local function uri_encode(s)
  return (s:gsub("[^%w%-%.%_%~%/]", function(c)
    return string.format("%%%02X", c:byte())
  end))
end

local function app_exists(bundle_name)
  if not is_mac then return false end
  local paths = {
    "/Applications/" .. bundle_name,
    vim.fn.expand("~/Applications/") .. bundle_name,
  }
  for _, p in ipairs(paths) do
    if vim.uv.fs_stat(p) then return true end
  end
  return false
end

local function cli_exists(cmd)
  return vim.fn.executable(cmd) == 1
end

local function spawn_cli(cmd, args)
  vim.system({ cmd, unpack(args) }, { detach = true })
end

local function open_app(app, path)
  vim.system({ "open", "-na", app, "--args", path }, { detach = true })
end

local function open_app_simple(app, path)
  vim.system({ "open", "-a", app, path }, { detach = true })
end

local function open_uri(uri)
  vim.ui.open(uri)
end

local function obsidian_uri(path)
  return "obsidian://open?path=" .. uri_encode(path)
end

local function shell_command(cmd, args)
  local parts = { cmd }
  for _, arg in ipairs(args or {}) do
    table.insert(parts, vim.fn.shellescape(tostring(arg)))
  end
  return table.concat(parts, " ")
end

local function obsidian_rsync_args(src, dst)
  local args = { "rsync", "-a" }
  for _, pattern in ipairs(OBSIDIAN_SEED_EXCLUDES) do
    table.insert(args, "--exclude=" .. pattern)
  end
  table.insert(args, src)
  table.insert(args, dst)
  return args
end

local function obsidian_rsync_command(src, dst)
  local args = obsidian_rsync_args(src, dst)
  table.remove(args, 1)
  return shell_command("rsync", args)
end

---Find longest-prefix matching known Obsidian vault for path.
---@param path string
---@return string|nil vault_path
function M.obsidian_find_vault(path)
  local registry = vim.fn.expand("~/Library/Application Support/obsidian/obsidian.json")
  local f = io.open(registry, "r")
  if not f then return nil end
  local ok, data = pcall(vim.json.decode, f:read("*a"))
  f:close()
  if not ok or not data or not data.vaults then return nil end
  local best, best_len = nil, 0
  for _, v in pairs(data.vaults) do
    local vp = v.path
    if vp and (path == vp or path:sub(1, #vp + 1) == vp .. "/") and #vp > best_len then
      best, best_len = vp, #vp
    end
  end
  return best
end

---@param dir string target directory
---@param on_done function called after rsync completes (or skipped)
function M.bootstrap_obsidian_vault(dir, on_done)
  local obsidian_dir = dir .. "/.obsidian"
  if vim.uv.fs_stat(obsidian_dir) then
    on_done()
    return
  end

  vim.ui.select({ "Yes", "No" }, {
    prompt = "Bootstrap .obsidian from main vault (" .. vim.fn.fnamemodify(OBSIDIAN_TEMPLATE_VAULT, ":~") .. ")?",
  }, function(choice)
    if choice ~= "Yes" then
      on_done()
      return
    end
    local src = OBSIDIAN_TEMPLATE_VAULT .. "/.obsidian/"
    local dst = obsidian_dir .. "/"
    vim.system(
      obsidian_rsync_args(src, dst),
      { detach = false },
      function(result)
        vim.schedule(function()
          if result.code ~= 0 then
            vim.notify("Obsidian vault bootstrap failed:\n" .. (result.stderr or ""), vim.log.levels.ERROR)
          else
            vim.notify("Obsidian vault seeded at " .. obsidian_dir, vim.log.levels.INFO)
          end
          on_done()
        end)
      end
    )
  end)
end

---@param path string absolute path
---@return "file"|"dir"|"other"
local function path_kind(path)
  local stat = vim.uv.fs_stat(path)
  if not stat then return "other" end
  if stat.type == "directory" then return "dir" end
  return "file"
end

local function parent_path(path)
  local parent = vim.fn.fnamemodify(path, ":h")
  if parent == "" or parent == path then return nil end
  return parent
end

local function obsidian_seed_dir(path)
  if path_kind(path) == "dir" then return path end
  return parent_path(path) or path
end

local function obsidian_seed_command(path)
  local seed_dir = obsidian_seed_dir(path)
  local obsidian_dir = seed_dir .. "/.obsidian"
  local src = OBSIDIAN_TEMPLATE_VAULT .. "/.obsidian/"
  local dst = obsidian_dir .. "/"
  return ("[ -d %s ] || %s; %s"):format(
    vim.fn.shellescape(obsidian_dir),
    obsidian_rsync_command(src, dst),
    shell_command("open", { obsidian_uri(path) })
  )
end

local function obsidian_profile_switcher_command(path)
  local seed_dir = obsidian_seed_dir(path)
  local obsidian_dir = seed_dir .. "/.obsidian"
  local src = OBSIDIAN_TEMPLATE_VAULT .. "/.obsidian"
  local dst_plugin_dir = obsidian_dir .. "/plugins/" .. SETTINGS_PROFILES_PLUGIN_ID
  return table.concat({
    shell_command("mkdir", { "-p", obsidian_dir .. "/plugins" }),
    shell_command("cp", { src .. "/hotkeys.json", obsidian_dir .. "/hotkeys.json" }),
    "printf '[\\n  \"settings-profiles\"\\n]\\n' > " .. vim.fn.shellescape(obsidian_dir .. "/community-plugins.json"),
    obsidian_rsync_command(src .. "/plugins/" .. SETTINGS_PROFILES_PLUGIN_ID .. "/", dst_plugin_dir .. "/"),
    shell_command("open", { obsidian_uri(path) }),
  }, "; ")
end

---@param dir string target directory
---@param on_done function called after bootstrap completes (or skipped)
function M.bootstrap_obsidian_profile_switcher(dir, on_done)
  local obsidian_dir = dir .. "/.obsidian"
  local src_obsidian = OBSIDIAN_TEMPLATE_VAULT .. "/.obsidian"
  local plugin_dir = obsidian_dir .. "/plugins/" .. SETTINGS_PROFILES_PLUGIN_ID

  local already_seeded = vim.uv.fs_stat(plugin_dir)
    and vim.uv.fs_stat(obsidian_dir .. "/hotkeys.json")
    and vim.uv.fs_stat(obsidian_dir .. "/community-plugins.json")
  if already_seeded then
    on_done()
    return
  end

  vim.ui.select({ "Yes", "No" }, {
    prompt = "Seed hotkeys + Settings Profiles only into " .. vim.fn.fnamemodify(obsidian_dir, ":~") .. "?",
  }, function(choice)
    if choice ~= "Yes" then
      on_done()
      return
    end

    local ok, err = pcall(function()
      vim.fn.mkdir(obsidian_dir .. "/plugins", "p")
      vim.fn.writefile(vim.fn.readfile(src_obsidian .. "/hotkeys.json"), obsidian_dir .. "/hotkeys.json")
      vim.fn.writefile({ "[", '  "' .. SETTINGS_PROFILES_PLUGIN_ID .. '"', "]" }, obsidian_dir .. "/community-plugins.json")
    end)

    if not ok then
      vim.notify("Obsidian profile-switcher seed failed:\n" .. tostring(err), vim.log.levels.ERROR)
      on_done()
      return
    end

    vim.system(
      obsidian_rsync_args(src_obsidian .. "/plugins/" .. SETTINGS_PROFILES_PLUGIN_ID .. "/", plugin_dir .. "/"),
      { detach = false },
      function(result)
        vim.schedule(function()
          if result.code ~= 0 then
            vim.notify("Obsidian Settings Profiles plugin seed failed:\n" .. (result.stderr or ""), vim.log.levels.ERROR)
          else
            vim.notify("Obsidian hotkeys + Settings Profiles seeded at " .. obsidian_dir, vim.log.levels.INFO)
          end
          on_done()
        end)
      end
    )
  end)
end

-- Category icons for grouping in picker display
local ICON_CODING = ""
local CAT_ICON = {
  Editor = ICON_CODING,
  IDE = ICON_CODING,
  Browser = "󰖟",
  Notes = "󰰥",
  ["File Manager"] = "󰉋",
  System = "󰀻",
}

-- App definitions (ordered; accept=nil means accept all)
M.apps = {
  {
    name = "Cursor",
    icon = "",
    category = "Editor",
    detect = function() return cli_exists("cursor") or app_exists("Cursor.app") end,
    command_string = function(path) return "cursor " .. vim.fn.shellescape(path) end,
    spawn = function(path)
      if cli_exists("cursor") then
        spawn_cli("cursor", { path })
      else
        open_app_simple("Cursor", path)
      end
    end,
  },
  {
    name = "VSCode",
    icon = "",
    category = "Editor",
    detect = function() return cli_exists("code") or app_exists("Visual Studio Code.app") end,
    command_string = function(path) return "code " .. vim.fn.shellescape(path) end,
    spawn = function(path)
      if cli_exists("code") then
        spawn_cli("code", { path })
      else
        open_app_simple("Visual Studio Code", path)
      end
    end,
  },
  {
    name = "Zed",
    icon = "",
    category = "Editor",
    detect = function() return cli_exists("zed") or app_exists("Zed.app") end,
    command_string = function(path) return "zed " .. vim.fn.shellescape(path) end,
    spawn = function(path)
      if cli_exists("zed") then
        spawn_cli("zed", { path })
      else
        open_app_simple("Zed", path)
      end
    end,
  },
  {
    name = "Sublime Text",
    icon = "",
    category = "Editor",
    detect = function() return cli_exists("subl") or app_exists("Sublime Text.app") end,
    command_string = function(path) return "subl " .. vim.fn.shellescape(path) end,
    spawn = function(path)
      if cli_exists("subl") then
        spawn_cli("subl", { path })
      else
        open_app_simple("Sublime Text", path)
      end
    end,
  },
  {
    name = "WebStorm",
    icon = "",
    category = "IDE",
    detect = function() return cli_exists("webstorm") or app_exists("Webstorm.app") end,
    command_string = function(path)
      if cli_exists("webstorm") then return "webstorm " .. vim.fn.shellescape(path) end
      return 'open -na WebStorm --args ' .. vim.fn.shellescape(path)
    end,
    spawn = function(path)
      if cli_exists("webstorm") then
        spawn_cli("webstorm", { path })
      elseif app_exists("Webstorm.app") then
        open_app("WebStorm", path)
      end
    end,
  },
  {
    name = "IntelliJ IDEA",
    icon = "",
    category = "IDE",
    detect = function()
      return cli_exists("idea") or app_exists("IntelliJ IDEA.app") or app_exists("IntelliJ IDEA CE.app")
    end,
    command_string = function(path)
      if cli_exists("idea") then return "idea " .. vim.fn.shellescape(path) end
      return 'open -na "IntelliJ IDEA" --args ' .. vim.fn.shellescape(path)
    end,
    spawn = function(path)
      if cli_exists("idea") then
        spawn_cli("idea", { path })
      elseif app_exists("IntelliJ IDEA.app") then
        open_app("IntelliJ IDEA", path)
      else
        open_app("IntelliJ IDEA CE", path)
      end
    end,
  },
  {
    name = "PyCharm",
    icon = "",
    category = "IDE",
    detect = function() return cli_exists("pycharm") or app_exists("PyCharm.app") or app_exists("PyCharm CE.app") end,
    command_string = function(path)
      if cli_exists("pycharm") then return "pycharm " .. vim.fn.shellescape(path) end
      return 'open -na PyCharm --args ' .. vim.fn.shellescape(path)
    end,
    spawn = function(path)
      if cli_exists("pycharm") then
        spawn_cli("pycharm", { path })
      elseif app_exists("PyCharm.app") then
        open_app("PyCharm", path)
      else
        open_app("PyCharm CE", path)
      end
    end,
  },
  {
    name = "GoLand",
    icon = "",
    category = "IDE",
    detect = function() return cli_exists("goland") or app_exists("GoLand.app") end,
    command_string = function(path)
      if cli_exists("goland") then return "goland " .. vim.fn.shellescape(path) end
      return 'open -na GoLand --args ' .. vim.fn.shellescape(path)
    end,
    spawn = function(path) if cli_exists("goland") then
        spawn_cli("goland", { path })
      else
        open_app("GoLand", path)
      end
    end,
  },
  {
    name = "DataGrip",
    icon = "",
    category = "IDE",
    detect = function() return cli_exists("datagrip") or app_exists("DataGrip.app") end,
    command_string = function(path)
      if cli_exists("datagrip") then return "datagrip " .. vim.fn.shellescape(path) end
      return 'open -na DataGrip --args ' .. vim.fn.shellescape(path)
    end,
    spawn = function(path)
      if cli_exists("datagrip") then
        spawn_cli("datagrip", { path })
      else
        open_app("DataGrip", path)
      end
    end,
  },
  {
    name = "Rider",
    icon = "",
    category = "IDE",
    detect = function() return cli_exists("rider") or app_exists("Rider.app") end,
    command_string = function(path)
      if cli_exists("rider") then return "rider " .. vim.fn.shellescape(path) end
      return 'open -na Rider --args ' .. vim.fn.shellescape(path)
    end,
    spawn = function(path)
      if cli_exists("rider") then
        spawn_cli("rider", { path })
      else
        open_app("Rider", path)
      end
    end,
  },
  {
    name = "Codex",
    icon = "󱓞",
    category = "Editor",
    detect = function() return app_exists("Codex.app") end,
    command_string = function(path) return 'open -a Codex ' .. vim.fn.shellescape(path) end,
    spawn = function(path) open_app_simple("Codex", path) end,
  },
  {
    name = "Xcode",
    icon = "",
    category = "IDE",
    detect = function() return app_exists("Xcode.app") end,
    command_string = function(path) return 'open -a Xcode ' .. vim.fn.shellescape(path) end,
    spawn = function(path) open_app_simple("Xcode", path) end,
  },
  {
    name = "Obsidian (in vault)",
    icon = "",
    category = "Notes",
    detect = function() return app_exists("Obsidian.app") end,
    accept = function(path, _) return M.obsidian_find_vault(path) ~= nil end,
    command_string = function(path) return shell_command("open", { obsidian_uri(path) }) end,
    spawn = function(path)
      open_uri(obsidian_uri(path))
    end,
  },
  {
    name = "Obsidian (seed config + open)",
    icon = "󰰥",
    category = "Notes",
    detect = function() return app_exists("Obsidian.app") end,
    accept = function(_, kind) return kind == "dir" or kind == "file" end,
    command_string = obsidian_seed_command,
    spawn = function(path)
      M.bootstrap_obsidian_vault(obsidian_seed_dir(path), function()
        open_uri(obsidian_uri(path))
      end)
    end,
  },
  {
    name = "Obsidian (hotkeys + profile switcher)",
    icon = "󰰥",
    category = "Notes",
    detect = function() return app_exists("Obsidian.app") end,
    accept = function(_, kind) return kind == "dir" or kind == "file" end,
    command_string = obsidian_profile_switcher_command,
    spawn = function(path)
      M.bootstrap_obsidian_profile_switcher(obsidian_seed_dir(path), function()
        open_uri(obsidian_uri(path))
      end)
    end,
  },
  {
    name = "Obsidian (copy path + open)",
    icon = "󰰥",
    category = "Notes",
    detect = function() return app_exists("Obsidian.app") end,
    accept = function(path, _) return M.obsidian_find_vault(path) == nil end,
    command_string = function(path) return "printf %s " .. vim.fn.shellescape(path) .. " | pbcopy; open -a Obsidian" end,
    spawn = function(path)
      vim.fn.setreg("+", path)
      vim.system({ "open", "-a", "Obsidian" }, { detach = true })
      vim.notify("Path copied. In Obsidian: Open folder as vault → ⌘V → Open", vim.log.levels.INFO)
    end,
  },
  {
    name = "Chrome",
    icon = "",
    category = "Browser",
    detect = function() return app_exists("Google Chrome.app") end,
    command_string = function(path) return 'open -a "Google Chrome" ' .. vim.fn.shellescape(path) end,
    spawn = function(path) open_app_simple("Google Chrome", path) end,
  },
  {
    name = "Safari",
    icon = "",
    category = "Browser",
    detect = function() return app_exists("Safari.app") end,
    command_string = function(path) return 'open -a Safari ' .. vim.fn.shellescape(path) end,
    spawn = function(path) open_app_simple("Safari", path) end,
  },
  {
    name = "Firefox",
    icon = "",
    category = "Browser",
    detect = function() return app_exists("Firefox.app") end,
    command_string = function(path) return 'open -a Firefox ' .. vim.fn.shellescape(path) end,
    spawn = function(path) open_app_simple("Firefox", path) end,
  },
  {
    name = "Arc",
    icon = "",
    category = "Browser",
    detect = function() return app_exists("Arc.app") end,
    command_string = function(path) return 'open -a Arc ' .. vim.fn.shellescape(path) end,
    spawn = function(path) open_app_simple("Arc", path) end,
  },
  {
    name = "Microsoft Edge",
    icon = "",
    category = "Browser",
    detect = function() return app_exists("Microsoft Edge.app") end,
    command_string = function(path) return 'open -a "Microsoft Edge" ' .. vim.fn.shellescape(path) end,
    spawn = function(path) open_app_simple("Microsoft Edge", path) end,
  },
  {
    name = "Default Browser",
    icon = "󰖟",
    category = "Browser",
    detect = function() return true end,
    command_string = function(path)
      local kind = path_kind(path)
      if kind == "file" then return shell_command("open", { "file://" .. path }) end
      return shell_command("open", { path })
    end,
    spawn = function(path)
      local kind = path_kind(path)
      if kind == "file" then
        open_uri("file://" .. path)
      else
        open_uri(path)
      end
    end,
  },
  {
    name = "Finder (reveal)",
    icon = "",
    category = "File Manager",
    detect = function() return is_mac end,
    command_string = function(path) return "open -R " .. vim.fn.shellescape(path) end,
    spawn = function(path) vim.system({ "open", "-R", path }, { detach = true }) end,
  },
  {
    name = "System Default",
    icon = "󰀻",
    category = "System",
    detect = function() return true end,
    command_string = function(path) return "open " .. vim.fn.shellescape(path) end,
    spawn = function(path) require("lazy.util").open(path, { system = true }) end,
  },
}

---Returns apps available on this system that accept the given path kind.
---@param path string
---@return table[]
function M.detect(path)
  local kind = path_kind(path)
  local result = {}
  for _, app in ipairs(M.apps) do
    local ok, detected = pcall(app.detect)
    if ok and detected then
      if not app.accept or app.accept(path, kind) then
        table.insert(result, app)
      end
    end
  end
  return result
end

---Returns display label for an app: "<cat-icon> <app-icon>  <name>"
---@param app table
---@return string
function M.format_label(app)
  local icon = CAT_ICON[app.category] or app.icon or ""
  if icon == "" then return app.name end
  return icon .. " " .. app.name
end

---Returns the shell command / URI string for an app+path (for clipboard copy).
---@param path string
---@param app table
---@return string
function M.command_string(path, app)
  if app.command_string then
    local ok, result = pcall(app.command_string, path)
    if ok then return result end
  end
  return app.name .. " " .. path
end

---@param path string
---@param app table
---@return string
function M.command_preview(path, app)
  local lines = {
    "# " .. app.name,
    "# Path that will open:",
    vim.fn.shellescape(path),
    "",
    "# Similar executable bash command:",
    M.command_string(path, app),
  }

  if app.name == "Obsidian (seed config + open)" then
    table.insert(lines, "")
    table.insert(lines, "# Seed copies " .. OBSIDIAN_TEMPLATE_VAULT .. "/.obsidian/ into:")
    table.insert(lines, "# " .. obsidian_seed_dir(path) .. "/.obsidian/")
    table.insert(lines, "# It uses rsync and does not symlink the config.")
    table.insert(lines, "# In Neovim this step is prompted and skipped when .obsidian already exists.")
  elseif app.name == "Obsidian (hotkeys + profile switcher)" then
    table.insert(lines, "")
    table.insert(lines, "# Minimal seed writes only:")
    table.insert(lines, "# - .obsidian/hotkeys.json")
    table.insert(lines, "# - .obsidian/community-plugins.json with settings-profiles only")
    table.insert(lines, "# - .obsidian/plugins/settings-profiles/")
    table.insert(lines, "# After Obsidian reloads, use Settings Profiles to choose/load a full profile.")
  end

  return table.concat(lines, "\n")
end

---Open a single app with path.
---@param path string
---@param app table app definition from M.apps
function M.open(path, app)
  local ok, err = pcall(app.spawn, path)
  if not ok then
    vim.notify("open_external: " .. app.name .. " failed: " .. tostring(err), vim.log.levels.ERROR)
  end
end

---Show picker and open chosen app.
---@param path string
function M.pick(path)
  local available = M.detect(path)
  if #available == 0 then
    vim.notify("open_external: no apps available for " .. path, vim.log.levels.WARN)
    return
  end

  local basename = vim.fn.fnamemodify(path, ":t")
  local ok, Snacks = pcall(require, "snacks")

  if ok and Snacks and Snacks.picker then
    local items = vim.tbl_map(function(app)
      return {
        text = M.format_label(app),
        app = app,
        preview = {
          text = M.command_preview(path, app),
          ft = "sh",
          loc = false,
        },
      }
    end, available)

    Snacks.picker.pick({
      source = "open_external",
      title = "Open " .. basename .. " in...",
      items = items,
      format = "text",
      preview = "preview",
      layout = { hidden = { "preview" } },
      actions = {
        copy_command = function(picker, item)
          if not item then return end
          local cmd = M.command_string(path, item.app)
          vim.fn.setreg("+", cmd)
          vim.notify("Copied: " .. cmd, vim.log.levels.INFO)
          picker:close()
        end,
        open_item = function(picker, item)
          if not item then return end
          picker:close()
          vim.schedule(function()
            M.open(path, item.app)
          end)
        end,
        pick_parent = function(picker)
          local parent = parent_path(path)
          if not parent then
            vim.notify("Already at filesystem root", vim.log.levels.WARN)
            return
          end
          picker:close()
          vim.schedule(function()
            M.pick(parent)
          end)
        end,
      },
      confirm = "open_item",
      win = {
        input = {
          footer = "Path: " .. path .. "  |  <CR> open  <A-y> copy bash  <A-p> preview  <A-u> parent",
          footer_pos = "left",
          keys = {
            ["<M-y>"] = { "copy_command", mode = { "i", "n" } },
            ["<A-y>"] = { "copy_command", mode = { "i", "n" } },
            ["<M-u>"] = { "pick_parent", mode = { "i", "n" } },
            ["<A-u>"] = { "pick_parent", mode = { "i", "n" } },
            ["-"] = { "pick_parent", mode = { "n" } },
            ["<CR>"] = { "open_item", mode = { "i", "n" } },
          },
        },
        list = {
          keys = {
            ["<M-y>"] = "copy_command",
            ["<A-y>"] = "copy_command",
            ["<M-u>"] = "pick_parent",
            ["<A-u>"] = "pick_parent",
            ["-"] = "pick_parent",
            ["<CR>"] = "open_item",
          },
        },
      },
    })
  else
    -- fallback: vim.ui.select (Snacks overrides it globally anyway)
    vim.ui.select(available, {
      prompt = "Open " .. basename .. " in... (" .. path .. ")",
      format_item = M.format_label,
    }, function(app)
      if app then M.open(path, app) end
    end)
  end
end

---Open the current buffer file (or its parent directory) in the external app picker.
function M.pick_current()
  local buf = vim.api.nvim_buf_get_name(0)
  if buf == "" then
    local cwd = vim.uv.cwd()
    if cwd then M.pick(cwd) end
    return
  end
  M.pick(vim.fn.fnamemodify(buf, ":p"))
end

return M
