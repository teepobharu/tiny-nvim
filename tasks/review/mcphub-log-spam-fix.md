---
title: "Fix MCPHub excessive log spam freezing Neovim UI"
status: review
priority: high
created: 2026-04-23
updated: 2026-04-23
related:
  - [Multi-profile port conflict task](tasks/open/mcphub-multi-profile-port-conflict.md)
  - [MCPHub config](lua/plugins/extra/myAi.lua)
  - [MCPHub memory doc](docs/memory/mcphub.md)
  - [Patch file](patches/mcphub.nvim/03-log-dedup-throttle.patch)
refs:
  - 163b3ad [v6.2.0] @2025-07-31 chore(release): v6.2.0
---

## Objective

Stop bursts of identical "'Unknown' client disconnected from MCP HUB" log
messages from flooding the MCPHub state and freezing Neovim's UI at startup.

## Root Cause

Three compounding issues:

1. **Trigger**: Multi-profile port conflict (or any bulk SSE reconnect) causes
   the mcp-hub Node.js process to emit one `LOG` SSE event per disconnecting
   client — 30-40 events within milliseconds, all with identical text.

2. **No dedup/throttle**: Every `LOG` SSE event goes straight to
   `State:add_server_output()` → `notify_subscribers()` synchronously,
   queuing 40 `vim.schedule` callbacks into Neovim's event loop.

3. **`log.level = WARN` had no effect on SSE stream**: The config option only
   filtered `vim.notify` calls; INFO-level server events still populated state
   and triggered UI redraws regardless.

## Fix: Patch `03-log-dedup-throttle.patch`

Three cooperating changes applied to `lua/mcphub/`:

### 1. `state.lua` — Dedup + Debounce

- **Dedup**: Consecutive identical messages (same `type` + `message`, within 2 s)
  collapse into one entry with `count` incremented. No extra table insert, no
  extra notify.
- **Debounce**: All notify calls are deferred 50 ms via `vim.uv.new_timer()`.
  Rapid bursts produce **exactly one** UI refresh 50 ms after the last message.

### 2. `handlers.lua` — SSE Level Filter

- Server log events below `State.config.log.level` are dropped before reaching
  state. With `log.level = WARN` (already configured in `myAi.lua`), INFO-level
  "client disconnected" events are discarded entirely — zero entries, zero renders.
- Errors bypass the filter (always stored).

### 3. `renderer.lua` — Count Badge

- Log entries with `count > 1` display ` ×N` suffix (muted highlight) so the
  user can see how many messages were collapsed rather than losing them silently.

## Files Changed

| File | Change |
|------|--------|
| `patches/mcphub.nvim/03-log-dedup-throttle.patch` | New patch file |
| _(no config changes needed — `log.level = WARN` already set)_ | — |

## Verification

### How to verify

Apply the patch and restart Neovim in the worktree profile. Trigger the
condition that causes log spam (open a second profile or just observe startup).
Check the MCPHub Logs tab.

### Commands

```bash
# Apply patch (lazy-local-patcher picks this up automatically on next startup)
# Or apply manually to inspect:
cd ~/.local/share/nvimwt3a/lazy/mcphub.nvim
patch --dry-run -p1 < ~/dotfiles/.config/nvimwt3a/patches/mcphub.nvim/03-log-dedup-throttle.patch
```

```bash
# Start worktree profile
NVIM_APPNAME=nvimwt3a nvim
```

```vim
" Open MCPHub and go to Logs tab
:MCPHub
" Press L to switch to Logs tab (or navigate there)
```

```bash
# To trigger the disconnect burst deliberately (in a second terminal):
NVIM_APPNAME=nvim3_jelly_tinynvim nvim
" :MCPHub in the second instance — this triggers a port-conflict hard-restart
```

### Passive check — how to know it's working

Look at the Logs tab in `:MCPHub` after startup:

- **Before patch**: 30-40 individual lines of `'Unknown' client disconnected from MCP HUB`
- **After patch (level filter active)**: Zero lines — INFO events never reach state with `log.level = WARN`
- **After patch (level filter bypassed, e.g. `log.level = INFO`)**: One single line:
  `'Unknown' client disconnected from MCP HUB ×39`

The `×N` badge confirms dedup fired. Absence of any frozen/stutter UI during
startup is the main success signal.

To observe the 50 ms debounce in action, enable Lua profiling or add a
`print(vim.loop.now())` call inside `notify_subscribers` before and after the
patch — you'll see dozens of timestamps collapsing to one.

### Checklist

- [ ] No UI freeze or stutter when starting Neovim
- [ ] No freeze when opening `:MCPHub` in a second profile while another is running
- [ ] MCPHub Logs tab shows at most 1-2 "client disconnected" entries (not 30-40)
- [ ] If any disconnects appear, they show `×N` count badge when collapsed
- [ ] WARN/ERROR messages still appear normally in Logs tab
- [ ] No Lua errors in `:messages` related to `_log_notify_timer`
- [ ] MCPHub tools still work in CodeCompanion after patch

## Notes

- The underlying trigger (multi-profile port conflict) is separately tracked in
  `tasks/open/mcphub-multi-profile-port-conflict.md`. That fix prevents the
  burst from happening; this patch makes the burst harmless if it does happen.
- Both fixes are complementary and should both eventually land.
- Upstream: consider filing a bug report on ravitemer/mcphub.nvim for the
  missing SSE level filter and the dedup behaviour.
