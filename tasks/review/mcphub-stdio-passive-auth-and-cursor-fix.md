---
title: "MCPHub startup slices done: Slack passive auth, stdio authCommand, Cursor popup fix"
status: review
priority: medium
created: 2026-09-11
updated: 2026-09-11
parent:
  - [Startup non-blocking UI task](tasks/open/mcphub-startup-slack-auth-async-ui.md)
related:
  - [MCPHub memory](docs/memory/mcphub.md)
  - [05 stdio authCommand patch](patches/mcphub.nvim/05-stdio-auth-command_v1.patch)
  - [Agent registry helper](lua/utils/mcphub_agents.lua)
  - [Shared hub config](~/dotfiles/ai/mcp/mcphub.json)
---

## Objective

Split from [mcphub-startup-slack-auth-async-ui](tasks/open/mcphub-startup-slack-auth-async-ui.md).
These slices are implemented and were verified at implementation time.
They are listed here so the parent task only tracks the remaining work
(backend async startup, pre-ready server rows, soft refresh key).
A quick re-verification below is enough to move this file to `completed/`.

## Completed Slices

### Slice 1: Slack bridge passive auth (done 2026-07-03)

- Passive auth support implemented in
  `/Users/tharutaipree/projects/ai/slack-official-mcp-bridge`
  (`SLACK_MCP_BRIDGE_AUTO_AUTH=0`): missing/expired token returns an
  auth-required signal without opening a browser; valid token still
  initializes; manual auth stays `node .../build/index.js auth`.
- `npm run build` plus passive missing-token, passive no-token non-initialize,
  mocked valid-token `initialize`, and mocked passive 401 `initialize` smokes
  all passed at review time.
- [~/dotfiles/ai/mcp/mcphub.json](~/dotfiles/ai/mcp/mcphub.json) passes
  `SLACK_MCP_BRIDGE_AUTO_AUTH=0` to `slack_official_bridge` (verified present
  2026-09-11, line 587).

### Slice 2: Cursor popup root cause (done 2026-07-07)

- The Cursor popup was traced to the CLI Agents panel shelling out
  `cursor mcp list`, which Cursor 3.10.x routes through its Electron CLI and
  can foreground the app.
- Fix applied: Cursor is now a config-backed agent - the registry reads
  `~/.cursor/mcp.json` and no longer shells out to `cursor mcp ...` during
  render/refresh/add/remove; UI hints for config-only agents show config
  editing only.
- LaunchServices evidence ruled out Cursor as an http/https/slack URL handler.

### Slice 4 (auth part): on-demand stdio auth (done, shipped as patch 05)

- `authCommand` support in the mcp-hub fork
  (`~/projects/mcp-hub/src/MCPConnection.js`) renders a passive auth-required
  stdio startup error as an unauthorized row.
- `l` on that row runs the configured `authCommand`, auto-reconnects the server
  on success, and broadcasts `SERVERS_UPDATED` so the UI redraws without a
  manual toggle.
- Shipped as [patches/mcphub.nvim/05-stdio-auth-command_v1.patch](patches/mcphub.nvim/05-stdio-auth-command_v1.patch);
  behavior documented in [docs/memory/mcphub.md](docs/memory/mcphub.md).

## Verification

### Commands

```bash
# Passive env still wired
grep -n "SLACK_MCP_BRIDGE_AUTO_AUTH" ~/dotfiles/ai/mcp/mcphub.json

# No cursor mcp shell-out while the panel renders
:MCPHub  # then in another terminal:
ps -axo pid,ppid,command | rg 'cursor mcp' || echo "no cursor mcp process"
```

### Checklist

- [ ] `:MCPHub` startup does not open a browser/Cursor popup for the Slack
      bridge while the token is valid.
- [ ] With the Slack token cleared, the bridge row goes unauthorized without a
      popup; pressing `l` runs manual auth and the row reconnects.
- [ ] No `cursor mcp` process is spawned while the CLI Agents panel renders.
