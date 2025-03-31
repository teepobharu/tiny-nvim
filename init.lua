require "config.options"
require "config.autocmds"
require "config.lazy"
require "config.keymaps"

require("kanagawa").load "wave"

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
