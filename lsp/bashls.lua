-- Bash Language Server Configuration

-- https://github.com/bash-lsp/bash-language-server?tab=readme-ov-file#neovim
return {
  cmd = { 'bash-language-server', 'start' },
  filetypes = { 'bash', 'sh' }
}
