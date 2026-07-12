---
title: "MCPHub multi-profile port conflict causes SIGTERM and bulk disconnects"
status: open
priority: high
created: 2026-03-25
updated: 2026-07-02
related:
  - [MCPHub config](lua/plugins/extra/myAi.lua)
  - [MCPHub memory doc](docs/memory/mcphub.md)
  - [MCPHub integration task](tasks/review/mcphub_integration.md)
  - "Shared server config: ~/dotfiles/ai/mcp/mcphub.json"
---

## Objective

Fix MCPHub port conflicts when two Neovim profiles (main `nvim3_jelly_tinynvim` and worktree `nvimwt3a`) are open simultaneously, causing SIGTERM shutdowns, bulk client disconnects, and stale error states in the UI.


##  Other possible cause and work around by user observation?

1. Some msg when mcphub version mismatch when open in diff profile
- use same version

2. quit nvim and reopen + restart 


## Context

### Current Status (2026-05-21)

The exact main-vs-worktree fixed-workspace-port conflict below has been
partially mitigated in [myAi.lua](lua/plugins/extra/myAi.lua): main uses global
port `37373`, worktree uses global port `37374`, and worktree workspace mode is
disabled. Main workspace mode still uses fixed workspace port `47474`, so two
main-profile Neovim instances in different workspace config roots can still
force a config mismatch on the same port.

The `Maximum call stack size exceeded` / `'Unknown' client disconnected ×N`
burst is now confirmed as an additional `mcp-hub` endpoint cleanup issue:
`src/mcp/server.js` attaches the same cleanup function to both `res.close` and
`transport.onclose`; cleanup calls `server.close()`, so mass disconnects can
re-enter cleanup. See [MCPHub memory](docs/memory/mcphub.md).
Added [mcp-hub patch 01](external-patches/mcp-hub/01-idempotent-endpoint-cleanup.patch)
to make endpoint cleanup idempotent for both `/mcp` and `/mcp-lean`.

Also confirmed: `mcphub.nvim` v6.2.0 accepted local `mcp-hub` `4.2.1` during
setup, then treated the same running hub as a mismatch during `check_server()`
because the health check used exact equality against required string `4.2.0`.
The compatible health-version check now lives in [grouped hub stability patch 02](patches/mcphub.nvim/02-hub-stability_v1.patch).
to reuse the existing semver-compatible validator.

### Historical Config (`myAi.lua:256-274`, identical in both profiles)

```lua
opts = {
  port = 37373,
  workspace = {
    enabled = true,
    look_for = { ".mcphub/servers.json" },
    port_range = { min = 40000, max = 41000 },
    get_port = function()
      return 47474  -- PROBLEM: hardcoded same port for both profiles
    end,
  },
}
```

Both profiles share the same `myAi.lua` (symlinked via worktree), so `get_port()` always returns `47474`.

### Root Cause

When profile A is running mcp-hub on port 47474 and profile B opens `:MCPHub`:

1. Profile B calls `check_server()` on port 47474 — finds existing mcp-hub
2. Config comparison detects **different config files** (profile B's `.mcphub/servers.json` resolves to a different CWD path)
3. Profile B calls `handle_same_port_different_config()` → sends `POST /api/hard-restart` to port 47474
4. Profile A's mcp-hub receives hard-restart → sends **SIGTERM** to itself
5. All connected SSE clients (profile A's Neovim, CLI agents like OpenCode) get bulk-disconnected
6. Profile B starts a new mcp-hub on 47474, but profile A's UI shows stale "Hard restart failed" error

## Observed Error Cases

### Case 1: SIGTERM Bulk Restart

- **Trigger**: Open MCPHub UI in profile B while profile A is running
- **Symptom**: Profile A's mcp-hub receives SIGTERM, all servers disconnect, all clients drop
- **Logs**:
  ```
  [19:52:10] Received SIGTERM signal - initiating graceful shutdown
  [19:52:10] Stopping HTTP server and closing all connections
  [19:52:10] 'atlassian' transport closed
  [19:52:10] 'gitlab_mr' transport closed
  [19:52:10] 'gitlab_proj' transport closed
  ```
- **UI**: Profile A shows "Stopped" with no auto-recovery

### Case 2: Excessive Client Disconnect Logs

- **Trigger**: Same as Case 1
- **Symptom**: 7x `'claude-code' client disconnected from MCP HUB` log spam
- **Cause**: Each OpenCode SSE connection is a separate client; all drop simultaneously when mcp-hub is killed

### Case 3: SSE Connection Failed (code 56)

- **Trigger**: Hard Refresh (`R`) after the server has been killed
- **Symptom**: `SSE connection failed with code 56` then shows `○ Stopped`
- **Cause**: curl error 56 = connection reset — profile A's nvim tries to reconnect SSE to a port whose mcp-hub was killed and replaced by profile B

### Case 4: Hard Restart Failed (exit code 7)

- **Trigger**: Profile A tries to hard-restart after its mcp-hub was killed
- **Symptom**: `curl error exit_code=7 stderr="Couldn't connect to server"` on port 37373
- **Cause**: Profile A falls back to base port 37373 but nothing is listening there (workspace mode bypasses it). The mcp-hub on 47474 now belongs to profile B.

## Key Source Code References

| Logic | File | Lines |
|-------|------|-------|
| Startup / port check | `mcphub.nvim/lua/mcphub/hub.lua` | 312-388 |
| Workspace port resolution | Same | 115-141 |
| Config mismatch → hard-restart | Same | 1326-1342 |
| SSE lifecycle | Same | 1199-1274 |
| Workspace cache lookup | `mcphub/utils/workspace.lua` | 186-210 |
| Plugin source | `~/.local/share/nvim3_jelly_tinynvim/lazy/mcphub.nvim/` | — |

## Implementation Plan

### Fix: Per-profile workspace ports using NVIM_APPNAME

Change `get_port()` in `lua/plugins/extra/myAi.lua` to derive a unique port per profile:

```lua
get_port = function()
  local appname = vim.env.NVIM_APPNAME or "nvim"
  if appname:find("nvimwt") then
    return 47475  -- worktree profile
  end
  return 47474    -- main profile
end,
```

- Both profiles can run simultaneously without conflict
- Each has a predictable fixed port for CLI agent access
- Workspace mode stays enabled (`.mcphub/servers.json` still works)

### Alternative Options Considered

**Option B: Disable workspace mode entirely**
```lua
workspace = { enabled = false }
```
- Single port 37373 for everything, but `.mcphub/servers.json` per-workspace customization lost
- Two profiles on same port 37373 would still share gracefully IF configs match (same `mcphub.json`, no workspace config diff)

**Option C: Remove get_port, use hash-based ports**
```lua
-- get_port removed → mcphub.nvim generates port from CWD hash
```
- Each CWD gets unique port automatically, but CLI agents can't predict the port

### Cleanup: Legacy flags in mcphub.json

Servers still using `USE_PIPELINE`/`USE_GITLAB_WIKI`/`USE_MILESTONE` alongside `GITLAB_TOOLSETS`:
- [x] `gitlab_mr`: Fixed — removed legacy flags, added `pipelines` to toolset
- [ ] `gitlab_proj`: Has `USE_GITLAB_WIKI`, `USE_MILESTONE`, `USE_PIPELINE` (all false) — remove them
- [ ] `gitlab_upload`: Same pattern (disabled server, low priority)
- [ ] `gitlab_localupload`: Same pattern (disabled server, low priority)

## Action Items

- [ ] Confirm the current profile/port behavior against `nvim3_jelly_tinynvim` and `nvimwt3a`.
- [ ] Remove remaining legacy GitLab flags from `~/dotfiles/ai/mcp/mcphub.json` if they still exist.
- [ ] Decide whether main workspace mode should keep fixed port `47474` or use per-profile workspace ports.
- [ ] Update [mcphub memory](docs/memory/mcphub.md) after the final port strategy is verified.

## Points to Confirm

- [ ] Confirm whether multiple main-profile Neovim instances with different CWDs must be supported.
- [ ] Confirm which ports should be reserved for CLI agents: `37373/37374`, `47474/47475`, or another pair.
- [ ] Confirm whether workspace mode is still required for the daily-driver profile.

## Success Criteria

- Two Neovim profiles can open `:MCPHub` simultaneously without killing each other
- No SIGTERM or bulk client disconnect when second profile opens
- CLI agents maintain stable SSE connections when multiple profiles are active
- No `GITLAB_TOOLSETS` legacy flag warnings in startup logs

## Verification

### How to verify

Open two terminal sessions, start both profiles, open MCPHub in each.

### Commands

```bash
# Terminal 1: main profile
NVIM_APPNAME=nvim3_jelly_tinynvim nvim
# :MCPHub → wait for servers to start

# Terminal 2: worktree profile
NVIM_APPNAME=nvimwt3a nvim
# :MCPHub → wait for servers to start

# Terminal 3: check both ports
lsof -i :47474 -i :47475
curl http://localhost:47474/health
curl http://localhost:47475/health
```

### Checklist

- [ ] Profile A's MCPHub stays running when profile B opens MCPHub
- [ ] No SIGTERM in profile A's MCPHub logs
- [ ] No bulk `client disconnected` log spam
- [ ] SSE connections remain stable (no code 56 errors)
- [ ] Hard Refresh (`R`) works in both profiles independently
- [ ] CLI agents connected to profile A remain connected after profile B starts
- [ ] No `GITLAB_TOOLSETS` legacy flag warnings in startup logs

## References

- MCPHub plugin source: `~/.local/share/nvim3_jelly_tinynvim/lazy/mcphub.nvim/`
- [MCPHub docs](https://ravitemer.github.io/mcphub.nvim/)
- [Worktree testing guide](docs/memory/nvim-worktree-testing.md)
