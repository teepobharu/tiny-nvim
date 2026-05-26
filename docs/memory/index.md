# Memory Index

> Plugin docs and patterns learned during development. Update when adding/changing memory docs.

## CodeCompanion

- [codecompanion.md](codecompanion.md) — adapter customization, model params, config location, GPT-5.2 fixes
- [codecompanion-inline-chat.md](codecompanion-inline-chat.md) — inline chat API, triggers, adapter overrides, JSON response schema
- [codecompanion-markdown-prompt-library.md](codecompanion-markdown-prompt-library.md) — markdown prompt frontmatter, prompt dirs, slash commands
- [codecompanion-prompt-library-gotchas.md](codecompanion-prompt-library-gotchas.md) — prompt library caveats and recurring issues
- [codecompanion-mcp-servers-investigation.md](codecompanion-mcp-servers-investigation.md) — v19.7 mcp_servers flow trace: YAML → action palette → Chat.new → start_mcp_servers
- [codecompanion-mcphub-server-discovery.md](codecompanion-mcphub-server-discovery.md) — root cause: CC internal registry vs MCPHub, mcp_servers config requirement
- [codecompanion_debug.md](codecompanion_debug.md) — debugging tips, log locations, common error patterns

## MCPHub

- [mcphub.md](mcphub.md) — setup, port config, workspace mode, server management
- [mcphub-nvim-integrations.md](mcphub-nvim-integrations.md) — MCPHub integration with CodeCompanion, Avante, CopilotChat
- [mcphub-native-lua-servers.md](mcphub-native-lua-servers.md) — writing native Lua MCP servers for MCPHub
- [mcphub-native-servers-quick-ref.md](mcphub-native-servers-quick-ref.md) — quick reference for native server API
- [mcphub-investigation-summary.md](mcphub-investigation-summary.md) — MCPHub architecture investigation notes

## Avante

- [avante.md](avante.md) — setup, keybindings, model config, update notes
- [avante-mcphub.md](avante-mcphub.md) — Avante + MCPHub integration, blink-cmp-avante, MCP completions

## Copilot / Minuet

- [copilot_model_fetching.md](copilot_model_fetching.md) — how CopilotChat fetches and resolves models
- [copilot-model-selection-bug.md](copilot-model-selection-bug.md) — model selection bug analysis and fix
- [minuet.md](minuet.md) — model pinning, 401 auth cause, change_model backend-switch behavior, AGD subprovider patch

## Lazy.nvim

- [lazy-nvim-config-merging.md](lazy-nvim-config-merging.md) — deep-merge rules: tables merge, functions don't (last wins)
- [lazy-local-patching.md](lazy-local-patching.md) — local patches for Lazy plugins via patches/ dir
- [lazy-nvim-local-dev.md](lazy-nvim-local-dev.md) — local plugin development with Lazy.nvim

## Git / GitLab

- [gitsigns.md](gitsigns.md) — gitsigns config, breaking changes, staging patterns
- [git_picker_fixes.md](git_picker_fixes.md) — git picker customization and fixes
- [gitlab_dirname_marker.md](gitlab_dirname_marker.md) — gitlab dirname marker for project detection

## File Navigation

- [neotree.md](neotree.md) — neo-tree config, keybindings, gotchas
- [oil.md](oil.md) — oil.nvim file manager config and patterns
- [obsidian.md](obsidian.md) — Obsidian vault registry/config audit and cleanup picker
- [snacks_picker.md](snacks_picker.md) — snacks.nvim picker config, path copy, session picker, CWD state

## Keybindings & Config

- [keybindings_conflicts.md](keybindings_conflicts.md) — known keybinding conflicts and resolutions
- [centralized-plugin-disable.md](centralized-plugin-disable.md) — centralized pattern for disabling plugins
- [rebase-safe-plugin-overrides.md](rebase-safe-plugin-overrides.md) — override patterns that survive upstream rebases
- [mypath_marker_options.md](mypath_marker_options.md) — path marker config options

## Task Runner

- [overseer.md](overseer.md) — custom actions (duplicate, copy), enhanced render, key mappings

## Infrastructure

- [file-agent-flow.md](file-agent-flow.md) — file-based multi-agent handoff workflow with receiver status watcher
- [nvim-worktree-testing.md](nvim-worktree-testing.md) — NVIM_APPNAME worktree isolation for testing
- [sidekick_env_propagation.md](sidekick_env_propagation.md) — environment variable propagation in sidekick sessions
- [slack-mcp.md](slack-mcp.md) — Slack MCP server setup and integration
