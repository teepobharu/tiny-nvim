local M = {}

-- foldtext for Neovim < 0.10.0
----- MY ADDED ------------

function M.copyBiomeConfigFromToCurrentGitRoot(originalConfig)
  local Lsp = require "lspconfig.util"

  local original_path = vim.fn.stdpath "config"
  local original_config_path = original_path .. "/biome.yaml"
  local pathUtil = require "utils.path"
  local git_dir = pathUtil.get_git_root() or vim.fn.getcwd()
  local new_config_path = git_dir .. "/biome.yaml"
  if vim.fn.filereadable(new_config_path) == 1 then
    vim.notify(new_config_path .. "already exists", vim.log.levels.WARN)
    return
  else
    vim.notify("Copying " .. original_config_path .. " to " .. new_config_path, vim.log.levels.INFO)
    -- copy the file
    vim.fn.system("cp " .. original_config_path .. " " .. new_config_path)
  end
end

---@return {fg?:string}?
function M.fg(name)
  local color = M.color(name)
  return color and { fg = color } or nil
end

---@param name string
---@param bg? boolean
---@return string?
function M.color(name, bg)
  ---@type {foreground?:number}?
  ---@diagnostic disable-next-line: deprecated
  local hl = vim.api.nvim_get_hl and vim.api.nvim_get_hl(0, { name = name, link = false })
    or vim.api.nvim_get_hl_by_name(name, true)
  ---@diagnostic disable-next-line: undefined-field
  ---@type string?
  local color = nil
  if hl then
    if bg then
      color = hl.bg or hl.background
    else
      color = hl.fg or hl.foreground
    end
  end
  return color and string.format("#%06x", color) or nil
end

function M.addVenvPyrightConfig()
  local pathUtil = require "utils.path"
  local git_dir = pathUtil.get_git_root() or vim.fn.getcwd()

  local venv_path = vim.fn.input("Enter config venv path: ", git_dir .. "/.venv")
  local config = { venvPath = venv_path, venv = ".venv" }
  if vim.fn.isdirectory(venv_path) == 0 then
    vim.notify("Venv path not exists, please run pipenv install", vim.log.levels.WARN)
    return
  end
  -- if file exists then confirm before override
  local pyrightconfig = git_dir .. "/pyrightconfig.json"

  if vim.fn.filereadable(pyrightconfig) == 1 then
    local confirm = vim.fn.input "Override existing pyrightconfig.json? (y/n): "
    -- confirm or empty string continue to override if not return
    if confirm ~= "y" and confirm ~= "" then
      vim.notify "Not override pyrightconfig.json"
      return
    end
  end

  local configStr = vim.fn.json_encode(config)
  vim.fn.writefile({ configStr }, pyrightconfig)
end

--- Get root marker info for an LSP client
---@param client table LSP client object
---@return string|nil root_dir The root directory
---@return string|nil marker The root marker file/folder found
local function get_client_root_info(client)
  local root_dir = client.config and client.config.root_dir or client.root_dir
  if not root_dir then
    return nil, nil
  end

  -- Common root markers to check
  local common_markers = {
    ".git",
    "package.json",
    "tsconfig.json",
    "jsconfig.json",
    "pyproject.toml",
    "pyrightconfig.json",
    "setup.py",
    "setup.cfg",
    "requirements.txt",
    "Pipfile",
    "Cargo.toml",
    "go.mod",
    "Makefile",
  }

  -- Check which marker exists in root_dir
  for _, marker in ipairs(common_markers) do
    local marker_path = root_dir .. "/" .. marker
    if vim.fn.isdirectory(marker_path) == 1 or vim.fn.filereadable(marker_path) == 1 then
      return root_dir, marker
    end
  end

  return root_dir, nil
end

--- Format display text for LSP client with root info
---@param client table LSP client object
---@return string display_text Formatted text like "pyright — myproject (pyproject.toml)"
local function format_client_display(client)
  local root_dir, marker = get_client_root_info(client)
  local name = client.name

  if not root_dir then
    return name
  end

  -- Get basename of root directory
  local root_basename = vim.fn.fnamemodify(root_dir, ":t")

  local root_rel_git = vim.fn.fnamemodify(root_dir, ":~:.")
  -- __AUTO_GENERATED_PRINT_VAR_START__
  print([==[format_client_display root_rel_git:]==], vim.inspect(root_rel_git)) -- __AUTO_GENERATED_PRINT_VAR_END__
  root_rel_git = root_rel_git:gsub("^" .. vim.fn.expand "$HOME", "~")
  print([==[format_client_display root_rel_git:]==], vim.inspect(root_rel_git)) -- __AUTO_GENERATED_PRINT_VAR_END__
  -- relative from git
  local picker_util = require "snacks.picker.util"
  local dir_shown = picker_util.truncpath(root_rel_git, 50)
  -- rel_from_git = vim.fn.fnamemodify(root_rel_git, ":.:h")

  -- root_rel_git = root_rel_git:gsub("/[^/]*$", "") -- remove last dir name
  print([==[format_client_display root_rel_git:]==], vim.inspect(root_rel_git)) -- __AUTO_GENERATED_PRINT_VAR_END__

  if root_basename == "" then
    root_basename = root_dir
  end

  -- Snacks.picker_util.truncpath(full_path, 20
  -- Format: "lsp_name — root_basename (marker)"
  if marker then
    return string.format("%s — %s %s (%s)", name, root_basename, marker, dir_shown)
  else
    return string.format("%s — %s %s", name, root_basename, dir_shown)
  end
end

--- Helper: Get all active LSP clients with formatted info
--- @return table[] clients List of client info objects with {client, display, root_dir, marker, name, id}
local function get_lsp_clients_info()
  local clients = vim.lsp.get_clients()
  local result = {}

  for _, client in ipairs(clients) do
    local root_dir, marker = get_client_root_info(client)
    local display = format_client_display(client)

    table.insert(result, {
      client = client,
      display = display,
      root_dir = root_dir,
      marker = marker,
      name = client.name,
      id = client.id,
    })
  end

  return result
end

--- Helper: Get open buffers whose filetype matches any of the given filetypes
--- @param filetypes string[] List of filetypes to match
--- @return integer[] bufnrs
local function lookup_buffers_for_filetypes(filetypes)
  local ft_set = {}
  for _, ft in ipairs(filetypes or {}) do
    ft_set[ft] = true
  end
  local result = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      local ft = vim.bo[buf].filetype
      if ft_set[ft] then
        table.insert(result, buf)
      end
    end
  end
  return result
end

--- Helper: Pick clients for action when multiple instances of same name exist (multi-root).
--- If only 0 or 1 client → returns list as-is. Else prompts user to pick "all" or specific root.
--- @param name string Server name
--- @param action_label string Action verb shown in prompt (e.g. "restart", "stop")
--- @param cb fun(clients: vim.lsp.Client[]) Called with chosen clients (possibly empty)
local function pick_clients_for_name(name, action_label, cb)
  local clients = vim.lsp.get_clients { name = name }
  if #clients <= 1 then
    cb(clients)
    return
  end
  local choices = { string.format("All %d instances", #clients) }
  for _, c in ipairs(clients) do
    local root = c.root_dir or "<no root>"
    table.insert(choices, string.format("[id=%d] %s", c.id, vim.fn.fnamemodify(root, ":~")))
  end
  vim.ui.select(choices, {
    prompt = string.format("%s %s — pick instance:", action_label, name),
  }, function(_, idx)
    if not idx then
      return
    end
    if idx == 1 then
      cb(clients)
    else
      cb({ clients[idx - 1] })
    end
  end)
end

--- Helper: Execute LSP client action (restart / stop / disable / pause / resume).
--- "resume" is the merged enable+resume: clears disable flag, attaches matching bufs (clears pause).
--- "restart" implies enable: clears disable flag, stops, re-fires FileType so framework re-attaches.
--- "disable" stops client which clears pause implicitly.
--- For disable/resume, `client` may be nil (server not running); pass `name` instead.
--- @param client vim.lsp.Client|nil The LSP client object (nil when server not currently running)
--- @param action "restart"|"stop"|"disable"|"pause"|"resume" The action to perform
--- @param silent? boolean If true, don't show debug message (caller will show it)
--- @param name? string Server name — required when client is nil
local function execute_lsp_action(client, action, silent, name)
  local server_name = (client and client.name) or name or "unknown"

  --- Re-fire FileType autocmd on matching open buffers so vim.lsp framework auto-starts/attaches.
  local function refire_filetype()
    local cfg = vim.lsp.config[server_name] or {}
    local fts = cfg.filetypes or (client and client.config and client.config.filetypes) or {}
    local bufs = lookup_buffers_for_filetypes(fts)
    for _, buf in ipairs(bufs) do
      vim.schedule(function()
        vim.api.nvim_exec_autocmds("FileType", { buffer = buf })
      end)
    end
  end

  if action == "stop" then
    if not silent then
      Snacks.debug("Stopping " .. server_name)
    end
    if client then
      vim.lsp.stop_client(client.id, true)
    end

  elseif action == "restart" then
    if not silent then
      Snacks.debug("Restarting " .. server_name)
    end
    -- restart implies enable (clear disabled flag) so framework will auto-attach
    vim.lsp.enable(server_name, true)
    if client then
      vim.lsp.stop_client(client.id, true)
    end
    -- Defer FileType re-fire so client fully shuts down first
    vim.defer_fn(refire_filetype, 150)

  elseif action == "disable" then
    if not silent then
      Snacks.debug("Disabling " .. server_name)
    end
    vim.lsp.enable(server_name, false)
    if client then
      -- stop_client kills attached_buffers → pause state cleared implicitly
      vim.lsp.stop_client(client.id, true)
    end

  elseif action == "pause" then
    -- Soft detach: keep process running but detach from all buffers
    if not silent then
      Snacks.debug("Pausing " .. server_name)
    end
    if client then
      for buf, _ in pairs(client.attached_buffers or {}) do
        pcall(vim.lsp.buf_detach_client, buf, client.id)
      end
    end

  elseif action == "resume" then
    -- Merged enable+resume: clear disable flag, re-attach matching open buffers.
    -- If server not running, FileType autocmd will start it via framework.
    if not silent then
      Snacks.debug("Resuming " .. server_name)
    end
    vim.lsp.enable(server_name, true)
    if client then
      -- Running: re-attach (clears pause state) — cheap, no re-init handshake
      local cfg = vim.lsp.config[server_name] or {}
      local fts = cfg.filetypes or (client.config and client.config.filetypes) or {}
      local bufs = lookup_buffers_for_filetypes(fts)
      for _, buf in ipairs(bufs) do
        pcall(vim.lsp.buf_attach_client, buf, client.id)
      end
    else
      -- Not running: trigger framework auto-start via FileType
      refire_filetype()
    end
  end
end

--- EXISTING: Keep for backward compatibility with vim.ui.select
--- Shows a simple select dialog to restart/stop LSP clients
--- @param action "restart"|"stop" The action to perform on selected client
function M.processLspClients(action)
  local clients_info = get_lsp_clients_info()
  local items = {}
  local display_to_client = {}

  for _, info in ipairs(clients_info) do
    table.insert(items, info.display)
    display_to_client[info.display] = info.client
  end

  -- Show list of clients with ui select
  vim.ui.select(items, {
    prompt = "Select LSP client to " .. action,
  }, function(choice)
    if choice then
      local client = display_to_client[choice]
      if client then
        execute_lsp_action(client, action)
      end
    end
  end)
end

-- Status icons (emoji) used in both parent and sub picker
local LSP_STATUS_ICON = {
  attached = "🟢", -- attached to buffers
  running  = "🟡", -- running, no buffers attached (paused)
  stopped  = "⚫", -- enabled but not running
  disabled = "🔴", -- vim.lsp.enable(name, false)
}

-- Compute current status of a client (or nil-client by name)
local function client_status_icon(client, name)
  if client then
    if next(client.attached_buffers or {}) then
      return LSP_STATUS_ICON.attached
    end
    return LSP_STATUS_ICON.running
  end
  if vim.lsp.is_enabled and not vim.lsp.is_enabled(name) then
    return LSP_STATUS_ICON.disabled
  end
  return LSP_STATUS_ICON.stopped
end

-- Build sub-picker items (one per running client instance for the given name)
local function build_root_items(name)
  local items = {}
  for _, c in ipairs(vim.lsp.get_clients { name = name }) do
    local root = c.root_dir or "<no root>"
    local icon = client_status_icon(c, name)
    table.insert(items, {
      text = string.format("%s [id=%d] %s", icon, c.id, vim.fn.fnamemodify(root, ":~")),
      name = name,
      client_id = c.id,
      root = root,
      icon = icon,
      bufs = vim.tbl_count(c.attached_buffers or {}),
    })
  end
  return items
end

--- Open a Snacks sub-picker scoped to a single LSP name, listing per-root client instances.
--- Action keys mirror parent picker but operate on the selected client only.
--- @param parent_picker table Parent snacks picker — closed by C-q "close all"
local function open_lsp_root_picker(name, on_close, parent_picker)
  local function root_finder(_, ctx)
    local items = build_root_items(name)
    return items
  end

  local function run(action, label, needs_running)
    return function(sub, _)
      local sel = sub:selected { fallback = true }
      for _, it in ipairs(sel) do
        local client = vim.lsp.get_client_by_id(it.client_id)
        if not client and needs_running then
          Snacks.debug(string.format("%s [id=%d] not running — skip", name, it.client_id))
        else
          execute_lsp_action(client, action, true, name)
        end
      end
      Snacks.debug(string.format("%s — %s × %d", name, label, #sel))
      vim.defer_fn(function()
        sub:find { refresh = true }
      end, 250)
    end
  end

  Snacks.picker.pick {
    title = string.format("LSP %s — Roots", name),
    finder = root_finder,
    format = "text",
    confirm = function(_)
      Snacks.debug "Use 🔄🛑🚫⏸️▶️ keys to act on this root"
    end,
    actions = {
      restart_one = run("restart", "🔄", false),
      stop_one    = run("stop",    "🛑", true),
      disable_one = run("disable", "🚫", false),
      pause_one   = run("pause",   "⏸️", true),
      resume_one  = run("resume",  "▶️", false),
      refresh_one = function(sub)
        sub:find { items = build_root_items(name), refresh = true }
      end,
      close_all = function(sub)
        sub:close()
        if parent_picker and not parent_picker.closed then
          parent_picker:close()
        end
      end,
    },
    win = {
      input = {
        footer = "🔄C-r 🛑M-x 🚫C-x ⏸️C-p ▶️C-e 🔁M-u ⬅️Esc 🚪C-q",
        keys = {
          ["<C-r>"] = { "restart_one", mode = { "n", "i" }, desc = "🔄 restart" },
          ["<M-x>"] = { "stop_one",    mode = { "n", "i" }, desc = "🛑 stop" },
          ["<C-x>"] = { "disable_one", mode = { "n", "i" }, desc = "🚫 disable" },
          ["<C-p>"] = { "pause_one",   mode = { "n", "i" }, desc = "⏸️ pause" },
          ["<C-e>"] = { "resume_one",  mode = { "n", "i" }, desc = "▶️ resume/enable" },
          ["<M-u>"] = { "refresh_one", mode = { "n", "i" }, desc = "🔁 refresh" },
          ["<Esc>"] = { "cancel",       mode = { "n", "i" }, desc = "⬅️ back" },
          ["<C-q>"] = { "close_all",   mode = { "n", "i" }, desc = "🚪 close all" },
        },
      },
      list = {
        keys = {
          ["<C-r>"] = { "restart_one", mode = "n", desc = "🔄 restart" },
          ["<M-x>"] = { "stop_one",    mode = "n", desc = "🛑 stop" },
          ["<C-x>"] = { "disable_one", mode = "n", desc = "🚫 disable" },
          ["<C-p>"] = { "pause_one",   mode = "n", desc = "⏸️ pause" },
          ["<C-e>"] = { "resume_one",  mode = "n", desc = "▶️ resume/enable" },
          ["<M-u>"] = { "refresh_one", mode = "n", desc = "🔁 refresh" },
          ["<Esc>"] = { "cancel",       mode = "n", desc = "⬅️ back" },
          ["<C-q>"] = { "close_all",   mode = "n", desc = "🚪 close all" },
        },
      },
    },
  }
end

--- NEW: Snacks picker with preview for LSP server management.
--- Lists ALL servers under runtime `lsp/*.lua` (attached, stopped, disabled).
--- Keys (parent):
---   <C-r> 🔄 restart · <M-x> 🛑 stop · <C-x> 🚫 disable
---   <C-p> ⏸️ pause   · <C-e> ▶️ resume/enable · <M-u> 🔁 refresh · <CR> roots sub-picker
function M.lsp_clients_picker()
  local function run_action(action, label, needs_running, refresh_ms)
    return function(picker, _)
      local items = picker:selected { fallback = true }
      Snacks.debug(#items == 1
        and string.format("%s %s", label, items[1].name)
        or string.format("%s × %d", label, #items))
      for _, sel in ipairs(items) do
        local clients = vim.lsp.get_clients { name = sel.name }
        if #clients == 0 then
          if needs_running then
            Snacks.debug(string.format("%s not running — skip", sel.name))
          else
            execute_lsp_action(nil, action, true, sel.name)
          end
        else
          for _, c in ipairs(clients) do
            execute_lsp_action(c, action, true, sel.name)
          end
        end
      end
      vim.defer_fn(function()
        picker:refresh()
      end, refresh_ms or 300)
    end
  end

  Snacks.picker.lsp_config {
    title = "LSP Manager",
    auto_close = false,

    -- <CR>: open per-root sub picker. Esc returns here; C-q closes both.
    confirm = function(picker, item)
      open_lsp_root_picker(item.name, function()
        -- refresh parent after sub-picker closes
        vim.defer_fn(function()
          if picker and not picker.closed then
            picker:refresh()
          end
        end, 100)
      end, picker)
    end,

    actions = {
      restart_lsp = run_action("restart", "🔄", false, 400),
      stop_lsp    = run_action("stop",    "🛑", true, 300),
      disable_lsp = run_action("disable", "🚫", false, 300),
      pause_lsp   = run_action("pause",   "⏸️", true, 200),
      resume_lsp  = run_action("resume",  "▶️", false, 400),
      refresh_picker = function(picker)
        picker:refresh()
      end,
    },

    win = {
      input = {
        footer = "🔄C-r 🛑M-x 🚫C-x ⏸️C-p ▶️C-e 🔁M-u ↵roots 🚪C-q",
        keys = {
          ["<C-r>"] = { "restart_lsp",    mode = { "n", "i" }, desc = "🔄 restart" },
          ["<M-x>"] = { "stop_lsp",       mode = { "n", "i" }, desc = "🛑 stop" },
          ["<C-x>"] = { "disable_lsp",    mode = { "n", "i" }, desc = "🚫 disable" },
          ["<C-p>"] = { "pause_lsp",      mode = { "n", "i" }, desc = "⏸️ pause" },
          ["<C-e>"] = { "resume_lsp",     mode = { "n", "i" }, desc = "▶️ resume/enable" },
          ["<M-u>"] = { "refresh_picker", mode = { "n", "i" }, desc = "🔁 refresh" },
          ["<C-q>"] = { "close",          mode = { "n", "i" }, desc = "🚪 close" },
        },
      },
      list = {
        keys = {
          ["<C-r>"] = { "restart_lsp",    mode = "n", desc = "🔄 restart" },
          ["<M-x>"] = { "stop_lsp",       mode = "n", desc = "🛑 stop" },
          ["<C-x>"] = { "disable_lsp",    mode = "n", desc = "🚫 disable" },
          ["<C-p>"] = { "pause_lsp",      mode = "n", desc = "⏸️ pause" },
          ["<C-e>"] = { "resume_lsp",     mode = "n", desc = "▶️ resume/enable" },
          ["<M-u>"] = { "refresh_picker", mode = "n", desc = "🔁 refresh" },
          ["<C-q>"] = { "close",          mode = "n", desc = "🚪 close" },
        },
      },
    },
  }
end

return M
