---
title: "MCPHub startup should not block on Slack bridge auth"
status: "open"
priority: "high"
created: 2026-07-03
updated: 2026-07-06
refs:
  - 163b3ad [tag:v6.2.0] chore(release): v6.2.0
related:
  - [MCPHub config](lua/plugins/extra/myAi.lua)
  - [MCPHub memory](docs/memory/mcphub.md)
  - [Main UI patch task](tasks/open/reconcile-mcphub-03-main-ui-patch.md)
  - [MCPHub multi-profile task](tasks/open/mcphub-multi-profile-port-conflict.md)
  - [MCPHub clear auth command](tasks/review/mcphub-clear-auth-command.md)
---

## Objective

Make MCPHub startup observable and non-blocking when one MCP server is slow,
requires authorization, or starts an external auth flow. Specifically, the
Slack official bridge should not open browser/IDE auth popups during initial
`:MCPHub` load, and the MCPHub UI should show server statuses without waiting
for every configured MCP server to finish connecting.

## Handoff Summary

The current behavior is not only a UI redraw issue. The backend marks the hub
ready only after all configured MCP connections have completed startup, and the
Slack bridge starts its own OAuth flow during stdio initialization. This causes:

- `:MCPHub` on a fresh Neovim session to show logs or appear stuck until all
  servers settle.
- Slack bridge OAuth to open a browser auth popup during automatic startup.
  - Sometimes Cursor opens around the same time as Slack auth. The earlier
    "Cursor is the OS handler" hypothesis is not supported by current local
    LaunchServices evidence; see the Cursor validation section below.
- A later Neovim session connected to an already-running MCPHub server to show
  the server UI immediately, because the backend is already in `READY`.

The desired behavior is:

- Initial load shows the server UI/status as soon as the hub HTTP/SSE layer is
  available.
- One slow/auth-required MCP server must not block the whole server list.
- Slack bridge auth should be passive on startup. It should report
  auth-required/fail status.
- User action, likely pressing `l` on the server row, should explicitly start
  the auth step.
- For stdio servers, explicit auth should be config-driven: the server can
  return an auth-required MCP error on startup, MCPHub should render the row as
  unauthorized, and `l` should run a configured `authCommand` instead of relying
  on the bridge to auto-auth during initialize.
- A soft refresh/reconnect key should refresh UI status even while the hub is
  still starting. Current `r` is not that key.

## Investigation Facts

### Local config

- [lua/plugins/extra/myAi.lua](lua/plugins/extra/myAi.lua) configures
  `mcphub.nvim` for this profile.
- The active worktree profile uses global MCPHub config from
  `~/dotfiles/ai/mcp/mcphub.json`.
- In `~/dotfiles/ai/mcp/mcphub.json`, `slack_official_bridge` runs:
  `node ${HOME}/projects/ai/slack-official-mcp-bridge/build/index.js`.
- As of 2026-07-06, `slack_official_bridge` passes
  `SLACK_MCP_BRIDGE_AUTO_AUTH=0`, and its config note says startup is passive.
  This should stop bridge-owned browser auth popups on startup after MCPHub is
  restarted so the new env is inherited.

### Slack auth popup root cause

MCPHub starts every enabled server during hub startup. For stdio servers this
starts the configured command and calls MCP `initialize`.

Relevant upstream/local source references:

- `/Users/tharutaipree/projects/mcp-hub/src/MCPHub.js:46`
  `startConfiguredServers`.
- `/Users/tharutaipree/projects/mcp-hub/src/MCPHub.js:89`
  calls `connection.connect()`.
- `/Users/tharutaipree/projects/mcp-hub/src/MCPHub.js:110`
  awaits all startup promises.
- `/Users/tharutaipree/projects/mcp-hub/src/MCPConnection.js:168-173`
  starts stdio transport and `client.connect`.

The Slack bridge itself starts OAuth during initialize:

- `/Users/tharutaipree/projects/ai/slack-official-mcp-bridge/src/index.ts:12-13`
  comments document auto-auth opening the browser.
- `/Users/tharutaipree/projects/ai/slack-official-mcp-bridge/src/index.ts:54-92`
  `ensureAuth()`.
- `/Users/tharutaipree/projects/ai/slack-official-mcp-bridge/src/index.ts:128-130`
  missing token triggers `ensureAuth()`.
- `/Users/tharutaipree/projects/ai/slack-official-mcp-bridge/src/index.ts:152-158`
  401 forces auto-auth retry.
- `/Users/tharutaipree/projects/ai/slack-official-mcp-bridge/src/oauth.ts:54-75`
  opens the auth URL.
- `/Users/tharutaipree/projects/ai/slack-official-mcp-bridge/src/oauth.ts:205`
  invokes the browser open path.

MCPHub HTTP OAuth behavior is different. MCPHub itself stores an
authorization URL and waits for user action:

- `/Users/tharutaipree/projects/mcp-hub/src/MCPConnection.js:770-778`
  marks HTTP OAuth servers unauthorized and stores auth URL.
- `/Users/tharutaipree/projects/mcp-hub/src/MCPConnection.js:610-620`
  `connection.authorize()` opens auth on demand.
- `~/.local/share/nvimwt3a/lazy/mcphub.nvim/lua/mcphub/ui/views/main.lua:414-422`
  calls authorization from the UI when the user presses `l` on an unauthorized
  row.

No explicit Cursor launch was found in MCPHub or Slack bridge. The Slack bridge
opens `https://slack.com/oauth/v2_user/authorize` through macOS `open <url>`.
Current local evidence does **not** validate the earlier claim that Cursor is
the default URL handler for the Slack auth URL.

### Cursor popup hypothesis validation

Validated on 2026-07-03:

- Slack bridge source:
  - `/Users/tharutaipree/projects/ai/slack-official-mcp-bridge/src/oauth.ts`
    uses `spawn("open", [url])` on macOS.
  - `/Users/tharutaipree/projects/ai/slack-official-mcp-bridge/src/credentials.ts`
    sets `SLACK_AUTH_URL = "https://slack.com/oauth/v2_user/authorize"`.
- MCPHub source:
  - `/Users/tharutaipree/projects/mcp-hub/src/MCPConnection.js` imports the
    `open` package and calls `open(this.authorizationUrl.toString())` only in
    `connection.authorize()`, which is user-triggered for HTTP OAuth servers.
  - No MCPHub source match was found for explicitly launching Cursor.
- macOS LaunchServices:
  - `http` and `https` URL schemes are currently handled by
    `com.microsoft.edgemac`.
  - `slack` URL scheme is currently handled by `com.tinyspeck.slackmacgap`.
  - No `com.todesktop.230313mzl4w4u92` Cursor handler entry was found for
    `http`, `https`, or `slack`.
- Cursor app metadata:
  - `osascript -e 'id of app "Cursor"'` returns
    `com.todesktop.230313mzl4w4u92`.
  - `/Applications/Cursor.app/Contents/Info.plist` registers only the
    `cursor:` URL scheme for Cursor.

Current conclusion:

- The direct cause of the popup is still the Slack bridge auto-auth calling
  macOS `open` during MCP initialization.
- The specific claim that Cursor opens because it is the default handler for
  Slack's `https://...` auth URL is **not validated** on this machine now.
- More likely explanations to test if Cursor still appears:
  - Edge or Slack redirects to a `cursor:` deep link from a browser extension,
    saved tab/session, or local automation.
  - A separate watcher/automation reacts to MCPHub/Slack auth logs and opens
    Cursor.
  - Cursor was already restoring a window/session and the timing made it look
    causally tied to Slack auth.
  - LaunchServices handler state changed between the observed incident and this
    validation.

Follow-up validation if Cursor still opens:

- Capture the exact URL passed to `openBrowser()` before launching it.
- Temporarily replace macOS `open` in the Slack bridge with a logger or a
  passive mode that prints the URL only.
- Run `log stream --predicate 'process == "Cursor" OR process == "open"'` while
  reproducing, then correlate timestamps with Slack bridge stderr.
- Check browser extensions/automation that may handle Slack OAuth redirects.

### Startup blocking root cause

MCPHub starts its HTTP server first, but it does not mark the hub ready until
managed MCP server initialization completes.

Relevant source references:

- `/Users/tharutaipree/projects/mcp-hub/src/server.js:1025-1036`
  HTTP server starts.
- `/Users/tharutaipree/projects/mcp-hub/src/server.js:184`
  awaits `this.mcpHub.initialize()`.
- `/Users/tharutaipree/projects/mcp-hub/src/server.js:185`
  sets `HubState.READY`.
- `/Users/tharutaipree/projects/mcp-hub/src/MCPHub.js:51-58`
  managed servers start in parallel.
- `/Users/tharutaipree/projects/mcp-hub/src/MCPHub.js:109-110`
  startup waits for all server startup promises.
- `/Users/tharutaipree/projects/mcp-hub/src/MCPConnection.js:45-47`
  connect timeout is `5 * 60000`, so a bad server can delay readiness for up to
  five minutes.

The Neovim UI is created asynchronously, but the main view hides the server UI
behind logs until hub state is `READY` or `RESTARTED`:

- `~/.local/share/nvimwt3a/lazy/mcphub.nvim/lua/mcphub/ui/views/main.lua:1112-1133`.

That explains the difference between a fresh hub startup and a later Neovim
session attached to an already-ready hub.

### Refresh/current keys

Current key behavior:

- `r` is not a light UI refresh. It maps to `UI:hard_refresh()`.
- `UI:hard_refresh()` calls `GET /api/refresh`, which refreshes capabilities
  and requires the hub to be ready.
- `R` is full hard restart through `/api/hard-restart`.
- `UI:refresh()` exists and calls `hub:refresh()`, but is not the same as
  current `r`.
- The Neovim client allows `/health` before the hub is ready, but blocks other
  API paths when not ready.
- Backend `/api/health` works while starting and returns `state`, `servers`,
  `workspaces`, and related status fields.
- SSE already exists via `/api/events`; there is event-driven status flow, not
  a polling loop. Installed worktree source did not show a robust automatic SSE
  recovery loop in the current profile.

Relevant source references:

- `~/.local/share/nvimwt3a/lazy/mcphub.nvim/lua/mcphub/ui/init.lua:329-331`
  maps `r` to hard refresh.
- `~/.local/share/nvimwt3a/lazy/mcphub.nvim/lua/mcphub/ui/init.lua:332-334`
  maps `R` to hard restart.
- `~/.local/share/nvimwt3a/lazy/mcphub.nvim/lua/mcphub/ui/init.lua:337-348`
  has unbound `UI:refresh()`.
- `~/.local/share/nvimwt3a/lazy/mcphub.nvim/lua/mcphub/hub.lua:1087-1218`
  API request guard.
- `~/.local/share/nvimwt3a/lazy/mcphub.nvim/lua/mcphub/hub.lua:1153-1163`
  blocks non-health paths before ready.
- `~/.local/share/nvimwt3a/lazy/mcphub.nvim/lua/mcphub/hub.lua:1449-1452`
  `hub:refresh()` status path.
- `~/.local/share/nvimwt3a/lazy/mcphub.nvim/lua/mcphub/hub.lua:1454-1473`
  hard refresh via `/api/refresh`.
- `/Users/tharutaipree/projects/mcp-hub/src/server.js:564-598`
  `/api/health` response.
- `~/.local/share/nvimwt3a/lazy/mcphub.nvim/lua/mcphub/hub.lua:1371-1439`
  SSE subscription.
- `~/.local/share/nvimwt3a/lazy/mcphub.nvim/lua/mcphub/utils/handlers.lua:39-101`
  hub state/server/log handlers.

## Suggested Design

### Backend: decouple hub readiness from MCP server readiness

Change mcp-hub startup so `initialize()` schedules MCP server connections but
does not await all of them before setting the hub to `READY`.

Expected behavior:

- Load config.
- Create `MCPConnection` objects for every configured server immediately.
- Mark disabled servers disabled and enabled servers connecting.
- Emit a status/server update once connection rows exist.
- Start each `connection.connect()` promise in the background.
- Each connection promise catches errors and records final status:
  connected, disconnected, failed, unauthorized, auth-required, or timed out.
- Emit a per-server update as each connection settles.
- Log final summary after `Promise.allSettled`, but do not block hub readiness.

The initial load should behave like later config changes/server enablement:
server rows appear first, individual statuses update as work completes, and no
single MCP blocks the global UI.

### Slack bridge: passive auth mode

Add a passive auth mode to the Slack bridge, for example:

```bash
SLACK_MCP_BRIDGE_AUTO_AUTH=0
```

Expected behavior:

- Missing token returns a quick MCP initialization error or auth-required signal
  without opening a browser.
- 401/expired token returns auth-required status without opening a browser.
- Existing valid token still initializes normally.
- `mcphub.json` sets passive mode for `slack_official_bridge`.

For `l` to trigger stdio auth, MCPHub needs an explicit convention because the
current `l` auth flow is HTTP OAuth-oriented and depends on an
`authorizationUrl`.

Options:

- Add a server config `authCommand`, for example `node .../index.js auth`, and
  have the UI/backend run it when pressing `l` on an auth-required stdio row.
- Or make the Slack bridge expose a known MCP method/tool for auth and teach
  MCPHub to call it from the row action.
- Or make the bridge output a structured auth-required error that MCPHub maps to
  `unauthorized` plus an action descriptor.

### Neovim UI: show status before ready

Use `GET /health` for status refresh while the hub is starting. Do not call
`/api/refresh` before ready.

Suggested key behavior:

- Keep `r` as current hard capability refresh to avoid changing existing
  semantics.
- Add `<C-r>` as a soft status refresh / SSE reconnect candidate.
- `<C-r>` should call health/status refresh and redraw the main UI even when the
  hub is not ready.
- `<C-r>` should not perform hard restart or backend capability reload.
- If the UI is in logs view because hub state is starting, `<C-r>` should switch
  or redraw into main status view when health has server rows.

Benefit of showing UI first:

- It gives visibility into which server is connecting, failed, or requires auth.
- It does not make MCP tools available before their server connects.
- It is only useful if rows and statuses are real; an empty dashboard without
  per-server status would not solve the issue.

## Implementation Plan

### Refined rollout order

1. **Slack bridge passive auth first.**
   This is the highest-impact and least-coupled slice. It stops browser/Cursor
   popups regardless of whether the later MCPHub async startup refactor is
   complete. Own this in the Slack bridge repo first, then wire the env in
   `mcphub.json`.
2. **MCPHub backend async startup second.**
   Backend readiness currently blocks the UI from having useful state. Change
   backend initialization to create server records and emit/update status before
   individual MCP connections settle.
3. **Neovim UI/status refresh third.**
   Once backend exposes useful startup state, update the main view and add a
   pre-ready-safe soft refresh key. A frontend-only change before backend state
   exists may improve redraw behavior but will not fully solve the blocking
   model.
4. **Manual stdio auth action last or alongside UI work.**
   Pressing `l` for stdio Slack auth needs an explicit contract
   (`authCommand`, action metadata, or a bridge subcommand). Do not overload the
   existing HTTP OAuth `authorizationUrl` path without a clear server type/action
   distinction.

### Slice 1: Slack bridge passive auth

- [ ] Add passive auth support in
      `/Users/tharutaipree/projects/ai/slack-official-mcp-bridge`.
  - Suggested env: `SLACK_MCP_BRIDGE_AUTO_AUTH=0`.
  - Missing token should return a quick JSON-RPC error with an auth-required
    message and **must not** call `runOAuthFlow()`.
  - 401/expired token should return auth-required without forced auto-auth when
    passive mode is enabled.
  - Existing `auth` subcommand should continue to run PKCE OAuth and save the
    token.
  - Existing valid-token startup should continue to proxy `initialize`.
- [ ] Build or typecheck the bridge with `npm run build`.
- [x] Configure `slack_official_bridge` in `~/dotfiles/ai/mcp/mcphub.json` to
      pass `SLACK_MCP_BRIDGE_AUTO_AUTH=0`.
- [x] Update the `slack_official_bridge` config note so it says startup is
      passive and manual auth is `node .../build/index.js auth`.

### Slice 2: Cursor validation if popup persists

- [ ] If Cursor still opens after passive auth is enabled, run the Cursor
      follow-up validation commands and capture the exact launch chain before
      attributing it to URL handler state.

### Slice 3: Backend async startup

- [ ] Change mcp-hub startup to create server rows and schedule connections
      without awaiting every connection before `READY`.
- [ ] Ensure `/api/health` returns useful per-server status during startup.
- [ ] Emit server status events as each startup connection settles.
- [ ] Preserve the existing all-server startup summary log, but generate it from
      a background `Promise.allSettled` path instead of blocking readiness.

### Slice 4: Neovim UI and refresh

- [ ] Update `mcphub.nvim` main view so `STARTING` can render known server rows
      instead of logs-only.
- [ ] Add `<C-r>` as soft status refresh / SSE reconnect, keeping `r` as hard
      capability refresh and `R` as hard restart.
- [x] Add a deliberate user-triggered auth action for stdio auth-required rows,
      ideally reusing `l` only when the row exposes an explicit stdio auth
      action.
- [x] Add config-driven `authCommand` support for `slack_official_bridge` so a
      passive auth-required startup error can render as unauthorized and `l`
      can start auth on demand.
- [x] Reconnect the stdio server automatically after the manual auth command
      exits successfully, and broadcast `SERVERS_UPDATED` so the UI can redraw
      without a server toggle.
- [x] Decide whether any UI changes belong in the existing
      [03 main UI patch](patches/mcphub.nvim/03-main-ui_v1.patch) or a new patch.
- [x] Update [docs/memory/mcphub.md](docs/memory/mcphub.md) for stdio
      `authCommand` / on-demand Slack auth behavior.
- [ ] Update [docs/memory/mcphub.md](docs/memory/mcphub.md) after the async
      startup/status behavior is implemented and verified.

### Worker delegation state

- Worker 1 (`Schrodinger`, agent id `019f247d-8aaa-70a2-aad8-8507ddd7274a`)
  was delegated on 2026-07-03 to own only the Slack bridge passive-auth slice
  and avoid editing MCPHub backend/UI files.
- Worker 1 completed the bridge implementation on 2026-07-03. Main-agent review
  reran `npm run build`, passive missing-token smoke, passive no-token
  non-initialize smoke, mocked valid-token `initialize`, mocked passive 401
  `initialize`, and `git diff --check`; all passed. No blocking review issues
  found. Minor caveat: the manual-auth error includes this machine's absolute
  bridge path, which is useful locally but should be made dynamic if the bridge
  is packaged or shared broadly.
- Later workers, if used, should have disjoint ownership:
  - backend worker: `/Users/tharutaipree/projects/mcp-hub/src/**`
  - UI worker: `patches/mcphub.nvim/**` and installed/worktree
    `mcphub.nvim` Lua source used for patch generation
  - docs/config worker: task/memory docs and `~/dotfiles/ai/mcp/mcphub.json`

## Success Criteria

- Opening `:MCPHub` in a fresh `NVIM_APPNAME=nvimwt3a` session shows server
  status without waiting for all 41 servers to finish connecting.
- A missing/expired Slack bridge token does not open a browser, Cursor, or any
  other app during initial MCPHub startup.
- If Cursor still opens, the task records an evidence-backed cause rather than
  assuming it is the default `https` handler.
- Slack bridge appears as auth-required/failed in the server list.
- Pressing `l` on the Slack bridge row starts the required auth step explicitly.
- A slow or timed-out MCP server does not block other server rows from rendering.
- `<C-r>` or the chosen soft refresh key refreshes UI/server status before the
  hub is ready.
- Existing `r` hard refresh and `R` hard restart behavior remain understandable
  and documented.
- Later config changes/server enablement and initial load use the same
  non-blocking status model.

## Verification

### How to verify

Use the worktree Neovim profile and a test Slack bridge state where the token is
missing or invalid. First verify passive startup behavior, then verify explicit
auth behavior from the UI.

Back up any token/config file before intentionally invalidating auth.

### Commands

```bash
NVIM_APPNAME=nvimwt3a nvim
```

```vim
:MCPHub
```

```bash
# Observe health while hub is starting.
curl -s http://localhost:37374/health | jq '{state, serverCount: (.servers | length // 0)}'
```

```bash
# Optional: inspect MCPHub/SSE process state from another terminal.
lsof -i :37374
```

### Checklist

- [ ] Fresh `:MCPHub` opens the main server status UI before all servers finish
      connecting.
- [ ] Server rows show `connecting`, `connected`, `failed`, `disabled`, or
      `auth-required` style status individually.
- [ ] Slack bridge missing-token startup does not open browser auth.
- [ ] Slack bridge missing-token startup does not open Cursor or another IDE.
- [ ] If Cursor opens, LaunchServices, Slack bridge stderr, and macOS process
      logs identify whether the launch came from `open <https://...>`, a
      `cursor:` deep link, browser/session restore, or another automation.
- [ ] Slack bridge row shows an explicit auth-required/fail status.
- [ ] Pressing `l` on the Slack bridge row starts the auth flow intentionally.
- [ ] Pressing `l` on HTTP OAuth servers still uses the existing
      authorization-url behavior.
- [ ] Slow/failing server does not keep the UI in logs-only view.
- [ ] `<C-r>` or the chosen soft refresh key updates server statuses while hub
      state is still starting.
- [ ] Current `r` still performs hard capability refresh only when the hub is
      ready.
- [ ] `R` still performs hard restart.
- [ ] Reconnecting a second Neovim session to an existing server behaves the
      same as fresh startup from the user's perspective.

## Suggested Skills / Tools For Next Session

- Use the task workflow in [tasks/AGENTS.md](tasks/AGENTS.md).
- Use `rtk` for shell commands per repo instructions.
- Use `terminal-keybindings` only if there is uncertainty about `<C-r>` or other
  terminal/Nvim key conflicts.

## Notes

- Do not treat this as only a `mcphub.nvim` UI patch. The fundamental blocker is
  backend readiness waiting for all MCP server connections.
- Do not rely on `/api/refresh` for pre-ready status. Use `/health` or a new
  pre-ready-safe status route.
- Avoid changing existing `r` semantics unless the user explicitly accepts that
  break. `<C-r>` is the safer candidate for soft status refresh.
- Redact secrets in any future logs. The prior investigation did not require
  storing any Slack webhook/token values in this task.
