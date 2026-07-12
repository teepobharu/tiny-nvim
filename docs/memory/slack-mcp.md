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


## Agoda Slack MCP server bug: top-level `text` injected into blocks

The Agoda remote Slack MCP server at
`https://slack-mcp-qa.privatecloud.sg.agoda.is/mcp` has a confirmed server-side
bug in `slack_post_message` and `slack_reply_to_thread`.

### Symptom

If a client sends a valid payload with:

- top-level `text`
- Block Kit `blocks`
- non-text blocks such as `divider`, `actions`, or `context`

the request fails with `invalid_blocks` because the server appears to inject the
same top-level `text` into every block before forwarding to Slack.

Observed errors:

```text
invalid additional property: text [json-pointer:/blocks/1]
invalid additional property: text [json-pointer:/blocks/3]
invalid additional property: text [json-pointer:/blocks/4]
```

### Impact

This is not a client formatting issue. It reproduced across multiple clients.
The failure is specific to the Agoda Slack MCP server path.

### Workaround

For this specific server:

- avoid sending top-level `text` together with raw `blocks`
- or avoid raw Block Kit entirely and use bridge/native markdown-driven Slack tools instead

### Alternative path

Agent-native bridge tools were verified as a practical fallback for normal use:

- `slack_official_bridge__slack_send_message`
- `slack_official_bridge__slack_send_message_draft`
- `slack_official_bridge__slack_schedule_message`
- `slack__slack_post_message`
- `slack__slack_send_message_draft`

Notes:

- rich markdown worked through bridge/native tools
- drafts worked through both tool families
- raw Block Kit with `divider` / `actions` / `context` still failed on the affected Slack MCP path
- `slack_official_bridge` avoids the issue for standard markdown flows because it does not expose a raw `blocks` parameter


## Bridge tool rendering and signature behavior

The direct bridge Slack tools behave differently from raw Slack MCP / Block Kit
flows because sent messages are posted by the Claude Slack app.

### Sent message behavior

When using bridge send tools:

- messages are posted by the Claude Slack app identity
- Slack may show a footer/signature like `Sent with @Claude`
- markdown is often rendered into richer native Slack presentation
- tables can render in a nicer table view instead of plain pasted markdown
- fenced code blocks can render more like native Slack code snippets/cards

This makes bridge sends useful when presentation quality matters more than strict
control over raw Block Kit payloads.

### Draft behavior

Bridge draft tools behave differently:

- they create a normal draft for the user
- the user reviews and sends it manually
- because the final send is user-driven, it avoids the Claude app footer/signature
- draft content behaves more like regular composed markdown/text until the user sends it

### Rule of thumb

- use bridge send for richer Slack-native rendering
- use bridge draft when the user should own the final send and avoid the app signature/footer
