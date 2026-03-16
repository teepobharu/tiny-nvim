# AGENTS.md — Neovim Config Agent Guide

## Project Overview

Lightweight Neovim 0.11+ config forked from `jellydn/tiny-nvim`. Focus: minimal plugins, built-in LSP, fast startup, AI tool integration (CodeCompanion, Avante, CopilotChat, MCPHub).

**Language**: Lua | **Formatter**: `stylua` (120 col, 2-space indent) | **Key config**: `lua/plugins/extra/my*.lua`

## Directory Structure

```
├── init.lua
├── lua/
│   ├── config/         # options, keymaps, autocmds (my*.lua = personal overrides)
│   ├── plugins/        # upstream specs (read-only); extra/my*.lua = personal overrides
│   ├── utils/          # shared utilities
│   └── langs/          # language-specific settings
├── patches/            # local patches for Lazy plugins (see docs/memory/lazy-local-patching.md)
├── docs/memory/        # living plugin docs (update as you learn)
├── tasks/              # task management — see tasks/AGENTS.md
└── scripts/install-tools.sh
```

## Worktree Testing

This config uses **git worktrees + `NVIM_APPNAME`** for isolated testing. Each worktree directory name becomes a separate Neovim profile with its own plugin data, state, and cache — changes never affect the main daily-driver profile. See [docs/memory/nvim-worktree-testing.md](docs/memory/nvim-worktree-testing.md).

| Profile | NVIM_APPNAME | Branch | Purpose |
|---------|-------------|--------|---------|
| Main | `nvim3_jelly_tinynvim` | `main` | Daily driver — stable |
| Worktree | `nvimwt3a` | `nvim3wt1` | Testing, POCs, plugin upgrades |

When making changes, test in the worktree profile first (`NVIM_APPNAME=nvimwt3a nvim`), then merge to `main` when verified.

## Editing Guidelines

- Do not remove any code comments unless instructed to or the implementation makes the comment obsolete.
- Avoid adding to existing `lua/plugins/*.lua` unless required.
- `myEditor` currently contains most overridden user config for plugins, but ideally plugins should be in `plugins/extra/my<plugin_groups/plugin_name>.lua` — slowly migrate, not urgent. For new overrides not yet in a `my*.lua` file, start there.
- For plugin configuration overrides, use files named `plugins/extra/my<group_name/plugin_name>.lua`. This separates personal changes from upstream configurations.
- When adding new overrides, prefer creating a `my*.lua` file with the "my" prefix to avoid conflicts with upstream updates.
- For POCs or temporary task changes, use `plugins/extra/tmp_<description>.lua` and clean them up later.
- Only modify `plugins/*.lua` directly if necessary (e.g., when deep-merging config is not possible for functions vs tables). In such cases, move custom code to `lua/plugins/extra/` or `lua/utils/`. If placed in `/extra`, ensure it is imported at the relevant entry point.
- When asked to work on a spec in `docs/*.md`, update the detail and short description in the shortlist with code reference hyperlinks.
- **DIGDEEP**: A reliable source for installed plugin source code is `~/.local/share/$NVIM_APPNAME/lazy/<plugin_name>` (e.g., `~/.local/share/nvim3_jelly_tinynvim/lazy/codecompanion.nvim/`).
- When working with plugin configurations or editing Vim/Lua files, be vigilant for common caveats, patterns, or recurring issues. Whenever you encounter a problem and its solution, document both in `docs/memory/<plugin_name>.md`. Keep it clean and concise. Treat this as a living resource — continually review and amend it.

## Plugin Conventions

| Rule | Detail |
|------|--------|
| Personal overrides | `lua/plugins/extra/my<name>.lua` |
| Temporary POCs | `lua/plugins/extra/tmp_<desc>.lua` |
| Don't edit | `lua/plugins/*.lua` (upstream) |
| Deep-merge not possible? | Move custom code to `lua/plugins/extra/` or `lua/utils/` |

Plugin source for investigation: `~/.local/share/nvim3_jelly_tinynvim/lazy/<plugin-name>/`

## Essential Commands

| Task | Command |
|------|---------|
| Start Neovim | `NVIM_APPNAME=nvim3_jelly_tinynvim nvim` |
| Start worktree profile | `NVIM_APPNAME=nvimwt3a nvim` |
| Install plugins | `NVIM_APPNAME=nvim3_jelly_tinynvim nvim --headless -c "Lazy install" -c "qa"` |
| Format Lua | `stylua lua/` |
| Plugin status | `:Lazy` |
| LSP status | `:LspInfo` |
| MCP servers | `:MCPHub` |

## Key Gotchas

**MCPHub workspace mode** — disable for consistent CLI agent port:
```lua
-- lua/plugins/extra/myAi.lua
opts = { port = 37373, workspace = { enabled = false } }
```

**Lazy.nvim merging** — tables deep-merge, functions don't (last wins). See `docs/memory/lazy-nvim-config-merging.md`.

**Project-specific config** — Neovim loads `.nvim-config.lua` from CWD (not git-tracked).

## AI Tool Integration

| Tool | Config file |
|------|-------------|
| CodeCompanion | `lua/plugins/extra/codecompanion.lua` |
| Avante | `lua/plugins/extra/avante.lua` |
| CopilotChat | `lua/plugins/extra/copilot-chat.lua` |
| MCPHub (orchestrates all) | `lua/plugins/extra/myAi.lua` |

MCPHub port: `37373` | Config: `~/dotfiles/ai/mcp/mcphub.json`

Reference: `docs/memory/mcphub.md`, `docs/memory/mcphub-nvim-integrations.md`

## Task Management

See **[tasks/AGENTS.md](tasks/AGENTS.md)** for the full workflow.

- Keep user in the loop to verify changes work with checkboxes, then iterate to fix failed cases.
- Pick up work from `tasks/open/` first before starting anything new.
- Follow `tasks/` folder structure for status management:
  - `tasks/drafts/` — Ideas and planning
  - `tasks/open/` — New tasks ready to start
  - `tasks/wip/` — Work in progress (optional, for longer tasks)
  - `tasks/review/` — Awaiting user verification
  - `tasks/completed/` — Completed and verified by USER
  - `tasks/archive/` — Abandoned or superseded
- **File vs Directory**: Use flat files (`.md`) for single tasks, directories (`task-name/README.md`) for complex tasks, projects, or milestones
- **IMPORTANT**: AI agents MUST NOT move tasks from `review/` to `completed/` — only the USER can do this.
- **Link Format Rule**: All file links in task files MUST use paths relative to git root WITHOUT `../` prefix
  - Correct: `[File](lua/utils/snacks_actions.lua)`
  - Wrong: `[File](../../lua/utils/snacks_actions.lua)`
- **Verification Required**: Before moving to `review/`, fill in the Verification section with:
  - How to verify (environment, preconditions)
  - Exact commands to run
  - Checklist of expected outcomes
- Learnings go in `docs/memory/`, not `tasks/`
- See [tasks/TASK-TEMPLATE.md](tasks/TASK-TEMPLATE.md) for task file template
- See [docs/task_tracking.md](docs/task_tracking.md) for detailed templates and reference

## Documentation (Living Memory)

Update `docs/memory/<plugin>.md` whenever you find a non-obvious pattern or fix. Key files:

- `codecompanion.md` · `avante.md` · `mcphub.md` · `mcphub-nvim-integrations.md`
- `gitsigns.md` · `neotree.md` · `lazy-nvim-config-merging.md` · `keybindings_conflicts.md`

---

**Last Updated**: 2026-03-16
