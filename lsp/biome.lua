local Lsp = require "utils.lsp"

return {
  cmd = { "biome", "lsp-proxy" },
  on_attach = Lsp.on_attach,
  filetypes = {
    "astro",
    "css",
    "graphql",
    "javascript",
    "javascriptreact",
    "json",
    "jsonc",
    "svelte",
    "typescript",
    "typescript.tsx",
    "typescriptreact",
    "vue",
  },
  root_markers = { "biome.json", "biome.jsonc", ".git" },
}
