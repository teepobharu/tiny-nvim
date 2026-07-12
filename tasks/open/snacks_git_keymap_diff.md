---
title: "snacks: improve git keymaps C-s and C-g to diff selected files"
status: "open"
assignee: "ai"
created: 2026-02-09
updated: 2026-07-02
priority: "high"
---

Problem
- The snacks picker keymaps `C-s` and `C-g` should show a git diff for the currently selected files against the picker's context ref, but current behavior opens files inconsistently and sometimes runs `gitsigns diffthis` without ensuring the file is present in a buffer/tab.

Goal
- Update snacks actions so that when the user presses `C-s` or `C-g` on one or more selected items the flow is:
  1. For each selected file: if the file is not in any current buffer, open it in a new tab (so the buffer exists and is focused in that tab).
  2. Run `:Gitsigns diffthis <ref>` (or the programmatic equivalent) in that buffer/tab to show the diff against the current picker context ref.
  3. If the file is already open in some buffer, reuse that buffer (do not open duplicate tabs) and run `gitsigns diffthis <ref>` there.

Acceptance criteria
- Keymaps `C-s` and `C-g` trigger the new behavior in the snacks picker.
- Files that are not open are opened in a new tab before diffing.
- Files already open are not opened again; diff runs in the existing buffer.
- Diff shown corresponds to the picker's current context ref (base/ref shown in picker header).
- Provide small unit/manual test steps in the task so reviewer can validate.

## Action Items

- [ ] Inspect current picker action registration for `C-s` and `C-g` in [snacks_pickers.lua](lua/utils/snacks_pickers.lua) and [editor_keymaps.lua](lua/utils/editor_keymaps.lua).
- [ ] Reuse the existing file-open/diff helper if it already handles buffer reuse and tab creation.
- [ ] Add a debug notification temporarily only if `C-s` still resolves to the wrong action.
- [ ] Remove any temporary debug output before moving the task to review.
- [ ] Fill a template-style `## Verification` section after implementation.

## Points to Confirm

- [ ] Confirm whether multi-selected files should open one tab per file or reuse the current tab workflow.
- [ ] Confirm whether `C-s` and `C-g` should remain aliases or keep distinct split/tab behavior.
- [ ] Confirm whether the diff base should always be the picker header ref or support an override.

## Implementation Notes

- Files to inspect/modify:
  - `lua/utils/snacks_actions.lua`
  - `lua/utils/snacks_pickers.lua`
  - `lua/plugins/extra/snacks.lua` (if keymaps are defined there)
- Use Neovim API to check open buffers (`vim.fn.bufloaded` / `vim.fn.buflisted`) and to open file in new tab (`vim.cmd('tabnew ' .. filepath)` or `vim.api.nvim_command`).
- After opening/ensuring buffer, run gitsigns action programmatically: `require('gitsigns').diffthis(ref)` or `vim.cmd('Gitsigns diffthis ' .. ref)` depending on gitsigns API availability.
- Ensure actions run per-file sequentially and do not close the picker until actions complete.

Manual verification
1. Open snacks picker that shows a git ref (e.g., `:lua require('utils.snacks_pickers').custom_git_pickers.git_last_commit_show()`)
2. Select a file that is not currently open and press `C-s`.
   - Expect: a new tab opens with that file and gitsigns diff for the picker's ref is shown.
3. Select a file already open in an existing buffer and press `C-s`.
   - Expect: no new tab opens; gitsigns diff is shown in the existing buffer.
4. Multi-select several files and press `C-g` (or `C-s`).
   - Expect: each file is opened (only if not already open) and diffed against the same ref.

Notes
- Keep changes in `lua/plugins/extra/mysnacks.lua` or `lua/utils/snacks_actions.lua` per repository conventions for personal overrides.
- If gitsigns does not expose a Lua API for `diffthis` with a ref, fall back to executing the `:Gitsigns diffthis <ref>` command in the target buffer.
