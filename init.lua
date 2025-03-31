require "config.options"
require "config.autocmds"
require "config.lazy"
require "config.keymaps"

-- Only load the theme if not in VSCode
if vim.g.vscode then
  -- Trigger vscode keymap
  local pattern = "NvimIdeKeymaps"
  vim.api.nvim_exec_autocmds("User", { pattern = pattern, modeline = false })
else
  -- Load the theme
  require("kanagawa").load "wave"
  -- Enable LSP servers for Neovim 0.11+
  vim.lsp.enable {
    "luals", -- Lua
    "tsls", -- or "vtsls" for TypeScript
    "biome", -- Biome = Eslint + Prettier but not fully yet, v2 beta
    "eslint", -- Linter
    "json", -- JSON
    "pyright", -- Python
    "gopls", -- Go
    "tailwindcss", -- Tailwind CSS
  }
end
