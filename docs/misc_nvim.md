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

- support run lua code and send snacks lines in clipboard when not in v mode and current line empty in local_leader+r/s
  - Implementation: `getSelectedLines()` utility function automatically uses clipboard when current line is empty (lua/utils/input.lua:73)
  - `<localleader>r`: Execute lua code (clipboard fallback when line empty) (lua/utils/editor_keymaps.lua:530)
  - `<localleader>s`: Send to snacks terminal (clipboard fallback when line empty) (lua/utils/editor_keymaps.lua:519)
  - To disable clipboard fallback: pass `disable_n_clipboard=true` to `getSelectedLines()`
