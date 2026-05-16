local Lsp = require "utils.lsp"

local function resolve_csharp_ls_cmd()
  local bin = vim.fn.exepath "csharp-ls"
  if bin ~= "" then
    return { bin }
  end

  local dotnet_tool_bin = vim.fn.expand "~/.dotnet/tools/csharp-ls"
  if vim.fn.filereadable(dotnet_tool_bin) == 1 then
    return { dotnet_tool_bin }
  end

  return { "csharp-ls" }
end

-- https://github.com/razzmatazz/csharp-language-server
-- https://github.com/Decodetalkers/csharpls-extended-lsp.nvim
return {
  cmd = resolve_csharp_ls_cmd(),
  on_attach = Lsp.on_attach,
  filetypes = { "cs" },
  root_markers = { "*.sln", "*.csproj", ".git" },
}
