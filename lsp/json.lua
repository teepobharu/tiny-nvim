-- NOTE: npm i -g vscode-langservers-extracted
return {
  cmd = { "vscode-json-language-server", "--stdio" },
  filetypes = { "json", "jsonc" },
  init_options = {
    provideFormatter = true,
  },
  single_file_support = true, -- this will not default back to git root in file search in mono repo projects
}
