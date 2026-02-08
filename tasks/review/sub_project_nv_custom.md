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
- [lua/utils/mypath.lua:240-262](lua/utils/mypath.lua) - Mono label extraction function
- [lua/utils/mypath.lua:300-305](lua/utils/mypath.lua) - Label extraction integration

## Implementation

### Changes Made

**1. Added `.nvim-config.lua` as the first marker** (line 207):

```lua
local markers = {
  { name = ".nvim-config.lua", type = "path", project_type = ".nvim-config" },
  { name = "package.json", type = "path", project_type = "yarn" },
  -- ... rest of markers
}
```

**2. Added mono label extraction function** (lines 240-262):

Extracts custom label from `.nvim-config.lua` file content:
- Searches for pattern: `-- mono:<label>`
- Returns the extracted label (e.g., `tbff` from `-- mono:tbff`)
- Falls back to `.nv` if pattern not found
- Pattern matching: case-sensitive, any non-whitespace characters after `mono:`

**3. Integrated label extraction into marker matching** (lines 300-305):

When `.nvim-config.lua` is detected, the function:
- Reads the file content
- Extracts the mono label
- Uses the label as the `project_type` in metadata
- This label is displayed in pickers (e.g., `toggle_cwd_files_grep` shows "Sub-Project (tbff)")

### Behavior

- **Search scope**: Upward from current buffer dir (or cwd) up to git root
- **Always enabled**: No opt-out flag needed
- **Priority**: Checked before all other markers (package.json, pyproject.toml, .git, etc.)
- **Metadata display**: 
  - `project_type = <extracted_label>` (e.g., `"tbff"` or `".nv"` fallback)
  - `marker_type = "path"`
- **Label extraction**:
  - Searches for `-- mono:<label>` in file content
  - Any characters after `mono:` until whitespace
  - Falls back to `.nv` if not found

### Testing

✓ **Code verification**: Marker successfully added at line 207  
✓ **Label extraction**: Function added and tested (lines 240-262)  
✓ **Test structure created**: `/tmp/testrepo/.nvim-config.lua` with `-- mono:tbff`  
✓ **Backward compatibility**: Test structure without `.nvim-config.lua` created
✓ **Label extraction tests**: All 3 test cases pass (with label, without label, non-existent file)

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

**Expected**: Should show `project_type = <extracted_label>` (e.g., `"tbff"`) and `marker_type = "path"`

### 3. Mono label extraction

```bash
# Create test with mono label
mkdir -p /tmp/testrepo_with_label/sub
cat > /tmp/testrepo_with_label/.nvim-config.lua << 'EOF'
-- mono:tbff
return {}
EOF

# Open file in that directory
nvim /tmp/testrepo_with_label/sub/test.lua

# Run in Neovim command mode:
:lua local meta = require("utils.mypath").get_sub_project_dir(nil, true); print(vim.inspect(meta.project_type))
```

**Expected**: Should return `"tbff"` (extracted from `-- mono:tbff`)

### 4. Mono label fallback

```bash
# Create test without mono label
mkdir -p /tmp/testrepo_no_label/sub
cat > /tmp/testrepo_no_label/.nvim-config.lua << 'EOF'
-- No mono label here
return {}
EOF

# Open file in that directory
nvim /tmp/testrepo_no_label/sub/test.lua

# Run in Neovim command mode:
:lua local meta = require("utils.mypath").get_sub_project_dir(nil, true); print(vim.inspect(meta.project_type))
```

**Expected**: Should return `".nv"` (fallback when no mono label found)

### 5. Backward compatibility

```bash
# Create test without .nvim-config.lua
mkdir -p /tmp/testrepo_no_config
touch /tmp/testrepo_no_config/package.json

# Open file in that directory
nvim /tmp/testrepo_no_config/test.js
```

**Expected**: Should fall back to `package.json` detection (existing behavior preserved)

### 6. Integration with Snacks pickers (toggle_cwd_files_grep)

Open a file inside a repo that contains `.nvim-config.lua` with a mono label, then use `toggle_cwd_files_grep` action (typically `<A-s>` in pickers) to cycle through CWD scopes. The picker should display the mono label as the project type.

**Example**: If `.nvim-config.lua` contains `-- mono:tbff`, the picker should show: `"Sub-Project (tbff)"`

## Commit Suggestion

**Title**: `add .nvim-config.lua highest-priority root detection in utils.mypath`

**Body**:
- Add upward-search marker `.nvim-config.lua` in get_sub_project_dir()
- Extract mono label from file content (pattern: `-- mono:<label>`)
- Set project_type to extracted label (fallback: `.nv`)
- Highest priority marker checked before package.json, pyproject.toml, etc.
- No behavior changes if file not present

## Notes

- Changes to `lua/utils/mypath.lua`:
  - Line 207: Added `.nvim-config.lua` marker entry
  - Lines 240-262: Added `extract_mono_label()` helper function
  - Lines 300-305: Integrated label extraction into `check_marker_match()`
- No modification to existing logic or other files
- Always-on behavior (no opt-out needed per user request)
- Leverages existing marker detection infrastructure
- Label extraction is case-sensitive and matches any non-whitespace characters after `mono:`
- Pattern: `-- mono:<label>` (with optional leading whitespace)
- Displayed in pickers via `project_type` metadata field (e.g., `toggle_cwd_files_grep` shows "Sub-Project (tbff)")
