---
title: "Unify ref-based file pickers into a single builder factory"
status: review
priority: medium
created: 2026-04-08
updated: 2026-04-21
related:
  - [snacks_pickers.lua](lua/utils/snacks_pickers.lua)
  - [editor_keymaps.lua](lua/utils/editor_keymaps.lua)
  - [snacks_actions.lua](lua/utils/snacks_actions.lua)
---

## Objective

Eliminate ~600 lines of duplicated code across 4 git ref-based file pickers by
creating a single `create_ref_file_picker(config)` factory function. Each picker
currently reimplements the same finder, format, actions, key groups, and
navigation refresh pattern from scratch.

## Context

### Current Pickers (all in `lua/utils/snacks_pickers.lua`)

| Picker | Function | Lines | Source ID | Trigger | Ref Strategy |
|--------|----------|-------|-----------|---------|-------------|
| Last commit | `git_last_commit_show()` | L516-703 | `git_show` | `<leader>fL` | `HEAD~N` offset |
| Upstream | `git_diff_upstream()` | L708-822 | `git_diff_upstream` | `<leader>fG` | Auto-detected, static |
| Merge-base | `git_diff_merge_base()` | L830-1208 | `git_diff_merge_base` | `<leader>fM` | `merge-base()` + offset |
| Change list sub-picker | `show_file_list_picker()` | L1421-1691 | `git_diff_files` | `<leader>fZ` confirm | SHA-walking |

### 7 Duplication Areas

| # | What | Where | Notes |
|---|------|-------|-------|
| 1 | `create_git_file_actions` | `editor_keymaps.lua:1153` + `snacks_actions.lua:2054` | Verbatim duplicate |
| 2 | Inline `custom_actions` tables | `snacks_pickers.lua:611`, `:1061`, `:1573` | Same 3 actions, different ref source |
| 3 | Finder pattern | `snacks_pickers.lua:636-653`, `:1089-1142`, `:1613-1641` | Same `git diff --name-only` + proc + transform |
| 4 | Format function | `snacks_pickers.lua:655-657`, `:1144-1147`, `:1643-1645` | Always `build_git_status_map -> git_status_formatter` |
| 5 | C-j/C-k duplication across input+list | `snacks_pickers.lua:654-699`, `:1154-1205`, `:1654-1688` | Same keys defined twice per picker |
| 6 | move_forward/backward refresh pattern | `snacks_pickers.lua:554-607`, `:973-1058`, `:1472-1570` | `Snacks.picker.get -> vim.schedule -> update_titles + refresh` |
| 7 | `git_file_keys` 3 variants | `editor_keymaps.lua:1341-1421` | Near-identical with minor key differences |

## Implementation Plan

### Phase 1: Deduplicate `create_git_file_actions` (low risk)

- [x] **1a.** Keep canonical version in `snacks_actions.lua:2054` (`M.action_factories.create_git_file_actions`)
- [x] **1b.** In `editor_keymaps.lua:1153`, replaced body with delegation
- [x] **1c.** Verified `git_diff_upstream` caller still works

### Phase 2: Extract shared helpers (medium risk)

- [x] **2a.** `make_ref_file_actions(get_ref_fn)` at `snacks_pickers.lua:450`
- [x] **2b.** `make_ref_file_finder(get_ref_fn, git_root, git_args_fn)` at `snacks_pickers.lua:482`
- [x] **2c.** `make_ref_file_format(get_ref_fn)` at `snacks_pickers.lua:515`
- [x] **2d.** `apply_keys_to_both_windows(base_keys, extra_keys)` at `snacks_pickers.lua:527`
- [x] **2e.** `refresh_ref_picker(source, get_title)` at `snacks_pickers.lua:539` (bonus helper)

### Phase 3: Create unified builder factory (main payoff)

- [x] **3a.** Created `create_ref_file_picker(config)` at `snacks_pickers.lua:567`
- [x] **3b.** Rewrote `git_last_commit_show()` — ~188 -> ~62 lines
- [x] **3c.** Rewrote `git_diff_upstream()` — ~115 -> ~90 lines (ref detection kept, picker call simplified)
- [x] **3d.** Rewrote `git_diff_merge_base()` — ~378 -> ~140 lines (with `git_args_fn` for staged/workdir)
- [x] **3e.** Rewrote `show_file_list_picker()` — ~270 -> ~100 lines (SHA-walking kept, factory handles rest)

### Phase 4: Simplify key groups (deferred — low priority)

- [ ] **4a.** Merge `git_file_keys`, `git_file_keys_upstream`, `git_file_keys_with_back` into single factory
- [ ] **4b.** Update all callers to use the parameterized factory
- Note: `git_file_keys_with_back` is now dead code (factory builds back keys inline). The 3 key group variants still work but could be unified in a follow-up.

### Phase 5: Cleanup

- [x] **5a.** `pick_cmd_result` is now orphaned (no callers), can be removed in follow-up
- [x] **5b.** Ran `stylua lua/` — no issues
- [x] **5c.** Both files pass `luac -p` syntax check
- [ ] **5d.** Test all 4 picker entry points (user verification)

### Phase 6: Post-refactor fixes & HEAD navigation (2026-04-21)

- [x] **6a.** Fix `vim.tbl_extend` crash at `snacks_pickers.lua:600` — changed single-arg call to `vim.deepcopy`
- [x] **6b.** Normalize C-j/C-k convention: C-j = base further from HEAD, C-k = base closer to HEAD
  - `git_last_commit_show` — already matched
  - `git_diff_merge_base` — already matched
  - `show_file_list_picker` — was inverted, swapped
- [x] **6c.** Add C-h/C-l HEAD-side navigation to all 3 navigable pickers
  - Generalized `build_git_status_map(base, head)` + `preview_git_diff_with_base(base, head)`
  - Added `get_head` callback to factory (defaults to `"HEAD"`)
  - Threaded through `make_ref_file_finder`, `make_ref_file_format`, and preview
  - Added `head_offset` state to `git_last_commit_show` and `git_diff_merge_base`
  - Added `current_head_ref` state to `show_file_list_picker` (SHA-walking HEAD)
  - Guards: HEAD cannot cross base ref; base cannot cross HEAD ref
- [x] **6d.** Moved fZ-stage-2 "back" key from `<C-h>` to `<C-q>` to free up `<C-h>` for HEAD navigation
- [x] **6e.** Added `show_empty = true` to `custom_change_list_picker` ref selector so it opens even with 0 candidates

## Actual Impact

- **git diff stat**: 730 deletions, 368 insertions = **362 net lines removed**
- `snacks_pickers.lua`: 2516 -> 2183 lines (-333)
- `editor_keymaps.lua`: 1841 -> 1819 lines (-22, action factory delegation)
- Phase 4 (key group unification) deferred — would remove another ~40 lines

## Success Criteria

- All 4 pickers produce identical UX as before (same keymaps, flow, preview, badges)
- `create_git_file_actions` exists in only one place (`snacks_actions.lua`)
- All pickers use the same `create_ref_file_picker()` factory
- `git_file_keys` group is a single parameterized factory (not 3 static tables)
- C-j/C-k keys no longer duplicated between input and list windows

## Verification

### How to verify

Restart Neovim with the worktree profile. Test each picker in a git repository
with multiple branches and commits.

### Commands

```bash
NVIM_APPNAME=nvimwt3a nvim
```

### Checklist

- [x] `<leader>fL` opens last commit picker, C-j/C-k navigate base ref (C-j further, C-k closer), C-h/C-l navigate HEAD ref, C-s opens gitsigns diff
- [x] `<leader>fG` opens upstream picker with auto-detected ref, C-s opens diff, C-o opens remote
- [x] `<leader>fu` opens merge-base picker, C-j/C-k navigate base, C-h/C-l navigate HEAD, C-w toggles workdir diff at HEAD
- [ ] `<leader>fZ` opens stage 1 (ref list with badges). Even when there are no candidates, the empty picker should open (no early error).
- [x] In `<leader>fZ` stage 1, confirm → stage 2 (file list). C-q goes back (previously C-h).
- [x] In stage 2 of `<leader>fZ`, C-j/C-k navigate base ref dynamically; C-h/C-l navigate HEAD ref; HEAD cannot cross base and vice versa (warning notify on collision)
- [ ] Preview shows git diff using the current base..head range in all pickers
- [ ] Alt-e toggles external/missing files filter in all file pickers - seem not do anything in git ref picker, gitfiles
- [ ] File status badges [A]/[M]/[D]/[R] display correctly and update as base/HEAD moves
- [ ] No regressions: other pickers (files, grep, buffers) unaffected
- [ ] No `vim.tbl_extend` crash when invoking `<leader>fL` (previous bug fixed)

## References

- [snacks_pickers.lua](lua/utils/snacks_pickers.lua) — main implementation (L454-1910)
- [editor_keymaps.lua](lua/utils/editor_keymaps.lua) — key groups (L1260-1421) + action factories (L1142-1184)
- [snacks_actions.lua](lua/utils/snacks_actions.lua) — duplicate action factory (L2048-2083)
- [Snacks picker source](~/.local/share/nvimwt3a/lazy/snacks.nvim/lua/snacks/picker/)
