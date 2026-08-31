---
title: "Add ,cp/,cP buffer path copy + git_status picker path copy actions + extend ,crp toggle"
status: review
priority: medium
created: 2026-07-03
updated: 2026-08-29
created_by: task-orchestrator-skill
task_orchestrator_version: "1.4.0"
source: text
synthesis_confidence: high
missing_info: []
related:
  - [mykeymaps.lua — existing <localleader>cf/cF](lua/config/mykeymaps.lua)
  - [editor_keymaps.lua — copy_path_keys, git_status keys](lua/utils/editor_keymaps.lua)
  - [snacks_actions.lua — copy_path_select, copy_to_clipboard](lua/utils/snacks_actions.lua)
  - [snacks.lua — <leader>gs git_status picker](lua/plugins/extra/snacks.lua)
---

## Objective

Add convenient direct keybindings for copying the current buffer's file path to clipboard, extend git_status picker with similar path copy actions, and enhance the path format picker:
- `,cp` — copy relative path of current buffer to clipboard
- `,cP` — copy absolute path of current buffer to clipboard
- Extend `git_status` picker (`<leader>gs`) with same copy path actions available on `files`/`git_files` pickers (`Yy`, `Yg`, `Yp`, `YP`, `YY`)
- Extend existing `,crp` (copy_path_select picker) with a new action key to toggle between path formats / file name within the picker

## Context

Current bindings for path copy exist at `<localleader>cf` (relative) and `<localleader>cF` (absolute) in `mykeymaps.lua:916-923`, but they use `@+` register. The picker-based `copy_path_keys` in `editor_keymaps.lua:1327-1339` uses `Yy`, `Yg`, `Yp`, `YP`, `YY` which are less discoverable. Want shorter `,cp`/`,cP` direct bindings + enhanced picker toggle.

The `git_status` picker (`<leader>gs`) currently only has `<Tab>` (git_stage) and `<C-r>` (git_restore) actions. The `files` and `buffers` pickers get the full `copy_path_keys` set via `snacks_picker_group_keys.files_keys.input`. The `git_status` source config in `editor_keymaps.lua:1565` only adds `<M-g>` for diff toggle — no copy path actions.

Existing helpers in `snacks_actions.lua`:
- `copy_to_clipboard(path, label)` — copies to `+` and `"` registers with notification
- `copy_path_select(picker, item)` — opens the path format picker
- `M.copy_path_relative_git`, `M.copy_path_absolute`, etc. — format-specific actions

## Implementation Plan

- [x] Add `,cp` keymap in `mykeymaps.lua` — copy relative path of current buffer to clipboard using `fnamemodify(..., ':.')`
- [x] Add `,cP` keymap in `mykeymaps.lua` — copy absolute path of current buffer to clipboard using `fnamemodify(..., ':p')`
- [x] Add `copy_path_keys` to `git_status` picker in `editor_keymaps.lua` — merge `snacks_picker_shared_keys.copy_path_keys.input` into the git_status keys table
- [x] Extend `,crp` and picker `copy_path_select` with `<A-f>` to toggle all path formats vs filename-only variants

## Success Criteria

- `,cp` copies relative file path to system clipboard with notification
- `,cP` copies absolute file path to system clipboard with notification
- `git_status` picker (`<leader>gs`) has copy path actions (`Yy`, `Yg`, `Yp`, `YP`, `YY`) working like `files`/`git_files` pickers
- `,crp` picker has a new toggle action for switching path format views

## Verification

### How to verify

Run the automated checks with the isolated worktree profile, then open any file
in that profile and test the clipboard-facing keybindings.

### Commands

```bash
NVIM_APPNAME=nvimwt3a nvim --headless -l tests/test_picker_search_and_paths.lua

NVIM_APPNAME=nvimwt3a nvim --headless \
  "+lua local cp=vim.fn.maparg(',cp','n',false,true); local cP=vim.fn.maparg(',cP','n',false,true); assert(cp and cp.desc == 'Copy current buffer relative path'); assert(cP and cP.desc == 'Copy current buffer absolute path'); print('buffer path keymaps: ok')" \
  +qa

NVIM_APPNAME=nvimwt3a nvim
```

### Checklist

- [x] Automated test confirms filename-only variants and all `git_status` copy-path mappings.
- [x] Headless startup confirms `,cp` and `,cP` are registered with the intended actions.
- [ ] `,cp` copies relative path — paste into terminal to verify
- [ ] `,cP` copies absolute path — paste into terminal to verify
- [ ] `,crp` picker opens with new toggle action visible in footer
- [ ] `<leader>gs` git_status picker has copy path actions (`Yy`, `Yg`, `Yp`, `YP`, `YY`) working
- [ ] No conflict with existing `<localleader>cf` / `<localleader>cF` (both should still work)
- [ ] Works on non-git files (falls back to CWD-relative)

## Review Feedback — 2026-07-27

### Bug: `,crp` errors with invalid buffer id

```
E5108: Error executing lua: lua/utils/code_ref.lua:225: Invalid buffer id: -1
stack traceback:
	[C]: in function 'nvim_buf_get_name'
	lua/utils/code_ref.lua:225: in function 'generate_path_variants'
	lua/utils/snacks_pickers.lua:2038: in function 'code_ref_picker'
```

Fix: guard against invalid buffer id (`-1`) in `generate_path_variants` at `code_ref.lua:225`.

### Requirement change: `p` suffix should copy dirpath

Current: all `p`-suffixed variants copy filepath. The `f` prefix already covers filepath, so `p` should copy the **directory path** instead.

- [x] Fix `,crp` invalid buffer id error — guard `vim.fn.bufnr "#"` result before calling `nvim_buf_get_name`
- [x] Change `p`-suffixed copy actions to copy dirpath instead of filepath — `Yp`/`YP` = dirpath, `Yf`/`YF` = filepath in snacks pickers
- [x] `,cp`/`,cP` now copy dirpath (not filepath) — `:h:.` and `:h:p` modifier
- [x] Neotree updated to match: `Yp`/`YP` = dirpath, `Yf`/`YF` = filepath, `copy_selector` includes dir options
- [x] Generic picker actions preserve selected directories: `Yp`/`YP` now keep
      directory entries themselves and use a file entry's parent directory;
      covered by `tests/test_picker_search_and_paths.lua`.
