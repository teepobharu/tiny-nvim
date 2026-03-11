---
title: Fix CodeCompanion v19 Compatibility with MCPHub Extension
status: open
priority: high
created: 2026-03-09
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

## Solution Options

### Option 1: Downgrade CodeCompanion to v18.x (Most Stable)
- **Pros**: No breaking changes, stable configuration
- **Cons**: Miss out on v19 features (agent mode improvements, new tools, etc.)
- **Implementation**: Pin codecompanion version in [lua/plugins/extra/codecompanion.lua](lua/plugins/extra/codecompanion.lua)

### Option 2: Disable MCPHub CodeCompanion Integration (Easiest)
- **Pros**: Keep codecompanion v19 features, no manual patching needed
- **Cons**: Lose MCP resources as codecompanion variables functionality
- **Implementation**: Disable in mcphub config or temporarily disable mcphub plugin

### Option 3: Patch MCPHub Locally (Requires Maintenance)
- **Pros**: Keep both v19 features and MCP integration
- **Cons**: Manual patch in lazy plugin directory, may be overwritten on plugin updates
- **Implementation**: Edit `~/.local/share/nvim3_jelly_tinynvim/lazy/mcphub.nvim/lua/mcphub/extensions/codecompanion/variables.lua`

### Option 4: Report Issue & Wait for Upstream Fix (Best Long-term)
- **Pros**: Official fix, no maintenance burden
- **Cons**: May take time, need temporary workaround
- **Implementation**: Open issue at [ravitemer/mcphub.nvim](https://github.com/ravitemer/mcphub.nvim) + use Option 2 temporarily

## Questions for Decision

1. How critical is the mcphub integration with codecompanion for your workflow?
2. Are you actively using MCP resources as codecompanion variables?
3. Would you prefer stability (downgrade) or latest features (disable integration)?

## Recommended Approach

**Hybrid Strategy**:
1. Disable MCPHub codecompanion integration temporarily (Option 2)
2. Report issue to mcphub.nvim upstream (Option 4)
3. Re-enable when official fix is available

## References

- CodeCompanion v19 upgrade docs: [doc/upgrading.md](https://github.com/olimorris/codecompanion.nvim/blob/main/doc/upgrading.md)
- Breaking change commit: `42ba80ca` - "refactor!: rename `variables` to `editor context`"
- Config location: [lua/plugins/extra/codecompanion.lua](lua/plugins/extra/codecompanion.lua)
- MCPHub config: [lua/plugins/extra/mcphub.lua](lua/plugins/extra/mcphub.lua)

## Implementation Steps (Once Decision Made)

### If Option 1 (Downgrade):
- [ ] Pin codecompanion to v18.7.0 in lazy spec
- [ ] Run `:Lazy update codecompanion` to downgrade
- [ ] Verify chat works without errors

### If Option 2 (Disable Integration):
- [ ] Comment out or disable mcphub extension for codecompanion
- [ ] Test codecompanion chat functionality
- [ ] Open issue on mcphub.nvim GitHub

### If Option 3 (Local Patch):
- [ ] Edit `~/.local/share/nvim3_jelly_tinynvim/lazy/mcphub.nvim/lua/mcphub/extensions/codecompanion/variables.lua`
- [ ] Change line 17: `config.interactions.chat.variables` → `config.interactions.chat.editor_context`
- [ ] Test MCP variables in codecompanion chat
- [ ] Document patch for future reference

### If Option 4 (Report & Wait):
- [ ] Create detailed issue report with error trace
- [ ] Implement Option 2 as temporary workaround
- [ ] Monitor for upstream fix
- [ ] Update when patch available
