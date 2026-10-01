---
title: "Keep MCPHub startup dashboard stable and expose early server status"
status: review
priority: medium
created: 2026-09-11
updated: 2026-09-26
refs:
  - mcphub.nvim lazy checkout `7cd5db3` (main profile), `163b3ad` (nvimwt3a profile)
related:
  - [Patch catalog](patches/mcphub.nvim/README.md)
  - [Consolidated main UI patch](patches/mcphub.nvim/03-main-ui_v3.patch)
  - [MCPHub config](lua/plugins/extra/myAi.lua)
  - [MCPHub memory](docs/memory/mcphub.md)
  - [Startup non-blocking UI task](tasks/open/mcphub-startup-slack-auth-async-ui.md)
  - [03 main UI reconciliation](tasks/review/reconcile-mcphub-03-main-ui-patch.md)
---

## Objective

During MCPHub initial load (including `setup_state = in_progress` and hub state
before `READY`/`RESTARTED`), the `:MCPHub` main view should remain the server
dashboard. Logs belong to `L`, so the main layout does not switch or shift as
entries stream. A fixed state row should say what is still pending, while server
rows and tool counts appear as soon as the backend exposes each connection,
without waiting for all configured servers or global `READY`. The codex CLI
Agents row should still expose the dotfiles catalog file so the mapping source
of truth is reachable from the UI.

## Context

`MainView:render()` in `lua/mcphub/ui/views/main.lua` returned early in the
`should_show_logs()` branch, so every non-`READY` state replaced the dashboard
with header + log entries + hub errors + active workspaces. It also let each
startup log redraw the main view.

Changed server snapshots still took the generic `UI:render()` path, which used
`switch_view(current_view)`. That treated a state refresh as a view transition:
it ran the current view's leave/enter hooks, rebuilt mappings and cursor
handlers, and restored only a physical line number after a new server row
shifted the layout.

The backend HTTP server exposes `GET /api/health` while it is still starting.
`startConfiguredServers()` inserts every `MCPConnection` into its connection
map before awaiting the aggregate startup promise, and the health route returns
each connection's current status/capabilities. The client can therefore obtain
real partial rows before the later `READY` SSE event, without forcing a
capability refresh or changing backend readiness.

Neither panel actually requires hub readiness:

- `render_endpoints` only needs the hub port (falls back to `37373`) and uses
  `is_ready()` for the green/red dot only.
- `render_agent_registry` shells out to each CLI via
  [lua/utils/mcphub_agents.lua](lua/utils/mcphub_agents.lua) (async, hub-independent).

The codex `mcph` mapping source of truth is
`~/dotfiles/ai/codex/config.ag-mcp.toml`, merged into the runtime
`~/.codex/config.toml` by `~/dotfiles/ai/codex/sync-agoda-mcp.sh` (append-only).
The main codex base config deliberately has no `[mcp_servers]` tables, so the
catalog file - not the base config - is the correct source to expose.

## Implementation

- [x] Replace the startup logs branch in `MainView:render()` with the normal
      dashboard path, shipped as
      [patches/mcphub.nvim/03-main-ui_v3.patch](patches/mcphub.nvim/03-main-ui_v3.patch).
- [x] Keep that dashboard shell during setup progress, with a fixed state row
      and a `Waiting for server status...` placeholder until a server snapshot
      exists; setup failure and the not-started welcome screen remain distinct.
- [x] Restrict log and server-output notifications to the `L` view, preventing
      streaming logs from redrawing the startup dashboard.
- [x] On UI open, call `GET /api/health` immediately and then at most 30 times
      at 500 ms, one request at a time. Retry through the asynchronous
      `State.hub_instance` handoff and perform one read around `READY`, whose
      event can precede its regular server update. A changed read, or the first
      successful read per probe generation, schedules an in-place redraw even
      when state already matches; a generation guard cancels stale retries
      after close/context change.
- [x] Coalesce a burst of changed state into one scheduled in-place redraw.
      Once shown, `UI:render()` draws the active view directly instead of
      re-entering it through `switch_view(current_view)`, so a refresh cannot
      run leave/enter hooks or recreate its mappings.
- [x] Preserve the selected main-view row by semantic identity across redraws:
      server, section, endpoint, workspace, instructions, and agent rows keep
      their cursor position after a snapshot inserts or reorders lines; a
      vanished row retains the existing numeric fallback.
- [x] Validate the revised patch in a clean `163b3ad` stack; no active profile
      cache or user-owned dirty state was modified.
- [ ] Sync the revised patch into the user-owned `nvimwt3a` configuration
      worktree when it is next rebased/updated, preserving its separate local
      state.
- [x] Add codex config alternate `2` (label `dg_mcp`,
      `~/dotfiles/ai/codex/config.ag-mcp.toml`, matcher `.mcp_servers`) to the
      codex agent entry in [lua/plugins/extra/myAi.lua](lua/plugins/extra/myAi.lua).
- [x] Update [patches/mcphub.nvim/README.md](patches/mcphub.nvim/README.md)
      application order and add the v2 section (kept identical in both profiles).
- [x] Document initial-load view and codex mapping source in
      [docs/memory/mcphub.md](docs/memory/mcphub.md).

## Success Criteria

- Opening `:MCPHub` during setup or a fresh hub startup keeps the MCP Servers,
  Endpoints, CLI Agents, and workspace dashboard visible, with one stable
  `Starting...`/pending-state row; logs appear only after `L`.
- A fast server's connected row and tool count can appear from a health snapshot
  while another configured server is still connecting and the hub has not
  emitted `READY`; `l` expands the row to its tool names.
- Log entries do not redraw or move the main dashboard. A changed startup health
  response, or the first successful response in a probe generation, redraws it
  in place even when unchanged, so a missed state notification cannot leave the
  waiting placeholder indefinitely or cause 500 ms redraw churn.
- Changed server/setup snapshots redraw once in place: they do not run the
  active view's leave/enter lifecycle, and a selected server/section/endpoint
  stays selected when its physical line moves.
- Agent binding rows remain actionable during startup (`t`/`d`/`e`/`R`/alternate
  config keys still dispatch on `agent_binding` lines).
- The normal `READY` view is unchanged.
- On the codex row, key `2` opens the dotfiles catalog at the `.mcp_servers`
  section and key `1` still opens the runtime config.

## Verification

### How to verify

Restart the hub so the next `:MCPHub` open goes through a real initial load
(the hub process owned by the previous Neovim is enough - quit that Neovim and
wait for auto-shutdown, or kill the node process). Then open `:MCPHub` in the
main profile and watch the first second or two of startup.

### Commands

```bash
# Which hub is running (stop/restart it only when you are ready for a cold test)
lsof -nP -iTCP:37373 -sTCP:LISTEN

NVIM_APPNAME=nvim3_jelly_tinynvim nvim
```

```vim
:MCPHub
```

### Checklist

- [ ] During setup and the startup window, the main view contains no server log
      entries; `L` shows those same entries. A `Starting...` state row explains
      pending work while the server, Endpoints, and CLI Agents sections remain
      in one stable layout.
- [ ] Open `:MCPHub` before the hub instance has been created and do not press
      any key. When the hub starts, the waiting placeholder automatically
      changes to server rows; it does not require closing/reopening the UI.
- [ ] With one intentionally slow server, a faster server's connected row/tool
      count appears before global `READY`; the slow row remains independently
      connecting/failed/unauthorized as reported by the backend.
- [ ] After the hub becomes ready, the same dashboard sections remain without
      duplication or a layout swap.
- [ ] Keep the cursor on a server, section, endpoint, or agent row while a
      startup snapshot adds or reorders rows. The same semantic item remains
      selected, its normal mappings still work, and the MCPHub window stays
      open rather than briefly blanking or closing.
- [ ] CLI Agents rows still respond to `t` (toggle), `e` (config), `R`
      (refresh) during the startup window.
- [ ] On the codex row, pressing `2` opens
      `~/dotfiles/ai/codex/config.ag-mcp.toml` positioned at `[mcp_servers]`;
      `1` still opens `~/.codex/config.toml`.
- [ ] No new Lua errors in `:messages` during startup.

### Already verified by agent (2026-09-13)

- Fresh sequential patch apply from clean `163b3ad`: `01 -> 02 -> 03_v1 ->
  03_v2 -> 04 -> 05 -> 06 -> 07` all apply, `luac -p` passes,
  `git diff --check` passes.
- Focused `NVIM_APPNAME=nvimwt3a` headless smoke: setup progress rendered the
  dashboard shell, state row, empty-server placeholder, Endpoints, and CLI
  Agents; a later health snapshot supplied a connected server/tool count before
  `READY`, a fake log was absent from the main buffer, and a logs-only state
  update did not redraw that buffer. Result: PASS.
- No live external hub or agent CLI listing was used. The main-profile source
  matches the revision, while the interactive checklist remains user-owned
  verification.

### Addendum verified by agent (2026-09-26)

- Fresh sequential patch apply from clean `163b3ad`: `01 -> 02 -> 03_v1 ->
  03_v2 -> 04 -> 05 -> 06 -> 07 -> 08 -> 09 -> 10` passed, followed by
  `git diff --check` and Lua parsing of the changed UI views.
- Focused isolated headless redraw smoke: a selected server anchor moved from
  its old physical line to its new one; a shown UI rendered exactly once
  without leave/enter hooks; two same-turn state notifications produced one
  redraw. Result: PASS.
- No live MCP hub, external agent CLI, or active Neovim profile cache was
  modified. The interactive checklist remains user-owned verification.

### Startup handoff follow-up verified by agent (2026-09-26)

- Focused isolated headless smoke covered an initial missing hub instance, the
  deferred retry after creation, a health read while the hub already reports
  ready, and an unchanged successful response. It verified that the response
  updates state when needed and schedules one in-place redraw per unchanged
  probe generation rather than on every retry. Result:
  PASS.
- The active Neovim profile cache was not changed; a real cold-start run remains
  user-owned verification.

## References

- [Revised main UI patch](patches/mcphub.nvim/03-main-ui_v3.patch)
- [Agent registry helper](lua/utils/mcphub_agents.lua)
- Codex MCP catalog: `~/dotfiles/ai/codex/config.ag-mcp.toml`
- Codex MCP sync script: `~/dotfiles/ai/codex/sync-agoda-mcp.sh`
