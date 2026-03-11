---
title: "Extend Files/Grep Picker with Code-Ref Variants"
status: "review"
assignee: "user"
created: 2026-02-12
priority: "high"
---

# Extended Files/Grep Picker with Code-Ref Variants

## Summary

Successfully extended the `<M-y>` and `YY` keymaps in files/grep/buffers pickers to show **code-ref format variants** (with line:col info) in addition to existing path formats when grep search results contain position data.

## Changes

### Modified Files

**[`lua/utils/snacks_actions.lua`](lua/utils/snacks_actions.lua)** - Lines 128-676

### New Functions

1. **`generate_coderef_formats(path_formats, line, col)`** - Line 264
   - Generates 5 code-ref format variants per path format:
     - `colon`: `path:line:col`
     - `space`: `path line:col`
     - `at`: `@path line:col`
     - `at_caps`: `@path Lline:Ccol`
     - `hash`: `path#LlineCcol`
   - Respects `vim.g.code_ref_hide_col` toggle
   - Skips directory path variants (only processes file paths)

### Updated Functions

1. **`get_item_path(item)`** - Line 128
   - Now returns `(file_path, line, col)` instead of just `file_path`
   - Extracts line/col from grep items:
     - Line: `item.pos[1]` (1-based, no conversion needed)
     - Col: `item.pos[2] + 1` (0-based → 1-based conversion)
   - Returns `nil, nil, nil` for files/buffers (no position info)

2. **`copy_path_select(picker, item)`** - Line 491
   - Merges path formats and code-ref formats
   - Title shows "[+N code-refs]" when code-refs available
   - Adds `<A-c>` toggle keymap for column visibility

3. **Other copy functions updated** (signature compatibility):
   - `copy_path_relative_buffer()`
   - `copy_path_relative_git()`
   - `copy_path_relative_cwd()`
   - `copy_path_absolute()`

### New Keymap

**`<A-c>` in sub-picker** (line 647)

- Toggles `vim.g.code_ref_hide_col` global variable
- Shows notification: "Column: hidden" / "Column: shown"
- Closes and reopens picker with updated formats

## Behavior

### Files Picker (`<leader>ff` / `<leader><space>`)

- Press `<M-y>` or `YY` on a file
- **Shows:** ~4-8 path format variants only
- **No code-ref variants** (no line/col info available)

### Grep Picker (`<leader>/`)

- Search for a term (e.g., "function", "local")
- Press `<M-y>` or `YY` on a search result
- **Shows:** Path formats + Code-ref variants (~20-40 total items)

**Example output:**

```
Relative (colon): lua/utils/snacks_actions.lua:128:3
Relative (space): lua/utils/snacks_actions.lua 128:3
Relative (@):     @lua/utils/snacks_actions.lua 128:3
Relative (@caps): @lua/utils/snacks_actions.lua L128:C3
Relative (#):     lua/utils/snacks_actions.lua#L128C3

Git (colon):      utils/snacks_actions.lua:128:3
Git (@caps):      @utils/snacks_actions.lua L128:C3
... (continues for all path variants × 5 formats)
```

### Buffers Picker (`<leader>,` / `<leader>fb`)

- Press `<M-y>` or `YY` on a buffer
- **Shows:** ~4-8 path format variants only
- **No code-ref variants** (no line/col info available)

## User Testing Checklist

### Basic Functionality

- [ ] **Files picker test:**
  1. Open files picker: `<leader>ff`
  2. Select any file
  3. Press `<M-y>` or `YY`
  4. **Verify:** Only path formats shown, NO code-refs, NO "[+N code-refs]" in title

- [ ] **Grep picker test:**
  1. Open grep picker: `<leader>/`
  2. Search for "function" or "local"
  3. Select a search result
  4. Press `<M-y>` or `YY`
  5. **Verify:** Path formats + code-ref variants shown, title shows "[+N code-refs]"

- [ ] **Buffers picker test:**
  1. Open buffers picker: `<leader>,`
  2. Select any buffer
  3. Press `<M-y>` or `YY`
  4. **Verify:** Only path formats shown, NO code-refs

### Line/Col Accuracy

- [ ] **Grep result comparison:**
  1. In grep picker, note the line:col shown in result (e.g., `file.lua:42:10`)
  2. Press `<M-y>`
  3. Compare code-ref line:col with grep result
  4. **Verify:** Line and column numbers match

### Column Toggle

- [ ] **Toggle functionality:**
  1. Open grep picker, press `<M-y>` on a result
  2. In sub-picker, press `<A-c>`
  3. **Verify:** Notification shows "Column: hidden", picker refreshes
  4. **Verify:** Code-refs show `path:line` format (no `:col`)
  5. Press `<A-c>` again
  6. **Verify:** Notification shows "Column: shown", column info restored

### Copy/Paste Actions

- [ ] **Copy test (`<C-y>`):**
  1. Open grep picker, press `<M-y>` on result
  2. Navigate to a code-ref variant
  3. Press `<C-y>`
  4. Check clipboard: `:reg +`
  5. **Verify:** Clipboard contains selected format, picker stays open

- [ ] **Paste test (`<CR>`):**
  1. Open grep picker, press `<M-y>` on result
  2. Navigate to a code-ref variant
  3. Position cursor in a buffer
  4. Press `<CR>`
  5. **Verify:** Code-ref inserted at cursor, both pickers close

### Error Checking

- [ ] **No Lua errors:**
  1. Run all tests above
  2. Check `:messages` for errors
  3. **Verify:** No error messages

## User Reviewed Notes

- [ ] Unify behavior - [ ] enter = paste - [ ] c-y = copy
      Tested result
  - current file / grep picker enter = paste
    - preview show action hints + file info
    - paste as markdown link do weird thing should show correct format as : ()[<selected>]
  - keymap picker = copy
    - ui should show key hints in footer
    - preview show nothing

## Documentation

### Created Files

- [`tests/spec_coderef_picker_extension.md`](tests/spec_coderef_picker_extension.md) - Comprehensive test specification
- [`tests/manual_test_coderef_grep.md`](tests/manual_test_coderef_grep.md) - Manual testing log template

### Updated Files

- [`tasks/wip/coderef-snippets-and-keymaps.md`](tasks/wip/coderef-snippets-and-keymaps.md) - Added "Files/Grep Picker Integration" section

## Technical Details

### Line/Col Parsing Logic

```lua
-- Grep item structure:
item.pos = {line, col}      -- line: 1-based, col: 0-based
item.end_pos = {end_line, end_col}

-- Extraction in get_item_path():
line = item.pos[1]          -- 1-based (no conversion)
col = item.pos[2] + 1       -- 0-based → 1-based
```

### Format Generation

- **Path formats:** Generated by existing `generate_path_formats()` function
- **Code-ref formats:** `path_formats × 5` (colon, space, at, at_caps, hash)
- **Total items:** ~24-48 when code-refs available (depends on path variants)

### Global State

- **`vim.g.code_ref_hide_col`** - Shared with main code-ref picker toggles
- Persists across picker invocations

## Known Limitations

1. **Directory variants skipped** - Code-ref only generates for file paths
2. **Single position only** - Uses `item.pos[1]` (start line), ignores `end_pos`
3. **No visual mode support** - Not applicable in picker context

## Rollback Plan

If issues found, revert changes:

```bash
git checkout HEAD~1 -- lua/utils/snacks_actions.lua
```

Or manually revert:

1. `get_item_path()` - restore to return only `file_path`
2. Delete `generate_coderef_formats()` function
3. `copy_path_select()` - remove code-ref merging logic
4. Remove `<A-c>` keymap from sub-picker

## Next Steps

1. **User testing** - Run through all checklist items above
2. **Report issues** - Document any bugs or unexpected behavior
3. **Iterate** - Fix any issues found during testing
4. **Move to done** - After successful verification

## Notes

- All changes are backwards-compatible
- Existing path copy functionality unchanged for files/buffers
- No breaking changes to existing keymaps or workflows
