# Snacks Picker Memory Bank

## Critical Patterns & Caveats

### 1. Items Must Have `text` Field
**Problem**: "attempt to index local 'str' (a nil value)" error in matcher.lua:524
**Root Cause**: Snacks picker matcher requires a `text` field on all items for filtering/matching
**Pattern**: When creating picker items:
```lua
table.insert(items, {
  text = item_display_text,  -- REQUIRED: this is what gets matched
  file = item_path,          -- optional: for file pickers
  -- other fields...
})
```
**Reference**: lua/utils/snacks_pickers.lua:40-42

### 2. Static vs Dynamic Item Sources
**Static items** (use when list doesn't change):
```lua
Snacks.picker.pick {
  items = static_list,  -- Direct list
  -- ...
}
```

**Dynamic items** (use when list can change):
```lua
Snacks.picker.pick {
  finder = function(_opts, _ctx)
    local items = scan_source()  -- Rescanned on each refresh
    return items
  end,
  -- ...
}
```
**Reference**: lua/utils/snacks_pickers.lua:29-63

### 3. Picker Refresh Without Closing
**Pattern**: Keep picker open after save/delete operations
```lua
-- DO NOT close picker
-- picker:close()  -- ❌ Wrong

-- Instead, refresh after operation
vim.cmd("SDelete! " .. session)
vim.notify("Deleted", vim.log.levels.INFO)
vim.defer_fn(function()
  picker:refresh()  -- Rescans finder function
end, 100)  -- 100ms delay to let filesystem sync
```
**Why defer_fn**: Avoids race conditions when filesystem isn't immediately updated
**Reference**: lua/utils/snacks_pickers.lua:91-108

### 5. Function Parameter Requirements
**Issue**: `snacks_action_factories.create_git_file_actions` requires 2 parameters
```lua
-- ❌ Wrong - missing second parameter
local actions = create_git_file_actions("HEAD~1")

-- ✓ Correct - with no_resolve flag
local actions = create_git_file_actions("HEAD~1", false)
```
**Parameters**:
- `ref_provider`: Git reference to use
- `no_resolve`: boolean - if true, skip ref resolution
**Reference**: lua/utils/snacks_pickers.lua:220, 333

## Actions 
https://github.com/folke/snacks.nvim/blob/main/lua/snacks/picker/actions.lua

ask in : https://deepwiki.com/search/is-there-copy-action-and-how-d_e0314aa4-42c3-4052-878a-ab59592d04ec?mode=fast

## Debugging Tips

### Picker Item Structure Issues
If getting matcher errors:
1. Check all items have `text` field (required for format="text")
2. Use `finder` function for dynamic data
3. Verify item structure matches picker format type

### Refresh Not Working
- Use `vim.defer_fn()` with ~100ms delay after file operations
- Direct `picker:refresh()` doesn't reschedule if timing is off
- Test with print statements to verify refresh is called

### Resume Behavior
- Check `resume = false` to prevent unwanted cached state
- Useful for pickers showing dynamic data (sessions, terminals, etc)

## Related Files
- lua/utils/snacks_pickers.lua - Main picker implementations
- lua/utils/snacks_actions.lua - Picker action handlers
- ~/.local/share/nvim/lazy/snacks.nvim - Official snacks source

## Session Picker Implementation
**File**: lua/utils/snacks_pickers.lua:18-125
**Key features**:
- Dynamic finder scans session directory on refresh
- No close on save/delete - stays open
- Deferred refresh avoids race conditions
- `resume = false` ensures fresh session list each open
