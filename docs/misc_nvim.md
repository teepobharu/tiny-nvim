# TODO

## Code

- Copy ref with code anv format in n mode / v mode
  /Users/tharutaipree/dotfiles/.config/nvim3_jelly_tinynvim/docs/misc_nvim.md#L10
  /Users/tharutaipree/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/extra/myEditor.lua#
  sidekick_explore20260122.md

- runcode with sh support code-runner

## Editing / LSP

Folding
/Users/tharutaipree/dotfiles/.config/nvim3_jelly_tinynvim/tests/myTest.lua
debug_fold

# DONE

## Code

- gF goto file with git-style line references and smart path resolution
  - Support git/IDE line references: `file#L2`, `file#L2-L3`, `file#L2C3`
  - Path priority: no `./` or `../` → git root first; with prefix → buffer cwd first
  - Refactored to `lua/utils/file_reference.lua` with reusable utilities:
    - `parse_file_reference()` - Parse multiple file reference formats
    - `resolve_file_path()` - Smart path resolution with priority logic
    - `jump_to_anchor()` - Find and jump to markdown headings
  - Simplified `goto_file_line()` in `lua/config/mykeymaps.lua` (now ~80 lines instead of ~250)

- support run lua code and send snacks lines in clipboard when not in v mode and current line empty in local_leader+r/s
  - Implementation: `getSelectedLines()` utility function automatically uses clipboard when current line is empty (lua/utils/input.lua:73)
  - `<localleader>r`: Execute lua code (clipboard fallback when line empty) (lua/utils/editor_keymaps.lua:530)
  - `<localleader>s`: Send to snacks terminal (clipboard fallback when line empty) (lua/utils/editor_keymaps.lua:519)
  - To disable clipboard fallback: pass `disable_n_clipboard=true` to `getSelectedLines()`
