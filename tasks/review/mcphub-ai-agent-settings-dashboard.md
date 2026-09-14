---
title: "MCPHub AI Agent Settings dashboard"
status: review
priority: medium
created: 2026-09-15
updated: 2026-09-15
refs:
  - 163b3ad [tag:v6.2.0] @2025-07-31 07:52:38 +0000 chore(release): v6.2.0
related:
  - [MCPHub config](lua/plugins/extra/myAi.lua)
  - [Agent settings discovery](lua/utils/mcphub_agent_settings.lua)
  - [CLI agent helper](lua/utils/mcphub_agents.lua)
  - [MCPHub patch catalog](patches/mcphub.nvim/README.md)
  - [Agent settings patch](patches/mcphub.nvim/08-ai-agent-settings_v1.patch)
  - [MCPHub memory](docs/memory/mcphub.md)
  - [Native skills catalog follow-up](tasks/open/codecompanion-rules-mcphub-native-skills.md)
---

## Objective

Make the MCPHub main view a safe, read-only place to inspect AI-agent setup:
configured user/local roots, setup/config files, related `SKILL.md` files, and
per-agent readiness without launching agent CLIs.

## Design

- Add **AI Agent Settings** after the existing CLI Agents panel.
- Show an aggregate state detector at the top: ready, partial, setup needed,
  and total discovered skills.
- Use `gS` to cycle **Full → User → Local** configured roots without restarting
  the hub. `R` rescans only when the cursor is in this panel.
- Keep each shared/agent group expandable. Expanded groups expose nested Setup
  roots, Settings, and Skills sections with the existing `h`/`l`, `T`, and
  `J`/`K` section mechanics.
- Each concrete config/setup/skill file row supports `e`, reusing MCPHub's
  existing hide-and-edit flow. A missing setup file opens as a new editable
  buffer for first-time setup.
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

## Success Criteria

- The panel renders while MCPHub is starting and after it becomes ready.
- State/counts identify missing local setup separately from existing user setup.
- `gS`, `h`, `l`, `T`, and `J`/`K` work on the new headers without breaking
  the existing dashboard behavior.
- `e` opens the selected config, instruction, or `SKILL.md` file rather than
  starting an external agent process.
- Cursor remains config-only: opening or refreshing this panel never executes
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

- [ ] The main view shows **AI Agent Settings** with a Full-view aggregate
      state and skill count before or after hub readiness.
- [ ] Pressing `gS` cycles Full, User, and Local without restarting MCPHub.
- [ ] Pressing `l` on an agent row reveals Setup roots, Settings, and Skills;
      `h` collapses each level.
- [ ] `J`/`K` navigates the new section headers and `T` folds/unfolds visible
      sections alongside the existing MCPHub sections.
- [ ] Pressing `e` on a config/setup row opens that file, and pressing `e` on a
      skill row opens its `SKILL.md`.
- [ ] Pressing `R` from the panel rescans displayed state without a hub restart.
- [ ] Opening and refreshing the panel does not open or foreground Cursor.

## References

- [Patch catalog](patches/mcphub.nvim/README.md)
- [Agent helper](lua/utils/mcphub_agent_settings.lua)
- [MCPHub docs](docs/memory/mcphub.md)
