require "config.options"
require "config.myopts"

-- Load project setting if available, e.g: .nvim-config.lua
-- This file is not tracked by git
-- It can be used to set project specific settings
local project_setting = vim.fn.getcwd() .. "/.nvim-config.lua"
-- Check if the file exists and load it
if vim.loop.fs_stat(project_setting) then
  -- Read the file and run it with pcall to catch any errors
  local ok, err = pcall(dofile, project_setting)
  vim.print("Loaded project setting: " .. project_setting)
  if not ok then
    vim.notify("Error loading project setting: " .. err, vim.log.levels.ERROR)
  end
end

require "config.autocmds"
require "config.lazy"
require "config.keymaps"
require "config.project"
require "config.mykeymaps"
require "config.myautocmds"

-- Only load the theme if not in VSCode
if vim.g.vscode then
  -- Trigger vscode keymap
  local pattern = "NvimIdeKeymaps"
  vim.api.nvim_exec_autocmds("User", { pattern = pattern, modeline = false })
else
  -- Load the theme
  local theme = require "config.theme"
  theme.setup()
  theme.apply()

  local ts_server = vim.g.lsp_typescript_server or "ts_ls" -- "ts_ls" or "vtsls" for TypeScript

  -- Enable LSP servers per filetype (Neovim 0.11+)
  local lsp_by_ft = {
    lua = { "lua_ls" },
    json = { "json", "biome" },
    jsonc = { "json", "biome" },
    json5 = { "json", "biome" },
    python = { "basedpyright", "ruff" },
    go = { "gopls" },
    gomod = { "gopls" },
    gowork = { "gopls" },
    gotmpl = { "gopls" },
    rust = { "rust-analyzer" },
    javascript = { ts_server, "biome" },
    javascriptreact = { ts_server, "biome" },
    typescript = { ts_server, "biome" },
    typescriptreact = { ts_server, "biome" },
    markdown = { "marksman" },
    yaml = { "yaml" },
    html = { "tailwindcss" },
    css = { "tailwindcss" },
    scss = { "tailwindcss" },
    sass = { "tailwindcss" },
    less = { "tailwindcss" },
    postcss = { "tailwindcss" },
  }

  -- Gate C# LSP behind vim.g (default=false, opt-in per project via .nvim-config.lua)
  --
  -- Usage: vim.g.lsp_enable_csharp = true
  -- Optional: vim.g.lsp_csharp_server = "omnisharp" | "csharp_ls"
  local csharp_server = vim.g.lsp_csharp_server
  if not csharp_server then
    if vim.fn.executable "omnisharp" == 1 or vim.fn.executable "OmniSharp" == 1 then
      csharp_server = "omnisharp"
    elseif vim.fn.executable "csharp-ls" == 1 then
      csharp_server = "csharp_ls"
    else
      csharp_server = "omnisharp"
    end
  end
  if vim.g.lsp_enable_csharp then
    lsp_by_ft.cs = { csharp_server }
  end

  -- My custom handler to watch for different startup modes
  pcall(require, "utils.startup.simple_startup")
  -- Load additional config (skip if running with --noplugin)
  pcall(require, "config.mydefault-nvim-config")

  local enabled_lsp = {}
  local on_demands = vim.g.lsp_on_demands or {}
  local js_ts_filetypes = {
    javascript = true,
    javascriptreact = true,
    typescript = true,
    typescriptreact = true,
    json = true,
    jsonc = true,
    json5 = true,
  }

  local function enable_lsp(servers)
    if not servers or #servers == 0 then
      return
    end
    for _, server in ipairs(servers) do
      if not enabled_lsp[server] then
        enabled_lsp[server] = true
        vim.lsp.enable(server)
      end
    end
  end

  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("my_nvim_lsp_by_ft", { clear = true }),
    callback = function(event)
      local filetype = vim.bo[event.buf].filetype
      local servers = lsp_by_ft[filetype] or {}

      if js_ts_filetypes[filetype] and #on_demands > 0 then
        for _, server in ipairs(on_demands) do
          table.insert(servers, server)
        end
      end

      enable_lsp(servers)
    end,
  })
end
