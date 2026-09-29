# mcp-hub patches

These patches target the local `mcp-hub` fork used by
`lua/plugins/extra/myAi.lua` when `~/projects/mcp-hub/dist/cli.js` or
`~/projects/mcp-hub/src/utils/cli.js` exists.

These are historical patches for a pre-feature fork checkout. **Do not apply
them to the current fork tip (`bc31828` plus local build-info work)**: 01/02
are already present, and 03/04 overlap committed clear-auth/stdio-auth code.
The old `6a4ce7e` base also predates `src/mcp/proxy.js`, which patch 01 edits,
so this stack is not a reproducible clean-clone recipe. Use the fork commits
directly; keep these files only for provenance until they can be archived.

## Historical application order (not for current fork tip)

```bash
cd ~/projects/mcp-hub
git apply --ignore-space-change external-patches/mcp-hub/01-idempotent-endpoint-cleanup.patch
git apply --ignore-space-change external-patches/mcp-hub/02-hard-restart-response-before-shutdown.patch
git apply --ignore-space-change external-patches/mcp-hub/03-clear-auth-endpoint.patch
git apply --ignore-space-change external-patches/mcp-hub/04-stdio-auth-command.patch
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

## 04-stdio-auth-command.patch

Commit context: `6a4ce7e` (upstream v4.2.1), after patches 01, 02, and 03

- Adds optional stdio server `authCommand` support.
- If a stdio server with `authCommand` fails initialize with an
  auth-required/authorization-required MCP error, the connection is marked
  `unauthorized` instead of plain `disconnected`.
- Exposes the resolved `authCommand` in `getServerInfo()`.
- Lets `POST /servers/authorize` start the configured command when no
  HTTP `authorizationUrl` is available. This makes `l` in mcphub.nvim usable for
  stdio auth flows such as `slack_official_bridge`.
- When the manual auth command exits successfully, reconnects the server and
  broadcasts `SERVERS_UPDATED`, so the UI can move from `unauthorized` to
  `connected` without a manual toggle.

---

After applying to `~/projects/mcp-hub`, rebuild with:

```bash
npm run build
```

`myAi.lua` prefers `dist/cli.js`, so rebuilding is required unless you point
`MCP_HUB_FORK_CLI` directly at `src/utils/cli.js`.

## Build patch manifest

The fork's build script optionally reads `PATCHES.json` at build time. If you
apply new uncommitted external patches to a future base, write a JSON array of
`{ "name": "...", "sha256": "...", "appliedAt": "UTC timestamp" }` entries
for **patches actually applied** before building. The manifest is ignored by
Git and embedded in the standalone binary; no runtime `.git` or patch-file
read is needed. The current fork has these capabilities in commits, so its
manifest is absent and `/api/build-info` correctly reports `patches: []`.
