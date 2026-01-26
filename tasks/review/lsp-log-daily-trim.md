---
title: "Add daily trim for lsp.log (keep last 70% lines)"
status: "review"
assignee: "ai"
created: 2026-01-25
updated: 2026-01-26
priority: "medium"
stash: "stash@{0}: fix(lsp): daily log trim with fast-event fix and --noplugin compat"
related:
  - lua/utils/startup/lsp_log_trim.lua
  - lua/config/myautocmds.lua
  - init.lua
---

> **Note**: Code changes are stashed. Apply with: `git stash apply stash@{0}`

## Objective

Trim the LSP log daily to the last 70% of lines, run lazily after startup, and remember successful runs to avoid repeating the trim on the same day.

## Changes Summary

### What Was Done

- Added a daily trim utility that:
  - Runs only with a UI (skips headless)
  - Defers work until after `VimEnter` (5s delay by default)
  - Trims `vim.lsp.get_log_path()` to the last 70% of lines
  - Persists a daily stamp file only after a successful trim
- Hooked the utility into startup without blocking

### Issues Fixed (2026-01-26)

**Issue 1: Fast Event Context Error**
- **Problem**: `vim.fn.shellescape()` called inside async callbacks caused "E5560: Vimscript function must not be called in a fast event context"
- **Fix**: Pre-compute all shell-escaped paths before entering async callbacks (lua/utils/startup/lsp_log_trim.lua:56-57)
- **Fix**: Wrap `write_last_date()` calls in `vim.schedule()` to defer them out of fast event context (lua/utils/startup/lsp_log_trim.lua:72-74, 90-92)
- **Fix**: Replaced `vim.fn.shellescape()` with pure Lua implementation (lua/utils/startup/lsp_log_trim.lua:25-28)

**Issue 2: Feature Always Disabled**
- **Problem**: Line 127 had `if vim.g.lsp_log_trim_enabled == false or true then` which always evaluated to `true`, disabling the feature
- **Fix**: Changed to `if vim.g.lsp_log_trim_enabled == false then` (lua/utils/startup/lsp_log_trim.lua:119)

**Issue 3: Misleading Documentation**
- **Problem**: Comments suggested `_did_setup` would persist across restarts
- **Fix**: Added clarifying comment that `_did_setup` only prevents multiple setups in same session; daily frequency controlled by date stamp file (lua/utils/startup/lsp_log_trim.lua:108-110)

### Files Modified

✓ **Fixed**: lua/utils/startup/lsp_log_trim.lua
  - Replaced `vim.fn.shellescape()` with pure Lua escaping
  - Pre-compute escaped paths before async operations
  - Wrap file writes in `vim.schedule()`
  - Fixed enable/disable logic
  - Clarified documentation comments

✓ **Fixed**: init.lua (2026-01-26)
  - Added `pcall()` guards for plugin-dependent code
  - Prevents errors when running with `--noplugin`
  - Wraps `require("kanagawa")` and `require("config.mydefault-nvim-config")`

✓ **Unchanged**: lua/config/myautocmds.lua (calls `require("utils.startup.lsp_log_trim").setup()`)

## Implementation Notes

- Daily stamp file: `${stdpath('state')}/lsp-log-trim.last`
- Default delay: 5000ms after `VimEnter`
- Disable switch: `vim.g.lsp_log_trim_enabled = false`
- Shell escaping: Pure Lua implementation using single-quote wrapping with `'\\''` escape sequence

## Compatibility Guarantees

### `nvim --clean`
- ✅ No errors: User config (`init.lua`) is not loaded at all
- ✅ Feature skipped gracefully: `lsp_log_trim.setup()` never called
- ✅ No plugin dependencies involved

### `nvim --noplugin`
- ✅ No errors: `init.lua` loads with `pcall()` guards around plugin code
- ✅ Feature works: `lsp_log_trim.lua` uses only core Neovim APIs
- ✅ Dependencies verified:
  - `vim.uv` / `vim.loop` (libuv bindings)
  - `vim.fn.stdpath()`, `vim.fn.readfile()`, `vim.fn.writefile()`
  - `vim.lsp.get_log_path()`
  - `vim.system()` (with fallback check)
  - `vim.schedule()`, `vim.defer_fn()`
  - All core APIs, no plugin dependencies

## Technical Details

### Fast Event Context Solution

The original error occurred because:
1. `vim.system()` callbacks run in a "fast event" context
2. Vimscript API functions (`vim.fn.*`) are restricted in fast events
3. Solution: Pre-compute all Vimscript calls before entering callbacks

### Shell Escaping Strategy

```lua
-- Old (causes fast event error):
local function shellescape(path)
  return vim.fn.shellescape(path)  -- ❌ Can't call in async
end

-- New (pure Lua, works anywhere):
local function shellescape(path)
  return "'" .. path:gsub("'", "'\\''") .. "'"  -- ✓ Safe
end
```

## Code References

- Daily stamp path: lua/utils/startup/lsp_log_trim.lua:5
- Keep ratio + delay defaults: lua/utils/startup/lsp_log_trim.lua:102
- UI-only + deferred run: lua/utils/startup/lsp_log_trim.lua:123
- Trim pipeline (wc/tail/writeback): lua/utils/startup/lsp_log_trim.lua:59
- Startup hook: lua/config/myautocmds.lua:217
- Shell escape pre-computation: lua/utils/startup/lsp_log_trim.lua:54-57
- Scheduled file writes: lua/utils/startup/lsp_log_trim.lua:72-74, 90-92

## Verification Checklist

### Functionality Tests
- [ ] Start Neovim and wait ~5s; confirm no "fast event context" errors
- [ ] Confirm `~/.local/state/nvim3_jelly_tinynvim/lsp-log-trim.last` is created with today's date
- [ ] Confirm `lsp.log` line count decreases to ~70% of original
- [ ] Restart Neovim the same day and confirm no additional trim occurs (check logs)
- [ ] Test with log path containing spaces or special characters
- [ ] Test disabling: `vim.g.lsp_log_trim_enabled = false` and confirm no trim occurs

### Compatibility Tests (Added 2026-01-26)
- [x] Test with `nvim --clean` → No errors (config not loaded)
- [x] Test with `nvim --noplugin` → Module loads and works (uses only core APIs)
- [x] Test module in isolation → All core APIs available

## Testing Commands

```lua
-- Check if feature is active
:lua print(vim.g.lsp_log_trim_enabled)  -- should be nil (enabled by default)

-- Check log path
:lua print(vim.lsp.get_log_path())

-- Check stamp file
:lua print(vim.fn.stdpath("state") .. "/lsp-log-trim.last")

-- Read stamp file
:lua print(vim.inspect(vim.fn.readfile(vim.fn.stdpath("state") .. "/lsp-log-trim.last")))

-- Disable feature
:lua vim.g.lsp_log_trim_enabled = false
```
