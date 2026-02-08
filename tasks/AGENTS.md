# AGENTS.md - Neovim Configuration Repository Guide

Welcome! This guide documents everything you need to know to work effectively in this Neovim configuration repository.

## Project Overview

**tiny-nvim**: A lightweight Neovim configuration for Neovim 0.11+ emphasizing:
- Minimal, essential plugins only
- Leveraging Neovim's built-in LSP (no lspconfig dependency)
- Fast startup times
- Focus on AI tool integration (CodeCompanion, Avante, CopilotChat, MCPHub)

**Type**: Neovim Lua configuration (not a library/application)
**Key Language**: Lua (vim scripting)
**Target**: Neovim 0.11+

## Directory Structure

```
├── init.lua                    # Main entry point
├── lua/
│   ├── config/                # Core configuration
│   │   ├── options.lua        # Vim options (read-only upstream)
│   │   ├── myopts.lua         # Personal overrides
│   │   ├── keymaps.lua        # Core keymaps (read-only upstream)
│   │   ├── mykeymaps.lua      # Personal keymaps
│   │   ├── autocmds.lua       # Core autocommands (read-only upstream)
│   │   ├── myautocmds.lua     # Personal autocommands
│   │   ├── lazy.lua           # Plugin manager setup
│   │   └── project.lua        # Project-specific config loading
│   ├── plugins/               # Plugin specifications (read-only upstream)
│   │   ├── extra/             # Personal plugin overrides and config
│   │   │   ├── my*.lua        # Personal plugin configs (preferred pattern)
│   │   │   └── tmp_*.lua      # Temporary POC files (clean up later)
│   │   └── *.lua              # Upstream plugin specs (don't modify)
│   ├── utils/                 # Shared utilities and helpers
│   ├── langs/                 # Language-specific settings
│   └── overseer/              # Overseer task configuration
├── docs/
│   ├── memory/                # Plugin-specific documentation and troubleshooting
│   │   └── *.md               # Living documentation (constantly updated)
│   ├── task_tracking.md       # Task workflow and format specification
│   └── tasks/                 # Deprecated, use tasks/ instead
├── tasks/                     # Task management system (CRITICAL - see below)
│   ├── projects/              # Long-running projects with dedicated dirs
│   ├── open/                  # Tasks ready to work on
│   ├── wip/                   # Work in progress
│   ├── review/                # Completed, awaiting user verification
│   ├── done/                  # Verified and completed
│   └── drafts/                # Ideas and planning
├── scripts/
│   └── install-tools.sh       # Required tools installation
├── tests/                     # Debug utilities (minimal)
├── cursor-migration/          # Separate project for Cursor-like AI setup
├── .crushrc                   # Crush agent configuration
├── .claude/                   # Claude Code session data
├── .luarc.json               # Lua LSP configuration
├── CLAUDE.md                 # Editing and coding guidelines
├── README.md                 # User-facing documentation
└── biome.json                # JavaScript/TypeScript formatter config
```

## Critical Concepts

### Plugin Organization

1. **Read-only plugins**: `lua/plugins/*.lua` - Don't modify directly
2. **Personal overrides**: `lua/plugins/extra/my*.lua` - Preferred location for customizations
   - Follow pattern: `my<group_name>.lua` or `my<plugin_name>.lua`
   - Example: `myAi.lua`, `myCoding.lua`
3. **Temporary POCs**: `lua/plugins/extra/tmp_*.lua` - Clean up after testing
4. **Config imports**: Added to relevant entry point (e.g., `config/mykeymaps.lua` imports `plugins/extra/mykeymaps.lua`)

### File Naming Conventions

- **Personal files**: Prefix with `my` (e.g., `myAi.lua`, `myopts.lua`)
- **Temporary files**: Prefix with `tmp_` (e.g., `tmp_feature_test.lua`)
- **Memory docs**: Lowercase with dashes (e.g., `codecompanion.md`, `mcphub.md`)

### Lua Code Style

- **Column width**: 120 characters (see `.stylua.toml`)
- **Indentation**: 2 spaces (no tabs)
- **Line endings**: Unix (LF)
- **Quotes**: Auto-prefer double quotes
- **Call parentheses**: None (style: `func{...}` not `func({...})`)
- **Formatter**: Use `stylua` (installed by `scripts/install-tools.sh`)

Example formatting:
```lua
-- Good
return {
  {
    "plugin/name",
    opts = {
      key = "value",
    },
    config = function(_, opts)
      -- Implementation
    end,
  },
}
```

## Task Management Workflow

### Structure

```
tasks/
├── projects/      # Long-running projects (status in file frontmatter)
├── open/          # Ready to work on
├── wip/           # Work in progress
├── review/        # Awaiting user verification
├── done/          # Verified and completed
└── drafts/        # Ideas and planning
```

### Key Rules

1. **Link Format**: Use paths **relative to git root WITHOUT `../` prefix**
   - ✓ Correct: `[File](lua/utils/snacks_actions.lua)`
   - ✗ Wrong: `[File](../../lua/utils/snacks_actions.lua)`

2. **File Frontmatter**: Required for task and project files
   ```markdown
   ---
   title: "Task description"
   status: "open|wip|review|done|draft"
   assignee: "ai|user"
   created: 2026-01-24
   priority: "high|medium|low"
   ---
   ```

3. **Workflow**:
   - User creates task in `tasks/drafts/` or `tasks/open/`
   - Move to `tasks/wip/` when starting work
   - Move to `tasks/review/` when completed for verification
   - User moves to `tasks/done/` after verification (never do this yourself)

4. **Documentation**: See `docs/task_tracking.md` for full details

## Essential Commands

### Running & Development

| Task | Command | Notes |
|------|---------|-------|
| Start Neovim | `NVIM_APPNAME=nvim3_jelly_tinynvim nvim` | Custom app name uses separate config |
| Install tools | `./scripts/install-tools.sh` | Run after cloning |
| Install plugins | `NVIM_APPNAME=nvim3_jelly_tinynvim nvim --headless -c "Lazy install" -c "qa"` | Lazy plugin manager |
| Update plugins | `NVIM_APPNAME=nvim3_jelly_tinynvim nvim --headless -c "Lazy update" -c "qa"` | Check updates |
| Format Lua | `stylua lua/` | Use stylua (120 col, 2 space indent) |
| Check LSP | `:LspInfo` | View active LSP servers |
| Plugin info | `:Lazy` | See installed plugins and their status |

### Key Keybinds (Work Context)

| Keymap | Action | File |
|--------|--------|------|
| `<leader>ah` | MCPHub UI | `lua/plugins/extra/myAi.lua` |
| `<leader>ca` | CodeCompanion chat | `lua/plugins/extra/codecompanion.lua` |
| `:MCPHub` | MCP server management | MCPHub UI command |
| `:CCToggle` | Toggle CodeCompanion | CodeCompanion command |

## Code Patterns & Conventions

### Plugin Configuration Pattern

```lua
-- lua/plugins/extra/my<plugin>.lua
return {
  {
    "plugin/namespace",
    -- Lazy.nvim setup
    event = "VeryLazy",
    keys = { ... },
    opts = {
      -- Options passed to plugin.setup()
    },
    config = function(_, opts)
      local plugin = require "plugin"
      plugin.setup(opts)
      -- Custom config/hooks
    end,
  },
}
```

### LSP Setup Pattern

Built-in LSP (Neovim 0.11+). See `init.lua:35-45`:
```lua
vim.lsp.enable {
  "ts_ls",     -- TypeScript/JavaScript
  "lua_ls",    -- Lua
  "biome",     -- Formatter/linter
  "pyright",   -- Python
  "gopls",     -- Go
}
```

### Comment Style

- Use `--` for single-line comments
- Document plugins with URLs to source or documentation
- Don't remove code comments unless obsolete (per CLAUDE.md)
- Focus on `why` not `what` (implementation is obvious from code)

## Important Gotchas & Non-Obvious Patterns

### Workspace Mode & MCPHub

**Issue**: MCPHub's workspace mode creates per-directory hubs with dynamic ports.
**Solution**: Disable workspace mode in `lua/plugins/extra/myAi.lua`:
```lua
opts = {
  port = 37373,
  workspace = {
    enabled = false,  -- Consistent port for CLI agents
  },
}
```
**Reason**: CLI agents (Claude Code, etc.) need a fixed port.

### Plugin Config Merging

Lazy.nvim deep-merges Lua tables, but **functions don't merge** - the last one wins.
- For function-heavy customization: Create separate `my*.lua` file
- For table overrides: Can nest in `lua/plugins/extra/`
- Reference: `docs/memory/lazy-nvim-config-merging.md`

### Project-Specific Config

Neovim loads `.nvim-config.lua` from the working directory (if present).
- Useful for project-specific LSP settings
- Not tracked by git (add to `.gitignore`)
- Loaded with `pcall` to prevent startup errors

### AI Tool Integration

Three main AI interfaces:
1. **CodeCompanion** (`lua/plugins/extra/codecompanion.lua`) - Local models + API adapters
2. **Avante** (`lua/plugins/extra/avante.lua`) - Chat interface
3. **CopilotChat** (`lua/plugins/extra/copilot-chat.lua`) - GitHub Copilot

**MCPHub** (`lua/plugins/extra/myAi.lua`) - MCP server orchestration for all three
- Reference: `docs/memory/mcphub.md`

## Editing Guidelines (from CLAUDE.md)

1. **Don't remove code comments** - Preserve knowledge unless obsolete
2. **Avoid editing `lua/plugins/*.lua`** directly - Use `lua/plugins/extra/my*.lua` instead
3. **Config merging**: If deep merging isn't possible (e.g., with functions), move custom code to `lua/plugins/extra/` or `lua/utils/`
4. **When working with plugins**: Watch for common issues and document solutions in `docs/memory/<plugin>.md`
5. **Task file links**: Always use relative paths from git root without `../`
6. **Keep CLAUDE.md updated**: Regularly add new patterns, gotchas, and solutions discovered

## Documentation (Living Memory)

The `docs/memory/` directory contains plugin-specific documentation:

- **codecompanion.md** - Setup, adapters, debugging
- **avante.md** - Avante chat configuration
- **mcphub.md** - MCPHub architecture and server customization
- **mcphub-nvim-integrations.md** - CodeCompanion, Avante, CopilotChat integration
- **gitsigns.md** - Gitsigns keybindings and configuration
- **neotree.md** - Neotree file explorer settings
- **lazy-nvim-config-merging.md** - How Lazy.nvim merges configurations
- **keybindings_conflicts.md** - Known keymap conflicts

**Keep these updated** as you discover patterns and issues.

## Testing & Verification

### Manual Testing

1. **Start fresh**:
   ```bash
   NVIM_APPNAME=nvim3_jelly_tinynvim nvim
   ```

2. **Check plugin status**:
   ```vim
   :Lazy        " See all plugins and their load status
   :LspInfo      " View active LSP servers
   :MCPHub       " Inspect MCP servers (if integrated)
   ```

3. **Verify keybinds**:
   - Test critical keymaps manually
   - Check for conflicts: `:map <leader>` lists all leader-prefixed maps

### Headless Testing

Useful for scripted verification:
```bash
NVIM_APPNAME=nvim3_jelly_tinynvim nvim --headless \
  -c "Lazy install" \
  -c "Lazy check" \
  -c "qa"
```

## Common Workflows

### Adding a New Personal Plugin Override

1. Create `lua/plugins/extra/my<plugin>.lua`:
```lua
return {
  {
    "plugin/name",
    event = "VeryLazy",
    opts = { ... },
    config = function(_, opts)
      require("plugin").setup(opts)
    end,
  },
}
```

2. Import in appropriate config file (if not auto-discovered)
   - Keymaps → `config/mykeymaps.lua`
   - Options → `config/myopts.lua`
   - Autocommands → `config/myautocmds.lua`

3. Test:
```bash
NVIM_APPNAME=nvim3_jelly_tinynvim nvim
```

4. Format:
```bash
stylua lua/plugins/extra/my<plugin>.lua
```

### Adding Plugin Documentation

1. Create `docs/memory/<plugin>.md`
2. Include:
   - Overview and purpose
   - Key gotchas or non-obvious patterns
   - Configuration details
   - Troubleshooting tips
3. Link from relevant task files
4. Keep updated as you learn more

### Updating Task Status

1. Change `status:` in file frontmatter
2. Move file to corresponding folder (`open/`, `wip/`, `review/`, `done/`)
3. Link related files from task (using relative paths, no `../`)

## Integration Points

### MCPHub (AI Server Orchestration)

Port: `37373` (fixed when workspace mode disabled)
Config: `~/dotfiles/claude/mcp-proxy/mcphub.json`
Neovim UI: `:MCPHub`

14 MCP servers configured:
- neovim (Neovim integration)
- filesystem (File operations)
- git (Git operations)
- python, node, ruby (Language-specific tools)
- etc.

Reference: `docs/memory/mcphub.md`

### Cursor Migration Project

Separate containerized environment for testing Cursor-like AI capabilities.
Location: `cursor-migration/`
Profiles: minimal, standard, full, gpu, cursor
Reference: `tasks/projects/cursor-migration.md`

## External Dependencies

Installed via `scripts/install-tools.sh`:

- **ripgrep** (`rg`) - Fast grep for searching
- **fd** - Fast find alternative
- **stylua** - Lua formatter
- **shellcheck** - Shell script linter
- **gopls**, **pyright**, **lua_ls**, **ts_ls** - LSP servers
- **node** - JavaScript runtime (various plugins depend on it)

## Git & Version Control

- Repository is git-tracked
- **Don't modify**: Core plugin specs (`lua/plugins/*.lua`)
- **Do modify**: Personal files (`lua/plugins/extra/my*.lua`, `config/my*.lua`)
- Use `.nvim-config.lua` for project-specific settings (not tracked)
- Task files are tracked but status managed via folder structure

## Quick Reference

| Need | Where | Action |
|------|-------|--------|
| Add plugin override | `lua/plugins/extra/my*.lua` | Create new file or edit existing |
| Add keymap | `config/mykeymaps.lua` | Edit or create `my` variant |
| Add autocommand | `config/myautocmds.lua` | Edit or create |
| Document pattern | `docs/memory/<plugin>.md` | Create or update |
| Report issue | Create task in `tasks/open/` | File with clear steps |
| Test changes | `NVIM_APPNAME=nvim3_jelly_tinynvim nvim` | Run and verify |
| Format code | `stylua lua/` | Run before committing |

## Key Contacts & Resources

- **Project**: https://github.com/jellydn/tiny-nvim
- **Author**: jellydn
- **Docs**: `README.md` (user-facing), `docs/` (technical)
- **Tasks**: `tasks/` folder with status-based subfolders

---

**Last Updated**: 2026-02-05
**For questions or improvements**: Check `docs/memory/` first, then review task files in `tasks/`
