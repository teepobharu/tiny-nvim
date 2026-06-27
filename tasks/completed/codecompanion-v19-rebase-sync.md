---
title: "Sync CodeCompanion v19.17 rebase from main worktree (nvim3_jelly_tinynvim)"
status: open
priority: high
created: 2026-06-25
updated: 2026-06-25
refs:
  - 38bec52 [main] feat(ai): add kimi alt model via env config for AGD proxy (latest main)
  - 76735d9 [worktree] fix(ui): disable conflicting fff.nvim keys via false values (latest worktree)
  - 4393bb8 [worktree] fix(codecompanion): align myCodecomp.lua with v19.17.0 upstream config paths
parent: # Optional: rebase-upstream effort
related:
  - [myCodecomp.lua (worktree)](lua/plugins/extra/myCodecomp.lua)
  - [myCodecomp.lua (main)](file:///Users/tharutaipree/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/extra/myCodecomp.lua)
  - [my_codecompanion_utils.lua (worktree)](lua/utils/my_codecompanion_utils.lua)
  - [my_codecompanion_utils.lua (main)](file:///Users/tharutaipree/dotfiles/.config/nvim3_jelly_tinynvim/lua/utils/my_codecompanion_utils.lua)
---

## Objective

Synchronize the CodeCompanion v19.17 rebase work from main (`nvim3_jelly_tinynvim`) into this worktree (`nvimwt3a`), ensuring all features are present and **fully migrated to v19.17 APIs** (no `strategies`, proper `interactions`, etc.).

## Context

Both repos share the same origin (`teepobharu/tiny-nvim`) and forked at a common ancestor. Main is ~40 commits ahead with many CodeCompanion-related features. This worktree already has v19.17 structural fixes applied in commit `4393bb8`.

### Already done in this worktree (committed as `4393bb8` + working tree)

- [x] `strategies` → `interactions` migration
- [x] `system_prompt` moved to `interactions.chat.opts.system_prompt`
- [x] `cache_models_for` moved to `adapters.http.opts.cache_models_for`
- [x] `vim.tbl_deep_extend` wrapper around adapter merge
- [x] Version pin updated to `19.17.x`
- [x] `short_name` → `alias` in prompt_library
- [x] `show_model_choices = true` added to `adapters.http.opts` (fixes `ga` model picker)
- [x] `build_mcphub_lean_group()` ported from main + wired to `interactions.chat.tools`

### What differs: main is still on old v19-incompatible patterns

| File | Main status | Action needed |
|------|-------------|---------------|
| `myCodecomp.lua` | Still has `strategies = { chat = { tools = ... } }` (line 662) — **pre-v19** | Main needs v19 migration first, or we skip merging that block |
| `myCodecomp.lua` | Version pin is `19.13.x` | Update to `19.17.x` on main side |
| `my_codecompanion_utils.lua` | Has `form_tools` override (OpenAI 128-tool hard limit) — ~60 new lines | Port to worktree |

### Expected conflicts on `git rebase upstream`

The rebase onto `jellydn/tiny-nvim` upstream will touch `lua/plugins/extra/codecompanion.lua` heavily. Our overrides live in `myCodecomp.lua` so conflicts there should be minimal, but watch for:

1. **`codecompanion.lua`** — upstream config changes will rebase cleanly (we don't modify it)
2. **`myCodecomp.lua`** — if upstream changes `interactions` defaults, our `vim.tbl_deep_extend` merge may conflict on structure
3. **`lazy-lock.json`** — will auto-resolve on `:Lazy update`
4. **`my_codecompanion_utils.lua`** — low risk (our file, upstream doesn't touch)

### Features in main NOT yet in worktree (non-CodeCompanion)

These are unrelated to CC but on main already:

- `lua/plugins/extra/mySlackMcp.lua` + `lua/utils/slack_mcp/*` (7 files) — Slack MCP integration
- `lua/plugins/extra/oil.lua` — Oil.nvim config
- Various mcphub patches, overseer improvements, session picker, snacks enhancements

### Features in worktree NOT in main

- `lua/plugins/extra/nvim-eslint.lua` — ESLint plugin (worktree-only experiment)

## Implementation Plan

- [ ] Port `form_tools` override from main's `my_codecompanion_utils.lua` to worktree
  - Copy the `form_tools = function(self, tools) {...}` block (~60 lines starting at line 83)
  - This enforces OpenAI's 128-tool hard limit when MCP servers push tool count over the limit
- [ ] Decide: merge non-CC features from main or keep separate?
  - Slack MCP, oil.nvim, session picker etc. are independent of CC rebase
  - If merging, do them as separate commits to isolate conflicts
- [ ] Fix main's `myCodecomp.lua` `strategies` block before any future merge back
  - Replace `strategies = { chat = { tools = build_mcphub_lean_group() } }` with `tools = build_mcphub_lean_group()` under `interactions.chat`
  - Update version pin to `19.17.x`
- [ ] Verify `ga` (change_adapter) flow works end-to-end in worktree
- [ ] Run `:Lazy update` to sync `lazy-lock.json` after any version changes

## Success Criteria

1. `myCodecomp.lua` in worktree has all v19.17-compatible features from main
2. `ga` keymap shows adapter picker → model picker (both working)
3. MCP lean proxy tools (`mcphub_list_servers`, `mcphub_list_tools`, `mcphub_call_tool`) visible in chat
4. No `strategies` blocks remaining in either file
5. `form_tools` override active in `my_codecompanion_utils.lua`

## Verification

### How to verify

Start Neovim with worktree profile, open any file, and test the CodeCompanion chat flow.

### Commands

```bash
NVIM_APPNAME=nvimwt3a nvim
```

```vim
" Open chat & press ga to test adapter/model picker
:CodeCompanion chat
" Then press ga in the chat buffer
```

### Checklist

- [ ] `ga` shows adapter picker with multiple adapters
- [ ] After selecting an adapter, model picker appears (not silently skipped)
- [ ] `mcphub_list_servers` tool is available in chat (type `@mcp_lean` or check `/tools`)
- [ ] No Lua errors on `:Lazy load` or chat buffer creation
- [ ] `form_tools` does not error when MCP tool count < 128

## References

- [Upstream change_adapter.lua](~/.local/share/nvimwt3a/lazy/codecompanion.nvim/lua/codecompanion/interactions/chat/keymaps/change_adapter.lua) — shows `show_model_choices` check at line 52
- [Upstream config defaults](~/.local/share/nvimwt3a/lazy/codecompanion.nvim/lua/codecompanion/config.lua:1094) — `action_palette` provider config
- [docs/memory/codecompanion-v19-migration.md](docs/memory/codecompanion-v19-migration.md) (if exists)
- [Main worktree myCodecomp.lua](file:///Users/tharutaipree/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/extra/myCodecomp.lua)
