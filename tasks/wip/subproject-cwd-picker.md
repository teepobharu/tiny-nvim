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
- [x] Wire keymap to launch the subproject picker from files/grep pickers
- [x] Register action in snacks action table
- [ ] User verification

## Implementation Notes

- Uses subproject metadata from `get_sub_project_dir(..., true, true)` to build picker items.
- Applies selected CWD to the active picker while preserving search state and picker toggles.

## Success Criteria

- Files/grep pickers can open a subproject list, select a CWD, and immediately filter results using that directory.
