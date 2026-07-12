---
title: "Slack MCP server injects top-level text into blocks"
status: archive
priority: high
created: 2026-07-02
updated: 2026-07-02
related:
  - [MCPHub memory](docs/memory/mcphub.md)
  - [MCPHub utilities](lua/utils/mcphub_utils.lua)
  - [Slack MCP memory](docs/memory/slack-mcp.md)
---

# Slack MCP Server: text param injected into blocks

## Status: Archived

## Summary

The Agoda Slack MCP server (`slack-mcp-qa.privatecloud.sg.agoda.is`) has a bug in `slack_post_message` and `slack_reply_to_thread` where the top-level `text` parameter is injected into each block object before forwarding to Slack's `chat.postMessage` API.

This causes `invalid_blocks` errors on block types that don't accept a `text` property (divider, actions, context).

## Resolution

This task is being archived rather than kept open because a practical alternative path exists:

- use direct bridge/native Slack tools for normal messaging, drafts, and scheduling
- avoid the Agoda Slack MCP server for raw Block Kit payloads until the server is fixed upstream

The underlying Agoda server bug is still real and still reproducible, but it is no longer blocking normal Slack usage in this workflow.

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

Prefer bridge/native Slack tools for standard usage.

If the Agoda Slack MCP server must be used with raw Block Kit, avoid sending top-level `text` when `blocks` is present.

## Server details

- URL: `https://slack-mcp-qa.privatecloud.sg.agoda.is/mcp`
- Affected tools: `slack_post_message`, `slack_reply_to_thread`
- MCPHub config: `~/dotfiles/ai/mcp/mcphub.json`

## Outcome

- direct bridge/native Slack tools were verified as workable alternatives
- rich markdown messages worked through bridge/native tools
- drafts worked through both tool families
- scheduling worked through `slack_official_bridge`
- explicit Block Kit with `divider`, `actions`, and `context` remains broken on the affected Agoda Slack MCP path

## Why archive instead of keep open

The bug is upstream and outside this Neovim config repo.

There is enough documentation now to:

- explain the failure mode
- preserve the workaround
- guide future users to the alternative bridge path

So this task is better treated as documented-and-worked-around, not as active local work.

## Related

- [docs/memory/mcphub.md](docs/memory/mcphub.md) — MCPHub schema fixes section
- [docs/memory/slack-mcp.md](docs/memory/slack-mcp.md) — Slack MCP notes and workaround
- [lua/utils/mcphub_utils.lua](lua/utils/mcphub_utils.lua) — $ref resolver and strict mode patch
