# Marker Options in get_sub_project_dir

## Overview
The marker system in `lua/utils/mypath.lua` supports various options to control matching behavior beyond just file/directory existence.

## Available Marker Options

### `match_from_within` (boolean)
**Purpose**: Only match this marker when `current_dir` is inside the marker's directory.

**Use case**: Markers that should only activate when browsing files within a specific directory, not when browsing sibling directories.

**Example**:
```lua
{ name = ".gitlab", type = "path", project_type = ".glab", match_from_within = true }
```

**Behavior**:
```
/repo
  /.gitlab/          ← marker directory
    /ci.yml          ← browsing here → matches ✓
    /templates/      ← browsing here → matches ✓
  /subproject/       ← browsing here → no match ✗
    /file.ts
```

**Implementation** (lua/utils/mypath.lua:298-307):
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

### Standard Options (existing)

#### `name` (string | string[])
The file/directory name(s) to match. If array, ALL names must exist (AND condition).

#### `type` (string)
- `"path"`: Check for file or directory existence
- `"pattern"`: Match filename against Lua pattern

#### `project_type` (string)
The label to display for this project type (e.g., "yarn", "python", ".glab").

## Future Extension Ideas

Other potential marker options that could be added:

1. **`match_from_outside`**: Opposite of `match_from_within` - only match when NOT inside the directory
2. **`min_depth`**: Only match if directory is at least N levels deep from git root
3. **`max_depth`**: Only match if directory is at most N levels deep from git root
4. **`require_file_content`**: Match only if file contains specific pattern (like how `.nvim-config.lua` checks for `-- mono:` label)
5. **`exclude_if_exists`**: Skip this marker if another file/directory exists

## Design Principles

1. **Options over types**: Prefer adding marker options over creating new marker types
2. **Composability**: Options should be composable (multiple options on same marker)
3. **Clear naming**: Option names should clearly indicate their behavior
4. **Minimal logic**: Each option should do one thing well
5. **Reusability**: Options should be reusable across different markers

## Examples

### Example 1: .gitlab marker with match_from_within
```lua
{ 
  name = ".gitlab", 
  type = "path", 
  project_type = ".glab", 
  match_from_within = true 
}
```
Only shows `.glab` type when editing files inside `.gitlab/` directory.

### Example 2: Hypothetical .config marker
```lua
{ 
  name = ".config", 
  type = "path", 
  project_type = "cfg", 
  match_from_within = true,
  min_depth = 1  -- hypothetical: only match if not at root
}
```

### Example 3: Multiple markers with options
```lua
local markers = {
  { name = ".nvim-config.lua", type = "path", project_type = ".nv" },
  { name = ".gitlab", type = "path", project_type = ".glab", match_from_within = true },
  { name = ".github", type = "path", project_type = ".gh", match_from_within = true },
  { name = "package.json", type = "path", project_type = "yarn" },
}
```

## Testing

When adding new marker options:
1. Write unit tests for the option behavior
2. Test edge cases (nested directories, multiple markers, etc.)
3. Test interaction with existing options
4. Update documentation with examples

## Related Files
- `lua/utils/mypath.lua:205-221` - Marker configuration
- `lua/utils/mypath.lua:298-307` - match_from_within implementation
- `docs/memory/gitlab_dirname_marker.md` - .gitlab marker documentation
