-- Bash Language Server Configuration
local Path = require("utils.path")
local Lsp = require("utils.lsp")

-- https://github.com/bash-lsp/bash-language-server?tab=readme-ov-file#neovim
return {
  cmd = { 'bash-language-server', 'start' },
  filetypes = { 'bash', 'sh' }
  -- on_attach = Lsp.on_attach,
}
