# ${VAR} Curly Brace Expansion Test

Test file specifically for ${VAR} syntax that was previously broken.

## Issue

The `${VAR}` syntax wasn't expanding because `vim.fn.expand()` only handles `$VAR` and `~`, not `${VAR}`.

## Fix

Added two-step expansion:
1. Manual gsub to expand `${VAR}` using `os.getenv()`
2. Then `vim.fn.expand()` for `$VAR` and `~`

## Test Cases

Place cursor on each line and press `gF`. All should open correctly.

### Basic ${VAR} Expansion

1. ${HOME}/.config/nvim3_jelly_tinynvim/lua/config/mykeymaps.lua
2. ${HOME}/.config/nvim3_jelly_tinynvim/lua/config/mykeymaps.lua:1000
3. ${HOME}/.config/nvim3_jelly_tinynvim/init.lua

### With Wrappers

4. `${HOME}/.config/nvim3_jelly_tinynvim/lua/config/mykeymaps.lua`
5. "${HOME}/.config/nvim3_jelly_tinynvim/init.lua"
6. '${HOME}/.local/share/nvim/lazy/overseer.nvim/CHANGELOG.md'
7. [${HOME}/.config/nvim3_jelly_tinynvim/lua/plugins/ui.lua:302]

### Custom Environment Variables

8. ${XDG_CONFIG_HOME}/nvim/init.lua
9. `${XDG_CONFIG_HOME}/nvim3_jelly_tinynvim/init.lua`

### Comparison with Other Formats

All three should work identically:

10. ${HOME}/.config/nvim3_jelly_tinynvim/lua/config/mykeymaps.lua
11. $HOME/.config/nvim3_jelly_tinynvim/lua/config/mykeymaps.lua
12. ~/.config/nvim3_jelly_tinynvim/lua/config/mykeymaps.lua

## Expected Results

- All `${VAR}` should expand to actual paths
- Line numbers should be preserved
- Wrappers should be stripped first
- Files should open at correct location

## Verification

After testing:
- [ ] Basic ${VAR} expansion works (3 tests)
- [ ] ${VAR} with wrappers works (4 tests)
- [ ] Custom env vars work (2 tests)
- [ ] All three formats work identically (3 tests)

Total: 12 ${VAR} tests
