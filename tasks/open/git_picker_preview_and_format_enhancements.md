---
title: "Fix git pickers preview showing help text & enhance format with status indicators"
status: "open"
assignee: "ai"
created: 2026-01-25
priority: "high"
related:
  - [snacks_pickers.lua](lua/utils/snacks_pickers.lua)
  - [Snacks picker memory](docs/memory/snacks_picker.md)
---

## Objective

Fix two critical issues with custom git pickers:
1. **Bug**: Preview window shows `git diff` help text instead of actual diff
2. **Enhancement**: Add formatted status indicators (A/D/M) before filenames similar to todo_comments picker

## Problem

### Issue 1: Preview Shows Git Help Instead of Diff

Currently, the git diff preview shows:
```
usage: git diff [<options>] [<commit>] [--] [<path>...]
   or: git diff [<options>] --cached [--merge-base] [<commit>] [--] [<path>...]
   ...
common diff options:
  -z            output diff-raw with lines terminated with NUL.
  -p            output patch format.
  ...
```

**Root Cause**: [snacks_pickers.lua:75](lua/utils/snacks_pickers.lua:75) contains invalid git flag:
```lua
vim.list_extend(cmd, { "diff", base_ref .. "..HEAD", "--x", ctx.item.file })
                                                      ^^^^
```

The `--x` flag is NOT a valid git diff option. This should be `--` (path separator).

### Issue 2: Plain Filename Format

Current format shows only plain filenames:
```
lua/utils/snacks_actions.lua
lua/plugins/snacks.lua
tests/myTest.lua
```

**Desired format** (similar to todo_comments picker):
```
[A] lua/utils/new_file.lua
[M] lua/plugins/snacks.lua
[D] tests/old_test.lua
```

Where:
- `[A]` = Added file (green)
- `[M]` = Modified file (blue/yellow)
- `[D]` = Deleted file (red)

## Implementation Plan

### Part 1: Fix Preview Bug

**File**: [lua/utils/snacks_pickers.lua:75](lua/utils/snacks_pickers.lua:75)

**Current Code**:
```lua
vim.list_extend(cmd, { "diff", base_ref .. "..HEAD", "--x", ctx.item.file })
```

**Fix**:
```lua
vim.list_extend(cmd, { "diff", base_ref .. "..HEAD", "--", ctx.item.file })
```

**Change**: Replace `"--x"` with `"--"` (standard git path separator)

### Part 2: Add Status Indicators to File List

**Affected Functions**:
1. `git_last_commit_show()` - Line 322
2. `git_diff_upstream()` - Line 348
3. `show_file_list_picker()` (within custom_change_list_picker) - Line 626

**Implementation Approach**:

1. **Get file status** for each file using `git diff --name-status`:
   ```lua
   -- Returns format: "M\tfile.lua" or "A\tfile.lua" or "D\tfile.lua"
   local status_output = vim.fn.systemlist({
     "git", "diff", "--name-status", base_ref .. "..HEAD"
   })
   ```

2. **Parse status into lookup table**:
   ```lua
   local file_status_map = {}
   for _, line in ipairs(status_output) do
     local status, file = line:match("^(%a)%s+(.+)$")
     if status and file then
       file_status_map[file] = status
     end
   end
   ```

3. **Create custom formatter**:
   ```lua
   format = function(item)
     local file = item.file or item.text
     local status = file_status_map[file] or "M"

     local status_icons = {
       A = { icon = "[A]", hl = "DiagnosticOk" },      -- Green
       M = { icon = "[M]", hl = "DiagnosticInfo" },    -- Blue
       D = { icon = "[D]", hl = "DiagnosticError" },   -- Red
       R = { icon = "[R]", hl = "DiagnosticWarn" },    -- Yellow (renamed)
     }

     local status_info = status_icons[status] or { icon = "[?]", hl = "Comment" }

     return {
       { status_info.icon .. " ", status_info.hl },
       { file, "SnacksPickerFile" },
     }
   end
   ```

4. **Update transform to include status**:
   ```lua
   transform = function(item)
     item.cwd = picker_opts.cwd or git_root
     item.file = item.text
     item.git_status = file_status_map[item.text]  -- Add this
     -- ... existing logic
   end
   ```

### Files to Modify

- [lua/utils/snacks_pickers.lua](lua/utils/snacks_pickers.lua)
  - Line 75: Fix `--x` → `--`
  - Line 322-342: Add formatter to `git_last_commit_show()`
  - Line 348-457: Add formatter to `git_diff_upstream()`
  - Line 626-682: Add formatter to `show_file_list_picker()`

## Reference: How todo_comments Does It

Check `~/.local/share/nvim/lazy/snacks.nvim/lua/snacks/picker/source/todo.lua` for reference on:
- How they format items with prefixes
- How they use highlight groups
- How they structure the format return value

## Success Criteria

### Part 1: Preview Fix
- [ ] Preview shows actual git diff output
- [ ] No git help/usage text appears
- [ ] Diff is properly highlighted with delta or native viewer
- [ ] Works for all three git pickers

### Part 2: Status Indicators
- [ ] Files show `[A]` prefix for added files (green)
- [ ] Files show `[M]` prefix for modified files (blue)
- [ ] Files show `[D]` prefix for deleted files (red)
- [ ] Files show `[R]` prefix for renamed files (yellow)
- [ ] Format matches visual style of todo_comments picker
- [ ] Status indicators are colorized properly

## Verification Checklist

**Test git_last_commit_show (`:lua require("utils.snacks_pickers").custom_git_pickers.git_last_commit_show()`)**:
- [ ] Preview shows actual diff (not git help)
- [ ] Files have status indicators [A]/[M]/[D]
- [ ] Status colors are correct

**Test git_diff_upstream (bound to a keymap)**:
- [ ] Preview shows actual diff (not git help)
- [ ] Files have status indicators
- [ ] Works with different upstream refs

**Test custom_change_list_picker (two-stage picker)**:
- [ ] First stage: Select ref works correctly
- [ ] Second stage: File list has status indicators
- [ ] Preview shows actual diff (not git help)

**Edge Cases**:
- [ ] Renamed files show [R] status
- [ ] Deleted files show [D] and handle missing file gracefully
- [ ] Files with spaces in names work correctly
- [ ] Empty diffs handle gracefully

## Implementation Notes

### Git Status Codes

From `git diff --name-status`:
- `A` - Added
- `M` - Modified
- `D` - Deleted
- `R` - Renamed (R100 = 100% similarity)
- `C` - Copied
- `T` - Type changed

### Highlight Groups to Use

Standard Neovim diagnostic highlights:
- `DiagnosticOk` - Green (for Added)
- `DiagnosticInfo` - Blue (for Modified)
- `DiagnosticError` - Red (for Deleted)
- `DiagnosticWarn` - Yellow (for Renamed)

Or use Snacks-specific:
- `SnacksPickerTitle`
- Custom highlight groups if needed

### Performance Consideration

The `git diff --name-status` call should be made once per picker invocation and cached in the finder closure, not per-item in transform.

## Related Documentation

After implementation, update:
- [docs/memory/snacks_picker.md](docs/memory/snacks_picker.md) - Add notes about custom formatting and git status integration
- Consider adding example screenshots or ASCII art of the new format

---

**Priority**: HIGH - Preview bug breaks usability completely
**Complexity**: MEDIUM - Bug fix is simple, formatter requires understanding snacks format API
**Impact**: HIGH - Affects all custom git pickers

