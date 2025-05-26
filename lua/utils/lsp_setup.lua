local M = {}

-- foldtext for Neovim < 0.10.0
----- MY ADDED ------------

function M.copyBiomeConfigFromToCurrentGitRoot(originalConfig)
  local Lsp = require("lspconfig.util")

  local original_path = vim.fn.stdpath("config")
  local original_config_path = original_path .. "/biome.yaml"
  local pathUtil = require("utils.path")
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
  local pathUtil = require("utils.path")
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
    local confirm = vim.fn.input("Override existing pyrightconfig.json? (y/n): ")
    -- confirm or empty string continue to override if not return
    if confirm ~= "y" and confirm ~= "" then
      vim.notify("Not override pyrightconfig.json")
      return
    end
  end

  local configStr = vim.fn.json_encode(config)
  vim.fn.writefile({ configStr }, pyrightconfig)
end

function M.processLspClients(action)
  -- List all active clients
  local clients = vim.lsp.get_clients()
  local items = {}
  for _, client in ipairs(clients) do
    table.insert(items, client.name)
  end

  -- Show list of clients with ui select
  vim.ui.select(items, {
    prompt = "Select LSP client to " .. action,
  }, function(choice)
    if choice ~= nil then
      for _, client in ipairs(clients) do
        if client.name == choice then
          if action == "stop" then
            vim.notify("Stopping " .. client.name)
            vim.lsp.stop_client(client.id, true)
          elseif action == "restart" then
            vim.notify("Stopping and starting " .. client.name)
            vim.lsp.stop_client(client.id, true)
            vim.lsp.start_client(client.config)
          end
          return
        end
      end
    end
  end)
end

return M
