# Task: Fix git_last_commit_show() picker - C-s key and title format

## Status: IN PROGRESS

## Previous Session Summary
- Refactored picker to use range-based diffs (HEAD~N..HEAD)
- Fixed picker refresh issue by using `Snacks.picker.get({ source = "..." })`
- Range navigation now works: `<C-k>` expands, `<C-j>` shrinks

## Current Session Progress

### ✅ Completed
1. **Title format updated** (lua/utils/snacks_pickers.lua:390-404)
   - Format: `<branch:shorthash>..<HEAD:shorthash> (N commits)`
   - Example: `main:abc1234..def5678 (3 commits)`
   - Uses `git_util.get_short_hash()` and `git_util.get_ref_branch_name()`
   - Removed "Changed: " prefix since format now includes commit count

2. **Title references updated** (line 429, 461, 491)
   - All three title assignments now use just the display string
   - Picker refresh maintains current title format

### 🔴 ISSUE: `<C-s>` key not working
**Current behavior**: Opens file in new tab WITHOUT diff view
**Expected behavior**: Should open Gitsigns diff view comparing with current base ref

**Problem identified**:
- `<C-s>` maps to action `"open_file_diff"` defined in `custom_actions` (line 470-477)
- Action calls: `git_util.open_file_with_gitsigns_diff(item.file, get_base_ref())`
- `<C-g>` works correctly (user confirmed)
- Something wrong with how `<C-s>` is being resolved or executed

**Investigation needed**:
1. Confirm `open_file_diff` action is being called
2. Check if `git_util.open_file_with_gitsigns_diff()` is working with the base ref
3. Verify action registration in snacks picker

## Code Locations

**lua/utils/snacks_pickers.lua**:
- `get_range_display()`: lines 390-404
- `move_range_forward()`: lines 413-434
- `move_range_backward()`: lines 437-466
- `custom_actions.open_file_diff`: lines 470-477
- Picker config: lines 489-558

**lua/utils/editor_keymaps.lua**:
- `git_file_keys` definition: lines 1124-1141
- Both `<C-s>` and `<C-g>` map to `"open_file_diff"`

**lua/utils/git.lua**:
- `open_file_with_gitsigns_diff()`: Used by action
- `get_short_hash()`: lines 427-438
- `get_ref_branch_name()`: lines 443-463

## Next Steps

### For user verification:
1. Open picker with `:lua require('utils.snacks_pickers').custom_git_pickers.git_last_commit_show()`
2. Check title format - should show `branch:hash..HEAD:hash (N commits)`
3. Press `<C-k>` several times - title should update with new range
4. **Test `<C-s>`** - should open diff, not just file tab
5. **Test `<C-g>`** - should also open diff (this already works)

### Debug steps if <C-s> still fails:
1. Add debug notification in `open_file_diff` action
2. Check if action is receiving item correctly
3. Verify `git_util.open_file_with_gitsigns_diff()` parameters
4. Compare with `<C-g>` to find differences

## Files Modified

- [lua/utils/snacks_pickers.lua](lua/utils/snacks_pickers.lua) - Updated title format and action
- No changes to lua/utils/editor_keymaps.lua
- No changes to lua/utils/git.lua

## Test Checklist

- [ ] Title format displays correctly: `branch:hash..HEAD:hash (N commits)`
- [ ] Title updates when pressing `<C-k>` to expand range
- [ ] Title updates when pressing `<C-j>` to shrink range
- [ ] `<C-g>` opens Gitsigns diff with current base ref (WORKS)
- [ ] `<C-s>` opens Gitsigns diff with current base ref (BROKEN - opens file tab only)
- [ ] Diff shows correct range comparison
- [ ] Navigation between files works

## Root Cause Analysis (TBD)

Possible causes for `<C-s>` issue:
1. Action not registered in `actions` table
2. Action signature mismatch
3. `git_util.open_file_with_gitsigns_diff()` issue with parameters
4. Snacks picker action resolution issue
5. Different keybinding source (checking wrong keys table)
