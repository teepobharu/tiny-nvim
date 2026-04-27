---
title: "MCPHubClearAuth user command with vim.ui.select picker"
status: review
priority: medium
created: 2026-04-21
updated: 2026-04-21
related:
  - [MCPHub plugin config](lua/plugins/extra/myAi.lua)
  - [MCPHub memory doc](docs/memory/mcphub.md)
  - [OAuth storage file](~/.local/share/mcp-hub/oauth-storage.json)
---

## Objective

Add `:MCPHubClearAuth` user command to clear stale OAuth credentials for a
specific MCP server stored in `~/.local/share/mcp-hub/oauth-storage.json`. When
invoked without an argument, show a `vim.ui.select` picker listing only servers
that currently have stored credentials (non-null `clientInfo`/`tokens`).

Use case: when an upstream MCP OAuth server invalidates / rotates its client
registry (e.g. pod restart dropping in-memory DCR state), MCPHub keeps sending
the old client_id and the consent page fails with "client ID not found in
server's client registry". There is no built-in clear-auth route in `mcp-hub`
server nor a command in `mcphub.nvim`, so we add one locally.

## Context

### Prior investigation

- Stale client_id reproduced for `slack-mcp-qa.privatecloud.sg.agoda.is`
  (`e1e22ab8-9f0a-44ad-be92-e4f791153bf0`). Claude Code worked because it keeps
  its own separate OAuth store with a different, still-valid DCR.
- Storage file format:
  ```json
  {
    "<server-url>": {
      "clientInfo": { "client_id": "...", ... } | null,
      "tokens": { "access_token": "...", ... } | null,
      "codeVerifier": "..." | null
    }
  }
  ```
- Resetting an entry to `{clientInfo:null, tokens:null, codeVerifier:null}`
  triggers fresh Dynamic Client Registration on next server start.

### Upstream gap (confirmed)

- `mcp-hub` Node server exposes no clear-auth / revoke endpoint (checked
  `~/.local/share/nvim3_jelly_tinynvim/lazy/mcphub.nvim/bundled/mcp-hub/node_modules/mcp-hub/dist/cli.js`
  — only `/api/oauth/callback`, `/servers/authorize` exist).
- `mcphub.nvim` defines only one user command: `:MCPHub` (in
  `~/.local/share/nvim3_jelly_tinynvim/lazy/mcphub.nvim/plugin/mcphub.lua:10`).

### Existing workaround

Manual `jq` on the JSON file then restart hub.

## Implementation Plan

- [x] Add `lua/utils/mcphub_auth.lua` with pure functions:
  - [x] `M.storage_path()` → resolved path with `$XDG_DATA_HOME` fallback
  - [x] `M.read()` → decoded table or `{}` on missing/invalid
  - [x] `M.write(tbl)` → atomic write (temp file + rename) with backup of prior
  - [x] `M.list_authed()` → array of `{url=..., has_client=bool, has_tokens=bool}` filtered to entries with any non-null field
  - [x] `M.clear(url)` → reset single entry to all-null, write back, return ok/err
  - [x] `M.clear_notify(url)` → clear + vim.notify result
  - [x] `M.pick_and_clear()` → vim.ui.select picker over authed entries
  - [x] `M.list_all_urls()` → all URLs for tab-completion
- [x] Add `:MCPHubClearAuth [url]` in [lua/plugins/extra/myAi.lua](lua/plugins/extra/myAi.lua) (optional mcphub.nvim spec with `config`):
  - [x] With arg → validate URL exists, clear directly, notify
  - [x] Without arg → `vim.ui.select` picker showing URL + `[client]`/`[tokens]` badges
  - [x] Tab-completion of stored URLs via `complete = function() ... end`
  - [x] After clearing, notify user to restart the server (`R` in MCPHub UI)
- [x] Add `<leader>ahx` keymap in mcphub.nvim `keys` table + which-key group spec
- [x] Update [docs/memory/mcphub.md](docs/memory/mcphub.md):
  - [x] "OAuth — Stale DCR Client ID" section with symptom, root cause, fix
  - [x] Reference to `:MCPHubClearAuth` and `<leader>ahx`
- [x] Run `stylua`

## Success Criteria

- `:MCPHubClearAuth` with no arg opens a picker listing only authed servers
- Selecting an entry clears its `clientInfo`/`tokens`/`codeVerifier` and writes a timestamped backup
- `:MCPHubClearAuth <url>` clears the given URL non-interactively and errors cleanly on unknown URL
- Tab-complete after `:MCPHubClearAuth ` suggests stored server URLs
- Next `:MCPHub` restart of that server triggers fresh DCR (new client_id in storage)
- No impact on other stored entries

## Verification

### How to verify

Need `~/.local/share/mcp-hub/oauth-storage.json` with at least one authed
entry (current Agoda setup qualifies — slack, atlassian, outlook-meetings,
superset all have `clientInfo` populated).

Backup first: `cp ~/.local/share/mcp-hub/oauth-storage.json{,.verify-bak}`.
Restore with `mv` if anything goes sideways.

### Commands

```bash
# 1. Sanity check starting state
jq 'to_entries | map({url: .key, has_client: (.value.clientInfo != null), has_tokens: (.value.tokens != null)})' \
  ~/.local/share/mcp-hub/oauth-storage.json
```

```vim
" 2. Picker flow
:MCPHubClearAuth

" 3. Direct URL flow
:MCPHubClearAuth https://slack-mcp-qa.privatecloud.sg.agoda.is/mcp

" 4. Tab-completion
:MCPHubClearAuth <Tab>

" 5. Unknown URL error
:MCPHubClearAuth https://nonexistent.example.com/mcp
```

```bash
# 6. Confirm backup was written and target entry was cleared
ls -lt ~/.local/share/mcp-hub/oauth-storage.json.bak.* | head -3
jq '.["https://slack-mcp-qa.privatecloud.sg.agoda.is/mcp"]' ~/.local/share/mcp-hub/oauth-storage.json
# Expected: {"clientInfo": null, "tokens": null, "codeVerifier": null}
```

### Checklist

- [x] `:MCPHubClearAuth` with no arg opens `vim.ui.select` picker
- [x] Picker shows only server URLs with stored credentials (no null-only entries)
- [x] Each picker entry shows visual hint for client/token presence (e.g. `[c][t]` or similar)
- [x] Selecting a picker entry clears it and shows notification
- [x] `:MCPHubClearAuth <full-url>` clears that URL without prompting
- [x] Tab-completion after `:MCPHubClearAuth ` lists stored URLs
- [ ] Unknown URL argument produces an error notification (not a silent pass)
- [x] A timestamped `oauth-storage.json.bak.<ts>` file appears on each clear
- [x] Target entry is reset to `{clientInfo:null, tokens:null, codeVerifier:null}`
- [x] Other entries in `oauth-storage.json` are unmodified
- [x] `<leader>aHx` (or chosen keymap) invokes the command and appears in which-key under MCPHub group
- [x] Restarting the cleared server from `:MCPHub` UI triggers re-auth with a fresh `client_id`

> Notes:
- After clear token requires trigger hard refresh to server else the clientid will use the same and it will not work

## References

- [MCPHub plugin config](lua/plugins/extra/myAi.lua:255-332)
- [Snacks picker notes](docs/memory/snacks_picker.md)
- [MCPHub memory](docs/memory/mcphub.md)
- mcp-hub upstream: https://github.com/ravitemer/mcp-hub
- Bundled server source: `~/.local/share/nvim3_jelly_tinynvim/lazy/mcphub.nvim/bundled/mcp-hub/node_modules/mcp-hub/dist/cli.js`
- OAuth storage: `~/.local/share/mcp-hub/oauth-storage.json`
