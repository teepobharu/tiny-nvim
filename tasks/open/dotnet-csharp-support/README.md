---
title: "Add .NET/C# standalone script support — code runner, shebang fallback, output toggle"
status: open
priority: medium
created: 2026-03-25
updated: 2026-03-26
related:
  - [test.cs sample](tests/lang_coderun/test.cs)
  - [run_script_deterministic](lua/overseer/template/user/run_script_deterministic.lua)
  - [dotnet_test overseer template](lua/overseer/template/agoda/dotnet/dotnet_test.lua)
  - [quick-code-runner config](lua/plugins/extra/myEditor.lua:102-157)
  - [overseer config](lua/plugins/extra/myEditor.lua:47-95)
  - [treesitter config](lua/plugins/ui.lua:338-371)
  - [init.lua LSP enable](init.lua:38-107)
  - [mydefault-nvim-config](lua/config/mydefault-nvim-config.lua)
  - [Suggested patch](tasks/open/dotnet-csharp-support/01-dotnet-csharp-support.patch)
  - [overseer component loader](~/.local/share/nvim3_jelly_tinynvim/lazy/overseer.nvim/lua/overseer/component.lua:152)
---

## Objective

Add standalone .NET/C# script execution support focusing on:
1. **Fix overseer code runner** for single `.cs` file execution (not project-based)
2. **Shebang (#!) fallback** — universal fallback for ANY filetype via first-line `#!` detection
3. **Auto-show overseer output panel** when `run script - deterministic` runs
4. **LSP gated by `vim.g`** — OmniSharp disabled by default, opt-in per project
5. **TreeSitter highlighting** for C#

## Context

### What already exists

| Feature | File | Status |
|---------|------|--------|
| Overseer `dotnet run` for `.cs` | `run_script_deterministic.lua:62-69` | **Broken**: uses `--project $file` (wrong for single files) |
| Overseer `dotnet test` | `agoda/dotnet/dotnet_test.lua` | Works for `*Test.cs` in projects |
| `cs_script` runner | `run_script_deterministic.lua:71-79` | Orphaned — `cs_script` is not a real Neovim filetype |
| `.cshtml` filetype | `lua/config/autocmds.lua:165` | Works |
| `.sln` subproject marker | `lua/utils/mypath.lua:21` | Works |
| TreeSitter `c_sharp` | Not in `ensure_installed` | **Missing** |
| C# LSP config | No `lsp/` file | **Missing** |
| quick-code-runner `.cs` | Not in `file_types` | **Missing** |
| Overseer output auto-show | No `open_output` component | **Missing** |

### The `test.cs` sample — standalone script focus

`tests/lang_coderun/test.cs` uses shebang: `#!/usr/bin/env mise exec dotnet@10 -- dotnet run`

- **dotnet 10** supports `dotnet run <file.cs>` directly ("run-file" feature, `--file` flag)
- **dotnet 8** does NOT — requires `.csproj` project or `dotnet-script` tool
- The sample already has a working shebang for mise-managed dotnet 10
- The goal is to make the code runner execute this standalone script, NOT run projects

### mise dotnet versions installed

```
dotnet  8.0.412   (active default via ~/.config/mise/config.toml)
dotnet  10.0.201  (needed for single-file run)
```

---

## Investigation Results

### 1. Fix overseer `cs` runner — standalone scripts

**Current broken config** (`run_script_deterministic.lua:62-79`):

```lua
cs = {
  { name = "dotnet", cmd = { "dotnet", "run", "--project", "$file" }, ... },
},
cs_script = {  -- orphaned: not a real filetype
  { name = "dotnet-script", cmd = { "dotnet", "script", "$file" }, ... },
},
```

**Problems**:
- `--project $file` expects a `.csproj`, not a `.cs` file
- `cs_script` key is never matched (Neovim sets ft=`cs` for `.cs` files, not `cs_script`)
- `dotnet-script` runner is unreachable

**Fix**: Merge both into the `cs` filetype. Use `dotnet run $file` for dotnet 10+ run-file, keep `dotnet-script` as fallback. Remove orphaned `cs_script`.

```lua
cs = {
  {
    name = "dotnet-run-file",
    cmd = { "dotnet", "run", "$file" },
    prerequisite = ".NET 10+ SDK (single-file execution via run-file feature)",
    executable_check = "dotnet",
    comment_syntax = "//",
    content_patterns = { "#:package", "Console%." },
    is_match_with_content_only = false,
  },
  {
    name = "dotnet-script",
    cmd = { "dotnet", "script", "$file" },
    prerequisite = "dotnet-script tool (dotnet tool install -g dotnet-script)",
    executable_check = "dotnet",
    comment_syntax = "//",
  },
},
-- REMOVE cs_script = { ... }
```

### 2. Shebang (#!) fallback — universal for any filetype

**Question**: Does the runner support fallback execution via shebang for any arbitrary file?

**Answer**: No. Currently the `default` fallback is hardcoded `sh $file` which fails for non-shell shebangs like `#!/usr/bin/env mise exec dotnet@10 -- dotnet run`.

**Proposed design**: Add shebang detection as a universal fallback that works for ANY filetype when no configured runner matches or all fail.

#### Shebang detection helper

```lua
--- Detect shebang from first line. Returns parsed info or nil.
--- @param file string absolute path
--- @return { has_shebang: boolean, interpreter: string|nil, raw_line: string }
local function detect_shebang(file)
  local lines = vim.fn.readfile(file, "", 1)
  if not lines or #lines == 0 then
    return { has_shebang = false, raw_line = "" }
  end
  local first_line = lines[1]
  if not first_line:match("^#!") then
    return { has_shebang = false, raw_line = first_line }
  end
  local shebang_cmd = first_line:match("^#!%s*(.+)$") or ""
  local args = {}
  for arg in shebang_cmd:gmatch("[^%s]+") do
    table.insert(args, arg)
  end
  return {
    has_shebang = true,
    interpreter = args[1],
    args_table = args,
    raw_line = first_line,
  }
end

--- Build command from shebang. For /usr/bin/env: chmod +x and run directly.
--- For absolute paths: use interpreter + file.
local function build_shebang_command(file, shebang_info)
  if not shebang_info.has_shebang or not shebang_info.interpreter then
    return nil
  end
  -- /usr/bin/env style: make executable and run directly (kernel handles the shebang)
  if shebang_info.interpreter == "/usr/bin/env" then
    return { "sh", "-c", string.format("chmod +x %q && %q", file, file) }
  end
  -- Absolute path interpreter
  if shebang_info.interpreter:match("^/") then
    return { shebang_info.interpreter, file }
  end
  -- Command in PATH
  if vim.fn.executable(shebang_info.interpreter) == 1 then
    return { shebang_info.interpreter, file }
  end
  return nil
end
```

#### Integration into the flow

Two integration points:

**A. In `get_best_runner()`** — after no traditional runner matches, try shebang:
```lua
-- At end of get_best_runner(), if best_runner is nil:
if not best_runner then
  local shebang_info = detect_shebang(file)
  if shebang_info.has_shebang then
    best_runner = "shebang"
  end
end
```

**B. In `builder()`** — handle the special "shebang" runner:
```lua
if params.chosen_runner == "shebang" then
  local shebang_info = detect_shebang(file)
  cmd = build_shebang_command(file, shebang_info) or { "sh", file }
else
  -- existing $file replacement logic
end
```

**C. Update `default` fallback** — add shebang before `sh`:
```lua
default = {
  {
    name = "shebang",
    is_shebang_fallback = true,
    prerequisite = "File must have a valid shebang (#!) as first line",
    executable_check = "sh",  -- always available, so it appears in choices
    comment_syntax = "#",
  },
  {
    name = "fallback",
    cmd = { "sh", "$file" },
    prerequisite = "sh or bash must be installed",
    executable_check = "sh",
  },
},
```

**Edge cases**:
| Case | Behavior |
|------|----------|
| No shebang present | Falls through to `sh $file` fallback |
| File not executable | `chmod +x` in the command handles this |
| Broken interpreter path | Overseer shows error in output panel |
| Complex shebang (`#!/usr/bin/env -S python3 -u`) | Runs directly via `chmod +x` approach |
| `test.cs` with `#!/usr/bin/env mise exec dotnet@10 -- dotnet run` | chmod +x, kernel reads shebang, mise runs dotnet 10 |

### 3. Auto-show overseer output panel on run

**Question**: Does the output panel auto-toggle when `run script - deterministic` runs?

**Answer**: No. The current builder returns:
```lua
components = {
  { "on_output_quickfix", set_diagnostics = true },
  "default",
}
```

The `"default"` alias expands to (`config.lua:90-94`):
- `on_exit_set_status` — sets task status on exit
- `on_complete_notify` — sends notification when done
- `on_complete_dispose` — disposes task from list

None of these open the output panel.

**Fix**: Add the `open_output` component (`overseer/component/open_output.lua`):

```lua
components = {
  { "on_output_quickfix", set_diagnostics = true },
  { "open_output", on_start = "always", direction = "dock", focus = false },
  "default",
},
```

**Key detail**: The default `on_start` value is `"if_no_on_output_quickfix"`, which would skip opening because we HAVE `on_output_quickfix` in the component list. So `on_start = "always"` is required.

**Component params** (from `open_output.lua`):
| Param | Options | Chosen | Why |
|-------|---------|--------|-----|
| `on_start` | `always`, `never`, `if_no_on_output_quickfix` | `always` | Always show output when task starts |
| `on_complete` | `always`, `never`, `success`, `failure` | `never` (default) | Don't re-open on complete |
| `direction` | `dock`, `float`, `tab`, `vertical`, `horizontal` | `dock` | Opens docked to bottom next to task list |
| `focus` | boolean | `false` | Don't steal focus from editor |

### 4. LSP — gated by `vim.g.lsp_enable_csharp` (default=false)

**Requirement**: Do NOT run LSP by default. Control via `vim.g` variable.

**Existing pattern** in this config (`init.lua:39-107`):
- `lsp_by_ft` table maps filetypes to LSP servers
- `FileType` autocmd calls `vim.lsp.enable()` per filetype
- `vim.g.lsp_on_demands` for extra servers per project

**Implementation**: Add `cs` to `lsp_by_ft` conditionally:

```lua
-- init.lua — inside lsp_by_ft table, add conditionally:
local lsp_by_ft = {
  -- ... existing entries ...
}

-- Gate C# LSP behind vim.g (default=false, opt-in per project)
if vim.g.lsp_enable_csharp then
  lsp_by_ft.cs = { vim.g.lsp_csharp_server or "omnisharp" }
end
```

**Per-project opt-in** via `.nvim-config.lua`:
```lua
-- .nvim-config.lua in a C# project
vim.g.lsp_enable_csharp = true
-- vim.g.lsp_csharp_server = "csharp_ls"  -- optional: use lightweight alternative
```

**LSP config file** (`lsp/omnisharp.lua`):
```lua
local Lsp = require("utils.lsp")
-- Install: brew install omnisharp-mono OR :MasonInstall omnisharp
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
```

### 5. TreeSitter `c_sharp`

- Parser name: `c_sharp` (NOT `csharp`)
- Add via `lua/langs/csharp.lua` following existing pattern (`lua/langs/go.lua`)

```lua
return {
  {
    "nvim-treesitter/nvim-treesitter",
    optional = true,
    opts = { ensure_installed = { "c_sharp" } },
  },
}
```

### 6. Permission error handling — pre-emptive chmod + detection component

**Problem**: When executing files via shebang (`./file`), users can hit "Permission denied" (exit code 126). Currently overseer shows a generic "FAILURE" notification — no actionable guidance. Also `chmod` itself could fail (read-only fs, ownership issues).

**Approach**: Option A + B combined:
- **A**: Pre-emptive `chmod +x` already built into `build_shebang_command()` above
- **B**: Custom overseer component `on_permission_error` that pattern-matches output and shows actionable notification

**Component placement**: `lua/overseer/component/on_permission_error.lua` — overseer auto-discovers components via `nvim_get_runtime_file("lua/overseer/component/*.lua", true)` (see `component.lua:152`), so placing it in the config's `lua/overseer/component/` directory works — same mechanism as custom templates.

**Component design**:

```lua
-- lua/overseer/component/on_permission_error.lua
---@type overseer.ComponentFileDefinition
return {
  desc = "Detect permission errors and notify with fix command",
  params = {
    auto_chmod = {
      desc = "Auto chmod +x the file and notify (does not auto-retry)",
      type = "boolean",
      default = false,
    },
  },
  constructor = function(params)
    return {
      detected = false,
      on_output_lines = function(self, task, lines)
        if self.detected then
          return
        end
        for _, line in ipairs(lines) do
          if line:match("Permission denied") or line:match("permission denied") or line:match("EACCES") then
            self.detected = true
            local denied_file = line:match(":%s*(.-):%s*[Pp]ermission denied")
              or line:match("open '(.-)'")
              or ""

            if params.auto_chmod and denied_file ~= "" then
              local chmod_ok = os.execute(string.format("chmod +x %q", denied_file))
              if chmod_ok then
                vim.notify(
                  string.format("Auto-fixed: chmod +x %s\nRerun with <leader>or", denied_file),
                  vim.log.levels.INFO
                )
              else
                vim.notify(
                  string.format(
                    "Permission denied: %s\nchmod failed — check ownership:\n  ls -la %s\n  sudo chmod +x %s",
                    denied_file, denied_file, denied_file
                  ),
                  vim.log.levels.ERROR
                )
              end
            else
              vim.notify(
                string.format(
                  "Permission denied%s\nFix: chmod +x <file> then rerun with <leader>or",
                  denied_file ~= "" and (": " .. denied_file) or ""
                ),
                vim.log.levels.WARN
              )
            end
            return
          end
          if line:match("command not found") or line:match("No such file or directory") then
            self.detected = true
            local missing_cmd = line:match("(%S+):%s*command not found")
              or line:match("(%S+):%s*No such file")
              or ""
            vim.notify(
              string.format(
                "Command not found%s\nCheck: which %s\nOr install the required tool.",
                missing_cmd ~= "" and (": " .. missing_cmd) or "",
                missing_cmd
              ),
              vim.log.levels.WARN
            )
            return
          end
        end
      end,
    }
  end,
}
```

**Usage in builder** — add to the components list in `run_script_deterministic.lua`:
```lua
components = {
  { "on_output_quickfix", set_diagnostics = true },
  { "open_output", on_start = "always", direction = "dock", focus = false },
  { "on_permission_error", auto_chmod = false },
  "default",
},
```

---

## Implementation Plan

- [ ] Fix `cs` runner in `run_script_deterministic.lua` — merge `cs_script` into `cs`, use `dotnet run $file`
- [ ] Add shebang fallback to `run_script_deterministic.lua` — `detect_shebang()` + `build_shebang_command()` helpers, add `shebang` to `default` runners
- [ ] Add `open_output` component to builder return — `{ "open_output", on_start = "always", direction = "dock", focus = false }`
- [ ] Create `lua/overseer/component/on_permission_error.lua` — detect permission/command-not-found errors, show actionable notification
- [ ] Add `on_permission_error` component to builder return in `run_script_deterministic.lua`
- [ ] Create `lua/langs/csharp.lua` — TreeSitter `c_sharp` parser
- [ ] Create `lsp/omnisharp.lua` — OmniSharp config file
- [ ] Gate LSP in `init.lua` — conditional `lsp_by_ft.cs` behind `vim.g.lsp_enable_csharp` (default=false)
- [ ] Add `cs` to quick-code-runner `file_types` in `myEditor.lua`
- [ ] (Optional) Add CSharpier to conform.nvim + install script

## Success Criteria

- `test.cs` runs via overseer `run script - deterministic` using shebang or `dotnet run`
- Output panel auto-opens docked when any `run script - deterministic` task starts
- Shebang fallback works for ANY file with `#!` first line (not just `.cs`)
- Permission errors show actionable notification (not just generic "FAILURE")
- "Command not found" errors show notification with the missing command name
- C# LSP does NOT start unless `vim.g.lsp_enable_csharp = true` is set
- `.cs` files get syntax highlighting via TreeSitter `c_sharp` parser

## Verification

### How to verify

Restart Neovim after applying changes. Test each feature independently.

### Commands

```bash
NVIM_APPNAME=nvim3_jelly_tinynvim nvim tests/lang_coderun/test.cs
```

```vim
" 1. Verify TreeSitter highlighting
:InspectTree
" Should show c_sharp parse tree

" 2. Verify code runner (overseer)
:OverseerRun
" Select 'run script - deterministic'
" Runner choices should show: dotnet-run-file, dotnet-script, shebang, fallback
" Output panel should auto-open docked at bottom

" 3. Verify LSP is OFF by default
:LspInfo
" Should NOT show omnisharp attached

" 4. Verify shebang fallback works on arbitrary file
" Create a temp file with shebang:
"   #!/usr/bin/env python3
"   print("hello")
" Set ft to something weird (:set ft=unknown)
" Run via overseer — should detect shebang and run
```

### Checklist

- [ ] `.cs` files have syntax highlighting (`:InspectTree` shows `c_sharp`)
- [ ] Overseer `run script - deterministic` shows `dotnet-run-file` as runner for `.cs`
- [ ] Output panel auto-opens (docked at bottom) when task starts
- [ ] Focus stays in editor (not stolen by output panel)
- [ ] Shebang fallback runs `test.cs` via its `#!/usr/bin/env mise exec dotnet@10 -- dotnet run` shebang
- [ ] Shebang fallback works on non-cs files with `#!` lines
- [ ] Running a non-executable file shows actionable "Permission denied" notification (not generic "FAILURE")
- [ ] "Command not found" errors show the missing command name in notification
- [ ] No LSP starts for `.cs` files by default
- [ ] LSP starts when `vim.g.lsp_enable_csharp = true` is set in `.nvim-config.lua`
- [ ] Existing `dotnet test` overseer template still works for `*Test.cs` files
- [ ] quick-code-runner (`<leader>cp`) works for `.cs` files

## References

- [overseer open_output component](~/.local/share/nvim3_jelly_tinynvim/lazy/overseer.nvim/lua/overseer/component/open_output.lua)
- [overseer component loader](~/.local/share/nvim3_jelly_tinynvim/lazy/overseer.nvim/lua/overseer/component.lua:152)
- [overseer config aliases](~/.local/share/nvim3_jelly_tinynvim/lazy/overseer.nvim/lua/overseer/config.lua:88-106)
- [dotnet 10 run-file feature](https://learn.microsoft.com/en-us/dotnet/core/whats-new/dotnet-10#file-based-apps)
- [OmniSharp releases](https://github.com/OmniSharp/omnisharp-roslyn/releases)
- [csharp-ls](https://github.com/razzmatazz/csharp-language-server)
