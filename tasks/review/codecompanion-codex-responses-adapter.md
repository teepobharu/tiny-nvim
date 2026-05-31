---
title: "Enable gpt-5.3-codex in CodeCompanion via openai_responses adapter"
status: review
priority: medium
created: 2026-05-31
updated: 2026-06-01
related:
  - [my_ai_constants.lua](lua/utils/my_ai_constants.lua)
  - [my_codecompanion_utils.lua](lua/utils/my_codecompanion_utils.lua)
  - [myAi.lua](lua/plugins/extra/myAi.lua)
  - [codecompanion.md](docs/memory/codecompanion.md)
---

## Objective

`gpt-5.3-codex` (and `gpt-5.1-codex-max`, `gpt-5.1-codex-mini`) fail in CodeCompanion because they are not exposed on AGD's `/v1/chat/completions` endpoint — they require `/v1/responses`. Route codex models through a dedicated `openai_responses_agd` adapter so they work in CodeCompanion without touching the working `gpt-5.5/5.4/5.4-nano` chat path.

## Context

**Why models are excluded today:** `lua/utils/my_ai_constants.lua:260-267`
```lua
M.codecompanion_chat_excluded_models = {
  [M.providers.openai_agd.adapter_name] = {
    [M.models.gpt.GPT_5_3_CODEX] = true,   -- "gpt-5.3-codex"
    [M.models.gpt.GPT_5_1_CODEX_MAX] = true,
    [M.models.gpt.GPT_5_1_CODEX_MINI] = true,
    ...
  },
}
```
Comment at `L174-178`: *"codex models fail codecompanion /completions — not a chat model"*.

**Transport difference:** The existing `openai_agd` adapter at `lua/utils/my_codecompanion_utils.lua:68-106` extends `openai` with `chat_url = "/v1/chat/completions"`. Codex models need `openai_responses` adapter from the plugin (`~/.local/share/nvim3_jelly_tinynvim/lazy/codecompanion.nvim/lua/codecompanion/adapters/http/openai_responses.lua`) which uses `/v1/responses`.

**Provider remap pattern** exists at `my_ai_constants.lua:269-277` for Gemini `-preview` suffix — can be adapted if needed for codex endpoint routing.

**Working models are unaffected** as long as the new adapter is a separate key in the adapters table.

## Implementation Plan

- [x] Read `~/.local/share/nvim3_jelly_tinynvim/lazy/codecompanion.nvim/lua/codecompanion/adapters/http/openai_responses.lua` to understand required env keys and schema shape
- [x] Add `openai_responses_agd` provider block to `lua/utils/my_ai_constants.lua` (alongside `M.providers.openai_agd`) with:
  - `adapter_name = "openai_responses_agd"`
  - AGD base URL env key (same `AG_OPENAIPROXY`) and responses endpoint (`/v1/responses`)
- [x] In `lua/utils/my_codecompanion_utils.lua` alongside `get_agoda_adapters()`, add a factory for `openai_responses_agd` extending `openai_responses` with AGD env and a model `choices` function returning only codex models
- [x] Create `merge_agoda_responses_adapters()` helper (pattern mirrors existing `merge_agoda_adapters()`)
- [x] In `lua/plugins/extra/myAi.lua`, call `merge_agoda_responses_adapters()` in the adapters table block (around `L897`)
- [x] Remove `GPT_5_3_CODEX` (and the `5.1-codex-*` models) from `codecompanion_chat_excluded_models` — they now have their own adapter
- [ ] Test in worktree profile first: `NVIM_APPNAME=nvimwt3a nvim`

## Success Criteria

- `gpt-5.3-codex` appears as a selectable model in CodeCompanion chat
- A chat request using `gpt-5.3-codex` completes without 404/error
- `gpt-5.5`, `gpt-5.4`, `gpt-5.4-nano` continue to work on `openai_agd` chat path unaffected
- No new errors in `:messages` or `nvim.log` on startup

## Verification

### How to verify

Start the worktree Neovim profile, open a CodeCompanion chat, switch model to `gpt-5.3-codex`, and send a message.

```bash
NVIM_APPNAME=nvimwt3a nvim
```

```vim
:CodeCompanionChat
" In chat buffer:
" Press <C-a> or use the model-selection keymap to pick gpt-5.3-codex
" Type: "say hello" and send
```

```bash
# Check for startup errors
cat ~/.local/state/nvimwt3a/log
```

### Checklist

- [ ] `gpt-5.3-codex` appears in the model picker in CodeCompanion chat
- [ ] Sending a message with `gpt-5.3-codex` returns a response (not an error)
- [ ] `gpt-5.5` chat still works normally in the same session
- [ ] No error notifications on Neovim startup related to adapters
- [ ] `:messages` shows no adapter-related Lua errors

## References

- [Adapter factory](lua/utils/my_codecompanion_utils.lua:60-110)
- [Exclusion table](lua/utils/my_ai_constants.lua:260-267)
- [Model constants](lua/utils/my_ai_constants.lua:25-40)
- [myAi.lua adapter merge point](lua/plugins/extra/myAi.lua:897)
- [Upstream openai_responses adapter](~/.local/share/nvim3_jelly_tinynvim/lazy/codecompanion.nvim/lua/codecompanion/adapters/http/openai_responses.lua)
- [GPT5.2 adapter fix reference](tasks/completed/gpt52_adapter_fix.md)
- [CodeCompanion memory](docs/memory/codecompanion.md)
