---
title: "Enable gpt-5.3-codex in CodeCompanion via openai_responses adapter"
status: review
priority: medium
created: 2026-05-31
updated: 2026-06-01
related:
  - [my_ai_constants.lua](lua/utils/my_ai_constants.lua)
  - [my_codecompanion_utils.lua](lua/utils/my_codecompanion_utils.lua)
  - [myCodecomp.lua](lua/plugins/extra/myCodecomp.lua)
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
- [x] In `lua/plugins/extra/myCodecomp.lua`, call `merge_agoda_responses_adapters()` in the adapters table block (see `myCodecomp.lua:370-374`)
- [x] Remove `GPT_5_3_CODEX` (and `5.1-codex-*` models) from `codecompanion_chat_excluded_models` — they now have their own adapter

### Iteration 2 (2026-06-01)

- [x] Suppress `top_p` for codex models — added `top_p = { enabled = function() return false end }` to `get_agoda_responses_adapters()` schema (mirrors upstream `gpt-5.4-nano` gate at `openai_responses.lua:750-753`)
- [x] Drop static `choices` override — inherit upstream's static codex list from `openai_responses.lua:586-661` (already includes gpt-5-codex, gpt-5.1-codex, gpt-5.1-codex-max, gpt-5.2-codex, gpt-5.3-codex)
- [x] Remove `GPT_5_1_CODEX_MINI` from `codecompanion_responses_models` — model not exposed on AGD proxy
- [ ] Test in worktree profile: `NVIM_APPNAME=nvimwt3a nvim`

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
- [ ] Sending a message with `gpt-5.3-codex` returns a response (not an error) [ ] `gpt-5.5` chat still works normally in the same session
- [ ] No error notifications on Neovim startup related to adapters
- [ ] `:messages` shows no adapter-related Lua errors

## References

- [Adapter factory — openai_agd](lua/utils/my_codecompanion_utils.lua:65-158)
- [Adapter factory — openai_responses_agd](lua/utils/my_codecompanion_utils.lua:161-200)
- [Exclusion table](lua/utils/my_ai_constants.lua:264-270)
- [Responses models list](lua/utils/my_ai_constants.lua:271-277)
- [Model constants](lua/utils/my_ai_constants.lua:25-40)
- [Adapter merge point in myCodecomp.lua](lua/plugins/extra/myCodecomp.lua:370-374)
- [Upstream openai_responses adapter](~/.local/share/nvim3_jelly_tinynvim/lazy/codecompanion.nvim/lua/codecompanion/adapters/http/openai_responses.lua)
- [GPT5.2 adapter fix reference](tasks/completed/gpt52_adapter_fix.md)
- [CodeCompanion memory](docs/memory/codecompanion.md)

