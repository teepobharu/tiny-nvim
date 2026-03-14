# Marker Options in get_sub_project_dir

## Overview
The marker system in `lua/utils/mypath.lua` supports various options to control matching behavior beyond just file/directory existence.

## Available Marker Options

### `match_from_within` (boolean)
**Purpose**: Only match this marker when `current_dir` is inside the marker's directory. The marker directory itself becomes the subproject dir (not its parent).

**Use case**: Markers that should only activate when browsing files within a specific directory, not when browsing sibling directories.

**Example**:
```lua
{ name = ".gitlab", type = "path", project_type = ".glab", match_from_within = true, is_directory = true }
```

**Behavior**:
```
/repo
  /.gitlab/          ← marker directory = subproject dir
    /ci.yml          ← browsing here → matches ✓ (subproject = /repo/.gitlab)
    /templates/      ← browsing here → matches ✓ (subproject = /repo/.gitlab)
  /subproject/       ← browsing here → no match ✗
    /file.ts
```

**Implementation** (lua/utils/mypath.lua): Two code paths handle this:
1. **Direct match**: When candidate dir IS the marker dir (e.g. `/repo/.gitlab`), basename comparison triggers early return
2. **Parent match**: When candidate dir is the parent (e.g. `/repo`), finds marker child and redirects `effective_dir` to marker dir

### `git_ignored` (boolean, default: false)
**Purpose**: Mark files that are excluded by `.gitignore` (global or local). Uses `git ls-files --ignored` or filesystem glob fallback.

**Use case**: Files like `.nvim-config.lua` that are in global gitignore but should still be detected as subproject markers.

**Example**:
```lua
{ name = ".nvim-config.lua", type = "path", project_type = ".nv", git_ignored = true }
```

**Opt-out**: Set `vim.g.subproject_scan_ignored = false` to disable Pipeline C entirely.

### `is_directory` (boolean, default: false)
**Purpose**: Indicates the marker target is a directory, not a file. Uses `**/<name>/**` pattern with `git ls-files` to find files inside, then extracts the parent directory.

**Use case**: Directories like `.gitlab/`, `Clientside/`, `Serverside/`, `.git/` that won't be found by `git ls-files` directly (git only tracks files, not directories).

**Example**:
```lua
{ name = { "Clientside", "Serverside" }, type = "path", project_type = "cronos", is_directory = true }
```

### Standard Options (existing)

#### `name` (string | string[])
The file/directory name(s) to match. If array, ALL names must exist (AND condition).
Names are auto-stripped of trailing `/` during scanning.

#### `type` (string)
- `"path"`: Check for file or directory existence
- `"pattern"`: Match filename against Lua pattern

#### `project_type` (string)
The label to display for this project type (e.g., "yarn", "python", ".glab").

## Scanning Pipelines

The `get_sub_project_dirs_from_root()` function uses three pipelines based on marker flags:

| Pipeline | Condition | Method | Examples |
|----------|-----------|--------|----------|
| A: Tracked files | `!git_ignored && !is_directory` | `git ls-files -- **/<name>` | package.json, Cargo.toml |
| B: Tracked dirs | `!git_ignored && is_directory && !skip_scan` | `git ls-files -- **/<name>/**` | .gitlab, Clientside |
| C: Ignored files | `git_ignored` | `fd` with timeout, `find` fallback | .nvim-config.lua |
| Pattern | `type == "pattern"` | `git ls-files -- **/<glob>` | %.sln$ |
| (skip) | `skip_scan = true` | No scan, detected via candidate_dirs | .git |

### Performance Notes

- **Pipeline B** can be slow on large monorepos if directory markers contain many files (e.g. `Clientside/` with 3000+ files). The inner loop breaks on first marker match per file and deduplicates via `seen_dir_candidates`.
- **Pipeline C** prefers `fd` because it is much faster on large repos (`~0.05s` cold on `TRIPWEB-2701-custom-note-slice` vs `find ~0.53s`). It groups all ignored marker names into one command, honors `vim.g.subproject_scan_ignored_timeout_ms`, and falls back to `find` only when `fd` is unavailable. Disable Pipeline C entirely with `vim.g.subproject_scan_ignored = false`.
- **`skip_scan`** flag prevents `.git` from entering Pipeline B — git root is always added as a candidate automatically.
- **Caching** prevents repeated scans within the same session. Cache invalidates on `.git` mtime changes or when `clear_subproject_cache()` bumps the generation counter. Ignored-only files like `.nvim-config.lua` do not touch `.git`, so use force refresh when those markers change.

## Result Metadata

Each result includes a `scan_source` field for diagnostics:
- `"tracked"` — found via Pipeline A (default)
- `"dir"` — found via Pipeline B
- `"ignored"` — found via Pipeline C

Shown in picker preview header as `marker:<name>(<source>)` when source is not "tracked".

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

### Example 1: .gitlab marker with match_from_within + is_directory
```lua
{ 
  name = ".gitlab", 
  type = "path", 
  project_type = ".glab", 
  match_from_within = true,
  is_directory = true 
}
```
Only shows `.glab` type when editing files inside `.gitlab/` directory. The `.gitlab/` dir itself is the subproject.

### Example 2: Git-ignored file marker
```lua
{ 
  name = ".nvim-config.lua", 
  type = "path", 
  project_type = ".nv", 
  git_ignored = true 
}
```
Found via `--ignored` flag or filesystem glob. Extracts mono label from file content.

### Example 3: Directory AND-condition marker
```lua
{ 
  name = { "Clientside", "Serverside" }, 
  type = "path", 
  project_type = "cronos", 
  is_directory = true 
}
```
Both directories must exist in the same parent. Found via Pipeline B scanning.

## Testing

When adding new marker options:
1. Write unit tests for the option behavior
2. Test edge cases (nested directories, multiple markers, etc.)
3. Test interaction with existing options
4. Update documentation with examples

## Related Files
- `lua/utils/mypath.lua:4-25` - Marker configuration
- `lua/utils/mypath.lua:367-489` - check_marker_match_with_meta (match_from_within, is_directory handling)
- `lua/utils/mypath.lua:491-616` - Three scanning pipelines
- `docs/memory/gitlab_dirname_marker.md` - .gitlab marker documentation
