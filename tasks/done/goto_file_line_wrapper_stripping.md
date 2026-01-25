---
title: "Add wrapper character stripping to goto_file_line()"
status: "done"
assignee: "ai"
created: 2026-01-25
priority: "medium"
related:
  - [mykeymaps.lua](lua/config/mykeymaps.lua)
  - [file_reference.lua](lua/utils/file_reference.lua)
---

## Objective

Enhanced `goto_file_line()` function to automatically strip wrapping characters (backticks, quotes, brackets) from file paths, making it easier to navigate to files referenced in documentation, changelogs, and markdown files.

## Changes Summary

### What Was Done

**Phase 1: Wrapper character stripping**

- Backticks: `` `file.lua` `` → `file.lua`
- Single quotes: `'file.lua'` → `file.lua`
- Double quotes: `"file.lua"` → `file.lua`
- Square brackets: `[file.lua]` → `file.lua`
- Angle brackets: `<file.lua>` → `file.lua`
- Handles unbalanced/multiple wrappers: `'[file` → `file`

**Phase 2: Environment variable expansion**

- Tilde: `~/.config/nvim/init.lua` → `/Users/username/.config/nvim/init.lua`
- Dollar sign: `$HOME/file.lua` → `/Users/username/file.lua`
- Braces: `${HOME}/file.lua` → `/Users/username/file.lua`
- Works with line numbers: `$HOME/file.lua:100`
- Works with wrappers: `` `~/file.lua` `` → expands correctly

**Phase 3: Bug fix - trailing colon stripping**

- Trailing colon: `file.lua:` → `file.lua` (was keeping `:` before)
- Multiple colons: `file.lua::` → `file.lua`
- With wrappers: `` `file.lua:` `` → `file.lua`
- User-reported: `lua/overseer/template/agoda/android_client/and_build.lua:` → now works!

### Files Modified

✓ **Modified**: [lua/config/mykeymaps.lua:1050-1066](lua/config/mykeymaps.lua:1050)

- Added iterative wrapper stripping (handles unbalanced/multiple wrappers)
- Added environment variable expansion (tilde, $VAR, ${VAR})
- Fixed ${VAR} expansion (vim.fn.expand doesn't handle this natively)
- Two-step expansion: manual ${VAR} → then vim.fn.expand for $VAR and ~
- Updated function comment to document new features

✓ **Modified**: [lua/utils/file_reference.lua:33-35,47-49](lua/utils/file_reference.lua:33)

- Fixed trailing colon bug (e.g., `file.lua:` now strips to `file.lua`)
- Added `:+$` pattern to strip trailing colons when no line number present
- Handles both regular paths and file:// URIs

✓ **Modified**: [tasks/done/goto_file_line_wrapper_stripping.md](tasks/done/goto_file_line_wrapper_stripping.md)

- Documented env var expansion strategy
- Added env var test samples
- Updated use cases with env var examples

✓ **Created**: [tests/test_env_var_expansion.md](tests/test_env_var_expansion.md)

- 16 test cases for env var expansion
- Real-world examples from changelogs

✓ **Created**: [tests/test_trailing_colon_bug.md](tests/test_trailing_colon_bug.md)

- 12 test cases for trailing colon stripping
- Documents the user-reported bug and fix
- Tests with wrappers and file:// URIs

## Implementation Details

### Code Location

The processing pipeline in goto_file_line():

```lua
-- Order of operations:
1. Extract path from cursor/selection
2. Strip markdown link parentheses: [text](path) → path
3. Strip wrapper characters (backticks, quotes, brackets)
4. Expand environment variables and tilde (NEW)
5. Parse file reference (line numbers, anchors)
6. Open file
```

### Wrapper Stripping Strategy

**Simple iterative approach** - strips non-path characters from both ends until clean:

```lua
-- Strip non-path characters from start and end (iteratively)
-- Non-path chars: backticks, quotes, brackets, angle brackets, whitespace
local prev
repeat
  prev = target
  target = target:gsub("^[`'\"<%[%]>%(%)%s]+", "")  -- strip from start
  target = target:gsub("[`'\"<%[%]>%(%)%s]+$", "")  -- strip from end
until target == prev
```

**Handles edge cases:**

- Unbalanced wrappers: `'file.lua` → `file.lua`
- Multiple wrappers: `['file.lua]` → `file.lua`
- Nested wrappers: `` `'file.lua'` `` → `file.lua`
- Mixed wrappers: ``['`file.lua`']`` → `file.lua`
- Whitespace: `  "file.lua"  ` → `file.lua`

### Environment Variable Expansion

**Better than native gf** - expands env vars (including ${VAR}) and tilde:

```lua
-- Expand environment variables and tilde
-- Handles: $HOME/file, ${HOME}/file, ~/file, $ENV_VAR/path
local path_part = target:match("^([^:#]+)") or target

-- First, manually expand ${VAR} syntax (vim.fn.expand doesn't handle this)
local expanded_part = path_part:gsub("%${([^}]+)}", function(var)
  return os.getenv(var) or ("${" .. var .. "}")
end)

-- Then use vim.fn.expand for $VAR and ~ (standard expansion)
expanded_part = vim.fn.expand(expanded_part)

if expanded_part ~= path_part then
  target = target:gsub("^" .. vim.pesc(path_part), expanded_part)
end
```

**Why two-step expansion:**

- `vim.fn.expand()` handles `$VAR` and `~` but NOT `${VAR}`
- Manual gsub handles `${VAR}` → `$VAR` using `os.getenv()`
- Both combined = full env var support

**Supported formats:**

- Tilde: `~/.config/nvim/init.lua` → `/Users/username/.config/nvim/init.lua`
- Dollar sign: `$HOME/.config/nvim/init.lua` → `/Users/username/.config/nvim/init.lua`
- Braces: `${HOME}/.config/nvim/init.lua` → `/Users/username/.config/nvim/init.lua`
- Custom vars: `$DOTFILES/lua/config/mykeymaps.lua` → (expanded path)
- With line numbers: `$HOME/file.lua:100` → `/Users/username/file.lua:100`
- With anchors: `~/docs/README.md#section` → `/Users/username/docs/README.md#section`

## Test Samples

### Basic Formats (all work with gF)

**IDE-style (colon separator):**

```
lua/config/mykeymaps.lua:100
./lua/config/mykeymaps.lua:1000:5
./lua/plugins/init.lua:1
snippets/global.json:1
```

**Git-style (hash + L prefix):**

```
lua/config/mykeymaps.lua#L100
lua/config/mykeymaps.lua#L100C5
lua/config/mykeymaps.lua#L100-L110
lua/config/mykeymaps.lua#L98C10-L110C10
```

**README anchor style:**

```
docs/misc_nvim.md#done
docs/misc_nvim.md#code
```

**Relative paths:**

```
./snippets/global.json
../snippets/global.json
```

**file:// URI scheme:**

```
file:///tmp/test.lua:10:5
```

### Wrapped Paths (NEW - backticks, quotes, brackets, angle brackets)

**Backticks (inline code):**

```
`lua/config/mykeymaps.lua:10`
`~/.local/share/nvim/lazy/overseer.nvim/CHANGELOG.md`
```

**Single quotes:**

```
'lua/plugins/init.lua:1'
'docs/memory/snacks_picker.md#actions'
```

**Double quotes:**

```
"snippets/global.json"
"lua/utils/file_reference.lua:50"
```

**Square brackets:**

```
[docs/misc_nvim.md#done]
[lua/config/mykeymaps.lua:100-110]
```

**Angle brackets:**

```
<lua/utils/file_reference.lua>
<docs/task_tracking.md#workflow>
```

### Environment Variables (NEW - tilde and env var expansion)

**Tilde expansion:**

```
~/.config/nvim3_jelly_tinynvim/lua/config/mykeymaps.lua
~/.config/nvim3_jelly_tinynvim/lua/config/mykeymaps.lua:100
~/docs/README.md#section
```

**$HOME expansion:**

```
$HOME/.config/nvim3_jelly_tinynvim/init.lua
$HOME/.config/nvim3_jelly_tinynvim/lua/config/mykeymaps.lua:50
```

**${VAR} expansion:**

```
${HOME}/.config/nvim3_jelly_tinynvim/lua/plugins/ui.lua
${HOME}/.local/share/nvim/lazy/overseer.nvim/CHANGELOG.md
```

**Custom env vars (if set):**

```
$DOTFILES/.config/nvim3_jelly_tinynvim/lua/config/mykeymaps.lua
$NVIM_CONFIG/lua/plugins/ui.lua:100
```

**Combined with wrappers:**

```
`$HOME/.config/nvim3_jelly_tinynvim/lua/config/mykeymaps.lua:100`
"~/.config/nvim3_jelly_tinynvim/init.lua"
'${HOME}/docs/README.md#section'
```

## Path Priority Logic

**No ./ or ../ prefix** → git root first, then buffer cwd

```
lua/config/mykeymaps.lua:100  # Searches git root first
```

**With ./ or ../ prefix** → buffer cwd first, then git root

```
./lua/config/mykeymaps.lua:1000:5  # Searches buffer cwd first
```

## Use Cases

### 1. Reading Changelogs

Navigate directly to files mentioned in CHANGELOG.md:

```markdown
- add mise tasks template provider ([00e01e6])
  See: `lua/overseer/template/mise.lua`
```

Place cursor on `` `lua/overseer/template/mise.lua` `` and press `gF`.

### 2. Documentation References

Jump to code from documentation:

```markdown
The configuration is in `lua/plugins/coding.lua:45-60`.
```

### 3. Issue References

Navigate from issue descriptions:

```markdown
Check the implementation in [lua/utils/git.lua:100]
```

### 4. Code Comments

Follow file references in comments:

```lua
-- See also: <lua/utils/file_reference.lua>
```

### 5. Configuration Files (NEW - env var expansion)

Navigate to config files using env vars:

```markdown
Edit your init.lua: `~/.config/nvim3_jelly_tinynvim/init.lua`
Check the changelog: `${HOME}/.local/share/nvim/lazy/overseer.nvim/CHANGELOG.md`
```

Place cursor on path and press `gF` - env vars expand automatically.

### 6. Cross-Platform Paths

Use env vars for portable documentation:

```markdown
Config location: $HOME/.config/nvim3_jelly_tinynvim/lua/config/mykeymaps.lua:100
Plugin directory: ${HOME}/.local/share/nvim/lazy/
```

Works on any system with HOME set.

## Success Criteria

- [x] Backticks stripped from inline code blocks
- [x] Single/double quotes stripped
- [x] Square/angle brackets stripped
- [x] Unbalanced/multiple wrappers handled
- [x] Environment variables expanded ($VAR, ${VAR})
- [x] Tilde expansion works (~/)
- [x] Trailing colons stripped when no line number (e.g., `file.lua:` → `file.lua`)
- [x] All existing path formats still work
- [x] Line numbers and anchors preserved
- [x] Test samples documented
- [x] No regressions with existing behavior

## Verification Checklist

**Test with cursor on wrapped paths:**

- [x] `` `lua/config/mykeymaps.lua:100` `` → opens file at line 100
- [x] `'lua/plugins/init.lua:1'` → opens file at line 1
- [x] `"snippets/global.json"` → opens file
- [x] `[docs/misc_nvim.md#done]` → opens file and jumps to anchor
- [x] `<lua/utils/file_reference.lua>` → opens file

**Test edge cases (unbalanced/multiple wrappers):**

- [x] `'lua/plugins/init.lua:1` → strips unbalanced quote, opens file
- [x] `['lua/plugins/init.lua:1` → strips multiple wrappers, opens file
- [x] `` `'`lua/plugins/init.lua`'` `` → strips all wrappers, opens file
- [x] `  "file.lua"  ` → strips whitespace and quotes

**Test with existing formats (no regressions):**

- [x] `lua/config/mykeymaps.lua:100` → still works
- [x] `lua/config/mykeymaps.lua#L100` → still works
- [x] `[text](file.md#anchor)` → extracts and opens file
- [x] Visual selection + gF → still works

**Edge cases:**

- [x] Nested wrappers: `"[file.lua]"` → strips all wrappers
- [x] Mixed wrappers: `` `'file.lua'` `` → strips all wrappers
- [x] Multiline paths in visual mode → cleaned correctly

**Test environment variable expansion:**

- [x] `~/.config/nvim3_jelly_tinynvim/lua/config/mykeymaps.lua` → expands tilde
- [x] `$HOME/.config/nvim3_jelly_tinynvim/init.lua` → expands $HOME
- [x] `${HOME}/.local/share/nvim3_jelly_tinynvim/lazy/codecompanion.nvim/CHANGELOG.md` → expands ${HOME} ✅ FIXED
- [x] `~/.config/nvim3_jelly_tinynvim/lua/config/mykeymaps.lua:100` → expands + jumps to line
- [x] `` `$HOME/.config/nvim3_jelly_tinynvim/init.lua` `` → strips wrapper + expands env var
- [x] `${XDG_CONFIG_HOME}/$NVIM_APPNAME/init.lua`

**Test trailing colon stripping:**

- [x] `lua/config/mykeymaps.lua:` → strips trailing colon, opens file ✅ FIXED
- [x] `lua/overseer/template/agoda/android_client/and_build.lua:` → opens correctly
- [x] `` `lua/plugins/ui.lua:` `` → strips wrapper + trailing colon
- [x] `"lua/utils/file_reference.lua::"` → strips both trailing colons
- [x] `file:///tmp/test.lua:` → handles file:// URI with trailing colon

## Related Work

**Previous Tasks:**

- goto_file_line refactoring and file_reference.lua extraction
- Smart path resolution with git root vs buffer cwd priority
- Markdown anchor jumping support

**Completed Enhancements:**

- ✅ Wrapper character stripping (backticks, quotes, brackets)
- ✅ Unbalanced/multiple wrapper handling
- ✅ Environment variable expansion ($HOME, ${VAR}, ~)
- ✅ Trailing colon bug fix (file.lua: → file.lua)

**Future Enhancements:**

- Support for language-specific link formats (e.g., Python docstrings)
- Auto-detection of file references without gF command
- Preview file content on hover
- Custom env var aliases (e.g., $NVIM_CONFIG → $HOME/.config/nvim)

---

**Completed**: 2026-01-25
**Verified**: Ready for user testing
2026-01-26 00:23

- [x] Done passed normal mode
- [x] Done passed visual mode

Extra notes:

- refactor out form myeditor to path and input utils lua/utils/mypath.lua:557
