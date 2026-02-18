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

function M.processLspClients(action)
  -- List all active clients
  local clients = vim.lsp.get_clients()
  local items = {}
  local display_to_client = {} -- Map display text back to client

  for _, client in ipairs(clients) do
    local display = format_client_display(client)
    table.insert(items, display)
    display_to_client[display] = client
  end

  -- Show list of clients with ui select
  vim.ui.select(items, {
    prompt = "Select LSP client to " .. action,
  }, function(choice)
    if choice ~= nil then
      local client = display_to_client[choice]
      if client then
        if action == "stop" then
          vim.notify("Stopping " .. client.name)
          vim.lsp.stop_client(client.id, true)
        elseif action == "restart" then
          vim.notify("Stopping and starting " .. client.name)
          vim.lsp.stop_client(client.id, true)
          vim.lsp.start_client(client.config)
        end
      end
    end
  end)
end

return M
