---
title: "Add ,cp/,cP buffer path copy + git_status picker path copy actions + extend ,crp toggle"
status: open
priority: medium
created: 2026-07-03
updated: 2026-07-03
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

- [ ] Add `,cp` keymap in `mykeymaps.lua` — copy relative path of current buffer to clipboard using `expand('%:.')`
- [ ] Add `,cP` keymap in `mykeymaps.lua` — copy absolute path of current buffer to clipboard using `expand('%:p')`
- [ ] Add `copy_path_keys` to `git_status` picker in `editor_keymaps.lua:1565` — merge `snacks_picker_shared_keys.copy_path_keys.input` into the git_status keys table
- [ ] Extend `,crp` picker (`copy_path_select`) with a new action key to toggle between showing path formats vs file name only

## Success Criteria

- `,cp` copies relative file path to system clipboard with notification
- `,cP` copies absolute file path to system clipboard with notification
- `git_status` picker (`<leader>gs`) has copy path actions (`Yy`, `Yg`, `Yp`, `YP`, `YY`) working like `files`/`git_files` pickers
- `,crp` picker has a new toggle action for switching path format views

## Verification

### How to verify

Open Neovim with the main profile, open any file, and test the keybindings.

### Commands

```bash
NVIM_APPNAME=nvim3_jelly_tinynvim nvim
```

### Checklist

- [ ] `,cp` copies relative path — paste into terminal to verify
- [ ] `,cP` copies absolute path — paste into terminal to verify
- [ ] `,crp` picker opens with new toggle action visible in footer
- [ ] `<leader>gs` git_status picker has copy path actions (`Yy`, `Yg`, `Yp`, `YP`, `YY`) working
- [ ] No conflict with existing `<localleader>cf` / `<localleader>cF` (both should still work)
- [ ] Works on non-git files (falls back to CWD-relative)
