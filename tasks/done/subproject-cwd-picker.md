---
title: "Add subproject picker for snacks CWD"
status: "wip"
assignee: "ai"
created: 2026-02-11
priority: "medium"
related:
  - [Snacks CWD actions](lua/utils/snacks_actions.lua)
  - [Snacks picker keys](lua/utils/editor_keymaps.lua)
  - [Snacks plugin config](lua/plugins/extra/myEditor.lua)
  - [Subproject detection](lua/utils/mypath.lua)
---

## Objective

Add a picker action and keymap to choose from available subproject CWDs and apply the selection to the active files/grep picker.

## Checklist

- [x] Add subproject picker action and apply selected CWD to active picker
- [x] Wire keymap to launch the subproject picker from files/grep pickers (now <M-S>)
- [x] Register action in snacks action table
- [x] Show git root in the picker list
- [x] Preview: show subdir list (like zoxide/projects picker preview) with pre value meta at the top of preview
- [x] User verification

Deprioritized:

- Preview shrink to be smaller - fail to set

## Implementation Notes

- Uses subproject metadata from `get_sub_project_dir(..., true, true)` to build picker items.
- Applies selected CWD to the active picker while preserving search state and picker toggles.
- Keymap updated to <M-S> for files/grep picker launch.
- Preview now reuses Snacks built-in previewer via `Snacks.picker.preview.file` (directory-aware).

## DIGDEEP

- Snacks previewer source: https://github.com/folke/snacks.nvim/blob/main/lua/snacks/picker/preview.lua
- Local reference: `~/.local/share/nvim3_jelly_tinynvim/lazy/snacks.nvim/lua/snacks/picker/preview.lua`
- Grep path ellipsis uses `Snacks.picker.util.truncpath` in formatter `snacks.picker.format.filename` to center-truncate based on picker window width. See https://github.com/folke/snacks.nvim/blob/main/lua/snacks/picker/format.lua and https://github.com/folke/snacks.nvim/blob/main/lua/snacks/picker/util/init.lua

## Success Criteria

- Files/grep pickers can open a subproject list, select a CWD, and immediately filter results using that directory.
