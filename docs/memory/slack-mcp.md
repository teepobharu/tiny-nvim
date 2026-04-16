# Slack MCP Native Server

Native Lua MCPHub server for Slack operations. Lives in `lua/utils/slack_mcp/`.

## Token Support

Both token types accepted at `:SlackAuth setup`:

| Token prefix | Type | Posts as |
|---|---|---|
| `xoxp-*` | User OAuth | Human user |
| `xoxb-*` | Bot | Bot identity |

Token type is auto-detected from the prefix and stored in macOS Keychain as `token_type`.
`auth.is_bot()` and `auth.token_type()` expose it at runtime.

## Tool Behaviour by Token Type

| Tool | User (`xoxp-`) | Bot (`xoxb-`) |
|---|---|---|
| `slack_get_my_info` | Full human profile via `users.info` | Bot identity from `auth.test` + `known_users` reference table |
| `slack_get_user_info` | ID or email lookup | ID lookup works; email lookup needs `users:read.email` scope |
| `slack_send_message` | Posts as user | Posts as bot |
| `slack_draft_message` | Local preview | Local preview |
| `slack_schedule_message` | Scheduled as user | Scheduled as bot |
| `slack_auth_status` | Shows user token details | Shows bot token details |

## Bot Mode: Email Resolution (`known_users`)

Bot tokens cannot call `users.lookupByEmail` without admin scopes.
Workaround: pass a `known_users` array to `slack_get_my_info`:

```json
{
  "known_users": [
    { "email": "alice@example.com", "id": "U1234567890", "name": "Alice" }
  ]
}
```

The tool returns this as a formatted reference table so the AI can resolve email → ID.

## Setup

```
:SlackAuth setup    " paste xoxp- or xoxb- token, auto-detected
:SlackAuth status   " show token type, expiry, cache state
:SlackAuth clear    " remove all tokens from Keychain
```

## Keychain Keys

Stored under service `com.neovim.slack-mcp`:

- `access_token` — the xoxp-/xoxb- token
- `token_type` — `"user"` or `"bot"`
- `token_expiry` — unix timestamp (far-future for non-rotating tokens)
- `refresh_token` — only if token rotation enabled (user tokens)
- `client_id` / `client_secret` — optional, for token rotation

## Required Slack Scopes

**User token (xoxp-):**
- `chat:write`, `users:read`, `users:read.email`, `users.profile:read`

**Bot token (xoxb-):**
- `chat:write`, `users:read`
- Add `users:read.email` to also support email lookup via `slack_get_user_info`

## Architecture

```
lua/utils/slack_mcp/
  init.lua      — native server definition, 6 tools
  auth.lua      — token storage, is_bot(), get_token(), setup(), status()
  api.lua       — curl-based async Slack API client
  keychain.lua  — macOS Keychain CRUD via `security` CLI
  types.lua     — JSON inputSchemas for all tools

lua/plugins/extra/mySlackMcp.lua  — plugin spec + :SlackAuth command
```

## Gotchas

- Tools can't be dynamically removed at runtime (MCPHub registers statically).
  Bot-incompatible behaviour is handled in-handler, not by hiding tools.
- `auth.is_bot()` reads from Keychain on every call — has slight overhead but avoids stale cache issues.
- Token rotation (`refresh_token`) is only prompted for user tokens (`xoxp-`); bot tokens don't rotate.
- `slack_get_user_info` with email + bot token still attempts the call — it may succeed if `users:read.email` scope is granted.
