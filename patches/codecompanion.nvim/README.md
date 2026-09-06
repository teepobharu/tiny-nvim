# codecompanion.nvim patches

Patch files are applied in lexical order by `lazy-local-patcher`. This patch
targets the pinned CodeCompanion checkout at `eba3b42`.

## 01-editor-context-refresh_v1.patch

CodeCompanion caches editor-context completion entries. MCPHub can register or
remove resources after a chat is created, so changing only the shared config
leaves existing completion candidates stale. This patch exposes
`refresh_editor_context_cache()` from the completion provider.

It is paired with
[`patches/mcphub.nvim/07-codecompanion-resource-refresh_v1.patch`](../mcphub.nvim/07-codecompanion-resource-refresh_v1.patch),
which updates every open chat's MCP context and calls this invalidation hook.
The update preserves non-MCP, chat-local context entries.

Validation:

```bash
PLENARY_PLUGIN_ROOT=<plenary.nvim> \
CODECOMPANION_PLUGIN_ROOT=<patched-codecompanion.nvim> \
MCPHUB_PLUGIN_ROOT=<patched-mcphub.nvim> \
NVIM_APPNAME=nvimwt3a \
nvim --headless -u NONE -i NONE \
  --cmd 'let &runtimepath = $PLENARY_PLUGIN_ROOT . "," . &runtimepath' \
  -l tests/test_mcphub_codecompanion_live_chat_refresh.lua
```
