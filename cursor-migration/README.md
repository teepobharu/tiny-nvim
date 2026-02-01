# Cursor Migration Guide for Neovim

## Overview

This guide explores migrating from GitHub Copilot to Cursor-like AI capabilities in Neovim.

**Key Finding**: There's no official Cursor plugin for Neovim. Community solutions exist:

| Approach | Plugin | Stars | Status |
|----------|--------|-------|--------|
| Direct CLI wrapper | `cursor-agent.nvim` | 49 | Active |
| ACP multi-provider | `agentic.nvim` | 162 | Active |
| Full Cursor-like UX | `avante.nvim` | 17.2k | **Recommended** |
| Open-source agent | `goose.nvim` | 304 | Active |

## Current AI Stack (This Config)

```
lua/plugins/
├── coding.lua           # blink.cmp + copilot.vim (autocomplete)
├── claude-code.lua      # Claude Code CLI integration
├── extra/
│   ├── avante.lua       # Cursor-like sidebar (already installed!)
│   ├── codecompanion.lua # AI chat with multi-adapter
│   └── mcphub.lua       # MCP server hub
```

## Recommended Migration Path

### Option 1: Enhance Existing Avante (Minimal Change)

You already have `avante.nvim` - enable more Cursor-like features:

```lua
-- lua/plugins/extra/avante.lua enhancements
{
  "yetone/avante.nvim",
  opts = {
    provider = "claude",  -- or "copilot" for GitHub models
    auto_suggestions_provider = "copilot",  -- Tab completions
    behaviour = {
      auto_apply_diff_after_generation = true,  -- Auto-apply changes
      support_paste_from_clipboard = true,
    },
    -- Enable Zen Mode for CLI-like experience
    -- Usage: :lua require("avante.api").zen_mode()
  },
}
```

### Option 2: Add cursor-agent.nvim (Direct Cursor CLI)

Requires Cursor Pro subscription and CLI installed:

```lua
-- lua/plugins/extra/cursor-agent.lua
return {
  "xTacobaco/cursor-agent.nvim",
  cmd = { "CursorAgent", "CursorAgentSelection", "CursorAgentBuffer" },
  keys = {
    { "<leader>aC", "<cmd>CursorAgent<cr>", desc = "Cursor Agent" },
    { "<leader>aCs", "<cmd>CursorAgentSelection<cr>", mode = "v", desc = "Send selection to Cursor" },
  },
  config = function()
    require("cursor-agent").setup({
      cmd = "cursor-agent",  -- Must be in PATH
    })
  end,
}
```

### Option 3: agentic.nvim (Multi-Provider ACP)

Supports Claude, Gemini, Cursor, Codex, and more:

```lua
-- lua/plugins/extra/agentic.lua
return {
  "carlos-algms/agentic.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  keys = {
    { "<C-\\>", function() require("agentic").toggle() end, mode = { "n", "v", "i" }, desc = "Toggle Agentic" },
    { "<leader>aG", function() require("agentic").toggle() end, desc = "Agentic Agent" },
  },
  opts = {
    provider = "claude",  -- or "cursor-acp" for Cursor Agent
    -- For Cursor: npm i -g @blowmage/cursor-agent-acp
  },
}
```

### Option 4: goose.nvim (Open-Source Alternative)

Uses Block's Goose AI agent (fully open-source):

```lua
-- lua/plugins/extra/goose.lua
return {
  "azorng/goose.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  cmd = { "Goose", "GooseToggle" },
  keys = {
    { "<leader>aG", "<cmd>GooseToggle<cr>", desc = "Toggle Goose" },
    { "<leader>aGc", "<cmd>GooseContext<cr>", desc = "Goose Context" },
  },
  config = function()
    require("goose").setup({
      -- Requires: goose CLI from https://github.com/block/goose
    })
  end,
}
```

## Docker Services

See `docker-compose.yml` for:
- **goose**: Open-source AI agent container
- **mcp-hub**: MCP server orchestration
- **ollama**: Local LLM for offline use

## Cursor MCP Configuration

If using Cursor IDE alongside Neovim, share MCP config:

```bash
# Link Neovim MCPHub config to Cursor
ln -sf ~/.config/nvim/lua/plugins/extra/mcphub.json ~/.cursor/mcp.json
```

## Feature Comparison

| Feature | Copilot | Cursor | Avante | CodeCompanion |
|---------|---------|--------|--------|---------------|
| Inline completion | ✅ | ✅ | ✅ | ❌ |
| Chat sidebar | ✅ | ✅ | ✅ | ✅ |
| Agentic mode | ✅ | ✅ | ✅ | ✅ |
| Plan mode | ❌ | ✅ | ✅ | ❌ |
| MCP support | ❌ | ✅ | ✅ | ✅ |
| Price | $10/mo | $20/mo | Free | Free |

## Keybinding Strategy

Current AI prefixes in this config:
- `<leader>a` - CodeCompanion actions
- `<leader>r` - Avante/Refactoring
- `<leader>C` - Claude Code

Suggested additions:
- `<leader>aG` - Goose/Agentic toggle
- `<leader>aC` - Cursor Agent
- `<C-\>` - Quick agent toggle (agentic.nvim style)

## Files in This Directory

```
cursor-migration/
├── README.md                  # This file
├── docker-compose.yml         # Container services (goose, mcp-hub, ollama)
├── .env.example               # Environment variables template
├── .gitignore                 # Ignore .env and local files
├── configs/
│   ├── cursor-mcp.json        # Cursor IDE MCP config example
│   ├── mcp-servers.json       # MCP Hub server config (Docker)
│   ├── goose-config.yaml      # Goose agent configuration
│   └── .cursorrules           # Cursor rules file example
└── sample-plugins/
    ├── cursor-agent.lua       # Direct Cursor CLI wrapper
    ├── agentic.lua            # Multi-provider ACP client
    ├── goose.lua              # Open-source Goose agent
    └── avante-enhanced.lua    # Enhanced avante.nvim config
```

## Quick Start

```bash
cd cursor-migration

# 1. Setup environment
cp .env.example .env
# Edit .env with your API keys (ANTHROPIC_API_KEY, etc.)

# 2. Build the container
make build

# 3. Run Neovim (choose a profile)
make run          # Standard: your config + avante/codecompanion
make run-full     # Full: all AI tools + MCP Hub
make run-minimal  # Minimal: base config only
make run-cursor   # Cursor: Cursor CLI focus
make run-gpu      # GPU: with local Ollama LLMs
```

## Container Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Docker Container (nvim-ai)                    │
├─────────────────────────────────────────────────────────────────┤
│  Neovim + Your Config (read-only mount)                         │
│    └── /root/.config/nvim ← ../  (your nvim config)             │
│                                                                  │
│  Plugin Overlay System                                           │
│    └── /nvim-overlay/lua/plugins ← ./sample-plugins/            │
│    └── Merged into lua/plugins/extra/ at startup                │
│                                                                  │
│  AI CLI Tools (pre-installed)                                    │
│    ├── goose          (Block's open-source agent)               │
│    ├── cursor-agent-acp (Cursor ACP bridge)                     │
│    ├── claude-code    (Claude CLI)                              │
│    ├── aider          (AI pair programming)                     │
│    └── mcp-hub        (MCP server orchestration)                │
│                                                                  │
│  Persistent Volumes                                              │
│    ├── nvim-data      (plugins, lazy.nvim cache)                │
│    ├── goose-sessions (chat history)                            │
│    └── mcp-data       (MCP state)                               │
├─────────────────────────────────────────────────────────────────┤
│  Host Integrations                                               │
│    ├── ~/.gitconfig   → Git identity                            │
│    ├── ~/.ssh         → SSH keys for git                        │
│    ├── ~/.cursor      → Cursor credentials (cursor profile)     │
│    └── $PROJECT_DIR   → /workspace                              │
└─────────────────────────────────────────────────────────────────┘
```

## Profiles

| Profile | Command | Description |
|---------|---------|-------------|
| `nvim` | `make run` | Standard - your existing config |
| `nvim-full` | `make run-full` | All AI tools + MCP Hub on :5555 |
| `nvim-minimal` | `make run-minimal` | Base config, no AI overlays |
| `nvim-cursor` | `make run-cursor` | Cursor CLI tools focus |
| `nvim-local` | `make run-gpu` | With Ollama local LLMs (GPU) |

## SSH Agent Forwarding

For git operations inside container:

```bash
# macOS/Linux
make run-ssh

# Or manually
docker compose run --rm \
  -e SSH_AUTH_SOCK=/ssh-agent \
  -v $SSH_AUTH_SOCK:/ssh-agent \
  nvim
```

## GPU Support (Local LLMs)

```bash
# Start Ollama with GPU
docker compose --profile gpu up -d ollama

# Pull models
make pull-models

# Run nvim with Ollama integration
make run-gpu
```

## Plugin Overlay System

Extra plugins in `sample-plugins/` are automatically merged at container startup:

```bash
# To add a new AI plugin:
cp my-plugin.lua sample-plugins/

# It will appear in lua/plugins/extra/ inside the container
# Profile controls which overlays are applied
```

## Direct Tool Access

```bash
make goose    # Goose AI agent
make aider    # Aider pair programming
make shell    # Shell inside container
make mcp      # Start MCP Hub server
```
