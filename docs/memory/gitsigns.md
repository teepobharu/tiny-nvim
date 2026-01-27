# Gitsigns.nvim Memory Bank

## 🚨 BREAKING CHANGES - v2.0.0 (2025-01-24)

### Critical Migration Items

#### 1. Custom Highlight Names REMOVED
**What Changed**: Configuration for custom highlight group names eliminated
**Action Required**:
```lua
-- ❌ REMOVE - No longer supported
config = {
  signs = {
    add = { hl = "MyCustomAddHighlight" },
    change = { hl = "MyCustomChangeHighlight" },
  }
}

-- ✅ USE - Standard highlight groups only
-- Gitsigns will use its own highlight groups
-- Customize via standard vim highlight commands:
vim.api.nvim_set_hl(0, "GitSignsAdd", { fg = "#00ff00" })
```

**Check**: Search config for `signs.*hl =` patterns

---

#### 2. Setup Function Now Optional
**What Changed**: `require('gitsigns').setup()` no longer mandatory
**Behavior**:
```lua
-- Both are valid:
require('gitsigns').setup({})  -- With custom config
-- OR
-- No setup call - uses defaults
```
**Current Config**: CHECK lua/plugins/ui.lua for gitsigns setup

---

#### 3. Minimum Neovim Version: 0.11
**Dropped**: Support for Neovim 0.9.5
**Action**: Verify Neovim version >= 0.11
```vim
:version  " Check current version
```

---

#### 4. Deprecated Options Removed

**current_line_blame_formatter_opts** - REMOVED
```lua
-- ❌ REMOVE if present
config = {
  current_line_blame_formatter_opts = { ... }
}

-- ✅ USE instead
config = {
  current_line_blame_formatter = "<custom_format>"
}
```

**yadm support** - REMOVED
```lua
-- ❌ REMOVE if present
config = {
  yadm = { enable = true }
}
```

---

## ✨ New Features (v2.0.0)

### 1. Statuscolumn Support (commit b2094c6)
**What**: Native statuscolumn integration for git signs
**Pattern**:
```lua
-- Gitsigns will automatically populate statuscolumn
-- Configure in neovim:
vim.opt.statuscolumn = "%s%=%{v:relnum?v:relnum:v:lnum} "
```
**Benefit**: Shows git signs in statuscolumn alongside line numbers

### 2. Better Stability
- **Timer Improvements** (commit 72acb69): More robust timer closing
- **WinResized Handler** (commit ecd3717): Update blame window extmarks on resize
- **Cygpath Handling** (commit 8690d7a): MSYS2 environment support

---

## Configuration Validation

### Step 1: Find Current Config
**Check locations**:
1. `lua/plugins/ui.lua` - Most likely location
2. `lua/plugins/*.lua` - Search for "gitsigns"
3. `lua/config/*.lua` - Config overrides

**Search command**:
```bash
rg "gitsigns" --type lua -l
```

### Step 2: Identify Breaking Changes
**Look for**:
- Custom `hl =` in signs config
- `current_line_blame_formatter_opts`
- `yadm` references
- Neovim version checks

### Step 3: Remove Deprecated
**Pattern**:
```lua
-- BEFORE (v1.x)
require('gitsigns').setup({
  signs = {
    add = { hl = 'GitSignsAdd', text = '+' },
  },
  current_line_blame_formatter_opts = { ... },
  yadm = { enable = true },
})

-- AFTER (v2.0)
require('gitsigns').setup({
  signs = {
    add = { text = '+' },  -- No hl field
  },
  -- Removed: current_line_blame_formatter_opts
  -- Removed: yadm
})
```

### Step 4: Test Functionality
```vim
" Open a git-tracked file
:e some_file.lua

" Check gitsigns status
:Gitsigns status

" Test blame
:Gitsigns blame_line

" Check health
:checkhealth gitsigns
```

---

## Current Config Analysis

**File**: lua/plugins/ui.lua (NEEDS VERIFICATION)

**Search Results**: Found references in:
- tests/myTestSnacks.lua
- lua/config/mykeymaps.lua
- lua/config/autocmds.lua
- tests/myTest.lua
- lua/plugins/ui.lua ← CHECK THIS
- lua/utils/git.lua
- lua/utils/editor_keymaps.lua
- lua/utils/snacks_actions_wip.lua
- lua/utils/snacks_actions.lua

**Action**: Read lua/plugins/ui.lua and verify gitsigns config

---

## Migration Checklist

### Pre-Migration
- [ ] Backup current config
- [ ] Note current keymaps and functionality
- [ ] Check Neovim version >= 0.11

### Breaking Changes
- [ ] Remove custom `hl =` definitions
- [ ] Remove `current_line_blame_formatter_opts`
- [ ] Remove `yadm` config
- [ ] Verify no deprecated functions used

### Post-Migration
- [ ] Test blame functionality
- [ ] Test sign display
- [ ] Test keymaps (if any)
- [ ] Run `:checkhealth gitsigns`
- [ ] Verify statuscolumn integration (if used)

### Customization (Optional)
- [ ] Set custom highlights via `nvim_set_hl()`
- [ ] Configure statuscolumn for signs
- [ ] Adjust sign text/numhl/linehl

---

## Common Issues & Solutions

### Issue: Signs not showing after update
**Cause**: Custom highlight removed
**Solution**:
```lua
-- Set custom highlights properly
vim.api.nvim_set_hl(0, "GitSignsAdd", { fg = "#00ff00" })
vim.api.nvim_set_hl(0, "GitSignsChange", { fg = "#ffff00" })
vim.api.nvim_set_hl(0, "GitSignsDelete", { fg = "#ff0000" })
```

### Issue: Blame formatter not working
**Cause**: `current_line_blame_formatter_opts` removed
**Solution**: Use `current_line_blame_formatter` string format

### Issue: YADM repos not detected
**Cause**: YADM support removed in v2.0
**Solution**: Use regular git or submit feature request

---

## References

- **Config Location**: lua/plugins/ui.lua (TO VERIFY)
- **Source**: ~/.local/share/nvim/lazy/gitsigns.nvim
- **Changelog**: https://github.com/lewis6991/gitsigns.nvim/blob/main/CHANGELOG.md
- **v2.0 Release**: https://github.com/lewis6991/gitsigns.nvim/releases/tag/v2.0.0
- **Help Docs**: `:help gitsigns.txt`

---

## Next Steps

1. **Immediate**: Check lua/plugins/ui.lua for gitsigns config
2. **Validate**: Remove any breaking change patterns
3. **Test**: Verify functionality after cleanup
4. **Document**: Note any custom highlights needed

---

## Staging/Unstaging Keymaps

**Full documentation**: [tasks/done/gitsigns_unstage_buffer_keymap.md](tasks/done/gitsigns_unstage_buffer_keymap.md)

### Buffer-Level Operations

| Keymap | Function | Git Equivalent | Destructive? | Description |
|--------|----------|----------------|--------------|-------------|
| `<leader>ghS` | `stage_buffer()` | `git add <file>` | No | Stage all hunks in buffer |
| `<leader>ghU` | `reset_buffer_index()` | `git reset HEAD <file>` | No | Unstage buffer (keeps changes) |
| `<leader>ghR` | `reset_buffer()` | `git checkout -- <file>` | ⚠️ YES | Discard all changes in buffer |

### Hunk-Level Operations

| Keymap | Function | Description |
|--------|----------|-------------|
| `<leader>ghs` | `stage_hunk` | Stage hunk under cursor |
| `<leader>ghr` | `reset_hunk` | Reset hunk under cursor |
| `<leader>ghu` | `undo_stage_hunk` | ⚠️ DEPRECATED - Use stage_hunk on staged signs |

### Key Differences

**`stage_buffer()` vs `reset_buffer_index()`**
- `stage_buffer()`: Adds changes to staging area (prepares for commit)
- `reset_buffer_index()`: Removes changes from staging area (keeps working directory changes)
- Both are **safe** - they preserve your changes

**`reset_buffer_index()` vs `reset_buffer()`**
- `reset_buffer_index()`: Unstages only (changes remain in file)
- `reset_buffer()`: **DESTRUCTIVE** - permanently discards changes

### Workflow Example

```
Your Changes → Stage → Commit
    ↓            ↓
reset_buffer()  reset_buffer_index()
(DANGEROUS!)    (Safe unstage)
```

**Location**: [lua/plugins/ui.lua:300-303](lua/plugins/ui.lua:300)

---

**Last Updated**: 2026-01-25
**Plugin Version**: v2.0.0
**Status**: ⚠️ BREAKING CHANGES - NEEDS VALIDATION
**Priority**: HIGH - Test ASAP
