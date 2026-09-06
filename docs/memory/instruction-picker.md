# Instruction-file picker

## Purpose

`lua/utils/instruction_picker.lua` provides a standalone Snacks catalog for AI
instruction files. It is intentionally independent of MCPHub's internal views,
so MCPHub upgrades cannot break the catalog registration.

Open it with `:InstructionFiles` or `<leader>fI`.

## Discovery contract

- Global roots cover shared/Codex skills plus configured Claude, Codex, Cursor,
  OpenCode, Pi, and shared instruction paths.
- The current Git root is scanned for recognized instruction filenames,
  `SKILL.md` files below `skills/`, and markdown below `rules/`.
- Add installation-specific roots with `vim.g.instruction_picker_sources`. Each
  entry accepts `path`, `agent`, `scope`, `category`, and `label`.
- Traversal skips dependency/build directories and nested symlinks, and caps
  depth, node count, and readable file size. Missing configured paths are
  counted in the picker title instead of aborting the scan.
- Rows expose agent, scope, category, path, and heading. Labels are compact:
  `[g]`/`[p]` for global/project scope, `[md]` for instructions, `[sk]` for
  skills, and `[r]` for rules. Discovery also records line counts, and
  fuzzy-search text includes all row fields.

Example override:

```lua
vim.g.instruction_picker_sources = {
  {
    path = "~/my-agent/rules",
    agent = "my-agent",
    scope = "global",
    category = "rule",
    label = "Personal rules",
  },
}
```

## Actions

- `<CR>` opens the selected file.
- `<C-y>` copies its absolute path.
- `<C-l>` copies its content.
- `<A-s>` cycles between the unfiltered catalog and each discovered agent/tool;
  shared `all` rows remain visible with a selected agent.
- `<A-g>` toggles global-only scope filtering.
- The normal file preview is available because every row carries Snacks' `file` field.

## Test

```sh
NVIM_APPNAME=nvimwt3a nvim --headless -u NONE -i NONE \
  --cmd 'set rtp^=/Users/tharutaipree/dotfiles/.config/nvimwt3a' \
  -l tests/test_instruction_picker.lua
```
