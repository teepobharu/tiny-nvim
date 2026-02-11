# .gitlab Directory Marker Detection

## Overview
Special handling for `.gitlab` directory marker that only activates when browsing **inside** the `.gitlab` directory itself, not from other subprojects.

## Problem
Previous approach using `../.gitlab` marker would mark ALL subdirectories of a git repo as `.glab` type, even when browsing regular subprojects. This was unwanted behavior.

## Solution
Added new marker option: `match_from_within = true`

### Marker Configuration
```lua
{ name = ".gitlab", type = "path", project_type = ".glab", match_from_within = true }
```

### Behavior
- ✅ **Activates**: When `current_dir` path contains `/.gitlab/` or ends with `/.gitlab`
- ❌ **Does NOT activate**: When browsing other directories (even if `.gitlab` exists at repo root)

### Examples

```
/repo
  /.gitlab           ← .gitlab directory exists
    /ci.yml          ← browsing here → type = ".glab" ✓
    /templates/      ← browsing here → type = ".glab" ✓
  /subproject1/      ← browsing here → type = "git" (not .glab) ✓
    /src/
      /file.ts       ← browsing here → type = "git" (not .glab) ✓
```

## Implementation Details

### Marker Option: `match_from_within`
Added in `check_marker_match()` function (after finding matched files):

```lua
-- Check match_from_within option: only match if current_dir is inside this directory
if marker.match_from_within and #matched_files > 0 then
  local marker_dir = dir .. "/" .. matched_files[1]
  -- Check if current_dir is inside marker_dir
  local is_inside = current_dir:match("^" .. vim.pesc(marker_dir) .. "/") 
                 or current_dir == marker_dir
  if not is_inside then
    return nil  -- Skip this marker if not browsing inside the directory
  end
end
```

### How It Works
1. Marker is checked normally (file/directory exists at `dir/.gitlab`)
2. If `match_from_within = true`, additional check:
   - Is `current_dir` inside `dir/.gitlab/` (starts with path)
   - Or is `current_dir` exactly `dir/.gitlab`
3. If not inside, return `nil` (no match)
4. If inside, proceed with normal marker match

### Priority Order
The `.gitlab` marker (index 10) is checked **before** `.git` (index 11), but only matches when actively browsing inside `.gitlab` directory.

## Use Cases

1. **GitLab CI configuration management**: When editing files in `.gitlab/` directory, show `.glab` project type
2. **Monorepo subprojects**: Regular subprojects show their own marker type (yarn, python, etc.), not `.glab`
3. **Multiple .gitlab directories**: Each subproject can have its own `.gitlab/` directory with independent detection

## Testing

See comprehensive tests in `/tmp/test_gitlab_comprehensive.lua`:
- ✓ Root `.gitlab/` directory detection
- ✓ Nested paths inside `.gitlab/nested/`
- ✓ Subproject-specific `.gitlab/` directories
- ✓ Non-matching behavior for regular subprojects
- ✓ Non-matching for directories without `.gitlab`

## Related Files
- `lua/utils/mypath.lua:295-303` - match_from_within logic
- `lua/utils/mypath.lua:218` - Marker configuration

## Migration Notes
Changed from:
```lua
{ name = "../.gitlab", type = "path", project_type = ".glab" }
```

To:
```lua
{ name = ".gitlab", type = "path", project_type = ".glab", match_from_within = true }
```

This approach uses a marker option instead of a new type, making it reusable for other markers that need similar behavior.
