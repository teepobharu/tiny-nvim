# Trailing Colon Bug Test

Test file for the trailing colon bug reported by user.

## Issue

When a path has a trailing colon without a line number (e.g., `file.lua:`), the colon was not being stripped, causing the file to not be found.

## Bug Report

User reported:
```
lua/overseer/template/agoda/android_client/and_build.lua:
```

This path with trailing colon was not opening correctly.

## Fix

Added trailing colon stripping in `lua/utils/file_reference.lua`:

```lua
-- No line number - use whole target, but strip trailing colons
path = target:gsub(":+$", "")  -- Remove trailing colons
```

## Test Cases

Place cursor on each path and press `gF`. All should open correctly now.

### Basic Trailing Colon

1. lua/config/mykeymaps.lua:
2. lua/plugins/ui.lua:
3. lua/utils/file_reference.lua:

### Multiple Trailing Colons

4. lua/config/mykeymaps.lua::
5. lua/plugins/ui.lua:::

### With Wrappers

6. `lua/config/mykeymaps.lua:`
7. "lua/plugins/ui.lua:"
8. 'lua/utils/file_reference.lua:'
9. [lua/config/mykeymaps.lua:]

### The Reported Bug

10. lua/overseer/template/agoda/android_client/and_build.lua:

### With file:// URI

11. file:///tmp/test.lua:
12. `file:///tmp/test.lua:`

## Expected Results

All paths should:
1. Strip trailing colons (one or more)
2. Strip wrappers if present
3. Open the correct file
4. NOT try to jump to a line (since no line number was provided)

## Verification

After testing:
- [ ] Basic trailing colon works (3 tests)
- [ ] Multiple trailing colons work (2 tests)
- [ ] Wrappers + trailing colon work (4 tests)
- [ ] Reported bug is fixed (1 test)
- [ ] file:// URI with trailing colon works (2 tests)

Total: 12 trailing colon tests

## Technical Details

**Before fix:**
- `file.lua:` → kept as `file.lua:` → file not found
- Pattern `(.+):(%d+)$` requires a number after `:`
- Falls through to treating entire string as path

**After fix:**
- `file.lua:` → stripped to `file.lua` → file found
- `file.lua::` → stripped to `file.lua` → file found
- Uses `gsub(":+$", "")` to remove one or more trailing colons
