---
title: "Cursor Migration - AI Tools Container Setup"
status: "wip"
assignee: "ai"
created: 2026-01-28
priority: "medium"
category: "ai-tooling"
related:
  - [Project Dir](cursor-migration/)
  - [README](cursor-migration/README.md)
  - [Docker Compose](cursor-migration/docker-compose.yml)
  - [Dockerfile](cursor-migration/Dockerfile)
  - [Current Avante](lua/plugins/extra/avante.lua)
  - [CodeCompanion](lua/plugins/extra/codecompanion.lua)
---

## Objective

Explore and setup Cursor-like AI capabilities for Neovim via containerized environment with multiple profiles and persistent sessions.

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

## Available Profiles

| Profile | Command | Description |
|---------|---------|-------------|
| Standard | `make run` | Your existing config |
| Full | `make run-full` | All AI tools + MCP Hub |
| Minimal | `make run-minimal` | Base config only |
| Cursor | `make run-cursor` | Cursor CLI focus |
| GPU | `make run-gpu` | With Ollama local LLMs |

## Key Findings

1. **No official Cursor-Neovim plugin** - Community solutions only
2. **Best alternatives**:
   - `avante.nvim` (17k stars) - Already installed, enable Zen Mode
   - `goose.nvim` - Open-source agent from Block
   - `agentic.nvim` - Multi-provider ACP client
3. **Container approach** allows testing without polluting host config

## Tools compatability
- opencode (requires local sv run) : https://github.com/Nomadcxx/opencode-cursor

## Success Criteria

- [ ] Container builds and runs successfully
- [ ] Can edit files in /workspace from nvim
- [ ] AI tools (goose, aider) work inside container
- [ ] Plugin overlay system correctly merges extra plugins
- [ ] Sessions persist between container restarts

## User notes (DO NOT EDIT) 
### Refs
- https://cursor.com/docs/cli/acp#ide-integrations

### Quota comparison
Agoda License:
- Copilot - 300 interactions / mo
- Cursor - 500 interactions + 250$ credit / mo 

### Findings
- Sidekick NES only integrates copilot

### Alternatives for completion
https://github.com/cursortab/cursortab.nvim#providers
- allow llama.cpp local models qwen 0.8B local fast (not sure about multiple instances RAM perf)

