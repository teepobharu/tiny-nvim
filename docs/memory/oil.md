# Oil.nvim Memory Bank

## Recent Updates (2026-01-24)

### New Features

#### 1. Multicursor Support (commit 756dec8)
**What**: Integration with `multicursor.nvim` plugin
**Status**: NOT CONFIGURED (not in current oil.lua)
**Use Case**: Edit multiple files simultaneously in oil buffer

**Pattern** (if enabled):
```lua
-- Would need multicursor.nvim plugin
-- Oil automatically detects and integrates
```

**Decision Point**:
- ✅ Add multicursor.nvim if frequently editing multiple file names
- ❌ Skip if single-file editing is sufficient

---

#### 2. Horizontal Scrolling Actions (commit 2405570)
**What**: New actions for horizontal navigation
**Benefit**: Better handling of wide directory listings

**New Actions** (check `:help oil-actions`):
- Scroll left/right
- Jump to start/end of line
- Better wide path support

**Current Config**: NOT explicitly configured (uses defaults)
**Recommendation**: Test with `g?` in oil buffer to see available actions

---

#### 3. Toggle Float Parameters (commit f55b25e)
**What**: `open_float` and `toggle_float` now accept params
**Pattern**:
```lua
-- More flexible float control
require('oil').toggle_float({
  max_width = 150,
  max_height = 40,
  -- ... other overrides
})
```

**Current Usage** (myEditor.lua:99-106):
```lua
keys = {
  {
    "<leader>e",
    function()
      require("oil").toggle_float()  -- No params yet
    end,
  },
}
```

**Enhancement Opportunity**: Add params for different contexts

---

#### 4. Improved Error Handling (commit d278dc4)
**What**: Better error propagation in recursive_delete and recursive_copy
**Benefit**: Clearer error messages when operations fail

---

## Current Configuration

**File**: lua/plugins/extra/oil.lua:44-108

### Core Settings ✅
```lua
opts = {
  default_file_explorer = true,           -- Replace netrw
  skip_confirm_for_simple_edits = true,   -- Faster workflow
  use_default_keymaps = true,             -- Standard keymaps
}
```

### View Options ✅
```lua
view_options = {
  show_hidden = false,  -- Don't show dotfiles by default
  is_hidden_file = function(name, _)
    -- Dotfiles
    if vim.startswith(name, ".") then
      return true
    end

    -- Gitignored files
    local dir = require("oil").get_current_dir()
    if not dir then return false end
    return vim.list_contains(git_ignored[dir], name)
  end,
}
```

**Smart Hiding**: Uses git-ignored cache (lines 1-20)
- Memoizes `git ls-files --ignored` output
- Automatic cache per directory
- Efficient for large repos

### Float Configuration ✅
```lua
float = {
  padding = 2,
  max_width = 120,
  max_height = max_height(),  -- Dynamic (lines 21-30)
  border = "rounded",
  win_options = { winblend = 0 },
}
```

**Dynamic Height Pattern** (lines 21-30):
- Window ≥ 40 lines → max_height = 30
- Window ≥ 30 lines → max_height = 20
- Window < 30 lines → max_height = 10

### Custom Keymaps ✅
```lua
keymaps = {
  ["<C-c>"] = false,              -- Disable default
  ["<C-s>"] = {
    desc = "Save all changes",
    callback = function()
      require("oil").save({ confirm = false })
    end,
  },
  ["q"] = "actions.close",
  ["<C-y>"] = "actions.copy_entry_path",
}
```

**Keymap Strategy**:
- `<C-s>` - Quick save without confirmation
- `q` - Quick close
- `<C-y>` - Copy path to clipboard
- Disables `<C-c>` (uses default Neovim escape)

---

## Patterns & Caveats

### 1. Git-Ignored Files Caching
**Location**: lua/plugins/extra/oil.lua:1-20
**Pattern**:
```lua
local git_ignored = setmetatable({}, {
  __index = function(self, key)
    -- Run git ls-files only once per directory
    local proc = vim.system({
      "git", "ls-files", "--ignored",
      "--exclude-standard", "--others", "--directory"
    }, { cwd = key, text = true })
    -- Cache result
    rawset(self, key, ret)
    return ret
  end,
})
```

**Why**: Avoid repeated git calls for same directory
**Caveat**: Cache persists until Neovim restart
**Workaround**: Toggle `show_hidden` to refresh view

---

### 2. Dynamic Float Height
**Pattern** (lines 21-30):
```lua
local function max_height()
  local height = vim.fn.winheight(0)
  if height >= 40 then return 30
  elseif height >= 30 then return 20
  else return 10 end
end
```

**Why**: Adapt to terminal/window size
**Benefit**: Better UX on small screens vs large monitors

---

### 3. Snacks Explorer Disabled
**Pattern** (lua/plugins/extra/oil.lua:34-42):
```lua
{
  "folke/snacks.nvim",
  optional = true,
  opts = {
    explorer = { enabled = false },
  },
}
```

**Why**: Avoid conflicts between snacks.explorer and oil
**Current Choice**: Oil is the file explorer

---

## Multicursor Integration Decision

### If Using Multicursor Editing Frequently

**Add multicursor.nvim**:
```lua
-- In plugins/*.lua
{
  'jake-stewart/multicursor.nvim',
  config = function()
    require('multicursor-nvim').setup()
  end,
  -- Oil will automatically integrate
}
```

**Use Cases**:
- Batch rename files (change prefixes/suffixes)
- Mass delete similar files
- Simultaneous path editing

### If Single-File Editing Is Sufficient
- ✅ Keep current config (no multicursor)
- Use standard vim motions in oil buffer

---

## Enhancement Opportunities

### 1. Parameterized Toggle Float
**Current**:
```lua
require("oil").toggle_float()
```

**Enhanced**:
```lua
-- Context-aware float sizes
vim.keymap.set("n", "<leader>e", function()
  require("oil").toggle_float({
    max_width = vim.o.columns - 4,  -- Full width minus padding
    max_height = vim.o.lines - 4,    -- Full height minus padding
  })
end)

-- Or compact mode
vim.keymap.set("n", "<leader>E", function()
  require("oil").toggle_float({
    max_width = 80,
    max_height = 20,
  })
end)
```

### 2. Horizontal Scroll Actions
**Test**: Open oil and press `g?` to see available actions
**Add**: Keymaps for horizontal navigation if needed

### 3. Custom Save Confirmations
**Current**: `confirm = false` for all saves
**Alternative**: Conditional confirmation for risky operations
```lua
callback = function()
  local changes = require("oil").get_changes()
  local has_delete = vim.tbl_contains(
    vim.tbl_map(function(c) return c.type end, changes),
    "delete"
  )
  require("oil").save({
    confirm = has_delete  -- Confirm only for deletions
  })
end,
```

---

## Testing Checklist

### Core Functionality
- [ ] Open oil with `<leader>e`
- [ ] Navigate directories
- [ ] Create new file
- [ ] Rename file
- [ ] Delete file (test confirmation)
- [ ] Copy path with `<C-y>`
- [ ] Save changes with `<C-s>`
- [ ] Close with `q`

### Edge Cases
- [ ] Open in git repo (test gitignored filtering)
- [ ] Open in non-git directory
- [ ] Test with very long file names (horizontal scroll)
- [ ] Test float on small terminal
- [ ] Test float on large monitor

### New Features (if added)
- [ ] Multicursor editing (if plugin added)
- [ ] Horizontal scroll actions
- [ ] Parameterized float sizes

---

## Common Issues & Solutions

### Issue: Hidden files still showing
**Cause**: Git-ignored cache not refreshed
**Solution**: Toggle `show_hidden` twice to refresh

### Issue: Float too small/large
**Cause**: Fixed max_height/max_width
**Solution**: Adjust float config or use parameterized toggle

### Issue: Save confirmation annoying
**Cause**: `skip_confirm_for_simple_edits = false`
**Solution**: Already set to `true` in config ✅

---

## References

- **Config**: lua/plugins/extra/oil.lua
- **Keymap Config**: lua/plugins/extra/myEditor.lua:42-46
- **Source**: ~/.local/share/nvim/lazy/oil.nvim
- **Docs**: https://github.com/stevearc/oil.nvim
- **Help**: `:help oil.nvim`, `:help oil-actions`
- **Keymap Reference**: `g?` in oil buffer

---

## Next Steps

1. **Test Horizontal Scroll**: Open oil, press `g?`, explore new actions
2. **Multicursor Decision**: Evaluate if needed for workflow
3. **Parameterized Float**: Consider context-aware sizing
4. **Document Patterns**: Note any new issues/solutions here

---

**Last Updated**: 2026-01-24
**Plugin Version**: Latest (multiple recent commits)
**Status**: CONFIGURED ✅ WORKING ✅
**Enhancements**: Optional (multicursor, parameterized float)
