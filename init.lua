require "config.options"
require "config.autocmds"
require "config.lazy"
require "config.keymaps"

-- Only load the theme if not in VSCode
if not vim.g.vscode then
  require("kanagawa").load "wave"
else
  -- Trigger vscode keymap
  local pattern = "NvimIdeKeymaps"
  vim.api.nvim_exec_autocmds("User", { pattern = pattern, modeline = false })
end

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
