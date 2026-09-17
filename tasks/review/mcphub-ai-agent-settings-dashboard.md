---
title: "MCPHub AI Agent Settings dashboard"
status: review
priority: medium
created: 2026-09-15
updated: 2026-09-17
refs:
  - 163b3ad [tag:v6.2.0] @2025-07-31 07:52:38 +0000 chore(release): v6.2.0
related:
  - [MCPHub config](lua/plugins/extra/myAi.lua)
  - [Agent settings discovery](lua/utils/mcphub_agent_settings.lua)
  - [CLI agent helper](lua/utils/mcphub_agents.lua)
  - [MCPHub patch catalog](patches/mcphub.nvim/README.md)
  - [Agent settings patch](patches/mcphub.nvim/08-ai-agent-settings_v1.patch)
  - [Dedicated agent settings view](patches/mcphub.nvim/09-agent-settings-view_v1.patch)
  - [MCPHub memory](docs/memory/mcphub.md)
  - [Native skills catalog follow-up](tasks/open/codecompanion-rules-mcphub-native-skills.md)
---

## Objective

Make MCPHub's dedicated Agents view a safe, read-only place to inspect AI-agent setup:
configured user/local roots, setup/config files, related `SKILL.md` files, and
per-agent readiness without launching agent CLIs.

## Design

- Press `Z` to switch from MCPHub to a dedicated **Agents** view; keep the
  normal main dashboard focused on MCP servers, endpoints, and CLI bindings.
- Start in **User** scope. `gS` cycles User, Local, and Full; Full renders User
  and Local/workspace configuration in separate top-level groups.
- Show an aggregate state detector at the top: ready, partial, setup needed,
  and total discovered skills.
- `R` rescans only when the cursor is in this view.
- Keep each scope/agent group expandable. Expanded groups expose nested Setup
  roots, Settings, and Skills sections with `h`/`l`, `za`/`zc`/`zo`, `zM`/`zR`,
  `T`, and `J`/`K`. `h` on an item collapses its nearest parent; ordinary `j`
  stays down-navigation, matching normal Vim movement.
- `y` copies a concrete root/file/skill path. `e` opens files in MCPHub's
  centered editor popup without closing MCPHub; directories instead open in
  Neovim so root rows remain actionable. A missing setup file can be created
  from the popup.
- Keep discovery declarative in `myAi.lua`; the helper only stats configured
  paths and scans `SKILL.md` names. It does not parse secrets or run agent CLIs.

## Implementation

- [x] Add `lua/utils/mcphub_agent_settings.lua` with TTL-cached root/file/skill
      discovery and Full/User/Local filtering.
- [x] Declare shared and per-agent user/local roots in `myAi.lua`.
- [x] Add `08-ai-agent-settings_v1.patch` after the existing MCPHub patch stack.
- [x] Route `e`, `R`, and `gS` contextually without changing existing endpoint,
      CLI-binding, server, or capability behavior.
- [x] Update the patch catalog and MCPHub living-memory documentation.
- [x] Add `09-agent-settings-view_v1.patch`, the `Z` view switch, path copying,
      contextual parent-collapse, normal `z` fold controls, and in-place file
      editor behavior.
- [x] Default the view to User scope and separate User/Local data in Full mode.

## Success Criteria

- The Agents view renders while MCPHub is starting and after it becomes ready.
- State/counts identify missing local setup separately from existing user setup.
- `Z`, `gS`, `h`, `l`, `za`, `zM`, `zR`, `T`, and `J`/`K` work without changing
  the existing main-dashboard behavior.
- `y` copies the selected root/file/skill path; `e` opens an in-place popup for
  files and a normal Neovim directory buffer for directories.
- Cursor remains config-only: opening or refreshing this view never executes
  `cursor mcp list`.

## Verification

### How to verify

Use the isolated worktree profile after the branch is aligned with main. Start
MCPHub from this repository so both user and local roots are visible.

### Commands

```bash
NVIM_APPNAME=nvimwt3a nvim
```

```vim
:MCPHub
```

### Checklist

- [ ] Press `Z`: the dedicated **Agents** view opens in User scope and displays
      a state/skill summary before or after hub readiness.
- [ ] Press `gS`: User, Local, and Full cycle without restarting MCPHub. In
      Full, User and Local/workspace configuration stay in separate groups.
- [ ] Press `l` on an agent row to reveal Setup roots, Settings, and Skills;
      press `h` on either a header or an item to collapse the relevant level.
- [ ] Check `za`, `zc`, `zo`, `zM`, `zR`, `T`, and `J`/`K`; ordinary `j` still
      moves down the list.
- [ ] Press `y` on a directory, config/setup file, and skill row; each copies
      its absolute path to the clipboard.
- [ ] Press `e` on a config/setup/skill file: edit in the centered MCPHub popup
      and save without leaving the Agents view. Press `e` on a root: open its
      directory in Neovim.
- [ ] Press `R` from the Agents view: it rescans displayed state without a hub restart.
- [ ] Opening and refreshing the view does not open or foreground Cursor.

## References

- [Patch catalog](patches/mcphub.nvim/README.md)
- [Agent helper](lua/utils/mcphub_agent_settings.lua)
- [MCPHub docs](docs/memory/mcphub.md)
