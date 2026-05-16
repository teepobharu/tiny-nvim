local Lsp = require "utils.lsp"

-- Ref: https://github.com/neovim/nvim-lspconfig/blob/21db1fd40cbcbf1524ae154ab8f394fdf085749a/lsp/omnisharp.lua
-- Ref: https://github.com/OmniSharp/omnisharp-roslyn/releases

local dotnet = vim.fn.exepath "dotnet"
local pid = tostring(vim.fn.getpid())
local common_flags = {
  "-z", -- https://github.com/OmniSharp/omnisharp-vscode/pull/4300
  "--hostPID",
  pid,
  "DotNet:enablePackageRestore=false",
  "--encoding",
  "utf-8",
  "--languageserver",
}

local function with_flags(cmd)
  return vim.list_extend(cmd, vim.deepcopy(common_flags))
end

local function find_omnisharp_cmd()
  if type(vim.g.omnisharp_cmd) == "string" and vim.g.omnisharp_cmd ~= "" then
    return with_flags { vim.g.omnisharp_cmd }
  end

  if type(vim.g.omnisharp_cmd) == "table" and #vim.g.omnisharp_cmd > 0 then
    return vim.g.omnisharp_cmd
  end

  local omnisharp_bin = vim.fn.exepath "OmniSharp"
  if omnisharp_bin ~= "" then
    return with_flags { omnisharp_bin }
  end

  omnisharp_bin = vim.fn.exepath "omnisharp"
  if omnisharp_bin ~= "" then
    vim.notify(("Using omnisharp executable: %s %s"):format(tostring(dotnet), tostring(omnisharp_bin)), vim.log.levels.INFO)
    return with_flags { omnisharp_bin }
  end

  if dotnet ~= "" then
    local candidates = {
      vim.g.omnisharp_dll_path,
      vim.fn.expand "~/.local/share/nvim/mason/packages/omnisharp/libexec/OmniSharp.dll",
      vim.fn.expand "~/.local/share/" .. (vim.env.NVIM_APPNAME or "nvim") .. "/mason/packages/omnisharp/libexec/OmniSharp.dll",
      vim.fn.expand "~/.local/share/nvim3_jelly_tinynvim/mason/packages/omnisharp/libexec/OmniSharp.dll",
    }

    for _, dll_path in ipairs(candidates) do

      if type(dll_path) == "string" and dll_path ~= "" and vim.fn.filereadable(dll_path) == 1 then
        vim.notify(("Using dllpath executable: %s %s"):format(tostring(dotnet), tostring(dll_path)), vim.log.levels.INFO)

        return with_flags { dotnet, dll_path }
      end
    end
  end

  return with_flags { "omnisharp" }
end

-- vim.fs.find does literal name match, not glob — "*.sln" never matches.
-- Custom root_dir walks upward using readdir + Lua patterns, with tier priority:
--   Tier 1: *.sln / *.slnx  (broadest workspace, best cross-file references)
--   Tier 2: *.csproj / omnisharp.json / function.json  (single-project)
--   Tier 3: .git fallback with a WARN (references may be incomplete)
local function has_glob(dir, patterns)
  local ok, entries = pcall(vim.fn.readdir, dir)
  if not ok or not entries then return false end
  for _, name in ipairs(entries) do
    for _, p in ipairs(patterns) do
      if name:match(p) then return true end
    end
  end
  return false
end

local function find_csharp_root(fname)
  if not fname or fname == "" then return nil end
  local start = vim.fs.dirname(fname)

  local sln = { "%.sln$", "%.slnx$" }
  local proj = { "%.csproj$", "^omnisharp%.json$", "^function%.json$" }

  local function walk(patterns)
    local dir = start
    while dir and dir ~= "" and dir ~= "/" do
      if has_glob(dir, patterns) then return dir end
      local parent = vim.fs.dirname(dir)
      if parent == dir then break end
      dir = parent
    end
    return nil
  end

  local hit = walk(sln) or walk(proj)
  if hit then return hit end

  local git = vim.fs.root(fname, { ".git" })
  if git then
    vim.schedule(function()
      vim.notify(
        ("[omnisharp] rooted on .git (%s) for %s — no .sln/.csproj found; references may be incomplete"):format(git, fname),
        vim.log.levels.WARN
      )
    end)
  end
  return git
end

-- Install options:
-- 1) Homebrew/Mason binary in PATH (omnisharp)
-- 2) OmniSharp.dll + dotnet CLI (set vim.g.omnisharp_dll_path)
-- Gated by vim.g.lsp_enable_csharp in init.lua
return {
  cmd = find_omnisharp_cmd(),
  on_attach = Lsp.on_attach,
  filetypes = { "cs", "vb" },
  root_dir = function(bufnr, on_dir)
    on_dir(find_csharp_root(vim.api.nvim_buf_get_name(bufnr)))
  end,
  init_options = {},
  capabilities = {
    workspace = {
      workspaceFolders = false,
    },
  },
  settings = {
    FormattingOptions = {
      EnableEditorConfigSupport = true,
      OrganizeImports = nil,
    },
    MsBuild = {
      LoadProjectsOnDemand = nil,
    },
    RoslynExtensionsOptions = {
      EnableAnalyzersSupport = nil,
      EnableImportCompletion = nil,
      AnalyzeOpenDocumentsOnly = nil,
      EnableDecompilationSupport = nil,
    },
    RenameOptions = {
      RenameInComments = nil,
      RenameOverloads = nil,
      RenameInStrings = nil,
    },
    Sdk = {
      IncludePrereleases = true,
    },
  },
}
