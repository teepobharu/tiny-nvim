---
title: "Patch mcphub.nvim for CodeCompanion v19 compatibility"
status: review
priority: high
created: 2026-03-15
updated: 2026-03-21
related:
  - [MCPHub config](lua/plugins/extra/myAi.lua)
  - [MCPHub memory](docs/memory/mcphub.md)
  - [lazy-local-patcher.nvim](https://github.com/polirritmico/lazy-local-patcher.nvim)
  - [Upstream PR #279](https://github.com/ravitemer/mcphub.nvim/pull/279)
  - [Monitor PR task](tasks/open/monitor-mcphub-pr279-merge.md)
---

## Objective

Upgrade `codecompanion.nvim` from pinned `^18.7.0` to exact `v19.6.0` and patch
`mcphub.nvim` locally using `lazy-local-patcher.nvim` to apply the fixes from
[PR #279](https://github.com/ravitemer/mcphub.nvim/pull/279), which the
upstream maintainer has not yet merged.

## Context

CodeCompanion v19 introduced breaking API changes to its tool, variable, and
image APIs. The mcphub.nvim extension for CodeCompanion is not yet updated
upstream. PR #279 (by bahaaza) provides the fix but is unmerged. Rather than
wait, we apply it as a local patch via `lazy-local-patcher.nvim`, which
auto-applies patches before Lazy operations and reverts them before syncing so
updates still work cleanly.

Current state in `lua/plugins/extra/myAi.lua`:

```lua
version = "19.6.0",  -- exact pin for the patched mcphub integration
```

### v19 Breaking Changes (from PR #279)

| Area                | Old API                              | New API                                      |
| ------------------- | ------------------------------------ | -------------------------------------------- |
| Tool callback       | `callback = { table }`               | `callback = function() return { table } end` |
| Tool cmds handler   | `(agent, args, _, output_handler)`   | `(self, action, opts)`                       |
| Tool output handler | `(self, agent, cmd, data)`           | `(self, data, meta)`                         |
| Variables / editor context | `config.interactions.chat.variables` | `v19.3.0`: `config.interactions.chat.editor_context`, `v19.6.0`: `config.interactions.shared.editor_context` |
| Image helpers       | `helpers.add_image(chat, img)`       | `chat:add_image_message(img)`                |
| System prompt       | `function(self)`                     | `function(group_config, ctx)`                |

### Files to patch in mcphub.nvim

- `lua/mcphub/extensions/codecompanion/init.lua` (strategies → interactions)
- `lua/mcphub/extensions/codecompanion/tools.lua`
- `lua/mcphub/extensions/codecompanion/core.lua`
- `lua/mcphub/extensions/codecompanion/variables.lua`
- `lua/mcphub/extensions/codecompanion/slash_commands.lua`

## Implementation Plan

- [x] Install `polirritmico/lazy-local-patcher.nvim` — added spec at `lua/plugins/extra/myLazyPatcher.lua`
- [x] Create patches directory: `mkdir -p patches/mcphub.nvim` (in the worktree config dir)
- [x] Generate patch files from PR #279 diff (4 files) and save to the patches directory
  - Fetched raw diff from `https://github.com/ravitemer/mcphub.nvim/pull/279.diff`
  - Saved as `patches/mcphub.nvim/01-codecompanion-v19-compat.patch` (355 lines)
- [x] Configure `lazy-local-patcher.nvim` — defaults work correctly (`stdpath("config")/patches` = `~/.config/nvimwt3a/patches` for worktree profile)
- [x] Update CodeCompanion version pin in `lua/plugins/extra/myAi.lua` from `^18.7.0` to exact `19.6.0`
- [x] Verified patch applies cleanly against mcphub.nvim HEAD (`7cd5db3`, tag `v6.2.0-18`)
- [ ] Run `:Lazy sync` to upgrade CodeCompanion and verify patches apply cleanly
- [x] Test MCPHub integration: tools (`@server__tool`), variables (`#mcp:resource`), slash commands (`/mcp:prompt`)
- [x] Document any gotchas in `docs/memory/mcphub.md`

## Success Criteria

- CodeCompanion v19 is installed and running
- No startup errors related to mcphub extension or variable/tool API mismatches
- MCPHub tools appear in CodeCompanion chat (`@mcp` etc.)
- MCP resources available as variables (`#mcp:...`)
- MCP prompts available as slash commands
- `:Lazy sync` / `:Lazy update` work without leaving dirty mcphub.nvim state
- Patch auto-reverts before Lazy sync and re-applies after

## Verification

### How to verify

Restart Neovim with the **worktree profile** after `:Lazy sync` completes. Open a
CodeCompanion chat and confirm MCP tools, variables, and slash commands are
accessible without errors. Also verify Lazy can still sync mcphub.nvim cleanly.

**Important**: Use `NVIM_APPNAME=nvimwt3a` — this is isolated from the main profile.

### Commands

```bash
# Start Neovim (main profile or worktree)
NVIM_APPNAME=nvim3_jelly_tinynvim nvim
```

```vim
" 1. Check CodeCompanion version is v19+
:Lazy log codecompanion.nvim

" 2. Verify patch is applied (check mcphub plugin has local changes)
:!git -C ~/.local/share/nvim3_jelly_tinynvim/lazy/mcphub.nvim diff --stat

" 3. Verify the patched init.lua uses 'interactions' not 'strategies'
:!grep -n 'interactions\|strategies' ~/.local/share/nvim3_jelly_tinynvim/lazy/mcphub.nvim/lua/mcphub/extensions/codecompanion/init.lua

" 4. Force re-apply patch (if needed after Lazy sync)
:lua require("lazy-local-patcher").apply_all()

" 5. Open MCPHub to confirm servers running
:MCPHub

" 6. Open CodeCompanion chat and test MCP integration
:CodeCompanionChat
" Then type: @{mcp} what's available mcp
" Then type: # and look for mcp: entries
" Then type: / and look for mcp: entries

" 7. Verify no 'strategies' nil errors in messages
:messages

" 8. Test Lazy update cycle (should revert patch, update, re-apply)
:lua require("lazy-local-patcher").restore_all()
:!git -C ~/.local/share/nvim3_jelly_tinynvim/lazy/mcphub.nvim diff --stat
" (should show no changes - clean state)
:lua require("lazy-local-patcher").apply_all()
:!git -C ~/.local/share/nvim3_jelly_tinynvim/lazy/mcphub.nvim diff --stat
" (should show 5 files changed)

" 9. Verify patch file applies cleanly from scratch
:!git -C ~/.local/share/nvim3_jelly_tinynvim/lazy/mcphub.nvim stash && git -C ~/.local/share/nvim3_jelly_tinynvim/lazy/mcphub.nvim apply --check ~/.config/nvim3_jelly_tinynvim/patches/mcphub.nvim/01-codecompanion-v19-compat.patch && echo "PATCH OK" && git -C ~/.local/share/nvim3_jelly_tinynvim/lazy/mcphub.nvim stash pop
```

### Checklist

- [x] No errors on Neovim startup related to mcphub or codecompanion
- [x] `:Lazy log codecompanion.nvim` shows the pinned target version after sync
- [x] `:MCPHub` opens without errors
- [x] In CodeCompanion chat, typing `@` shows MCP tool entries
- [x] In CodeCompanion chat, typing `#mcp` shows MCP resource variables
- [x] In CodeCompanion chat, typing `/mcp` shows MCP prompt slash commands
- [x] No regressions in other CodeCompanion functionality (chat, inline, adapters)

  Not passing
  - `:Lazy sync` completes without errors and leaves mcphub.nvim clean (no dirty state) - still has dirty state
  - `:Lazy restore` fail message:
      mcphub.nvim 19.83ms  avante.nvim
        You have local changes in `/Users/tharutaipree/.local/share/nvimwt3a/lazy/mcphub.nvim`:
        * lua/mcphub/extensions/codecompanion/core.lua
  Both can be remedied by using require("lazy-local-patcher").revert_all() to clean the state, but ideally should work without manual intervention.

## References

- [Upstream PR #279 — adapt CodeCompanion extension for v19](https://github.com/ravitemer/mcphub.nvim/pull/279)
- [lazy-local-patcher.nvim README](https://github.com/polirritmico/lazy-local-patcher.nvim)
- [CodeCompanion v19 migration guide](https://codecompanion.olimorris.dev)
- [MCPHub config](lua/plugins/extra/myAi.lua)
- [MCPHub memory doc](docs/memory/mcphub.md)
- [Monitor PR task](tasks/open/monitor-mcphub-pr279-merge.md)
