# mcp-hub patches

These patches target the local `mcp-hub` fork used by
`lua/plugins/extra/myAi.lua` when `~/projects/mcp-hub/dist/cli.js` or
`~/projects/mcp-hub/src/utils/cli.js` exists.

All patches are tested against fork commit `6a4ce7e` (mcp-hub v4.2.1).
Apply in order; each patch assumes the previous ones are already applied.

## Application order

```bash
cd ~/projects/mcp-hub
git apply --ignore-space-change external-patches/mcp-hub/01-idempotent-endpoint-cleanup.patch
git apply --ignore-space-change external-patches/mcp-hub/02-hard-restart-response-before-shutdown.patch
git apply --ignore-space-change external-patches/mcp-hub/03-clear-auth-endpoint.patch
npm run build
```

---

## 01-idempotent-endpoint-cleanup.patch

Commit context: `6a4ce7e` (upstream v4.2.1)

- Makes `/mcp` endpoint client cleanup idempotent in `src/mcp/server.js`.
- Applies the same guard to the lean endpoint in `src/mcp/proxy.js`.
- Prevents re-entrant `server.close()` calls from producing
  `Maximum call stack size exceeded` and repeated
  `'Unknown' client disconnected from MCP HUB` logs during hard restarts or mass
  disconnects.

## 02-hard-restart-response-before-shutdown.patch

Commit context: `6a4ce7e` (upstream v4.2.1), after patch 01

- Makes `/api/hard-restart` return its JSON response before emitting `SIGTERM`.
- Prevents curl error 56 (`Recv failure: Connection reset by peer`) from being
  reported as "Hard restart failed" when the process is intentionally shutting
  down.

## 03-clear-auth-endpoint.patch

Commit context: `6a4ce7e` (upstream v4.2.1), after patches 01 and 02

- Adds `StorageManager.clear(serverUrl)` — zeros the in-memory entry and persists to disk.
- Adds `MCPHubOAuthProvider.clearAuth()` — public wrapper.
- Adds `POST /servers/clear-auth` route — clears in-memory OAuth state for one
  server by name, disconnects the connection, broadcasts `SERVERS_UPDATED`.
- This avoids a full hard-restart when an upstream MCP server's DCR registry is
  reset (pod restart / in-memory only). mcphub.nvim patch `04-clear-auth_v1`
  exposes this as the `X` key on server rows in `:MCPHub`.

---

After applying to `~/projects/mcp-hub`, rebuild with:

```bash
npm run build
```

`myAi.lua` prefers `dist/cli.js`, so rebuilding is required unless you point
`MCP_HUB_FORK_CLI` directly at `src/utils/cli.js`.
