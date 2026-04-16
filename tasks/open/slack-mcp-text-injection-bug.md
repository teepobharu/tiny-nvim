# Slack MCP Server: text param injected into blocks

## Status: Open

## Summary

The Agoda Slack MCP server (`slack-mcp-qa.privatecloud.sg.agoda.is`) has a bug in `slack_post_message` and `slack_reply_to_thread` where the top-level `text` parameter is injected into each block object before forwarding to Slack's `chat.postMessage` API.

This causes `invalid_blocks` errors on block types that don't accept a `text` property (divider, actions, context).

## Evidence

### Reproduces across ALL clients — not a client-side issue

**CodeCompanion (via MCPHub):**
```
"invalid additional property: text [json-pointer:/blocks/1]"
```

**Claude Code (direct MCP connection):**
```
'invalid additional property: text [json-pointer:/blocks/1]',
'invalid additional property: text [json-pointer:/blocks/3]',
'invalid additional property: text [json-pointer:/blocks/4]'
```

### Correctly formed client payload (from Claude Code log)

```json
{
  "channelId": "DKA67HEMV",
  "text": "Daily digest — Hello, Bright!",
  "blocks": [
    {"type":"section","text":{"type":"mrkdwn","text":"..."}},
    {"type":"divider"},
    {"type":"section","text":{"type":"mrkdwn","text":"..."}},
    {"type":"actions","elements":[...]},
    {"type":"context","elements":[{"type":"mrkdwn","text":"..."}]}
  ]
}
```

- `blocks/1` (divider) — no `text` in client payload, but Slack API rejects with `text` error
- `blocks/3` (actions) — no `text` in client payload, same error
- `blocks/4` (context) — no `text` in client payload, same error

### Root cause hypothesis

The MCP server likely merges the top-level `text` param into each block object:
```python
# Probable bug in server code
for block in blocks:
    block["text"] = params.get("text")  # injects text into divider/actions/context
```

## Current workaround

Prompt instructs LLM to NOT send `text` param when `blocks` is provided:
- [slack-draft-message.md](../../dotfiles/ai/agents/commands/codecompanion/slack-draft-message.md)

## Server details

- URL: `https://slack-mcp-qa.privatecloud.sg.agoda.is/mcp`
- Affected tools: `slack_post_message`, `slack_reply_to_thread`
- MCPHub config: `~/dotfiles/ai/mcp/mcphub.json`

## Action needed

Report bug to Slack MCP server team — the `text` parameter should be passed as a separate top-level field to `chat.postMessage`, not merged into block objects.

## Related

- [docs/memory/mcphub.md](docs/memory/mcphub.md) — MCPHub schema fixes section
- [lua/utils/mcphub_utils.lua](lua/utils/mcphub_utils.lua) — $ref resolver and strict mode patch
