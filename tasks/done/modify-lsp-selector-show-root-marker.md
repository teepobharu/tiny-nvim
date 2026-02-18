---
title: "Modify LSP selector to show root marker"
status: "review"
assignee: "user"
created: 2026-02-18
priority: "medium"
---

1: **Modify LSP selector to show root marker**

2: - What: Enhance the UI/listing used when selecting an LSP client so each entry shows the project's root marker (root folder or root file marker) in addition to the LSP name. Keep existing actions for stop/restart mapped under `<leader>L`.
3: - Why: When multiple LSP clients exist (or per-project LSP instances) it's easier to pick the correct server when the selector displays the project root or root marker alongside the LSP name.
4: - Acceptance: Pressing the LSP selector keybinding shows entries like "pyright — /path/to/project (has: pyproject.toml)" or similar, and existing stop/restart actions still work via `<leader>Lr` and `<leader>Lx`.

## Implementation Tasks

### 1. Find and update the selector formatting

- [x] Locate the code that builds the LSP client selection list (found in [lua/utils/lsp_setup.lua](lua/utils/lsp_setup.lua:140))
- [x] Modify the picker/formatter so each client entry includes a readable root marker: showing repo root basename and, if available, the root marker filename (`package.json`, `pyproject.toml`, `.git`, etc.)
- [x] Ensure the marker is optional (graceful fallback to basename when no marker file is found)

**Implementation Details:**

- Added `get_client_root_info()` function at [lua/utils/lsp_setup.lua:81](lua/utils/lsp_setup.lua:81) to detect root directory and marker files
- Added `format_client_display()` function at [lua/utils/lsp_setup.lua:118](lua/utils/lsp_setup.lua:118) to format display text
- Updated `processLspClients()` at [lua/utils/lsp_setup.lua:140](lua/utils/lsp_setup.lua:140) to use display mapping
- Format: `"lsp_name — root_basename (marker)"` or `"lsp_name — root_basename"` if no marker found

### 2. Preserve / wire existing keymaps

- [x] Confirmed current keymaps for LSP stop/restart are in [lua/config/mykeymaps.lua:821-823](lua/config/mykeymaps.lua:821) (`<leader>Lr`, `<leader>Lx`, `<leader>LX`)
- [x] Keymaps call `:RestartLspClients` and `:StopLspClients` commands which use the updated `processLspClients()` function

**No changes needed** - existing keymaps automatically use the updated selector.

### 3. UX considerations and formatting

- [x] Format implemented: `pyright — myproject (pyproject.toml)` or `ts_ls — frontend (package.json)`
- [x] Fallback to `lsp_name — root_basename` when no marker found
- [x] Uses `vim.ui.select` (native Neovim picker) - automatically handles display

### 4. Tests & manual verification

- [ ] Start Neovim: `NVIM_APPNAME=nvim3_jelly_tinynvim nvim`
- [ ] Trigger the LSP selector (identify existing mapping; check `<leader>L` prefix mappings with `:map <leader>` if unsure).
- [ ] Verify entries show both LSP name and root marker or root path.
- [ ] Test stopping a client via `<leader>Lx` and restarting via `<leader>Lr` still work as before.
- [ ] Test with multiple projects/buffer roots to confirm marker correctness.

## Notes / Implementation hints

- Prefer using existing utilities in `lua/utils/mypath.lua` or `lua/utils/lsp.lua` to resolve project root and root markers.
- When scanning for marker files, consider common markers: `.git`, `package.json`, `pyproject.toml`, `setup.cfg`, `pyrightconfig.json`, `Cargo.toml`, `go.mod`.
- Keep changes in `lua/plugins/extra/` or `config/` overrides when possible (follow project guidelines for plugin overrides).

## Acceptance checklist

- [x] Selector shows root marker alongside LSP name (implementation complete)
- [ ] Stop/restart keymaps unchanged and functional (`<leader>Lr`, `<leader>Lx`) - **needs user verification**
- [x] Formatting is readable for short and long paths
- [ ] Manual verification in real Neovim session - **needs user testing**

## User Testing Instructions

1. Start Neovim:

   ```bash
   NVIM_APPNAME=nvim3_jelly_tinynvim nvim
   ```

2. Open a file with an active LSP (e.g., open a `.lua` file to activate `lua_ls`)

3. Test the LSP selector:
   - Press `<leader>Lr` (LSP Restart) or `<leader>Lx` (LSP Stop)
   - **Expected:** Selector shows entries like:
     - `lua_ls — nvim3_jelly_tinynvim (.git)`
     - `pyright — myproject (pyproject.toml)`
     - Or `ts_ls — frontend (package.json)` depending on active clients

4. Verify functionality:
   - [x] Selector displays correctly with root marker
   - [x] Stop action works (`<leader>Lx`)
   - [x] Restart action works (`<leader>Lr`)
   - [x] Stop All works (`<leader>LX`)
   - [x] LSP Info works (`<leader>Li`)

5. Test with multiple projects:
   - Open files from different projects to get multiple LSP instances
   - Verify each shows its correct root and marker

## Implementation Summary

**Modified file:** [lua/utils/lsp_setup.lua](lua/utils/lsp_setup.lua)

**Changes:**

1. Added `get_client_root_info(client)` function (line 81) - detects root directory and finds marker file
2. Added `format_client_display(client)` function (line 118) - formats display as `"name — basename (marker)"`
3. Updated `processLspClients(action)` function (line 140) - uses display mapping to preserve client selection

**Root markers checked (in priority order):**

- `.git`, `package.json`, `tsconfig.json`, `jsconfig.json`
- `pyproject.toml`, `pyrightconfig.json`, `setup.py`, `setup.cfg`, `requirements.txt`, `Pipfile`
- `Cargo.toml`, `go.mod`, `Makefile`

## Follow-ups

1. If picker performance suffers when scanning markers, cache root/marker info per buffer in `vim.b` or a utility cache.
2. Consider adding an option to toggle displaying full path vs basename in the selector for users who prefer one or the other.
