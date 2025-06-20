local Lsp = require "utils.lsp"
-- uv tool install pyright@latest
return {
  cmd = { "pyright-langserver", "--stdio" },
  on_attach = Lsp.on_attach,
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
