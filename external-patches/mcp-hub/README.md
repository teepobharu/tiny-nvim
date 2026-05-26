# mcp-hub patches

These patches target the local `mcp-hub` fork used by
`lua/plugins/extra/myAi.lua` when `~/projects/mcp-hub/dist/cli.js` or
`~/projects/mcp-hub/src/utils/cli.js` exists.

## 01-idempotent-endpoint-cleanup.patch

- Makes `/mcp` endpoint client cleanup idempotent in `src/mcp/server.js`.
- Applies the same guard to the lean endpoint in `src/mcp/proxy.js`.
- Prevents re-entrant `server.close()` calls from producing
  `Maximum call stack size exceeded` and repeated
  `'Unknown' client disconnected from MCP HUB` logs during hard restarts or mass
  disconnects.
- **Server build dependency**: rebuild `~/projects/mcp-hub/dist/cli.js` after
  applying. Suggested commit title:
  `mcp-hub: make MCP endpoint cleanup idempotent`.

## 02-hard-restart-response-before-shutdown.patch

- Makes `/api/hard-restart` return its JSON response before emitting `SIGTERM`.
- Prevents curl error 56 (`Recv failure: Connection reset by peer`) from being
  reported as "Hard restart failed" when the process is intentionally shutting
  down.
- **Server build dependency**: rebuild `~/projects/mcp-hub/dist/cli.js` after
  applying. Suggested commit title:
  `mcp-hub: return hard-restart response before shutdown`.

After applying to `~/projects/mcp-hub`, rebuild with:

```bash
npm run build
```

`myAi.lua` prefers `dist/cli.js`, so rebuilding is required unless you point
`MCP_HUB_FORK_CLI` directly at `src/utils/cli.js`.
