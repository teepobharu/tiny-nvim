local Lsp = require "utils.lsp"
-- uv tool install pyright@latest
return {
  cmd = { "pyright-langserver", "--stdio" },
  on_attach = Lsp.on_attach,
  root_markers = { "pyproject.toml", "setup.py", "setup.cfg", "requirements.txt", "Pipfile", "pyrightconfig.json", ".git" },
  filetypes = { "python" },
  settings = {
    python = {
      pythonPath = require("utils.mypath").get_pythonpath(),
      analysis = {
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
        diagnosticMode = "openFilesOnly",
      },
    },
  },
}
