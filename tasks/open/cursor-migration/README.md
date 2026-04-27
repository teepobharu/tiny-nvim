---
title: "Cursor Migration - AI Tools Container Setup"
status: "wip"
assignee: "ai"
created: 2026-01-28
priority: "medium"
category: "ai-tooling"
related:
  - [Docker Compose](tasks/open/cursor-migration/docker-compose.yml)
  - [Dockerfile](tasks/open/cursor-migration/Dockerfile)
  - [Current Avante](lua/plugins/extra/avante.lua)
  - [CodeCompanion](lua/plugins/extra/codecompanion.lua)
---

## Objective

Explore and setup Cursor-like AI capabilities for Neovim via containerized environment with multiple profiles and persistent sessions.

## Investigation scope

*New*
- Find alternatives for nvim plugins copilot.vim auto completion suggestion for cursor
  - compare completion free usage on copilot vs cursor
- code companion cursor integration and model selection for the cursor adapater / provider vs copilot

*Done*

## Checklist

### Setup Phase
- [x] Research Cursor-Neovim integration options
- [x] Create Docker container with AI CLIs
- [x] Setup plugin overlay system
- [x] Configure multiple profiles (minimal, standard, full, cursor)
- [x] Add host integrations (git, ssh, clipboard)
- [x] Setup persistent volumes for sessions

### Testing Phase
- [ ] Build container: `make build`
- [ ] Test standard profile: `make run`
- [ ] Test full profile: `make run-full`
- [ ] Test GPU profile: `make run-gpu` (if NVIDIA available)
- [ ] Verify plugin overlay works
- [ ] Test goose CLI: `make goose`

### Integration Phase
- [ ] Decide which plugins to adopt (goose.lua, agentic.lua)
- [ ] Copy chosen plugins to lua/plugins/extra/
- [ ] Configure keybindings
- [ ] Update docs/memory/avante.md with learnings

## Key Findings

1. **No official Cursor-Neovim plugin** - Community solutions only
2. **Best alternatives**:
   - `avante.nvim` (17k stars) - Already installed, enable Zen Mode
   - `goose.nvim` - Open-source agent from Block
   - `agentic.nvim` - Multi-provider ACP client
3. **Container approach** allows testing without polluting host config

## Tools compatibility
- opencode (requires local sv run): https://github.com/Nomadcxx/opencode-cursor

## User notes (DO NOT EDIT)
### Refs
- https://cursor.com/docs/cli/acp#ide-integrations
Nvim plugins
- https://github.com/milanglacier/minuet-ai.nvim
  - rich integration: profile and endpoint configure ollama / llama.cpp, support preset with openai compatible
  - try with openai provider : https://github.com/milanglacier/minuet-ai.nvim#openai
- llama only ? https://github.com/ggml-org/llama.vim

### Quota comparison
Agoda License:
- Copilot - 300 interactions / mo
- Cursor - 500 interactions + 250$ credit / mo

### Findings
- Sidekick NES only integrates copilot

### Alternatives for completion
https://github.com/cursortab/cursortab.nvim#providers
- allow llama.cpp local models qwen 0.8B local fast (not sure about multiple instances RAM perf)

---

## Migration Options

| Approach | Plugin | Stars | Status |
|----------|--------|-------|--------|
| Direct CLI wrapper | `cursor-agent.nvim` | 49 | Active |
| ACP multi-provider | `agentic.nvim` | 162 | Active |
| Full Cursor-like UX | `avante.nvim` | 17.2k | **Recommended** |
| Open-source agent | `goose.nvim` | 304 | Active |

### Option 1: Enhance Existing Avante (Minimal Change)

```lua
-- lua/plugins/extra/avante.lua enhancements
{
  "yetone/avante.nvim",
  opts = {
    provider = "claude",
    auto_suggestions_provider = "copilot",
    behaviour = {
      auto_apply_diff_after_generation = true,
      support_paste_from_clipboard = true,
    },
  },
}
```

### Option 2: cursor-agent.nvim (Direct Cursor CLI)

Requires Cursor Pro subscription and CLI. See `sample-plugins/cursor-agent.lua`.

### Option 3: agentic.nvim (Multi-Provider ACP)

Supports Claude, Gemini, Cursor, Codex. See `sample-plugins/agentic.lua`.

### Option 4: goose.nvim (Open-Source)

Uses Block's Goose AI agent. See `sample-plugins/goose.lua`.

## Quick Start

```bash
cd tasks/open/cursor-migration
cp .env.example .env
# Edit .env with API keys

make build        # Build container
make run          # Standard profile
make run-full     # All AI tools + MCP Hub
make run-minimal  # Base config only
make run-cursor   # Cursor CLI focus
make run-gpu      # With Ollama local LLMs
```

## Project Structure

```
cursor-migration/
├── Dockerfile            # Neovim + AI CLIs (goose, aider, cursor-acp)
├── docker-compose.yml    # Multi-profile container stack
├── Makefile              # Convenience commands
├── entrypoint.sh         # Plugin overlay system
├── configs/
│   ├── goose-config.yaml # Goose agent settings
│   ├── mcp-servers.json  # MCP Hub config
│   └── .cursorrules      # Cursor rules example
└── sample-plugins/
    ├── agentic.lua       # Multi-provider ACP
    ├── goose.lua         # Open-source agent
    ├── cursor-agent.lua  # Direct Cursor CLI
    └── avante-enhanced.lua
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

---

## Verification (User)

Prerequisites:

```bash
cd tasks/open/cursor-migration
cp .env.example .env
# Edit .env with your API keys
```

### Build & Run
- [ ] `make build` - Container builds without errors
- [ ] `make run` - Opens nvim with your config
- [ ] Plugins load correctly (check `:Lazy`)
- [ ] Exit nvim cleanly

### Profiles
- [ ] `make run-minimal` - Opens minimal config
- [ ] `make run-full` - Opens with all AI tools
- [ ] Plugin overlay visible in `lua/plugins/extra/`

### AI Tools
- [ ] `make goose` - Goose CLI starts
- [ ] `make shell` - Can access container shell
- [ ] `make mcp` - MCP Hub starts on :5555

### Host Integration
- [ ] Git operations work inside container
- [ ] Can edit files in /workspace
- [ ] Changes persist after container restart
