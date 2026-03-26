**Enhance toggle_external & toggle_cwd: subproject upward traversal**

## Summary

Replaced the fixed CWD cycle set and single-jump external toggle with **subproject marker upward traversal**. Both `<A-s>` (scope) and `<A-e>` (external) walk up the subproject marker chain from initial cwd to git root. Buffer pickers got their own separate persistence.

**Latest fix**: Buffer transform now properly filters based on scope even when external is OFF — `<A-s>` scope change shows only buffers INSIDE the scope cwd, `<A-e>` then inverts to show OUTSIDE.

## Changes

### `lua/utils/snacks_actions.lua`

1. **New shared helpers** (lines 12-141):
   - `build_scope_traversal_chain(initial_cwd)` — builds ordered `[initial_cwd, ..., git_root]` chain using `in_cwd_traversal` subproject results
   - `get_picker_traversal_state(picker, persist_key)` — lazy-initializes chain on picker
   - `reset_picker_traversal_state(picker)` — clears scope + external state
   - `build_cwd_exclude_pattern(exclude_cwd, search_cwd)` — relative exclude pattern for fd/rg
   - All exposed via `M._*` for buffer action access

2. **Revised `toggle_external` (C: `<A-e>`)** (lines 143-258):
   - Files/grep: step-based — each press moves cwd one subproject level UP, excludes initial scope cwd
   - Past git root wraps to disable external, restoring original scope
   - Other pickers: simple boolean toggle (unchanged)

3. **Revised `toggle_cwd_files_grep` (B: `<A-s>`)** (lines 1171-1228):
   - Upward traversal through subproject chain — no fixed cycle set
   - Short-lived: does NOT persist `vim.g.picker_cwd_cycle_state_value`
   - Resets external state when scope changes
   - Past git root wraps to initial cwd

4. **Updated `select_subproject_cwd` (A: `<A-S>`)** (line 910):
   - Accepts `opts_or_item` with optional `persist_key` for buffer-specific persistence
   - Calls `reset_picker_traversal_state(picker)` on selection

### `lua/utils/editor_keymaps.lua`

5. **Revised buffers transform** (lines 1450-1509):
   - **Key fix**: When scope is set (via `<A-s>`), transform now filters buffers to show only those INSIDE scope cwd
   - When `<A-e>` toggles external ON: inverts to show only buffers OUTSIDE scope cwd + missing buffers
   - When no scope and no external: shows all buffers (default — `return item`)
   - Three-state logic: `(has_scope AND NOT external)` → inside-only, `(external)` → outside-only, `(neither)` → all

6. **Buffer scope toggle** (`toggle_buffer_scope`) (lines 1515-1555):
   - Clears `_buffer_scope_cwd` when returning to initial position (index 1) to show all buffers
   - Separate notification for initial vs intermediate vs git root positions

7. **Buffer subproject picker** (`select_buffer_subproject`) (lines 1556-1560):
   - Delegates to `select_subproject_cwd` with `persist_key = "picker_buffer_cwd_state_value"`

### State Model

| State | Persistence | Who sets it |
|-------|-------------|-------------|
| `vim.g.picker_cwd_cycle_state_value` | Across picker sessions | `<A-S>` (files) |
| `vim.g.picker_buffer_cwd_state_value` | Across picker sessions | `<A-S>` (buffers) |
| `picker.opts._scope_traversal_chain` | Current picker only | `<A-s>` lazy-init |
| `picker.opts._scope_step_index` | Current picker only | `<A-s>` toggle |
| `picker.opts._external_step_index` | Current picker only | `<A-e>` toggle |
| `picker.opts._buffer_scope_cwd` | Current picker only | `<A-s>` (buffers) |

### Interaction Rules

- `<A-s>` resets `<A-e>` state (external clears when scope changes)
- `<A-S>` resets both `<A-s>` and `<A-e>` state
- `<A-s>` is short-lived (no vim.g persist)
- Only `<A-S>` persists cwd across picker sessions

### Buffer Transform Logic

```
has_scope = _buffer_scope_cwd is set (via <A-s>)
show_external = picker.opts.external (via <A-e>)

NOT has_scope AND NOT external → return item (all buffers)
has_scope AND NOT external     → return inside-scope only
external                       → return outside-scope + missing
```

## Verification

### How to verify
Start Neovim with worktree profile. Test in a project with nested subproject markers (e.g., monorepo with `package.json` at multiple levels).

### Commands
```bash
NVIM_APPNAME=nvimwt3a nvim
```

```vim
" Enable debug to see traversal in :messages
:let g:snacks_debug_external_filter = 1
```

### Checklist

**B: Files `<A-s>` (scope toggle):**
- [ ] Open files picker (`<leader>ff`), press `<A-s>` — cwd moves one subproject level up
- [ ] Press `<A-s>` again — moves further up
- [ ] At git root: notification says "reached git root"
- [ ] Next `<A-s>` wraps back to initial scope
- [ ] Search filter text is preserved across toggles
- [ ] Does NOT persist — reopening picker starts from initial cwd

**C: Files `<A-e>` (external toggle):**
- [ ] Open files picker, press `<A-e>` — cwd moves up one step, excludes initial cwd
- [ ] Title shows `[ext: path, excl: subdir]`
- [ ] Press `<A-e>` again — moves further up, still excludes same initial cwd
- [ ] At git root: notification says "next toggle disables"
- [ ] Next `<A-e>` disables external, restores original scope
- [ ] After `<A-s>` changes scope, `<A-e>` starts fresh from new scope

**B+C interaction:**
- [ ] `<A-s>` to step to git/b, then `<A-e>` → cwd=git, exclude=git/b
- [ ] `<A-s>` after `<A-e>` → external fully resets

**A: Files `<A-S>` (subproject picker):**
- [ ] Opens subproject picker, selecting persists to `vim.g.picker_cwd_cycle_state_value`
- [ ] Parent picker scope and external state are reset

**D1: Buffers `<A-e>` (external toggle):**
- [ ] Open buffers picker (`<leader><space>`), press `<A-e>` — shows buffers outside scope cwd
- [ ] Toggle off — shows all buffers again

**D3+D1: Buffers `<A-s>` then `<A-e>`:**
- [ ] Press `<A-s>` → buffer list filters to show only buffers INSIDE scope cwd
- [ ] Press `<A-e>` → inverts: shows only buffers OUTSIDE that scope
- [ ] `<A-s>` wrapping to initial → clears scope, shows all buffers

**D2: Buffers `<A-S>` (subproject picker):**
- [ ] Opens subproject picker, persists to `vim.g.picker_buffer_cwd_state_value` (separate from files)

## Checklist
- [x] Shared helpers: build_scope_traversal_chain, get/reset state, build_cwd_exclude
- [x] Revised toggle_external (step-based for files/grep)
- [x] Revised toggle_cwd_files_grep (upward traversal, short-lived)
- [x] Updated select_subproject_cwd (persist_key, reset state)
- [x] Buffers D1: external filter using scope cwd
- [x] Buffers D2: subproject picker with separate persistence
- [x] Buffers D3: upward traversal for buffers
- [x] Buffer transform scope-aware filtering (inside/outside based on external flag)
- [x] Buffer scope toggle clears _buffer_scope_cwd when returning to initial
- [x] Fixed @ format in copy_path_select
- [x] stylua formatted, lua syntax verified

## User testing
Root project: ~/.config/nvimwt3a

```lua
vim.cmd [[
" new tab
tabnew
edit lua/utils/snacks_actions.lua
edit tasks/review/2026-01-26-enhance-toggle-external-files-picker.md
" external files
execute 'cd ' . fnameescape(expand('$HOME') . '/.config/' . expand('$NVIM_APPNAME'))
vsplit
" project scope lua/
edit lua/utils/editor_keymaps.lua

" different subproject scope snippets/
split
edit snippets/global.json

]]
```

Still not working 
2026-03-26
- buffer scope switch does not filter result to be only in that scope but the exclusion applied correctly on that selected scope 
- file external does not filter result when in external mode by the requirement of it’s upper scope   

Fix attempt (2026-03-26)
- `lua/utils/editor_keymaps.lua`: buffer transform now treats persisted buffer scope (`vim.g.picker_buffer_cwd_state_value`) as active scope, so non-external mode filters to that scope instead of returning all buffers.
- `lua/utils/snacks_actions.lua`: traversal initialization now prefers `picker.opts.cwd` over persisted global state to keep external/scope traversal aligned with the current picker scope.

Fix attempt (2026-03-27)
- `lua/utils/editor_keymaps.lua`: renamed key-bound action from `toggle_external` to `toggle_external_scope` across files/grep/buffers to avoid Snacks auto-generated `toggle_external` override from `opts.toggles.external`.
- Kept implementation in `lua/utils/snacks_actions.lua` unchanged; custom traversal/exclude logic now executes again for file pickers when pressing `<M-e>`.
