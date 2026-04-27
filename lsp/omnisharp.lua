local Lsp = require("utils.lsp")
-- Install: brew install omnisharp-mono # seem not available ?
-- Or:      :MasonInstall omnisharp
-- continue in : http://localhost:3000/?session=ses_2372f6808ffe2nvq5sfEPys2eh
-- Gated:   Only enabled when vim.g.lsp_enable_csharp = true
--          Set in .nvim-config.lua for C# projects
return {
  cmd = { "omnisharp", "--languageserver" },
  on_attach = Lsp.on_attach,
  filetypes = { "cs" },
  root_markers = { "*.sln", "*.csproj", "omnisharp.json", ".git" },
  settings = {
    FormattingOptions = {
      EnableEditorConfigSupport = true,
      OrganizeImports = true,
    },
    RoslynExtensionsOptions = {
      EnableAnalyzersSupport = true,
      EnableImportCompletion = true,
    },
  },
}
