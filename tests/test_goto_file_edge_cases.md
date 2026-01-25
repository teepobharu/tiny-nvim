# goto_file_line() Edge Case Tests

Test file for verifying wrapper stripping handles edge cases.

## Test Instructions

Place cursor on each path and press `gF`. All should open correctly.

## Edge Cases - Unbalanced Wrappers

Test unbalanced quotes and brackets:

1. `'lua/config/mykeymaps.lua:1
2. ['lua/config/mykeymaps.lua:1
3. `"lua/config/mykeymaps.lua:1
4. <lua/config/mykeymaps.lua:1

## Edge Cases - Multiple Adjacent Wrappers

Test multiple different wrapper types:

1. `['lua/config/mykeymaps.lua:1]`
2. "'lua/config/mykeymaps.lua:1'"
3. [`lua/config/mykeymaps.lua:1`]
4. <"lua/config/mykeymaps.lua:1">

## Edge Cases - Nested Wrappers

Test nested wrappers with line numbers:

1. `'`lua/config/mykeymaps.lua:100`'`
2. "[./lua/config/mykeymaps.lua]"
3. <'lua/config/mykeymaps.lua:100'>
4. (`lua/config/mykeymaps.lua:100`)

## Edge Cases - With Anchors

Test wrappers with markdown anchors:

1. `'docs/task_tracking.md#workflow
2. ["docs/task_tracking.md#workflow"]
3. <`docs/task_tracking.md#workflow`>

## Edge Cases - Whitespace

Test with leading/trailing whitespace:

1.   `lua/config/mykeymaps.lua:1`
2.   "lua/config/mykeymaps.lua:1"
3.   'lua/config/mykeymaps.lua:1'

## Expected Behavior

All paths above should:
- Strip all non-path characters (`, ', ", [, ], <, >, (, ), whitespace)
- Preserve the core path: `lua/config/mykeymaps.lua`
- Preserve line numbers: `:1`, `:100`
- Preserve anchors: `#workflow`
- Open the correct file at the correct location

## Verification

After testing, all items should be checked:

- [x] Unbalanced wrappers work (4 tests)
- [x] Multiple adjacent wrappers work (4 tests)
- [x] Nested wrappers work (4 tests)
- [x] Wrappers with anchors work (3 tests)
- [x] Whitespace handling works (3 tests)

Total: 18 edge case tests
