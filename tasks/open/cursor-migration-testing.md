---
title: "Test Cursor Migration Container Setup"
status: "open"
assignee: "user"
created: 2026-01-28
priority: "medium"
parent:
  - [Cursor Migration Project](tasks/projects/cursor-migration.md)
related:
  - [Project Dir](cursor-migration/)
  - [Makefile](cursor-migration/Makefile)
---

## Objective

User verification of the cursor-migration container setup.

## Prerequisites

```bash
# 1. Copy and configure environment
cd cursor-migration
cp .env.example .env
# Edit .env with your API keys
```

## Verification Checklist

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

## Quick Test Script

```bash
cd cursor-migration

# Build
make build

# Quick test
make run
# Inside nvim:
#   :Lazy          - verify plugins
#   :e /workspace  - verify workspace mount
#   :q

# Test goose
make goose
# Type: "hello" then Ctrl+C to exit
```

## Notes

- GPU profile requires NVIDIA drivers
- Cursor profile requires ~/.cursor credentials
- First run will install plugins (may take a moment)
