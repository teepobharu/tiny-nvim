---
title: "Rebase Alignment and Override Infrastructure"
status: open
priority: high
created: 2026-03-19
updated: 2026-03-19
refs:
  - 367a132 fix: ui show correctlynow, pending issue list in rebaseupstream docs
  - f818cec fix: ui and add toto myeditor refactor
  - 1aef7ca feat(plugins): centralize plugin-disable flow and add simple Claude integration
related:
  - [Rebase Resolution Detail](tasks/open/rebase-alignment-and-override-infra/rebase-resolution.md)
  - [Decoupling Follow-up](tasks/open/rebase-alignment-and-override-infra/decoupling-followup.md)
  - [Centralized Disable Memory](docs/memory/centralized-plugin-disable.md)
  - [Override Layering Guideline](docs/memory/rebase-safe-plugin-overrides.md)
  - [Default Config](lua/config/mydefault-nvim-config.lua)
  - [AI Overrides](lua/plugins/extra/myAi.lua)
  - [Editor Overrides](lua/plugins/extra/myEditor.lua)
  - [Snacks Overrides](lua/plugins/extra/mySnacks.lua)
---

## Objective

Keep the post-rebase notes, override architecture decisions, and remaining follow-up work in one task directory so future rebases have a single source of truth.

## Context

This branch rebased 93 local commits onto `upstream/main` after the upstream move from a snacks-heavy baseline to a mini.nvim baseline. Since local workflows still depend on snacks pickers and other custom integrations, the work since the rebase has focused on two goals:

1. patch behavior regressions introduced by the rebase
2. restructure local overrides so future rebases touch fewer upstream files

## Recent Changes

### `367a132` — initial rebase fallout tracking

- Captured the first post-rebase issue list and behavior mismatches.
- Introduced early domain-split groundwork in `lua/plugins/extra/myUi.lua` and `lua/plugins/extra/mySnacks.lua`.
- Kept `myEditor.lua` as the temporary aggregation point while conflicts were still being resolved.

### `f818cec` — UI alignment and early refactor out of `myEditor.lua`

- Moved the first chunk of snacks-related behavior out of `myEditor.lua`.
- Reworked project-setting generation/reload flow in `lua/plugins/extra/myproject.lua`.
- Continued aligning picker and UI behavior after the upstream mini migration.

### `1aef7ca` — centralized plugin disable flow

- Added `lua/plugins/extra/disablePlugins.lua` and the project settings picker flow around plugin toggles.
- Standardized `vim.g.disabled_plugins` + `vim.g.enable_extra_plugins` load order in `lua/config/mydefault-nvim-config.lua`.
- Added a lightweight Claude integration and improved override ordering.

### Current working tree — rebase-safe override infrastructure

- Reduced `vim.g.disabled_plugins` to single-file plugins only (`jellydn/tiny-term.nvim`).
- Added `xx*.lua` mute switches for grouped core-plugin toggles:
  - `xxMiniUi.lua`
  - `xxMiniCode.lua`
  - `xxMini.lua`
  - `xxTest.lua`
  - `xxRunner.lua`
  - `xxLegacyCopilotAi.lua`
- Moved snacks overrides into `lua/plugins/extra/mySnacks.lua`.
- Consolidated AI tools from `lua/plugins/extra/myEditor.lua` into `lua/plugins/extra/myAi.lua`:
  - `img-clip.nvim`
  - `github/copilot.vim`
  - `CopilotChat.nvim`
  - `avante.nvim`
  - `sidekick.nvim` prompt context merge
- Cut `lua/plugins/extra/myEditor.lua` down to editor-core responsibilities (`503` lines now, from `750`).

## Infrastructure Decisions

### Naming and ownership

- `lua/plugins/*.lua` = upstream/base specs; avoid editing directly unless unavoidable.
- `lua/plugins/extra/my*.lua` = domain overrides (`myAi`, `myCoding`, `myUi`, `mySnacks`).
- `lua/plugins/extra/xx*.lua` = mute switches for grouped core plugins.
- `lua/plugins/extra/disablePlugins.lua` = final single-plugin disable layer, loaded last.

### Granular toggle model

- Use `vim.g.disabled_plugins` only for single-file plugins or project-local overrides.
- Use `xx*.lua` when the plugin belongs to a grouped upstream file and needs a named mute switch.
- Keep domain ownership local: if a behavior belongs to AI, move it to `myAi.lua`; if it belongs to snacks, move it to `mySnacks.lua`.

### Rebase-safety rule

- Prefer moving local logic out of `myEditor.lua` and out of upstream files, not adding more conditionals to upstream specs.
- Keep override order explicit in `lua/config/mydefault-nvim-config.lua` so the final winner is obvious.

## Current State

### Done

- Rebase conflict log captured and preserved.
- Rebase behavior regressions documented with fixes/decisions.
- Disable/toggle infrastructure added.
- AI-related tools consolidated into `myAi.lua`.
- Snacks overrides isolated in `mySnacks.lua`.

### Still open

- Finish moving coding and UI leftovers out of `myEditor.lua`.
- Revisit which-key split between `myAi.lua` and `myUi.lua`.
- Regenerate `lazy-lock.json` after the plugin set settles.

## Task Files

- [Rebase Resolution Detail](tasks/open/rebase-alignment-and-override-infra/rebase-resolution.md)
- [Decoupling Follow-up](tasks/open/rebase-alignment-and-override-infra/decoupling-followup.md)

## Verification

### How to verify

Restart Neovim in the worktree profile and confirm the new override/toggle structure still loads the expected plugin behavior. Focus on snacks, AI tools, and mute-switch loading.

### Commands

```bash
NVIM_APPNAME=nvimwt3a nvim
```

```vim
:Lazy
:DisabledPlugins
:lua print(vim.inspect(vim.g.enable_extra_plugins))
:lua print(vim.inspect(vim.g.disabled_plugins))
```

### Checklist

- [ ] `myAi.lua` owns the moved AI specs and they still load without errors.
- [ ] `mySnacks.lua` owns snacks overrides and picker behavior still works.
- [ ] `myEditor.lua` no longer contains the moved AI/snacks specs.
- [ ] `xxMiniUi` is active by default and grouped mute files are visible in `vim.g.enable_extra_plugins`.
- [ ] `disablePlugins.lua` still loads last.
