---
title: Fix CodeCompanion v19 Compatibility with MCPHub Extension
status: review
priority: high
created: 2026-03-09
updated: 2026-03-16
tags: [codecompanion, mcphub, bug, breaking-change]
---

## Problem

After updating codecompanion from v18 to v19, getting error when opening chat:

```
Error executing vim.schedule lua callback: ...b.nvim/lua/mcphub/extensions/codecompanion/variables.lua:20: bad argument #1 to 'pairs' (table expected, got nil)
stack traceback:
	[C]: in function 'pairs'
	...b.nvim/lua/mcphub/extensions/codecompanion/variables.lua:20: in function 'register'
```

## Root Cause

**Breaking Change in CodeCompanion v19.0.0**: The `variables` configuration key was renamed to `editor_context` in [PR #2719](https://github.com/olimorris/codecompanion.nvim/pull/2719).

The mcphub.nvim plugin references the old path:
- **Old (v18)**: `config.interactions.chat.variables`
- **New (v19)**: `config.interactions.chat.editor_context`

Location: `~/.local/share/nvim3_jelly_tinynvim/lazy/mcphub.nvim/lua/mcphub/extensions/codecompanion/variables.lua:17`

## Chosen Approach: Option 3 (Local Patch via lazy-local-patcher.nvim)

Combined Option 3 + Option 4: Apply the fix from upstream [PR #279](https://github.com/ravitemer/mcphub.nvim/pull/279) as a local patch using `lazy-local-patcher.nvim`, and monitor the PR for merge.

### What was done

1. **Installed `lazy-local-patcher.nvim`** — new plugin spec at [lua/plugins/extra/myLazyPatcher.lua](lua/plugins/extra/myLazyPatcher.lua)
2. **Created patch from PR #279** — saved to `patches/mcphub.nvim/01-codecompanion-v19-compat.patch`
3. **Updated CodeCompanion version pin** — changed from `^18.7.0` to `^19` in [lua/plugins/extra/myAi.lua:216](lua/plugins/extra/myAi.lua:216)
4. **Verified patch applies cleanly** — `git apply --check` passed against current mcphub.nvim HEAD (`7cd5db3`)

### Files changed

| File | Change |
|------|--------|
| `lua/plugins/extra/myLazyPatcher.lua` | New — lazy-local-patcher.nvim plugin spec |
| `lua/plugins/extra/myAi.lua:216` | Changed version pin `^18.7.0` → `^19` |
| `patches/mcphub.nvim/01-codecompanion-v19-compat.patch` | New — PR #279 diff (4 files, 355 lines) |

### Upstream status

- **Issue**: [#275](https://github.com/ravitemer/mcphub.nvim/issues/275) — Crash on startup with codecompanion v19
- **PR**: [#279](https://github.com/ravitemer/mcphub.nvim/pull/279) — feat(extensions): adapt CodeCompanion extension for v19 compatibility (Open, not yet merged)
- **Cleanup task**: [tasks/open/monitor-mcphub-pr279-merge.md](tasks/open/monitor-mcphub-pr279-merge.md)

## Verification

### How to verify

Restart Neovim with the **worktree profile** to install the new plugin and apply
patches, then upgrade CodeCompanion to v19 and test MCP integration.

**Important**: Use the worktree profile (`NVIM_APPNAME=nvimwt3a`) — this is isolated
from the main daily-driver profile and won't affect it.

### Commands

```bash
# Test in the worktree profile (isolated from main daily-driver)
NVIM_APPNAME=nvimwt3a nvim
```

```vim
" Step 1: Install lazy-local-patcher and sync codecompanion to v19
:Lazy sync

" Step 2: Patches should auto-apply via Lazy sync, but can run manually if needed
:lua require("lazy-local-patcher").apply_all()

" Step 3: Restart Neovim to ensure clean state
" (quit and reopen with NVIM_APPNAME=nvimwt3a nvim)

" Step 4: Verify CodeCompanion version
:Lazy log codecompanion.nvim
" Should show v19.x.x

" Step 5: Open MCPHub
:MCPHub

" Step 6: Open CodeCompanion chat
:CodeCompanionChat
```

### Checklist

- [ ] `:Lazy sync` installs `lazy-local-patcher.nvim` and upgrades `codecompanion.nvim` to v19
- [ ] No errors on Neovim startup after sync
- [ ] `:Lazy log codecompanion.nvim` shows a v19.x.x version
- [ ] `:MCPHub` opens without errors
- [ ] In CodeCompanion chat, typing `@` shows MCP tool entries (e.g., `@mcp`)
- [ ] In CodeCompanion chat, typing `#mcp` shows MCP resource variables
- [ ] In CodeCompanion chat, typing `/mcp` shows MCP prompt slash commands
- [ ] No regressions in other CodeCompanion functionality (chat, inline, adapters)
- [ ] `:Lazy sync` a second time completes without errors (patch auto-reverts and re-applies)

## References

- [Upstream PR #279](https://github.com/ravitemer/mcphub.nvim/pull/279)
- [lazy-local-patcher.nvim](https://github.com/polirritmico/lazy-local-patcher.nvim)
- [CodeCompanion v19 migration guide](https://codecompanion.olimorris.dev)
- [Plugin spec](lua/plugins/extra/myLazyPatcher.lua)
- [MCPHub config](lua/plugins/extra/myAi.lua)
- [Monitor PR task](tasks/open/monitor-mcphub-pr279-merge.md)
