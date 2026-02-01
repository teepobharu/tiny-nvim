# MCPHub - Architecture & CLI Integration Guide

## Project Disambiguation

**Two separate projects** exist with confusingly similar names:

| Aspect | **mcp-hub** (ravitemer) | MCPHub (samanhappy) |
|--------|-------------------------|---------------------|
| GitHub | [ravitemer/mcp-hub](https://github.com/ravitemer/mcp-hub) | [samanhappy/mcphub](https://github.com/samanhappy/mcphub) |
| Type | npm CLI / Node.js | Docker container |
| Web UI | No | Yes |
| Default Port | 37373 (nvim) / 5555 (standalone) | 3000 |
| Config Format | `mcphub.json` / `servers.json` | `mcp_settings.json` |
| Neovim Plugin | [mcphub.nvim](https://github.com/ravitemer/mcphub.nvim) | None |

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

| Option | Default | Description |
|--------|---------|-------------|
| `port` | 37373 | Port mcp-hub listens on |
| `workspace.enabled` | true | **Disable for CLI agents** - creates per-directory hubs on random ports |
| `shutdown_delay` | 5 minutes | Time to wait after last client disconnects |
| `server_url` | nil | Override endpoint (for remote mcp-hub) |

### Workspace Mode Warning

**If CLI agents can't connect to port 37373:**
- Workspace mode (enabled by default) creates per-directory hubs on ports 40000-41000
- Add `workspace = { enabled = false }` to use consistent port 37373

### Port Collision Behavior

**When mcphub.nvim starts, it checks port 37373:**

| Scenario | Behavior |
|----------|----------|
| **Port free** | Starts new mcp-hub server |
| **Port in use by mcp-hub (same version)** | Connects to existing server (multi-instance) |
| **Port in use by mcp-hub (different version)** | Shows "version mismatch", restarts hub |
| **Port in use by other service** | Shows "Port in use by non-MCP Hub server" error |

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
      "timeout": 10000
    }
  }
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

| Question | Answer |
|----------|--------|
| Can CLI agents use mcp-hub without Neovim? | **Yes**, if mcp-hub is already running |
| Do CLI agents keep mcp-hub alive? | **Yes**, they are clients like Neovim |
| What if Neovim started mcp-hub then closed? | mcp-hub runs until `shutdown_delay` expires |
| Can I run mcp-hub independently? | **Yes**, see "Running mcp-hub Standalone" below |

---

## Running mcp-hub Standalone

For CLI agents to always have access (without Neovim), run mcp-hub independently:

### Option 1: Manual Start

```bash
# Install globally
npm install -g mcp-hub

# Start with your config
mcp-hub --config ~/dotfiles/claude/mcp-proxy/mcphub.json --port 37373 --watch
```

### Option 2: Using start-mcphub.sh

```bash
cd ~/dotfiles/claude/mcp-proxy

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

| Key | View |
|-----|------|
| `H` | Home/Main view |
| `M` | Marketplace |
| `C` | Config |
| `L` | Logs |
| `?` | Help |
| `q` | Close |
| `r` | Refresh |
| `R` | Restart mcp-hub |

### Main View Keys

| Key | Action |
|-----|--------|
| `l` / `<CR>` | Expand server |
| `h` / `<Esc>` | Collapse |
| `t` | Toggle server on/off |
| `a` | Toggle auto-approve |
| `ga` | Toggle global auto-approve |
| `A` | Add server |
| `e` | Edit server |
| `d` | Delete server |

---

## Configuration Files

| File | Purpose |
|------|---------|
| `~/dotfiles/claude/mcp-proxy/mcphub.json` | MCP server definitions |
| `~/dotfiles/claude/mcp-proxy/.env` | Environment variables |
| `~/dotfiles/claude/mcp-proxy/start-mcphub.sh` | Management script |
| `lua/plugins/extra/myAi.lua` | MCPHub + CodeCompanion MCP extension config |

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

| Field | Type | Description |
|-------|------|-------------|
| `disabled` | boolean | Disable server entirely |
| `disabled_tools` | string[] | Tools to hide from LLMs |
| `disabled_resources` | string[] | Resources to hide |
| `disabled_resourceTemplates` | string[] | Resource templates to hide |
| `autoApprove` | boolean \| string[] | Auto-approve tools without confirmation |
| `custom_instructions` | object | Per-server instructions for LLMs |

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
