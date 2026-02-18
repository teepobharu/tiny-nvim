# Pending Task: Code ref helper polish

## Status Summary

- **Completed:** 10/11
- **In Progress:** 0/11
- **Pending:** 1/11

## User Review Checkboxes ✨

Latest changes (Session 2):

- [ ] Check number line revert, copy not work picker
- [ ] char toggle toggle changes reflect in line range select correctly on all format except the hash # variant, it does not toggle the single mode
- [ ] some faulty range identification
- [ ] TO ADD : relative from cwd , subprojand relative from git

- [ ] **Review:** Visual mode now correctly uses visual marks for range detection [`lua/utils/code_ref.lua:98-127`]
- [ ] **Review:** Single-line selections don't show char info when `show_char_range=false`
- [ ] **Review:** `<A-c>` in picker now correctly toggles and refreshes items [`lua/utils/snacks_pickers.lua:1473-1492`]
- [ ] **Review:** New `<localleader>crt` keymap to completely hide column [`lua/config/mykeymaps.lua:199-202`]

Latest changes (Session 3 - backward range fix):

- [ ] **Review:** Fixed backward line ranges (e.g. `L19-L18` -> `L18-L19`) by switching from `vim.fn.getpos` to `vim.api.nvim_buf_get_mark` [`lua/utils/code_ref.lua:98-140`]
- [ ] **Verify:** Select lines upward (V + k) then `<localleader>cra` - range should be ascending
- [ ] **Verify:** Select lines downward (V + j) then `<localleader>cra` - range should be ascending
- [ ] **Verify:** Picker in visual mode shows correct ascending ranges

## Completed ✅

- [x] Add code-ref picker for all relative/absolute variants (Snacks picker) [`lua/utils/snacks_pickers.lua#1436-1512`]
- [x] Map picker to `<localleader>crp` (now supports visual mode) [`lua/config/mykeymaps.lua:190-192`]
- [x] Support visual-selection ranges in code ref outputs [`lua/utils/code_ref.lua#L98-L155`]
- [x] Add new `at_caps` format (`@path Lline:Ccol`) [`lua/utils/code_ref.lua#L47-L94`]
- [x] Remap code ref keymaps: move `a/A` to `b/B`, use `a/A` for new format [`lua/config/mykeymaps.lua:176-187`]
- [x] Add visual mode support to all code ref keymaps and picker [`lua/config/mykeymaps.lua:176-192`]
- [x] Add char range toggle: `<localleader>crT` toggles ranges with/without char info [`lua/config/mykeymaps.lua:194-197`]
- [x] Add column toggle: `<localleader>crt` to completely hide column [`lua/config/mykeymaps.lua:199-202`]
- [x] Fix visual range detection to handle recent selections (after picker closes) [`lua/utils/code_ref.lua:98-155`]
- [x] Fix picker Alt-c keymap error and implement proper item refresh [`lua/utils/snacks_pickers.lua:1473-1492`]

## Pending Tasks ⏳

### 1. Keymap mnemonic consolidation (Line 6)

- **Status:** ✓ ALREADY DONE (uses `<localleader>cr` prefix consistently)
- **Current:** `crr/crs/cra/crh` (relative) and `crR/crS/crA/crH` (absolute)
- **Action:** Mark as complete, old notes mentioned `acr` but implementation uses `cr`
- [ ] **FIX THIS:** Update task description to reflect actual implementation

### 2. Add which-key labels for `cr` prefix (Line 7)

- **Status:** TODO
- **File:** `lua/config/mykeymaps.lua`
- **What:** Add which-key grouping/description for `<localleader>cr` keymap prefix
- **Impact:** Better discoverability in which-key menu

### 3. Decide on `refAbs` LuaSnip helper (Line 8)

- **Status:** TODO - needs decision
- **File:** `lua/plugins/extra/myCoding.lua:19-25`
- **Current:** Snippet exists with comment "kept for backward compat"
- **Options:**
  - [a] Keep as-is for backward compatibility
  - [b] Remove and replace with `<localleader>crA` keymap + command flow
  - [c] Deprecate with warning
- **Decision needed:** Which approach?

### 4. Add git root missing tests (Line 9)

- **Status:** TODO
- **File:** `lua/utils/code_ref.lua` (functions: `get_path_parts`, `M.current`)
- **What:** Test behavior when git root is not found
- **Location:** `tests/myTestSnacks.lua`

### 5. Document workflow (Line 10)

- **Status:** TODO
- **Location:** `docs/memory/` or README snippet
- **Content:** How to use code-ref picker and keymaps

### 6. Keymap format suffix + remap (Line 11-12)

- **Status:** UNCLEAR - needs clarification
- **Reference:** `@claude/CLAUDE-CODE.docs.md :L797:C2`
- **Understanding:**
  - "add more key map + picker options to support this format as map with suffix key a"
  - "remap existing a to b (then fix the mapping desc to use R and Abs)"
- **Questions:**
  - What is the new format to support?
  - Which keys should map to which format?
  - Should this extend beyond current `crr/crs/cra/crh` variants?

## Current Implementation

### New Clipboard Utility Module

**File:** [`lua/utils/myinput.lua`] ✨ NEW

- Provides `copy_to_clipboard(text, mode)` function
- Modes: `"plus"` (system clipboard), `"unnamed"` (normal yank), `"both"` (both registers)
- Provides `copy_and_notify(text, mode, message)` with visual feedback
- **Default mode:** `"plus"` (system clipboard only, no auto-sync)

### Integration Points

1. **lua/config/mykeymaps.lua**
   - `YY` - Copy current line to system clipboard
   - `Y` (visual) - Copy selection to system clipboard
   - `<C-c>` (visual) - Copy selection to system clipboard
   - All use `copy_mode="plus"` (system clipboard only)

2. **lua/utils/code_ref.lua**
   - Updated `M.current()` to accept `copy_mode` option
   - Updated `M.copy_current()` to use clipboard utility
   - Defaults to `copy_mode="plus"`

3. **lua/utils/snacks_pickers.lua**
   - Code ref picker confirm action uses `copy_mode="plus"`
   - Visual feedback via `copy_and_notify()`

### Keymaps

**Relative paths (lowercase suffix):**

```
<localleader>crr - colon format (path:line:col)
<localleader>crs - space format (path line:col)
<localleader>cra - @ format with caps (@path Lline:Ccol) ✨ NEW
<localleader>crb - @ format (@path line:col) [moved from old 'a']
<localleader>crh - hash format (path#LlineCcol)
```

**Absolute paths (uppercase suffix):**

```
<localleader>crR - colon format (path:line:col)
<localleader>crS - space format (path line:col)
<localleader>crA - @ format with caps (@path Lline:Ccol) ✨ NEW
<localleader>crB - @ format (@path line:col) [moved from old 'A']
<localleader>crH - hash format (path#LlineCcol)
```

**Picker:**

```
<localleader>crp - Unified picker with path variants × formats
                   Shows: Git, Relative CWD, Absolute × 5 formats each
                   Total: ~15 items (3 path types × 5 formats)
                   Preview: hidden by default
                   Same item structure as <M-y> in grep/files pickers
                   ✨ visual mode support
```

**Toggle keymaps (normal mode only):**

```
<localleader>crT - Toggle char range in multi-line selections
                  OFF (default):  path:5-10  or  @path L5-L10
                  ON:             path:5:1-10:25  or  @path L5:C1-L10:C25

<localleader>crt - Toggle hide column entirely
                  OFF (default):  path:17:5  or  @path L17:C5
                  ON:             path:17  or  @path L17
```

**Picker keyboard shortcut:**

```
<A-c> (in picker) - Toggle char range in multi-line selections and refresh items
                    Shows current state in title: " [char: on]" or " [char: off]"
```

**Visual mode support:**

- All code ref keymaps (`crr`, `crs`, `cra`, `crb`, `crh`, etc.) work in visual mode (`v` and `V`)
- All toggles (`crT`, `crt`) affect visual mode output (use global variables)
- Multi-line visual selections automatically detected using visual marks
- Single-line selections use normal formatting rules
- Example: selecting lines 5-10 in visual mode with `<localleader>cra`:
  - With all toggles OFF: `@path L5-L10`
  - With `crT` ON: `@path L5:C1-L10:C25`
  - With `crt` ON: `@path L5` (single line format, column hidden)

### Configuration & Global Variables

- `vim.opt.clipboard = ""` - Clipboard disabled (manual control only)
- `vim.g.code_ref_show_char_range` - Show char positions in ranges (default: `false`)
- `vim.g.code_ref_hide_col` - Hide column entirely (default: `false`)
- All copy operations use `copy_mode="plus"` by default
- No auto-sync with system clipboard

---

## Session 2 Changes Detailed

### Problem Fixes:

1. **Visual mode keymaps not respecting toggles**
   - **Root cause:** Keymaps didn't pass `show_char_range` parameter to code_ref functions
   - **Fix:** Updated `copy_code_ref()` helper to read `vim.g.code_ref_show_char_range` and pass it

2. **Single-line visual selection showing char info**
   - **Root cause:** Visual range detection treated all selections as ranges
   - **Fix:** `get_visual_range()` correctly returns `nil` for same-line selections; single positions follow normal formatting
   - **Result:** Single line now shows `L17:C1` (with char) or `L17` (with `crt` toggle)

3. **Picker Alt-c keymap error (E5108)**
   - **Root cause:** Used non-existent `picker:set_items()` method
   - **Fix:** Changed to use `Snacks.picker.get()`, manually update `picker.items`, then call `picker:refresh()`
   - **Result:** Picker now properly refreshes when toggling char range

### New Features:

1. **Column Hide Toggle (`<localleader>crt`)**
   - **Function:** `M.toggle_hide_col()` in `code_ref.lua`
   - **Global variable:** `vim.g.code_ref_hide_col`
   - **Behavior:** When ON, removes `:Ccol` from all formats
   - **Formats:**
     - Colon: `path:17` (was `path:17:5`)
     - At caps: `@path L17` (was `@path L17:C5`)
     - Space: `path 17` (was `path 17:5`)

2. **Char Range Toggle (`<localleader>crT`)**
   - **Function:** `M.toggle_char_range()` in `code_ref.lua`
   - **Global variable:** `vim.g.code_ref_show_char_range`
   - **Behavior:** For multi-line selections, toggle between:
     - OFF (default): `path:5-10` (line range only)
     - ON: `path:5:1-10:25` (full char range)

3. **Picker Alt-c Toggle**
   - **Keymap:** `<A-c>` (Alt+C) in picker input mode
   - **Behavior:** Toggle `show_char_range` and refresh items dynamically
   - **Visual feedback:** Title updates to show `[char: on]` or `[char: off]`

### Files Modified:

- **`lua/utils/code_ref.lua`** (lines 29-265)
  - Updated `format_ref()` with `hide_col` logic
  - Fixed `get_visual_range()` to detect visual marks
  - Added `M.toggle_hide_col()` function
  - Updated function signatures to support new parameters

- **`lua/config/mykeymaps.lua`** (lines 10-12, 176-202)
  - Updated `copy_code_ref()` to pass `show_char_range`
  - Added `<localleader>crT` keymap
  - Added `<localleader>crt` keymap

- **`lua/utils/snacks_pickers.lua`** (lines 1436-1512)
  - Fixed Alt-c keymap error handling
  - Implemented proper picker item refresh using `Snacks.picker.get()`
  - Added `vim.schedule()` wrapper for UI updates

### Testing Recommendations:

1. **Normal mode keymaps:**

   ```
   - Position cursor on line 17, column 5
   - <localleader>cra → should copy: @path L17:C5
   - <localleader>crT (toggle)
   - <localleader>cra → should copy: @path L17:C5 (same, single position)
   - <localleader>crt (toggle)
   - <localleader>cra → should copy: @path L17 (column hidden)
   ```

2. **Visual mode (lines 5-10):**

   ```
   - V to select lines 5-10
   - <localleader>cra → copy: @path L5-L10
   - <localleader>crT (toggle)
   - <localleader>cra → copy: @path L5:C1-L10:C25 (or end of line)
   - <localleader>crt (toggle)
   - <localleader>cra → copy: @path L5-L10 (column hidden in range)
   ```

3. **Picker Alt-c toggle:**
   ```
   - <localleader>crp (open picker)
   - See "[char: off]" in title
   - <A-c> (toggle)
   - Items refresh, title shows "[char: on]"
   - <A-c> again
   - Title shows "[char: off]", items refresh back
   ```

---

## Quick Reference Card 🎯

| Task                  | Keymap              | Result                               |
| --------------------- | ------------------- | ------------------------------------ |
| Copy current line     | `<localleader>crr`  | `path:17:5`                          |
| Copy with @format     | `<localleader>cra`  | `@path L17:C5`                       |
| Toggle char in ranges | `<localleader>crT`  | Toggle: `:5:1-10:25` ↔ `:5-10`      |
| Hide column entirely  | `<localleader>crt`  | `:17` instead of `:17:5`             |
| Open picker           | `<localleader>crp`  | Shows all formats with toggle status |
| Toggle in picker      | `<A-c>` (in picker) | Refresh items, update title          |
| **Visual mode**       | **Same keymaps**    | **Auto-detects line ranges**         |

**Format Legend:**

- `crr`, `crR` = colon format: `path:line:col` or `path:line-line`
- `crs`, `crS` = space format: `path line:col` or `path line-line`
- `cra`, `crA` = at_caps format: `@path Lline:Ccol` or `@path Lline-Lline`
- `crb`, `crB` = at format: `@path line:col` (moved from old 'a'/'A')
- `crh`, `crH` = hash format: `path#LlineCcol`
- Lowercase suffix = relative paths, Uppercase = absolute paths

---

## Files/Grep Picker Integration (`<M-y>` / `YY`)

### Overview

The `<M-y>` and `YY` keymaps in files/grep/buffers pickers now show **both path formats AND code-ref variants** when line/col information is available (grep results).

### Implementation

**Modified Files:**

- [`lua/utils/snacks_actions.lua 128-656`]
  - `get_item_path()` - now returns `(path, line, col)`
  - `generate_coderef_formats()` - generates 5 code-ref variants per path format
  - `copy_path_select()` - merges path + code-ref formats

### Behavior

#### Files Picker (`<leader>ff`)

- Press `<M-y>` or `YY` on a file
- Shows: ~4-8 path format variants (Relative, Git, CWD, Absolute, Dir variants)
- **No code-ref variants** (no line/col info)

#### Grep Picker (`<leader>/`)

- Search for a term (e.g., "function")
- Press `<M-y>` or `YY` on a search result
- Shows:
  - **Path formats:** Relative, Git, CWD, Absolute (same as files)
  - **Code-ref formats:** 5 variants per path × multiple paths = ~20-40 options

    ```
    Relative (colon): lua/utils/code_ref.lua:128:3
    Relative (space): lua/utils/code_ref.lua 128:3
    Relative (@):     @lua/utils/code_ref.lua 128:3
    Relative (@caps): @lua/utils/code_ref.lua L128:C3
    Relative (#):     lua/utils/code_ref.lua#L128C3

    Git (colon):      utils/code_ref.lua:128:3
    Git (@caps):      @utils/code_ref.lua L128:C3
    ... (etc.)
    ```
- Line/col extracted from grep result `item.pos`: `{line, col}` (line 1-based, col 0-based → converted to 1-based)

#### Buffers Picker (`<leader>,`)

- Press `<M-y>` or `YY` on a buffer
- Shows: ~4-8 path format variants
- **No code-ref variants** (no line/col info)

### Picker Actions

| Keymap  | Action                   | Notes                                               |
| ------- | ------------------------ | --------------------------------------------------- |
| `<CR>`  | Paste path at cursor     | Closes picker                                       |
| `<C-y>` | Copy to clipboard        | Stays open for multiple copies                      |
| `<C-p>` | Paste path at cursor     | Same as `<CR>`                                      |
| `<C-n>` | Paste as markdown link   | Closes picker                                       |
| `<A-c>` | Toggle column visibility | Toggles `vim.g.code_ref_hide_col`, refreshes picker |
| `<Esc>` | Close picker             | Does not close parent picker                        |
| `<C-q>` | Close all pickers        | Closes both sub-picker and parent                   |

---

## Session 3: Unified Picker Implementation

### Changes Made

**Date:** 2026-02-12

#### Unified Format Generation

Modified [`lua/utils/code_ref.lua:210-259`] - `M.current_options()` function:

**Before:** Generated only 2 path variants (relative, absolute) × 5 formats = 10 items

**After:** Generates 3 path variants (Git, Relative CWD, Absolute) × 5 formats = ~15 items

**Benefits:**

- Same item structure as `<M-y>` picker in grep/files
- Shows Git-relative paths first (most useful in git repos)
- Consistent label format: "Git (colon)", "Relative CWD (@caps)", etc.
- Preview hidden by default (faster UX)

#### Path Variant Logic

1. **Git relative** - Path relative to git root (if in git repo)
   - Example: `lua/utils/code_ref.lua:128:3`
2. **Relative CWD** - Path relative to current working directory
   - Example: `../utils/code_ref.lua:128:3` (if CWD is different)
3. **Absolute** - Full absolute path
   - Example: `/Users/.../dotfiles/.config/nvim3_jelly_tinynvim/lua/utils/code_ref.lua:128:3`

#### Preview Hidden by Default

Changed [`lua/utils/snacks_pickers.lua:1935-1937`]:

```lua
layout = {
  preview = false, -- Hide preview by default
},
```

**Rationale:** Code-ref picker is a quick-select tool, preview adds unnecessary overhead.

#### Item Structure Alignment

Both `<localleader>crp` and `<M-y>` now use consistent item structure:

```lua
{
  label = "Git (colon)",           -- Path type + format
  text = "path:128:3",             -- Formatted reference (for crp)
  path = "path:128:3",             -- Same (for M-y compatibility)
  format = "colon",                -- Format key
  path_type = "git",               -- Path variant key
}
```

### Testing

**Test `<localleader>crp`:**

1. Open any file in a git repo
2. Press `<localleader>crp`
3. **Verify:** Shows ~15 items (3 path types × 5 formats)
4. **Verify:** First items are "Git (colon)", "Git (space)", etc.
5. **Verify:** No preview panel (faster)
6. **Verify:** `<A-c>` toggle still works

**Test `<M-y>` consistency:**

1. Open grep picker: `<leader>/`
2. Search for "function"
3. Press `<M-y>` on a result
4. **Verify:** Path variants match `crp` (Git, Relative CWD, Absolute)
5. **Verify:** Format labels match `crp` style

---

### Column Toggle (`<A-c>`)

Toggles `vim.g.code_ref_hide_col` global variable:

**Before (column shown):**

```
lua/utils/code_ref.lua:128:3
@lua/utils/code_ref.lua L128:C3
lua/utils/code_ref.lua#L128C3
```

**After (column hidden):**

```
lua/utils/code_ref.lua:128
@lua/utils/code_ref.lua L128
lua/utils/code_ref.lua#L128
```

Affects all code-ref formats globally (persists across picker invocations).

### Technical Details

**Line/Col Parsing (Grep Items):**

```lua
-- Grep item structure:
item.pos = {line, col}      -- line: 1-based, col: 0-based
item.end_pos = {end_line, end_col}

-- Extraction:
line = item.pos[1]          -- 1-based (no conversion)
col = item.pos[2] + 1       -- 0-based → 1-based
```

**Format Generation:**

- Each path variant (Relative, Git, CWD, Absolute) → 5 code-ref formats
- Total code-ref items = `path_variants × 5`
- Example: 4 path variants → 20 code-ref items

**Preview:**

- Shows file stats (type, size, line count, modified date)
- Shows current format label and path
- Displays available actions

### Testing

See [`tests/spec_coderef_picker_extension.md`] for comprehensive test scenarios.

**Quick Test:**

1. Open grep picker: `<leader>/`
2. Search for "function"
3. Press `<M-y>` on a result
4. Verify code-ref formats show line:col info
5. Press `<A-c>` to toggle column visibility
6. Copy/paste a code-ref variant

---
