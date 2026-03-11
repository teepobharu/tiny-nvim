# Test Spec: Code-Ref Picker Extension (`<M-y>` in Files/Grep Pickers)

## Overview

This spec validates that the `<M-y>` (copy_path_select) functionality now shows both path formats AND code-ref variants when line/col information is available.

## Implementation Details

**Modified Files:**
- [`lua/utils/snacks_actions.lua`] - Lines 128-656
  - `get_item_path()` - now returns `(path, line, col)`
  - `generate_coderef_formats()` - NEW function to generate 5 code-ref variants per path format
  - `copy_path_select()` - merges path + code-ref formats

**Key Features:**
- Grep items: extracts `line` from `item.pos[1]`, `col` from `item.pos[2] + 1` (0-based to 1-based)
- Files/buffers: no line info → only shows path formats
- Code-ref formats: colon, space, at, at_caps, hash
- Toggle: `<A-c>` toggles column visibility (uses `vim.g.code_ref_hide_col`)

---

## Test Scenarios

### 1. Files Picker (`<leader>ff` + `<M-y>`)

**Setup:**
1. Open Neovim
2. Press `<leader>ff` to open files picker
3. Navigate to any file
4. Press `<M-y>` to open path format picker

**Expected Results:**
- [ ] Sub-picker opens with title: "Select Path Format (C-y: copy, Enter: paste)"
- [ ] Shows ~4-8 path format variants (Relative, Git, CWD, Absolute, etc.)
- [ ] Does NOT show any code-ref variants (no line/col info)
- [ ] Title does NOT show "[+N code-refs]" indicator
- [ ] Can copy/paste any path variant successfully

**Validation:**
```lua
-- In grep/search buffer, run:
:lua vim.print(require("utils.snacks_actions").copy_path_select)
```

---

### 2. Grep Picker (`<leader>/` + `<M-y>`)

**Setup:**
1. Open Neovim in a project with multiple files
2. Press `<leader>/` to open grep picker
3. Search for a common term (e.g., "function")
4. Navigate to any search result
5. Press `<M-y>` to open path format picker

**Expected Results:**
- [ ] Sub-picker opens with title showing "[+N code-refs]" (where N ≈ 20-40 depending on path variants × 5 formats)
- [ ] First section: ~4-8 path format variants (Relative, Git, CWD, Absolute)
- [ ] Second section: Code-ref variants with line:col information
- [ ] Code-ref format examples:
  ```
  Relative (colon): lua/utils/snacks_actions.lua:128:3
  Relative (space): lua/utils/snacks_actions.lua 128:3
  Relative (@):     @lua/utils/snacks_actions.lua 128:3
  Relative (@caps): @lua/utils/snacks_actions.lua L128:C3
  Relative (#):     lua/utils/snacks_actions.lua#L128C3
  ```
- [ ] Line number matches the grep result line
- [ ] Column number matches the grep result start column

**Validation:**
```lua
-- Check item structure in grep picker:
:lua vim.print(vim.tbl_keys(require("snacks.picker").get()[1].items[1]))
-- Should see: pos, end_pos, file, text, etc.
```

---

### 3. Buffers Picker (`<leader>,` + `<M-y>`)

**Setup:**
1. Open multiple buffers
2. Press `<leader>,` to open buffers picker
3. Navigate to any buffer
4. Press `<M-y>` to open path format picker

**Expected Results:**
- [ ] Sub-picker opens with title: "Select Path Format (C-y: copy, Enter: paste)"
- [ ] Shows ~4-8 path format variants
- [ ] Does NOT show code-ref variants (no line/col info in buffer items)
- [ ] Title does NOT show "[+N code-refs]" indicator

---

### 4. Column Toggle (`<A-c>` in Sub-Picker)

**Setup:**
1. Open grep picker (`<leader>/`)
2. Search for a term
3. Press `<M-y>` on a result
4. In the sub-picker, press `<A-c>`

**Expected Results:**
- [ ] Notification shows "Column: hidden"
- [ ] Sub-picker closes and reopens automatically
- [ ] Code-ref formats now show WITHOUT column info:
  ```
  Before: lua/utils/snacks_actions.lua:128:3
  After:  lua/utils/snacks_actions.lua:128
  
  Before: @lua/utils/snacks_actions.lua L128:C3
  After:  @lua/utils/snacks_actions.lua L128
  ```
- [ ] Press `<A-c>` again → notification shows "Column: shown"
- [ ] Code-ref formats restore column info

**Validation:**
```lua
-- Check global state:
:lua vim.print(vim.g.code_ref_hide_col)
-- Should toggle: nil/false → true → false
```

---

### 5. Copy & Paste Actions

**Setup:**
1. Open grep picker and press `<M-y>` on a result
2. Navigate to a code-ref variant

**Expected Results:**
- [ ] **`<C-y>` (copy):** Copies to system clipboard ("+) and vim register (")
  - Run `:reg +` to verify
- [ ] **`<CR>` (paste):** Inserts path at cursor in parent buffer
- [ ] **`<C-p>` (paste):** Same as `<CR>`
- [ ] Picker does NOT close after copy (allows multiple copies)
- [ ] Picker CLOSES after paste

---

### 6. Line/Col Parsing Accuracy

**Setup:**
1. Create a test file with known content:
   ```lua
   -- test.lua
   local function test()
     print("hello")  -- line 2, col ~3 for "print"
   end
   ```
2. Grep for "print"
3. Press `<M-y>` on the result

**Expected Results:**
- [ ] Code-ref shows correct line number: `test.lua:2:X`
- [ ] Column number is reasonable (0-10 range for "print" start)
- [ ] Verify with actual grep result `item.pos`:
  ```lua
  :lua vim.print(require("snacks.picker").get()[1].items[1].pos)
  -- Should print: {2, X} where X is 0-based col
  ```

**Manual Verification:**
```bash
# In terminal:
cd /path/to/project
rg "print" test.lua
# Compare line:col with what picker shows
```

---

### 7. Edge Cases

#### 7.1 No Search Results
**Setup:** Grep for nonsense term like "xyzabc123"

**Expected:**
- [ ] Picker shows "No results" or empty list
- [ ] `<M-y>` does nothing or shows warning

#### 7.2 File at Project Root
**Setup:** Grep in a file at git root (e.g., `README.md`)

**Expected:**
- [ ] Path formats include "Git: README.md" (no subdirectory)
- [ ] Code-ref: `README.md:5:1` (not `./README.md:5:1`)

#### 7.3 File Outside Git Repo
**Setup:** Grep in a file outside any git repo

**Expected:**
- [ ] "Git" format variant is absent
- [ ] "Relative CWD" and "Absolute" still work
- [ ] Code-ref variants use CWD/absolute paths

---

## Acceptance Criteria

- [ ] All test scenarios pass
- [ ] No Lua errors in `:messages`
- [ ] Grep items show code-ref variants with correct line:col
- [ ] Files/buffers show only path variants (no code-ref)
- [ ] `<A-c>` toggle works and persists globally
- [ ] Copy/paste actions work as expected
- [ ] Performance is acceptable (sub-picker opens in <100ms)

---

## Known Issues / Limitations

1. **Directory variants:** Currently skipped for code-ref (only file paths supported)
2. **Multi-line grep matches:** Uses `pos[1]` as start line, ignores `end_pos` for ranges
3. **Visual mode:** Not applicable in picker context (would need separate implementation)

---

## Rollback Plan

If issues arise, revert changes to `lua/utils/snacks_actions.lua`:
```bash
git checkout HEAD~1 -- lua/utils/snacks_actions.lua
```

Or manually revert functions:
- `get_item_path()` - remove line/col return values
- `generate_coderef_formats()` - delete function
- `copy_path_select()` - restore to only use `generate_path_formats()`
