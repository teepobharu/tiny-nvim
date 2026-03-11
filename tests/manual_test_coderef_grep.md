# Manual Test: Code-Ref Grep Picker Extension

## Test Session Log

Date: 2026-02-12

### Pre-Test Checklist

- [ ] Neovim running: `NVIM_APPNAME=nvim3_jelly_tinynvim nvim`
- [ ] No errors in `:messages`
- [ ] Snacks picker loaded: `:lua print(vim.inspect(Snacks.picker))`

### Test 1: Files Picker (No Code-Refs Expected)

**Steps:**
1. Open files picker: `<leader>ff` or `<leader><space>`
2. Navigate to any file
3. Press `<M-y>` or `YY`

**Expected:**
- Sub-picker opens
- Title: "Select Path Format (C-y: copy, Enter: paste)"
- Shows ~4-8 path variants (Relative, Git, CWD, Absolute, Dir variants)
- NO code-ref variants
- NO "[+N code-refs]" in title

**Actual:**
- [ ] PASS / FAIL
- Notes:

---

### Test 2: Grep Picker (Code-Refs Expected)

**Steps:**
1. Open grep picker: `<leader>/`
2. Search for "function" or "local"
3. Navigate to any search result
4. Press `<M-y>` or `YY`

**Expected:**
- Sub-picker opens
- Title: "Select Path Format (C-y: copy, Enter: paste) [+N code-refs]" (where N > 0)
- First section: ~4-8 path variants
- Second section: Code-ref variants with format labels:
  - "Relative (colon): path:line:col"
  - "Relative (space): path line:col"
  - "Relative (@): @path line:col"
  - "Relative (@caps): @path Lline:Ccol"
  - "Relative (#): path#LlineCcol"
  - (Same for Git, CWD, Absolute variants)
- Line/col numbers match the grep result

**Actual:**
- [ ] PASS / FAIL
- Notes:

---

### Test 3: Line/Col Parsing Accuracy

**Steps:**
1. In grep picker, note the line:col shown in the grep result (e.g., "file.lua:42:10")
2. Press `<M-y>`
3. Compare code-ref line:col with grep result

**Expected:**
- Line number matches exactly
- Column number matches exactly (grep shows 0-based or 1-based?)

**Verification Command:**
```vim
:lua vim.print(require("snacks.picker").get()[1].items[1].pos)
" Should print: {line, col} where line is 1-based, col is 0-based
```

**Actual:**
- Grep shows: `_________:___:___`
- Code-ref shows: `_________:___:___`
- Match: [ ] YES / NO
- Notes:

---

### Test 4: Column Toggle (`<A-c>`)

**Steps:**
1. Open grep picker and press `<M-y>` on a result
2. In sub-picker, press `<A-c>`
3. Observe notification and picker refresh
4. Check if column info is hidden
5. Press `<A-c>` again

**Expected:**
- First `<A-c>`: Notification "Column: hidden", picker refreshes
  - Code-ref formats show: `path:line` (no `:col`)
  - @caps format: `@path Lline` (no `:Ccol`)
- Second `<A-c>`: Notification "Column: shown", picker refreshes
  - Code-ref formats restore column info

**Actual:**
- [ ] PASS / FAIL
- Notes:

---

### Test 5: Copy Action (`<C-y>`)

**Steps:**
1. Open grep picker, press `<M-y>` on a result
2. Navigate to a code-ref variant (e.g., "Relative (colon)")
3. Press `<C-y>`
4. Check clipboard: `:reg +`

**Expected:**
- Notification shows copy success
- Clipboard (`+` register) contains selected format
- Picker stays open (does not close)

**Actual:**
- Clipboard content: `__________________`
- Picker closed: [ ] YES / NO (should be NO)
- [ ] PASS / FAIL

---

### Test 6: Paste Action (`<CR>`)

**Steps:**
1. Open grep picker, press `<M-y>` on a result
2. Navigate to a code-ref variant
3. Position cursor in a buffer
4. Press `<CR>` in sub-picker

**Expected:**
- Selected code-ref inserted at cursor
- Both sub-picker and parent picker close

**Actual:**
- Inserted text: `__________________`
- Pickers closed: [ ] YES / NO (should be YES)
- [ ] PASS / FAIL

---

### Test 7: Buffers Picker (No Code-Refs Expected)

**Steps:**
1. Open buffers picker: `<leader>,` or `<leader>fb`
2. Navigate to any buffer
3. Press `<M-y>`

**Expected:**
- Same as Test 1 (files picker)
- No code-ref variants

**Actual:**
- [ ] PASS / FAIL
- Notes:

---

## Issues Found

### Issue 1: [Title]
**Description:**

**Steps to Reproduce:**

**Expected:**

**Actual:**

**Fix Applied:**

---

### Issue 2: [Title]
**Description:**

**Steps to Reproduce:**

**Expected:**

**Actual:**

**Fix Applied:**

---

## Summary

- Total Tests: 7
- Passed: ___
- Failed: ___
- Issues Fixed: ___

**Overall Status:** [ ] PASS / FAIL

**Next Steps:**

