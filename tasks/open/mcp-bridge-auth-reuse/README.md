---
title: "Generic MCP bridge auth reuse from Cursor / Claude / Codex"
status: open
priority: high
created: 2026-08-13
updated: 2026-08-13
category: ai-tooling
related:
  - [MCPHub config](lua/plugins/extra/myAi.lua)
  - [MCPHub memory](docs/memory/mcphub.md)
  - [Slack startup auth task](tasks/open/mcphub-startup-slack-auth-async-ui.md)
  - [MCPHub clear auth](tasks/review/mcphub-clear-auth-command.md)
  - Shared MCPHub config: `~/dotfiles/ai/mcp/mcphub.json`
  - Slack official bridge: `~/projects/ai/slack-official-mcp-bridge/`
  - mcp-hub OAuth provider: `~/projects/mcp-hub/src/utils/oauth-provider.js`
---

## Objective

Build a **generic, reusable MCP auth bridge** (patterned on `slack-official-mcp-bridge`) so MCPHub can use an already-authenticated connection from Cursor, Claude Code, or Codex instead of starting its own OAuth flow against `localhost:37373`.

Primary failure this unblocks: HTTP MCP servers behind Agoda MCP Gateway (e.g. Calculon) reject MCPHub's OAuth redirect URI.

Then validate end-to-end on Calculon, including **server rename / alias / URL matching** so tokens discovered under one agent name still bind when MCPHub uses a different server key.

## Problem

MCPHub HTTP OAuth registers a callback on the hub port:

```text
http://localhost:37373/api/oauth/callback?server_name=calculon
```

Gateway / IdP allowed redirect patterns do not include that URI. Connecting Calculon through MCPHub fails with:

```json
{
  "error": "invalid_request",
  "error_description": "Redirect URI 'http://localhost:37373/api/oauth/callback?server_name=calculon' does not match allowed patterns."
}
```

Full sample: [samples/calculon-oauth-redirect-mismatch.json](tasks/open/mcp-bridge-auth-reuse/samples/calculon-oauth-redirect-mismatch.json).

Cursor / Claude / Codex often already hold a valid token for the same upstream MCP URL (their OAuth clients use allowed redirect URIs). MCPHub cannot reuse those tokens today without a bridge.

## POC — gateway-compatible redirect (mcp-hub)

Tried in `~/projects/mcp-hub` (2026-08-13):

- Auto-use **compatible** redirect when server URL host contains `mcp-gateway`:
  `http://127.0.0.1:<port>/callback/<server_name>`
  (matches gateway allowlist `http://127.0.0.1:*/callback/*`)
- Keep **legacy** `/api/oauth/callback?server_name=` for everyone else
- Mount app routes `/callback/:server_name` and `/oauth/callback` (not only under `/api`)

### When to set `redirectUrl` style

| Trigger | Style | Resulting URI |
|---------|-------|---------------|
| Default | `legacy` | `http://localhost:PORT/api/oauth/callback?server_name=NAME` |
| Host matches `oauth.compatibleHostPatterns` (default `mcp-gateway`) | `compatible` | `http://127.0.0.1:PORT/callback/NAME` |
| Root `oauth.redirectStyle` | hub default when no host match | same as named style |
| Per-server `oauthRedirectStyle` | override | same as named style |
| Env `MCP_HUB_OAUTH_REDIRECT_STYLE` | force **all** servers | same as named style |

Precedence: per-server → env → host patterns → root `oauth.redirectStyle` → built-in `["mcp-gateway"]` → legacy.

Root config example (`mcphub.json`):

```json
{
  "oauth": {
    "compatibleHostPatterns": [
      "mcp-gateway",
      "^mcp-gateway(-qa)?\\."
    ],
    "redirectStyle": "legacy"
  },
  "mcpServers": { }
}
```

Patterns are JS regex sources (case-insensitive), or `/pattern/flags`. Plain `mcp-gateway` is a substring match. Use `^mcp-gateway\\.agodadev\\.io$` for an exact host.

Do **not** put `?server_name=` on gateway redirects — allowlist patterns do not cover query strings. Put the server key in the path instead.

After changing redirect shape: clear Calculon OAuth (`X` in `:MCPHub` or `:MCPHubClearAuth`) so stale DCR `redirect_uris` are not reused.

### Still open

If compatible redirect works for Calculon, bridge/token-reuse may be optional for gateway MCPs. If IdP still rejects (exact match quirks), fall back to token-reuse bridge.

## Desired Outcome

1. A reusable bridge (not Slack-specific) that:
   - Proxies stdio (or thin HTTP) to an upstream HTTP MCP URL.
   - Resolves bearer / OAuth tokens from host agent stores when present.
   - Falls back to its own on-demand auth command (passive on hub startup), same spirit as Slack `authCommand`.
2. MCPHub config can point Calculon (and similar servers) at the bridge instead of raw `type: http` + hub OAuth.
3. Matching is robust across agents:
   - Exact server name
   - Configurable aliases / rename map
   - Upstream URL equality (preferred stable key)
4. Document token source locations and safety rules (merge auth only; never wholesale replace agent config files).

## Context

### Current Calculon entry (`mcphub.json`)

- Key: `calculon`
- `type: http`
- `url: https://mcp-gateway.agodadev.io/calculon/mcp`
- `env.AUTH: localhost:fail` (documents that hub localhost OAuth is expected to fail)

### Reference pattern — Slack bridge

`~/projects/ai/slack-official-mcp-bridge/` already:

- Owns PKCE / static-client OAuth outside MCPHub DCR.
- Reads tokens from bridge store, then Claude keychain / `~/.claude/.credentials.json`.
- Supports passive startup via `SLACK_MCP_BRIDGE_AUTO_AUTH=0` + MCPHub `authCommand`.

This task should generalize that approach for arbitrary HTTP MCP servers whose IdP rejects MCPHub's redirect URI.

### Known agent auth stores (investigate; do not log secrets)

| Agent | Auth-ish locations (from prior host investigation) |
|-------|-----------------------------------------------------|
| Claude | `~/.claude/.credentials.json` (`mcpOAuth`), Keychain `Claude Code-credentials*` |
| Cursor | `anysphere.cursor-mcp` globalStorage; workspace/host MCP auth blobs |
| Codex | `~/.codex/auth.json` (Codex login); MCP server tokens TBD per server |
| MCPHub | `~/.local/share/mcp-hub/oauth-storage.json` (keyed by server URL) |

Related prior chat: [Codemaster SSH access](fa122854-9562-48a1-b4c6-bb299872ecdc) (host Cursor/Claude MCP auth sync discussion).

### Related MCPHub pieces

- OAuth / clear-auth: [docs/memory/mcphub.md](docs/memory/mcphub.md) (OAuth sections)
- Stdio `authCommand` patches: `external-patches/mcp-hub/04-stdio-auth-command.patch`, `patches/mcphub.nvim/05-stdio-auth-command_v1.patch`
- Startup must stay non-blocking: [tasks/open/mcphub-startup-slack-auth-async-ui.md](tasks/open/mcphub-startup-slack-auth-async-ui.md)

## Implementation Plan

- [ ] Map token layouts for Cursor / Claude / Codex for at least one gateway MCP (Calculon) that already works in those agents.
- [ ] Design generic bridge contract:
  - config: upstream URL, optional aliases, token source priority, auth callback port / client ids if needed
  - commands: `serve` (stdio MCP), `auth` (on-demand), `status` / `which-token` (debug, redacted)
- [ ] Implement token resolver with matching order: URL → alias → server name → explicit override.
- [ ] Wire MCPHub entry for Calculon via bridge + passive `authCommand` (no auto browser on hub start).
- [ ] Prove Calculon connects in `:MCPHub` without `localhost:37373` redirect.
- [ ] Document alias/rename examples when agent server key differs from MCPHub key.
- [ ] Extract durable notes to [docs/memory/mcphub.md](docs/memory/mcphub.md) (or new `docs/memory/mcp-bridge-auth.md`).

## Success Criteria

- Calculon reaches `connected` in MCPHub without IdP rejecting MCPHub redirect URI.
- Token reuse works when auth was completed in Cursor and/or Claude (whichever sources we support first).
- Renaming MCPHub server key or adding aliases still finds the same token via URL match.
- Auth remains on-demand / passive at hub startup (no blocking Slack-style popup storm).
- Solution is reusable for other gateway MCPs with the same redirect restriction, not Calculon-only hardcoding.

## Verification

> Fill concrete checklist results when moving to `review/`.

### How to verify

1. Ensure Calculon (or equivalent) is already authenticated in Cursor or Claude.
2. Point MCPHub Calculon entry at the generic bridge.
3. Restart mcp-hub / open `:MCPHub`.
4. Confirm no redirect-URI mismatch page; server becomes usable.

### Commands

```bash
# Hub health
curl -sS http://localhost:37373/health

# Bridge status (redacted) once implemented
# node <bridge>/build/index.js status --url https://mcp-gateway.agodadev.io/calculon/mcp
```

```vim
:MCPHub
" Select calculon row — expect connected / authorize via l only if no reused token
```

### Checklist

- [ ] Calculon no longer shows redirect URI `localhost:37373/.../callback?server_name=calculon` error
- [ ] Tools from Calculon callable through MCPHub after token reuse
- [ ] Alias or rename of server key still resolves token via URL
- [ ] Fresh auth path (`auth` / `l`) works when no host token exists
- [ ] Hub startup does not auto-open browser for this bridge

## Open Questions

- Prefer stdio bridge (Slack-like) vs injecting tokens into MCPHub `oauth-storage.json` for native HTTP mode?
- Which Cursor storage path is the canonical MCP OAuth token store for gateway servers?
- Should URL matching normalize query/trailing slash / gateway path segments?
- Scope: one shared package under `~/projects/ai/` vs first POC as `tmp_` + later extract?

## References

- Sample failure: [samples/calculon-oauth-redirect-mismatch.json](tasks/open/mcp-bridge-auth-reuse/samples/calculon-oauth-redirect-mismatch.json)
- Slack bridge README: `~/projects/ai/slack-official-mcp-bridge/README.md`
- Shared config: `~/dotfiles/ai/mcp/mcphub.json` (`calculon`, `slack_official_bridge`)
