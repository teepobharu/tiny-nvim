---
title: "Investigate MCPHub UI stuck on Starting... or showing 'No servers found'"
status: open
priority: medium
created: 2026-01-13
updated: 2026-01-13
refs:
  - mcphub.nvim 6.2.0
  - mcp-hub fork at ~/projects/mcp-hub
related:
  - [MCPHub Memory Doc](docs/memory/mcphub.md)
  - [myAi.lua config](lua/plugins/extra/myAi.lua)
  - [mcphub.json](~/dotfiles/ai/mcp/mcphub.json)
  - [Log dedup patch](patches/mcphub.nvim/03-log-dedup-throttle.patch)
  - [Compatible health version patch](patches/mcphub.nvim/06-compatible-health-version-check.patch)
  - [Hard restart confirm patch](patches/mcphub.nvim/07-confirm-hard-restart.patch)
---

## Objective

Investigate why the `:MCPHub` UI sometimes gets stuck showing `Starting...` without listing any servers, or shows "No servers found in `/Users/tharutaipree/dotfiles/ai/mcp/mcphub.json`".

## Confirmed Evidence (2026-01-13)

### Backend state — healthy, 42 servers loaded

- `curl -s http://localhost:37373/api/health` returns `state=ready, version=4.2.1, clients=1`
- `/api/health` contains **42 servers** in the response (`servers` array): 14 connected, 22 disabled, 5 unauthorized, 1 disconnected
- The `pi-mcph-bridge` is counted as **1 active client** by the hub
- SSE events stream correctly from `/api/events` — `log` events with debug/info levels flow through

### Renderer root cause — "No servers found" is a `config_source` filter, not an empty servers array

- `renderer.lua:268` `render_servers_grouped()` iterates `config_manager.get_active_config_files(true)` to get config source paths
- For each config source, it filters `servers` by `s.config_source == config_source` (line 274)
- If the filtered group is empty (`#sorted == 0`), it renders "No servers found in `mcphub.json`" (line 353)
- **This means the servers array IS populated, but none have `config_source` matching the active config file path** — the server objects from the hub API are missing or have a different `config_source` field than what `config_manager.get_active_config_files()` returns

### UI render flow — no race condition, but state depends on SSE or explicit refresh

- Initial state: `server_state.servers = {}`, `state = HubState.STARTING` (state.lua:53)
- `handle_hub_ready()` (hub.lua:593) calls `update_servers()` which calls `get_health()` and populates `server_state.servers` from the `/api/health` response
- SSE event `HUB_STATE` → `READY` triggers `handle_hub_ready()` → `update_servers()` → `fire_servers_updated()` → UI re-render
- The UI renders `State.server_state.servers` directly (main.lua:2222), so the list is empty only during the STARTING phase or if `update_servers()` hasn't been called yet

### pi-mcph-bridge reconnect behavior — designed to be transient, not a loop

- `index.ts:696-697`: On `session_start`, if AUTOCONNECT (default "1") and no active client, calls `ensureConnected("lean")` once
- `index.ts:290-298`: Auto-refresh runs every 60s (default), calls `refresh()` which calls `ensureConnected(target, true, false)` — force reconnect every minute
- `RetirableClientSlot` (client-lifecycle.ts): On `adopt()`, retires the previous client, which closes it when `inFlight === 0`
- `ensureConnected()` (index.ts:467): Creates a new `SSEClientTransport` + `Client`, connects, lists tools, then `clients.adopt()` replaces the old one
- **Each auto-refresh (every 60s) and each `/mcph` command creates a brand new SSE connection and closes the old one** — this produces exactly the "connected → disconnected → connected" log pattern seen
- The bridge name in logs is `pi-mcph-bridge` with version `0.3.0` (index.ts:437)

### Why the UI shows "Starting..." without servers

**Confirmed mechanism:**

1. PI's bridge auto-refreshes every 60s by calling `ensureConnected(target, true, false)` with `force=true`
2. `ensureConnected()` closes the old client (`closeClient()`) then creates a new SSE connection
3. The `closeClient()` triggers an SSE disconnect event from the hub
4. The new connection immediately reconnects → SSE connect event
5. This cycle produces pairs of `pi-mcph-bridge connected` + `Unknown client disconnected` logs
6. **But the Neovim UI is NOT the pi-mcph-bridge** — the UI connects via its own SSE handler (hub.lua:1421 `connect_sse()`)
7. The "No servers found" message means `config_source` mismatch, not missing servers
8. The "Starting..." stuck state means `HubState` hasn't transitioned to READY yet — this happens when the hub was just started or the SSE event for READY hasn't been received

### Open questions — not yet confirmed

- Does `config_manager.get_active_config_files()` return a different path than the `config_source` field in server objects from the hub API?
- Does the pi-mcph-bridge reconnect every 60s cause the Neovim UI SSE to drop momentarily?
- Is there a timing window where `update_servers()` hasn't been called but the UI has already rendered?

Two related symptoms observed in the MCPHub UI (`:MCPHub`):

### Symptom 1: Stuck on "Starting..."

The UI renders the top bar and log area, but the server list never populates. Log shows:

```
◉ Starting...
[22:49:39] 'pi-mcph-bridge' client connected to MCP HUB (lean)
[22:49:39] 'Unknown' client disconnected from MCP HUB (lean)
(repeats 15-20 times)
[22:49:39] 'grafana' MCP server connected
[22:49:39] 'graphify_catalog' MCP server connected
[22:49:39] 'superset' MCP server connected
[22:49:39] 'outlook-meetings' MCP server connected
(more pi-mcph-bridge connect/disconnect cycles)
```

The `pi-mcph-bridge` (PI's MCPHub bridge extension) is rapidly connecting and disconnecting from the `/mcp-lean` endpoint, while some servers do report "connected". Yet the server list section in the UI remains empty or stuck.

### Symptom 2: "No servers found"

At other times the UI fully renders but shows:

```
▼ Global
  No servers found in `/Users/tharutaipree/dotfiles/ai/mcp/mcphub.json` (Install from Marketplace)

▶ Project
  .mcphub/servers.json not in path

▼ Native Servers
  ▶ Neovim ~3.1k ( 10,  0,  4)
  ○ MCPHub
  󰏫 Auto-create Server
```

The Endpoints section correctly shows `/mcp` with 42 servers and `/mcp-lean` with 3 meta-tools, and CLI Agents panel shows agents connected. But the Global section reports zero servers from the config file.

### Known background from memory doc

- `pi-mcph-bridge` is the PI extension that connects PI to MCPHub. It is not managed by `pi mcp ...` CLI commands (PI doesn't expose those). The bridge connects to either `/mcp` or `/mcp-lean`.
- Log dedup patch (`03-log-dedup-throttle.patch`) collapses repeated "Unknown client disconnected" messages, but doesn't address the root cause of why the bridge cycles.
- Hard restart cascades (`06-compatible-health-version-check.patch`, `07-confirm-hard-restart.patch`) can trigger mass disconnects, but the user reports this happening without manual restart.
- mcp-hub uses a forked backend from `~/projects/mcp-hub` with multiple local patches applied.
- The config file at `~/dotfiles/ai/mcp/mcphub.json` has ~40 server entries (many disabled).

## Implementation Plan

### Phase 1 — Confirmed: pi-mcph-bridge reconnect cycle is EXPECTED behavior
- The bridge auto-refreshes every 60s via `ensureConnected(force=true)` which creates a new SSE client and closes the old one
- Each refresh produces 1 connect + 1 disconnect log pair — this is by design, not a bug
- `RETRY_COOLDOWN_MS=5000` limits failed reconnects but successful reconnects have no cooldown
- **Action: Document this in memory doc so future investigations don't chase false positives**

### Phase 2 — Investigate "No servers found" (confirmed: `#sorted == 0` condition)
- [ ] Read `config_manager.get_active_config_files()` to see what paths it returns
- [ ] Compare with the `config_source` field in server objects from `State.server_state.servers`
- [ ] Check if `vim.tbl_filter(function(s) return s.config_source == config_source end, servers)` produces empty results due to path mismatch (e.g., resolved vs unexpanded `~`)
- [ ] Reproduce: open `:MCPHub`, note if Global section is empty — if so, check `State.server_state.servers` for config_source values

### Phase 3 — Investigate "Starting..." stuck state
- [ ] Check if `update_servers()` is called after SSE READY event arrives
- [ ] Check if there's a timing window where the UI renders before `handle_hub_ready()` fires
- [ ] Verify the `fire_servers_updated()` → `notify_subscribers()` chain reaches the UI
- [ ] Check if the pi-mcph-bridge SSE connection count affects the hub's client tracking

## Success Criteria

- `:MCPHub` consistently shows the Global server list with connected/disconnected status for all configured servers
- No prolonged "Starting..." state beyond a few seconds
- "No servers found" message no longer appears when `mcphub.json` has valid server entries
- pi-mcph-bridge connect/disconnect pattern is documented as expected behavior

## Verification

### How to verify

Restart Neovim and open `:MCPHub` multiple times. Wait 5-10 seconds after opening. Check both the Global section and the Logs tab.

### Commands

```bash
# Check if mcp-hub is running and healthy
curl -s http://localhost:37373/health | jq .

# List servers from the backend API
curl -s http://localhost:37373/api/servers | jq '. | keys'

# Check for rapid reconnecting processes
lsof -i :37373
```

```vim
" Open MCPHub UI
:MCPHub

" Check Logs tab for error patterns
" Press L for Logs view
```

### Checklist

- [ ] `:MCPHub` opens and Global section lists servers within 5 seconds
- [ ] Server rows show status (connected/disconnected) with tool counts
- [ ] Logs tab shows at most 1-2 `pi-mcph-bridge` connect events (not 15+)
- [ ] No "Starting..." message persists after 10 seconds
- [ ] "No servers found" message does not appear when `mcphub.json` has servers
- [ ] Pressing `r` (Refresh) reliably updates the server list
- [ ] Issue does not recur after closing and reopening `:MCPHub`

## References

- [mcphub.nvim source](~/.local/share/nvim3_jelly_tinynvim/lazy/mcphub.nvim/)
- [mcp-hub fork](~/projects/mcp-hub/)
- [MCPHub memory doc](docs/memory/mcphub.md) — architecture, troubleshooting, OAuth issues
- [PI MCPHub bridge](~/.pi/agent/npm/node_modules/pi-mcphub-bridge/) — extension that bridges PI to MCPHub