# CodeCompanion History local patches

Apply these patches in numeric order with `lazy-local-patcher.nvim`.

| Patch | Target | Purpose |
| --- | --- | --- |
| `01-title-prompt-v1.patch` | `bc1b4fe` | Adds configurable title rules; filters v19 context lines (rules, `@{file}`/buffer/URL attachments, tool prompts, hidden `visible=false` messages) and strips picker-expanded annotations (tool replacement text, tool-group prompts, buffer notes) from title prompts. |

## Verification

Apply the patch to a clean checkout of the pinned revision, parse the touched
Lua files, then run the isolated adapter-stub regression:

```sh
git -C /path/to/codecompanion-history.nvim apply --check \
  patches/codecompanion-history.nvim/01-title-prompt-v1.patch

CODECOMPANION_HISTORY_PLUGIN_ROOT=/path/to/codecompanion-history.nvim \
NVIM_APPNAME=nvimwt3a nvim --headless -u NONE -i NONE \
  --cmd 'set rtp^=/Users/tharutaipree/dotfiles/.config/nvimwt3a' \
  -l tests/test_codecompanion_history_title_prompt.lua
```

The test stubs the adapter and verifies prompt construction only. A real model
response remains an interactive, user-owned smoke check.
