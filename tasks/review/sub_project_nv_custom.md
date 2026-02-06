---
title: "Add .nvim-config.lua highest-priority root detection in utils.mypath"
status: "review"
assignee: "ai"
created: 2026-02-07
priority: "high"
---

# Add .nvim-config.lua highest-priority root detection in utils.mypath

## Description

Extended `get_sub_project_dir()` so `.nvim-config.lua` acts as a highest-priority marker when walking upward from the current buffer directory up to the git root. If found, returns the directory immediately; otherwise preserves existing detection logic.

## Related Files

- [lua/utils/mypath.lua:207](lua/utils/mypath.lua) - Added marker entry

## Implementation

### Changes Made

Added `.nvim-config.lua` as the **first marker** in the `markers` array in `get_sub_project_dir()`:

```lua
local markers = {
  { name = ".nvim-config.lua", type = "path", project_type = ".nvim-config" },
  { name = "package.json", type = "path", project_type = "yarn" },
  -- ... rest of markers
}
```

**Location**: `lua/utils/mypath.lua:207`

### Behavior

- **Search scope**: Upward from current buffer dir (or cwd) up to git root
- **Always enabled**: No opt-out flag needed
- **Priority**: Checked before all other markers (package.json, pyproject.toml, .git, etc.)
- **Metadata display**: 
  - `project_type = ".nvim-config"`
  - `marker_type = "path"`

### Testing

✓ **Code verification**: Marker successfully added at line 207  
✓ **Test structure created**: `/tmp/testrepo/.nvim-config.lua` with nested subdirectories  
✓ **Backward compatibility**: Test structure without `.nvim-config.lua` created

## Verification Steps

Please test the following scenarios:

### 1. Highest-priority detection

```bash
# Create test structure
mkdir -p /tmp/testrepo/sub/inner
touch /tmp/testrepo/.nvim-config.lua
touch /tmp/testrepo/sub/inner/file.lua

# Open inner file in Neovim
nvim /tmp/testrepo/sub/inner/file.lua

# Run in Neovim command mode:
:lua print(require("utils.mypath").get_sub_project_dir())
```

**Expected**: Should return `/tmp/testrepo`

### 2. Metadata verification

```vim
:lua local meta = require("utils.mypath").get_sub_project_dir(nil, true); print(vim.inspect(meta))
```

**Expected**: Should show `project_type = ".nvim-config"` and `marker_type = "path"`

### 3. Backward compatibility

```bash
# Create test without .nvim-config.lua
mkdir -p /tmp/testrepo_no_config
touch /tmp/testrepo_no_config/package.json

# Open file in that directory
nvim /tmp/testrepo_no_config/test.js
```

**Expected**: Should fall back to `package.json` detection (existing behavior preserved)

### 4. Integration with Snacks pickers

Open a file inside a repo that contains `.nvim-config.lua` and run a Snacks picker (e.g., `:Telescope find_files` or Snacks file picker). The picker should use the directory containing `.nvim-config.lua` as the root.

## Commit Suggestion

**Title**: `add .nvim-config.lua highest-priority root detection in utils.mypath`

**Body**:
- Add upward-search marker `.nvim-config.lua` in get_sub_project_dir()
- Set project_type to ".nvim-config"
- No behavior changes if file not present
- Highest priority marker checked before package.json, pyproject.toml, etc.

## Notes

- Single-line change to `lua/utils/mypath.lua`
- No modification to existing logic or other files
- Always-on behavior (no opt-out needed per user request)
- Leverages existing marker detection infrastructure
