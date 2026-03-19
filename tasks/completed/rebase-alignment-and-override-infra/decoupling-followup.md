# Decoupling Follow-up

## Status Snapshot

Completed in the current working tree:

- snacks spec moved from `lua/plugins/extra/myEditor.lua` to `lua/plugins/extra/mySnacks.lua`
- sidekick prompt context merged into `lua/plugins/extra/myAi.lua`
- AI tools moved from `lua/plugins/extra/myEditor.lua` to `lua/plugins/extra/myAi.lua`
- `xx*.lua` mute-switch files added for grouped core-plugin toggles

## Remaining Moves

### Move to `myCoding.lua`

| Plugin                           | Why                                      |
| -------------------------------- | ---------------------------------------- |
| `jellydn/quick-code-runner.nvim` | coding workflow, not editor-core         |
| `saghen/blink.compat`            | completion support layer                 |
| `saghen/blink.cmp`               | completion config + avante source bridge |

### Move to `myConform.lua` (to match new plugin structure from upstream lua/plugins/conform.lua)

| - stevearc/conform.nvim : formatting policy belongs with coding domain

### Move to `myUi.lua`

| Plugin                                  | Why                           |
| --------------------------------------- | ----------------------------- |
| `folke/which-key.nvim` (general groups) | UI labeling and menu grouping |
| `{ import = "plugins.extra.myNoice" }`  | UI ownership                  |

### Keep in `myEditor.lua`

These still look like editor-core and do not currently need another split:

- treesitter + textobjects dependency
- disabled dashboard/treesj placeholders
- hurl, oil, overseer, mini.bufremove
- fzf-lua, persistence, trouble, harpoon
- flash, nvim-surround

## Current Risk Areas

- which-key split is still the trickiest cut because AI and non-AI labels are mixed
- blink config still bridges coding + AI provider concerns, so it should move as a unit
- avoid reintroducing cross-domain specs into `myEditor.lua` after the split

## Suggested Order

1. move `quick-code-runner`, `conform`, `blink.compat`, `blink.cmp` to `myCoding.lua`
2. split which-key groups: AI labels to `myAi.lua`, general labels to `myUi.lua`
3. move `myNoice` import to `myUi.lua`
4. re-check `myEditor.lua` line count and ownership boundaries

## Verification

```bash
luajit -e "assert(loadfile('lua/plugins/extra/myEditor.lua'))"
luajit -e "assert(loadfile('lua/plugins/extra/myCoding.lua'))"
luajit -e "assert(loadfile('lua/plugins/extra/myUi.lua'))"
luajit -e "assert(loadfile('lua/plugins/extra/myAi.lua'))"
```

Then verify in Neovim:

- snacks pickers still work
- avante, CopilotChat, and sidekick still work
- formatting and completion still work after coding moves
