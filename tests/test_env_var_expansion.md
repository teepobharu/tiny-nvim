# Environment Variable Expansion Tests

Quick tests for goto_file_line() env var expansion feature.

## Test Instructions

Place cursor on each path below and press `gF`. File should open correctly.

## Basic Environment Variables

Test tilde expansion:
- ~/.config/nvim3_jelly_tinynvim/lua/config/mykeymaps.lua
- ~/.config/nvim3_jelly_tinynvim/lua/config/mykeymaps.lua:1000

Test $HOME expansion:
- $HOME/.config/nvim3_jelly_tinynvim/lua/config/mykeymaps.lua
- $HOME/.config/nvim3_jelly_tinynvim/lua/config/mykeymaps.lua:1000

Test ${HOME} expansion:
- ${HOME}/.config/nvim3_jelly_tinynvim/lua/config/mykeymaps.lua
- ${HOME}/.config/nvim3_jelly_tinynvim/lua/config/mykeymaps.lua:1000

## With Wrappers

Test backticks + env vars:
- `~/.config/nvim3_jelly_tinynvim/lua/config/mykeymaps.lua`
- `$HOME/.config/nvim3_jelly_tinynvim/lua/config/mykeymaps.lua:1000`

Test quotes + env vars:
- "~/.config/nvim3_jelly_tinynvim/lua/config/mykeymaps.lua"
- '$HOME/.config/nvim3_jelly_tinynvim/lua/config/mykeymaps.lua:1000'

Test brackets + env vars:
- [${HOME}/.config/nvim3_jelly_tinynvim/lua/config/mykeymaps.lua]
- <~/.config/nvim3_jelly_tinynvim/lua/config/mykeymaps.lua:1000>

## Real-World Examples

From changelogs:
- `~/.local/share/nvim/lazy/overseer.nvim/CHANGELOG.md`
- `${HOME}/.local/share/nvim/lazy/gitsigns.nvim/CHANGELOG.md`

From documentation:
- "~/.config/nvim3_jelly_tinynvim/init.lua"
- '$HOME/.config/nvim3_jelly_tinynvim/lua/plugins/ui.lua:302'

## Expected Results

All paths should:
1. Expand `~` to your home directory
2. Expand `$HOME` to your home directory
3. Expand `${HOME}` to your home directory
4. Strip wrapper characters first
5. Open the correct file
6. Jump to line number if specified

## Verification

- [ ] Tilde expansion works (2 tests)
- [ ] $HOME expansion works (2 tests)
- [ ] ${HOME} expansion works (2 tests)
- [ ] Backticks + env vars work (2 tests)
- [ ] Quotes + env vars work (2 tests)
- [ ] Brackets + env vars work (2 tests)
- [ ] Real-world examples work (4 tests)

Total: 16 env var tests
