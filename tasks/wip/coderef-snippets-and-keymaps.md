# Pending Task: Code ref helper polish

## Status Summary

- **Completed:** 3/11
- **In Progress:** 0/11
- **Pending:** 8/11

TODO

- [x] Support visual-selection ranges in code ref outputs [`lua/utils/code_ref.lua#L59`]
- [x] Support additional format and replace the a / A suffix mapping , move existing a / A to b / B mapping
      <localleader>cra - @ format with (@path Lline:Ccol)
      <localleader>crb - @ format (@path Lline:col)
- [x] Add support for visual mode to add line range (no need for col when there's range) - it has to support on all existing mapping + in picker (visual mode)

## Completed ✅

- [x] Add code-ref picker for all relative/absolute variants (Snacks picker) [`lua/utils/snacks_pickers.lua:1233`]
- [x] Map picker to `<localleader>crp` (now supports visual mode) [`lua/config/mykeymaps.lua:185`]
- [x] Support visual-selection ranges in code ref outputs [`lua/utils/code_ref.lua#L29-L62`]
- [x] Add new `at_caps` format (`@path Lline:Ccol`) [`lua/utils/code_ref.lua#L43,L50,L58`]
- [x] Remap code ref keymaps: move `a/A` to `b/B`, use `a/A` for new format [`lua/config/mykeymaps.lua:163-187`]
- [x] Add visual mode support to all code ref keymaps and picker [`lua/config/mykeymaps.lua:163-187`]

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
<localleader>crp - picker (all variants) ✨ visual mode support
```

**Visual mode support:**
- All keymaps above now work in visual mode (`v` and `V`)
- In visual mode, automatically includes line range in output
- Example: selecting lines 5-10 with `<localleader>cra` produces: `@path L5:C1-L10:C1`

### Configuration

- `vim.opt.clipboard = ""` - Clipboard disabled (manual control only)
- All copy operations use `copy_mode="plus"` by default
- No auto-sync with system clipboard
