# MCPHub - Architecture & CLI Integration Guide

## Project Disambiguation

**Two separate projects** exist with confusingly similar names:

| Aspect        | **mcp-hub** (ravitemer)                                   | MCPHub (samanhappy)                                       |
| ------------- | --------------------------------------------------------- | --------------------------------------------------------- |
| GitHub        | [ravitemer/mcp-hub](https://github.com/ravitemer/mcp-hub) | [samanhappy/mcphub](https://github.com/samanhappy/mcphub) |
| Type          | npm CLI / Node.js                                         | Docker container                                          |
| Web UI        | No                                                        | Yes                                                       |
| Default Port  | 37373 (nvim) / 5555 (standalone)                          | 3000                                                      |
| Config Format | `mcphub.json` / `servers.json`                            | `mcp_settings.json`                                       |
| Neovim Plugin | [mcphub.nvim](https://github.com/ravitemer/mcphub.nvim)   | None                                                      |

**This guide focuses on:** `ravitemer/mcp-hub` and `mcphub.nvim`

---

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│                         MCP Clients                                   │
├─────────────┬─────────────┬─────────────┬─────────────┬──────────────┤
│   Neovim    │   Neovim    │   Claude    │  OpenCode   │    Other     │
│ (instance1) │ (instance2) │    Code     │   / Codex   │  CLI Agents  │
└──────┬──────┴──────┬──────┴──────┬──────┴──────┬──────┴──────┬───────┘
       │             │             │             │             │
       └─────────────┴─────────────┴─────────────┴─────────────┘
                                   │
                    http://localhost:37373/mcp
                                   │
                                   ▼
       ┌───────────────────────────────────────────────────────┐
       │                   mcp-hub Process                      │
       │              (Express Server + Router)                 │
       │                                                        │
       │  • Manages MCP server connections                      │
       │  • Routes tool/resource requests                       │
       │  • Handles multi-client coordination                   │
       │  • Auto-shutdown with configurable delay               │
       └─────────────────────────┬─────────────────────────────┘
                                 │
          ┌──────────────────────┼──────────────────────┐
          │                      │                      │
          ▼                      ▼                      ▼
    ┌───────────┐          ┌───────────┐          ┌───────────┐
    │  GitLab   │          │   Glean   │          │ Playwright │
    │   (SSE)   │          │  (stdio)  │          │  (stdio)   │
    └───────────┘          └───────────┘          └───────────┘
```

### Key Concepts

1. **mcp-hub** = Central Express server that manages MCP servers
2. **mcphub.nvim** = Neovim plugin that starts/controls mcp-hub
3. **MCP Servers** = Individual tools (GitLab, Glean, Playwright, etc.)
4. **Clients** = Any application connecting to mcp-hub (Neovim, Claude Code, etc.)

---

## Port & Persistence Model

### How Port Persistence Works

```
Timeline: ─────────────────────────────────────────────────────────────────►

Nvim1 starts    Nvim2 connects   Nvim1 closes    Nvim2 closes    Shutdown
     │               │                │               │           timer
     ▼               ▼                ▼               ▼           expires
┌─────────────────────────────────────────────────────────────────────────┐
│  mcp-hub running on port 37373                                          │
│  [Client: Nvim1]                                                        │
│  [Clients: Nvim1, Nvim2]                                                │
│  [Client: Nvim2]                (Nvim1 left, keep running)              │
│  [No clients]                   (Start shutdown_delay timer)            │
│                                                                    STOP │
└─────────────────────────────────────────────────────────────────────────┘
                                                   │
                                    ▲              │
                                    │              │
                          If new client connects   │
                          during this window ──────┘
                          (timer cancelled)
```

### Configuration Options

```lua
-- In mcphub.nvim setup (lua/plugins/extra/myAi.lua)
require("mcphub").setup({
    port = 37373,                    -- Port for mcp-hub
    workspace = { enabled = false }, -- IMPORTANT: Disable for CLI agent access
    shutdown_delay = 5 * 60 * 1000,  -- 5 minutes (default)
    -- Other options...
})
```

| Option              | Default   | Description                                                             |
| ------------------- | --------- | ----------------------------------------------------------------------- |
| `port`              | 37373     | Port mcp-hub listens on                                                 |
| `workspace.enabled` | true      | **Disable for CLI agents** - creates per-directory hubs on random ports |
| `shutdown_delay`    | 5 minutes | Time to wait after last client disconnects                              |
| `server_url`        | nil       | Override endpoint (for remote mcp-hub)                                  |

### Forked mcp-hub backend

`myAi.lua` supports switching from bundled `mcp-hub` to your fork via env vars:

- `MCP_HUB_FORK_CLI=/abs/path/to/mcp-hub/dist/cli.js` -> starts fork with `node <cli.js>`
- `MCP_HUB_FORK_REPO=/abs/path/to/mcp-hub` -> auto-detects `dist/cli.js` or `src/utils/cli.js`
- `MCP_HUB_SERVER_URL=http://host:port` -> connect to external hub endpoint instead of spawning local
- If env is omitted, `myAi.lua` also auto-detects local fork repos at `~/projects/mcp-hub` and `~/worktree/mcp-hub`

Resolution order is `MCP_HUB_SERVER_URL` -> `MCP_HUB_FORK_CLI` -> `MCP_HUB_FORK_REPO` -> default local fork paths -> bundled binary.

### Workspace Mode Warning

**If CLI agents can't connect to port 37373:**

- Workspace mode (enabled by default) creates per-directory hubs on ports 40000-41000
- Add `workspace = { enabled = false }` to use consistent port 37373

### Port Collision Behavior

**When mcphub.nvim starts, it checks port 37373:**

| Scenario                                       | Behavior                                        |
| ---------------------------------------------- | ----------------------------------------------- |
| **Port free**                                  | Starts new mcp-hub server                       |
| **Port in use by mcp-hub (same version)**      | Connects to existing server (multi-instance)    |
| **Port in use by mcp-hub (different version)** | Shows "version mismatch", restarts hub          |
| **Port in use by other service**               | Shows "Port in use by non-MCP Hub server" error |

**For CLI agents:**

- If mcp-hub running: Connect successfully
- If mcp-hub not running: Connection refused error
- Recommended: Start Neovim first, or run mcp-hub standalone

**EADDRINUSE handling:**

- If another Neovim instance starts mcp-hub first (race condition)
- mcphub.nvim detects EADDRINUSE and connects to existing server instead

### Persistence Scenarios

#### Scenario 1: Multiple Neovim Instances

```
Nvim1 starts → mcp-hub starts on :37373
Nvim2 starts → connects to existing :37373
Nvim1 closes → mcp-hub keeps running (Nvim2 still connected)
Nvim2 closes → shutdown timer starts (5 min default)
Nvim3 starts within 5 min → timer cancelled, mcp-hub continues
```

**Result:** mcp-hub stays running as long as any Neovim has it open.

#### Scenario 2: Neovim + CLI Agents

```
Nvim starts → mcp-hub starts on :37373
Claude Code connects → http://localhost:37373/mcp
Nvim closes → mcp-hub keeps running (Claude Code connected)
Claude Code session ends → shutdown timer starts
```

**Result:** CLI agents keep mcp-hub alive just like Neovim instances.

#### Scenario 3: All Clients Close

```
All clients disconnect → shutdown_delay timer starts
Timer expires → mcp-hub process exits
```

**Result:** After `shutdown_delay` with no clients, mcp-hub stops.

---

## CLI Agent Integration

### Endpoint

All CLI agents should connect to:

```
http://localhost:37373/mcp
```

### Configuration Examples

#### Claude Code (`~/.mcp.json`)

```json
{
  "mcpServers": {
    "mcp-hub": {
      "type": "sse",
      "url": "http://localhost:37373/mcp"
    }
  }
}
```

#### OpenCode (`opencode.jsonc`)

```jsonc
{
  "mcp": {
    "mcp-hub": {
      "type": "remote",
      "url": "http://localhost:37373/mcp",
      "enabled": true,
      "timeout": 10000,
    },
  },
}
```

#### Codex (`config.toml`)

```toml
[mcp_servers.mcp-hub]
url = "http://localhost:37373/mcp"
```

#### Crush (`crush.json`)

```json
{
  "mcp": {
    "mcp-hub": {
      "type": "http",
      "url": "http://localhost:37373/mcp",
      "disabled": false,
      "timeout": 30
    }
  }
}
```

### CLI Agent Behavior

| Question                                    | Answer                                          |
| ------------------------------------------- | ----------------------------------------------- |
| Can CLI agents use mcp-hub without Neovim?  | **Yes**, if mcp-hub is already running          |
| Do CLI agents keep mcp-hub alive?           | **Yes**, they are clients like Neovim           |
| What if Neovim started mcp-hub then closed? | mcp-hub runs until `shutdown_delay` expires     |
| Can I run mcp-hub independently?            | **Yes**, see "Running mcp-hub Standalone" below |

---

## Running mcp-hub Standalone

For CLI agents to always have access (without Neovim), run mcp-hub independently:

### Option 1: Manual Start

```bash
# Install globally
npm install -g mcp-hub

# Start with your config
mcp-hub --config ~/dotfiles/ai/mcp/mcphub.json --port 37373 --watch
```

### Option 2: Using start-mcphub.sh

```bash
cd ~/dotfiles/ai/mcp

# Start
./start-mcphub.sh start

# Check status
./start-mcphub.sh status

# Test connection
./start-mcphub.sh test

# View logs
./start-mcphub.sh logs

# Stop
./start-mcphub.sh stop
```

### Option 3: Systemd Service (Linux)

```ini
# ~/.config/systemd/user/mcp-hub.service
[Unit]
Description=MCP Hub Server
After=network.target

[Service]
ExecStart=/usr/bin/mcp-hub --config %h/.config/mcphub/servers.json --port 37373 --watch
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
```

```bash
systemctl --user enable mcp-hub
systemctl --user start mcp-hub
```

### Option 4: Long shutdown_delay in Neovim

```lua
require("mcphub").setup({
    shutdown_delay = 24 * 60 * 60 * 1000,  -- 24 hours
})
```

---

## mcphub.nvim Quick Reference

### Only One Command

```vim
:MCPHub              " Open/toggle MCPHub UI
```

### UI Navigation (Inside MCPHub Window)

| Key | View            |
| --- | --------------- |
| `H` | Home/Main view  |
| `M` | Marketplace     |
| `C` | Config          |
| `L` | Logs            |
| `?` | Help            |
| `q` | Close           |
| `r` | Refresh         |
| `R` | Restart mcp-hub |

### Main View Keys

| Key           | Action                     |
| ------------- | -------------------------- |
| `l` / `<CR>`  | Expand server              |
| `h` / `<Esc>` | Collapse                   |
| `t`           | Toggle server on/off       |
| `a`           | Toggle auto-approve        |
| `ga`          | Toggle global auto-approve |
| `A`           | Add server                 |
| `e`           | Edit server                |
| `d`           | Delete server              |

### Tool Form Navigation Keys (Capability Mode)

When a tool capability form is open (input fields + submit line), you can jump between fields without using `j`/`k`.

- Default: `<C-j>` moves to next input/submit line, `<C-k>` moves to previous.
- Configurable through `mcphub.setup({ ui = { input_navigation = { ... } } })`.

```lua
require("mcphub").setup({
  ui = {
    input_navigation = {
      next_field = "<A-j>",
      prev_field = "<A-k>",
    },
  },
})
```

---

## Configuration Files

| File                                | Purpose                                     |
| ----------------------------------- | ------------------------------------------- |
| `~/dotfiles/ai/mcp/mcphub.json`     | MCP server definitions                      |
| `~/dotfiles/ai/mcp/.env`            | Environment variables                       |
| `~/dotfiles/ai/mcp/start-mcphub.sh` | Management script                           |
| `lua/plugins/extra/myAi.lua`        | MCPHub + CodeCompanion MCP extension config |

### mcphub.json Format

```json
{
  "mcpServers": {
    "gitlab": {
      "url": "https://gitlab-mcp.example.com/mcp",
      "transportType": "sse",
      "headers": {
        "Authorization": "Bearer ${GITLAB_TOKEN}"
      }
    },
    "glean": {
      "command": "npx",
      "args": ["-y", "@anthropic/glean-mcp-server"],
      "env": {
        "GLEAN_TOKEN": "${GLEANTOKEN}"
      }
    }
  }
}
```

---

## Server Customization

MCPHub supports per-server customization for tools, resources, and custom instructions. These settings persist in the config file (`mcphub.json`).

### Config File Fields (MCPHub-specific)

```json
{
  "mcpServers": {
    "gitlab": {
      "url": "https://gitlab-mcp.example.com/mcp",
      "transportType": "sse",

      "disabled": false,
      "disabled_tools": ["expensive-tool", "dangerous-tool"],
      "disabled_resources": ["large-resource"],
      "disabled_resourceTemplates": ["template-name"],
      "autoApprove": ["safe-read-tool", "list-tool"],
      "custom_instructions": {
        "disabled": false,
        "text": "Always use pagination when listing. Prefer read operations over write."
      }
    }
  }
}
```

### Field Reference

| Field                        | Type                | Description                             |
| ---------------------------- | ------------------- | --------------------------------------- |
| `disabled`                   | boolean             | Disable server entirely                 |
| `disabled_tools`             | string[]            | Tools to hide from LLMs                 |
| `removed_tools`              | string[]            | Tools to hard-hide and block execution  |
| `disabled_resources`         | string[]            | Resources to hide                       |
| `disabled_resourceTemplates` | string[]            | Resource templates to hide              |
| `autoApprove`                | boolean \| string[] | Auto-approve tools without confirmation |
| `custom_instructions`        | object              | Per-server instructions for LLMs        |

### Env-based Tool Filters (Patch)

For servers that expose an env regex to control visible tools (for example `GITLAB_DENIED_TOOLS_REGEX`),
the local MCPHub patch can map those env values into MCPHub-side tool filtering.

- `*_DENIED_TOOLS_REGEX` or `*_DISABLED_TOOLS_REGEX`: hide matching tool names
- `*_ALLOWED_TOOLS_REGEX` or `*_ENABLED_TOOLS_REGEX`: only keep matching tool names
- Explicit keys are also supported: `DENIED_TOOLS_REGEX`, `ALLOWED_TOOLS_REGEX`, `ENABLED_TOOLS_REGEX`, plus `MCPHUB_*` and `GITLAB_*` variants

This affects both:

- Tool exposure in MCP system prompts / chat integrations
- MCPHub UI disabled state rendering for tool lists

### Strict Hidden Tools (`removed_tools`)

`removed_tools` is a stricter layer than `disabled_tools`:

- Hidden from mcphub.nvim integration capability exposure (`get_servers` / generated prompts)
- Still shown in MCPHub UI as removed (for local visibility)
- Blocked at execution time for tool calls routed through `MCPHub:call_tool`

Protocol scope:

- Upstream bundled `mcp-hub` still does not enforce `removed_tools` / `disabled_tools` for raw `/mcp` protocol clients
- Forked backend at `~/projects/mcp-hub` now enforces tool policy at transport level:
  - disallowed tools are removed from `/mcp` `tools/list`
  - disallowed tool names are rejected for `/mcp` `tools/call`

In MCPHub UI main view:

- `x` toggles strict hide for the selected tool (`removed_tools`)
- `t` keeps the existing soft toggle (`disabled_tools`)

### Auto-Approve Options

```json
// Option 1: Auto-approve ALL tools from this server
"autoApprove": true

// Option 2: Auto-approve specific tools only
"autoApprove": ["read_file", "list_files", "search"]

// Option 3: No auto-approve (default - omit the field)
// Every tool call requires user confirmation
```

### Custom Instructions

Custom instructions are injected into the system prompt for LLMs. They guide how the AI should use a specific server's tools.

**Default:** No custom instructions (empty)

**Setting via UI:**

1. Open `:MCPHub`
2. Navigate to server → expand with `l`
3. Edit custom instructions
4. Changes persist to config file automatically

**Setting via Config:**

```json
"custom_instructions": {
  "disabled": false,
  "text": "When using GitLab tools:\n- Always check MR status before approving\n- Use pagination for large result sets\n- Prefer API v4 endpoints"
}
```

**Disabling:**

```json
"custom_instructions": {
  "disabled": true,
  "text": "..."
}
```

### How External Agents Access Configs

External agents (Claude Code, OpenCode, etc.) receive configurations via the **system prompt**:

```
┌─────────────────┐     HTTP Request      ┌─────────────────┐
│  Claude Code    │ ───────────────────►  │    mcp-hub      │
│  (CLI Agent)    │                       │   (:37373)      │
└─────────────────┘                       └────────┬────────┘
                                                   │
                                                   ▼
                                          get_active_servers_prompt()
                                                   │
                                                   ▼
                                          ┌─────────────────┐
                                          │  System Prompt  │
                                          │  - Server list  │
                                          │  - Tool schemas │
                                          │  - Custom instr │
                                          └─────────────────┘
```

**What's included:**

- Active servers and their capabilities
- Tool/resource schemas (excluding disabled ones)
- Custom instructions per server
- Auto-approve status (for UI confirmation logic)

### LLM Server Control

MCPHub includes a native `mcphub` server with a `toggle_mcp_server` tool that allows LLMs to start/stop servers:

```lua
-- Enable in mcphub.nvim config
require("mcphub").setup({
    auto_toggle_mcp_servers = true,  -- Allow LLMs to toggle servers
})
```

**How it works:**

1. LLM requests to use a disabled server's tool
2. MCPHub's `toggle_mcp_server` tool activates the server
3. Server starts and becomes available
4. Original tool request proceeds

**Disable LLM control:**

```lua
require("mcphub").setup({
    auto_toggle_mcp_servers = false,  -- Prevent LLM from toggling
})
```

---

## Features

Server customization (tools, resources, instructions) is a powerful way to tailor the LLM's behavior with specific servers. By configuring these settings, you can:

`In the server_to_text function, custom instructions are added after the server description but before the tools and resources sections prompt.lua:232-233`
ask:

## OAuth — Stale DCR Client ID

### Symptom

Browser consent page shows:

> The client ID `<uuid>` was not found in the server's client registry.

This happens because `mcp-hub` uses Dynamic Client Registration (DCR). If the
upstream MCP OAuth server loses its registry (e.g. pod restart, in-memory only),
it forgets the client ID that MCPHub registered, but MCPHub keeps sending it.

### Root cause

`~/.local/share/mcp-hub/oauth-storage.json` holds the registered `clientInfo`
(including `client_id`) and active `tokens` per server URL. When the server-side
registry is reset, those values become stale.

`mcp-hub` loads `serversStorage` into module-level memory once at startup —
editing the JSON on disk has no effect until the process restarts. The fork patch
`external-patches/mcp-hub/03-clear-auth-endpoint.patch` adds `POST /servers/clear-auth`
which resets the in-memory entry and disconnects the server, so no process restart is
needed.

### Fix — single key in MCPHub UI (preferred)

With the fork patch applied (`external-patches/mcp-hub/03-clear-auth-endpoint.patch`)
and mcp-hub rebuilt:

1. Open `:MCPHub`
2. Move cursor to the unauthorized server row
3. Press `X` — clears in-memory OAuth state, immediately reconnects the server
4. Row transitions: `unauthorized` → `connecting` → `unauthorized` (fresh auth URL)
5. Press `l` → browser opens with fresh DCR → new valid client_id

The `X` key hint appears in the row's hover hint for unauthorized servers.
If the row ends up `disconnected` for any reason, `l` also reconnects it.

**Server build dependency**: requires mcp-hub fork with the patch applied.
See `external-patches/mcp-hub/README.md` for apply + rebuild instructions.

### Fix — command / picker (fallback or when hub not running)

```vim
:MCPHubClearAuth                          " picker: select from authed servers
:MCPHubClearAuth <url>                    " clear specific server non-interactively
```

`MCPHubClearAuth` now tries the API path first (same as `X`). If the hub is
not connected or the endpoint is absent, it falls back to file-edit and prints
a message to press `R` in `:MCPHub` to flush the running hub's in-memory state.

Keymap: `<leader>aHx` (under MCPHub which-key group).

Implementation: `lua/utils/mcphub_auth.lua` — `pick_and_clear()` / `clear_notify()`.
Registered in `lua/plugins/extra/myAi.lua`.

## OAuth — Stdio Bridge Auth On Demand

Some stdio bridges, such as `slack_official_bridge`, own their OAuth flow
inside the bridge process instead of using MCPHub's HTTP OAuth provider. Do not
let these bridges auto-open auth during `initialize`; that can block startup and
hide the MCPHub server list behind logs.

Local pattern:

- Set the bridge env to passive auth, e.g. `SLACK_MCP_BRIDGE_AUTO_AUTH=0`.
- Add a server-level `authCommand` in `mcphub.json`, e.g. `node .../build/index.js auth`.
- Apply/rebuild `external-patches/mcp-hub/04-stdio-auth-command.patch`.
- Apply `patches/mcphub.nvim/05-stdio-auth-command_v1.patch`.

With those pieces in place, a passive auth-required startup error marks the row
`unauthorized`. Pressing `l` on that row calls `/servers/authorize`, which
starts the configured auth command on demand. When the command exits
successfully, the mcp-hub fork reconnects the stdio server and broadcasts a
server update so the UI can move to `connected` without toggling the server.
HTTP OAuth servers still use the existing `authorizationUrl` flow and popup.

### Manual fallback (if Neovim isn't open)

```bash
SERVER_URL="https://slack-mcp-qa.privatecloud.sg.agoda.is/mcp"
jq --arg u "$SERVER_URL" '.[$u] = {clientInfo:null, tokens:null, codeVerifier:null}' \
  ~/.local/share/mcp-hub/oauth-storage.json \
  > /tmp/oauth.json && mv /tmp/oauth.json ~/.local/share/mcp-hub/oauth-storage.json
```

Then restart mcp-hub so it reloads the file into memory.

## Troubleshooting

### mcp-hub not starting

```bash
# Check if already running
curl http://localhost:37373/health

# Check port usage
lsof -i :37373

# Kill if needed
kill -9 $(lsof -t -i :37373)
```

### CLI agents can't connect

1. Verify mcp-hub is running: `curl http://localhost:37373/mcp`
2. Check if Neovim started it: Open Neovim, run `:MCPHub`
3. Or start manually: `./start-mcphub.sh start`

### mcp-hub stops too quickly

Increase `shutdown_delay`:

```lua
require("mcphub").setup({
    shutdown_delay = 30 * 60 * 1000,  -- 30 minutes
})
```

## Issues

1. Connect fail SSE
   try kill the port and restart mcphub (in this case 37373)

### Log spam freezing Neovim UI ("Unknown client disconnected" ×40+)

**Symptom**: On startup or when a second Neovim profile opens `:MCPHub`, dozens
of `'Unknown' client disconnected from MCP HUB` log lines flood the UI and
cause Neovim to freeze/stutter.

**Root cause** (three compounding issues):
- Multi-profile port conflict triggers a `hard-restart`, disconnecting all SSE
  clients simultaneously — one `LOG` event per client in milliseconds.
- No dedup or throttle: every LOG event calls `State:add_server_output()` →
  `notify_subscribers()` synchronously, queueing 40 `vim.schedule` callbacks.
- `log.level = WARN` config did NOT suppress INFO-level SSE events — it only
  filtered `vim.notify` calls.

**Fix**: Local patch `patches/mcphub.nvim/03-log-dedup-throttle.patch` (v6.2.0):
- **handlers.lua**: SSE log events below `log.level` are dropped before state.
  With `log.level = WARN`, INFO "client disconnected" events never reach state.
- **state.lua**: Consecutive identical messages (same type+text, within 2 s)
  collapse into one entry; `count` is incremented. Subscriber notification is
  debounced 50 ms so a burst produces exactly one UI refresh.
- **renderer.lua**: Collapsed entries show ` ×N` count badge in the Logs tab.

**Passive verification**: Open `:MCPHub` → Logs tab after startup — should show
at most 1 line per unique message (with `×N` badge) instead of 40 identical lines.

See `tasks/review/mcphub-log-spam-fix.md` for full investigation and checklist.

### Hard restart cascades with `/mcp` endpoint clients

**Symptom**: `Hard restart failed`, `SSE connection failed with code 18/56`,
and a burst like:

```text
Error closing server connected to Unknown: Maximum call stack size exceeded
'Unknown' client disconnected from MCP HUB ×1279
```

**Confirmed logic**:
- `mcphub.nvim` does **not** hard-restart just because another Neovim connects.
- Startup only posts `/api/hard-restart` when the health check finds the same
  port is an MCP Hub but either the `mcp-hub` version differs, the workspace
  cache has no matching hub entry, or the cached `config_files` differ from the
  current context. Manual `R` in the UI also uses `/api/hard-restart`.
- On `mcphub.nvim` v6.2.0 (`163b3ad`), setup-time version validation accepts
  compatible patch versions (required `4.2.0`, running `4.2.1`), but
  `check_server()` used exact string equality. Patch
  `patches/mcphub.nvim/06-compatible-health-version-check.patch` fixes that by
  using `validation.validate_version()` for `/api/health` responses.
- Patch `patches/mcphub.nvim/07-confirm-hard-restart.patch` makes automatic
  startup hard restarts explicit. Config/cache mismatch prompts default to
  **connect to existing**; version mismatch defaults to cancel unless the user
  chooses hard restart. Manual `R` is explicit user intent and does not prompt.
- `/api/hard-restart` in `mcp-hub` used to set state to `restarting`, emit
  `SIGTERM`, then try to return JSON. If the process closed before curl
  received JSON, curl reported exit 56 (`Recv failure: Connection reset by
  peer`) even though shutdown had started. External patch
  `external-patches/mcp-hub/02-hard-restart-response-before-shutdown.patch`
  returns JSON first, then emits `SIGTERM` from the response `finish` hook.

**Extra bug exposed by restarts**: the `mcp-hub` `/mcp` endpoint cleanup path in
`src/mcp/server.js` attaches the same cleanup function to both `res.close` and
`transport.onclose`; cleanup calls `server.close()`. During mass disconnects
this can re-enter cleanup and produce `Maximum call stack size exceeded`, then
repeat the `'Unknown' client disconnected` log many times.

**Local prevention patch**:
`external-patches/mcp-hub/01-idempotent-endpoint-cleanup.patch` adds a
per-session cleanup guard and detaches both close handlers before calling
`server.close()`. It covers both `src/mcp/server.js` (`/mcp`) and
`src/mcp/proxy.js` (`/mcp-lean`). The patch applies cleanly to the local
`~/projects/mcp-hub` fork; rebuild `dist/cli.js` after applying because
`myAi.lua` prefers the dist CLI when it exists.

**Avoidance**:
- Keep profiles and workspace contexts on distinct ports. Current config uses
  main global `37373`, worktree global `37374`, and main workspace `47474`.
- Do not share one fixed workspace port across multiple different workspace
  config roots. Either disable workspace mode for stable CLI-agent ports, or
  let workspace mode choose/hash per-workspace ports when project-specific
  `.mcphub/servers.json` isolation matters.
- Avoid manual `R` while other Neovim/CLI clients are connected unless the
  goal is to replace the process. Manual `R` intentionally does not prompt; use
  server-level refresh/reconnect for normal MCP server capability changes.
- For the `Maximum call stack` issue, patch `mcp-hub` endpoint cleanup with an
  idempotent guard so close handlers run once per client connection.

### MCPHub logs: source and startup cost

**Log source**: lines shown in the MCPHub Logs tab are mostly server-side
`mcp-hub` logs relayed over `/api/events`, not Neovim plugin logs.

- `Server 'query-assist' requires authorization` is emitted by
  `MCPConnection:_handleUnauthorizedConnection()` in the Node hub when a remote
  MCP server returns an auth challenge.
- `<server> stderr: ... ExperimentalWarning` is stderr from the child stdio MCP
  server process, captured by `MCPConnection:_createStdioTransport()` and
  rebroadcast by the hub logger. The Node 23/npm CommonJS/ESM warning is from
  the spawned `npx` process, not from mcphub.nvim.

**Startup cost**:

- `mcp-hub` constructs a connection object for every configured server, but
  disabled servers return early in `MCPConnection.connect()` before env
  resolution or process spawn. Their cost should be config parsing plus object
  creation.
- Slow startup comes from enabled servers: stdio servers spawn `npx` packages and
  fetch capabilities, while remote HTTP/SSE servers perform auth/connect checks.
  A project `.mcphub/servers.json` can override a global disabled server; in this
  config, project-local `tavily` is enabled even if many global servers are
  disabled.
- Lowest-risk optimization is to keep heavy servers disabled by default and use
  `auto_toggle_mcp_servers` or the UI to enable on demand. Consequence: first
  use pays the startup delay and tools are unavailable until the server connects.
- Using Node LTS instead of Node 23 can remove the npm experimental warnings.
  Filtering stderr in the hub is possible, but it risks hiding real MCP server
  startup errors.

### Main view action keys stopped working after endpoint/agent patch

**Symptom**: In the MCPHub main view, `l` still expands/opens rows, but actions
such as `t` toggle and `e` edit stop working on server, native-server, tool,
resource, or prompt rows.

**Cause**: The endpoint/agent registry patch originally managed row-specific
actions by deleting buffer-local mappings on every cursor move:
`e`, `t`, `d`, `a`, `A`, `r`, `R`, plus endpoint-only keys. Those keys are also
normal main-view actions. When the cursor moved to a non endpoint/agent row, the
normal mappings were gone and were not recreated.

**Fix**: `patches/mcphub.nvim/08-main-view-keymap-dispatch.patch` keeps core
main-view keymaps registered and dispatches them by current row type.
Endpoint-only actions (`s`, `i`, `u`, `y`) are silent row-aware mappings
owned by the main view, so cursor movement no longer deletes keymaps.

**Server build dependency**: none. This fix is client-side only and does not
require rebuilding `~/projects/mcp-hub/dist/cli.js`.

### Endpoint inspector auth and copy keys

**Symptom**: Pressing `e` on an endpoint row can open MCP Inspector, but the
Inspector UI cannot call its proxy because MCP Inspector 0.21+ requires a proxy
session token. Endpoint `E` also duplicates config editing already available via
the MCPHub config view (`C`, then `e`).

**Fix**:

- `patches/mcphub.nvim/09-endpoint-inspector-auth-copy.patch` removes endpoint
  `E` and endpoint hover hints for `E:cfg`.
- `lua/utils/mcp_inspector.lua` now honors `MCP_PROXY_AUTH_TOKEN` or creates
  `~/.config/mcp-inspector/proxy-token`, starts Inspector with that token, and
  opens the browser URL with `MCP_PROXY_AUTH_TOKEN=<token>`.
- The helper sets `MCP_AUTO_OPEN_ENABLED=false` so Neovim controls the browser
  open instead of racing Inspector's own auto-open.
- `y` copies the current MCP row name; endpoint rows keep `y` as URL copy.
- `Y` copies the full row path. For tools this is `server_name .. "_" .. tool`,
  for example `gitlab_mr_get_merge_request`.

**Endpoint tool execution in UI**: executing the tools exposed by `/mcp` or
`/mcp-lean` inside the MCPHub main view is possible, but it is a separate
feature. Those endpoint rows are MCP client entrypoints, not normal hub-managed
server rows. The low-risk path is to use `e` to open MCP Inspector for endpoint
execution; a native tab/context switch would need an endpoint-client session and
capability view for `/mcp` or `/mcp-lean`.

**Server build dependency**: none. This fix is client-side plus local helper
behavior only and does not require rebuilding `~/projects/mcp-hub/dist/cli.js`.

**Suggested commit title**:
`mcphub: auth inspector endpoint links and add copy actions`.

### Configurable CLI agent profiles

**Use case**: Show and manage more than one profile for the same CLI agent. For
example, the alternate Claude profile at `/Users/tharutaipree/.claude-agd` has
its own `settings.json` and `.claude.json`, and `claude mcp ...` can target it
by running with `CLAUDE_CONFIG_DIR=/Users/tharutaipree/.claude-agd`.

PI is also supported as a profile entry in the local MCPHub UI config, but with
an important caveat: current PI builds do not expose `pi mcp add/remove/list`
CLI subcommands. The MCPHub CLI Agents panel can still show the PI profile and
jump to its config targets:

- `~/.pi/agent/settings.json`
- `~/dotfiles/ai/pi/settings.json`

The local PI MCPHub integration is handled by the installed `pi-mcphub-bridge`
extension package instead of native `pi mcp ...` registration commands. That
bridge connects PI to either `/mcp` or `/mcp-lean` and exposes tools inside PI
via `/mcph-on`, `/mcph-lean`, `/mcph-full`, `/mcph-off`, and `/mcph-tools`.

For config discovery in the local MCPHub UI, PI now supports both:
- user settings: `~/.pi/agent/settings.json`
- project-local settings: `./.pi/settings.json`

**Fix**:

- `patches/mcphub.nvim/10-configurable-agent-profiles.patch` makes the CLI
  Agents panel key rows by profile id instead of executable name.
- `lua/utils/mcphub_agents.lua` supports preset-backed profiles. Existing
  `{ name = "claude" }` configs still work.
- `claude-agd` is configured in `lua/plugins/extra/myAi.lua` as:

```lua
{
  id = "claude-agd",
  preset = "claude",
  label = "claude-agd",
  command = "claude",
  config_dir = "/Users/tharutaipree/.claude-agd",
  config_path = "/Users/tharutaipree/.claude-agd/settings.json",
  binding_flat = "mcphub",
  binding_lean = "mcphub-lean",
  scopes = { "user" },
}
```

- `a`/`A`/`t`/`d` act only on the selected profile row.
- Endpoint-row `r`/`u` use `ui.agent_registry.default_agent_id` and
  `default_scope`, so the default target remains explicit.
- `e` on `claude-agd` opens `/Users/tharutaipree/.claude-agd/settings.json`;
  MCP list/add/remove still go through the Claude CLI with `CLAUDE_CONFIG_DIR`.

**Server build dependency**: none. This fix is client-side plus local helper
behavior only and does not require rebuilding `~/projects/mcp-hub/dist/cli.js`.

**Suggested commit title**:
`mcphub: support configurable CLI agent profiles`.

### Cursor agent registry is config-only

Do not probe Cursor with `cursor mcp list` from the MCPHub UI.

Root cause found on 2026-07-07:

- The CLI Agents panel calls `utils.mcphub_agents.list()` during render.
- Cursor was configured as an agent profile, so render ran `cursor mcp list`.
- Cursor 3.10.17 supports `--add-mcp`, but not a `mcp list` subcommand.
- The Cursor shell wrapper routes non-`agent` invocations through the
  Electron-backed editor CLI, so `cursor mcp list` can open or foreground the
  Cursor app when `:MCPHub` is opened.

Fix:

- `lua/utils/mcphub_agents.lua` only shells out for known-safe CLI list
  presets.
- Cursor is treated as `config_list` and read from `~/.cursor/mcp.json`.
- Config-only rows expose `e` / configured alternate config shortcuts, but not
  `a`/`A`/`t`/`d`.

### Active capability copy and token estimates

**Copy behavior**:

- In an active tool or prompt view, `y` on an input row copies the current field
  value.
- `y` on the submit row copies the JSON form payload without running validation
  first. Tool values are schema-converted when valid and left raw when invalid,
  so it is useful for debugging partially filled forms.
- `y` on any rendered text result line copies the whole current result, not just
  the visible line under the cursor. The same result tracking applies to tool,
  prompt, resource, and resource-template outputs.

**Token estimates**:

- `patches/mcphub.nvim/11-copy-payload-token-counts.patch` shows approximate
  `~Nt` token counts on connected server rows and expanded tool rows.
- Server counts estimate `mcphub.utils.prompt.server_to_text(server)` after
  applying `disabled_tools`, `removed_tools`, and env regex tool filters.
- Tool counts estimate the tool description plus rendered input schema only
  while the tool is visible to prompts.
- Counts use the existing `utils.calculate_tokens()` approximation
  (`ceil(chars / 4)`), so they are prompt-size hints, not exact tokenizer
  counts.
- Display is controlled from `lua/plugins/extra/myAi.lua`:

```lua
token_counts = {
  enabled = true,
  servers = true,
  tools = true,
}
```

**MCP lean execution in UI**: still future work. `/mcp-lean` exposes the lean
meta-tools as an endpoint client surface, not as normal hub-managed server rows.
The current low-risk path remains endpoint `e` to open MCP Inspector. Native
execution inside MCPHub would need a separate endpoint-client capability context
or a tab that treats `/mcp` and `/mcp-lean` as client sessions.

**Server build dependency**: none. This fix is client-side only and does not
require rebuilding `~/projects/mcp-hub/dist/cli.js`.

**Suggested commit title**:
`mcphub: copy active payloads and show token estimates`.

### Environment variables not loaded

Use `global_env` in mcphub.nvim config:

```lua
require("mcphub").setup({
    global_env = {
        "GITLAB_TOKEN",
        "GLEANTOKEN",
    }
})
```

---

## Related Documentation

- [Neovim Integrations](mcphub-nvim-integrations.md) - CodeCompanion, Avante, CopilotChat setup
- [MCPHub.nvim Docs](https://ravitemer.github.io/mcphub.nvim/)
- [mcp-hub CLI](https://github.com/ravitemer/mcp-hub)
- [MCP Specification](https://modelcontextprotocol.io/)
