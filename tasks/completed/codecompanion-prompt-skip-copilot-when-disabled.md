---
title: "Skip Copilot prompt_library entries when Copilot is disabled + sync top_choices to proxy-models.md"
status: open
priority: medium
created: 2026-05-24
updated: 2026-05-24
related:
  - [my_codecompanion_prompt_library.lua](lua/utils/my_codecompanion_prompt_library.lua)
  - [my_ai_constants.lua](lua/utils/my_ai_constants.lua)
  - [myAi.lua](lua/plugins/extra/myAi.lua)
  - [proxy-models.md](~/dotfiles/ai/agents/docs/agoda/proxy-models.md)
---

## Objective

Refine the generated CodeCompanion model action list so it only includes
providers and models that can actually be used from the current Neovim config.

1. When `AI_CFG.ENABLE_COPILOT = false`, do not generate any `Copilot ...`
   entries for CodeCompanion `prompt_library`. The `copilot` adapter is already
   removed at runtime, but `utils.my_codecompanion_prompt_library.build()` still
   iterates every provider in `M.providers`.
2. Refresh AGD `top_choices` in [my_ai_constants.lua](lua/utils/my_ai_constants.lua)
   against `/Users/tharutaipree/dotfiles/ai/agents/docs/agoda/proxy-models.md`
   (last verified 2026-05-21). Keep shared `top_choices` useful for Avante and
   other consumers, but filter generated CodeCompanion chat prompt-library
   entries so they only include `/v1/chat/completions`-capable models.

## Context

- Generator: [my_codecompanion_prompt_library.lua](lua/utils/my_codecompanion_prompt_library.lua)
  has `M.build(empty_prompt)` and currently loops over
  `ai_constants.providers` unconditionally.
- Call site: [myAi.lua](lua/plugins/extra/myAi.lua) `prompt_library =
  vim.tbl_extend("keep", ...)` merges generated entries from
  `M.build(EMPTY_PROMPT_CODECOMPANION)`.
- Toggle: `local ENABLE_COPILOT = AI_CFG.ENABLE_COPILOT` in
  [myAi.lua](lua/plugins/extra/myAi.lua) already gates `github/copilot.vim`,
  `CopilotChat.nvim`, and Avante's `copilot` provider. Reuse that same flag for
  generated CodeCompanion prompt entries.
- Proxy model source of truth:
  `/Users/tharutaipree/dotfiles/ai/agents/docs/agoda/proxy-models.md`.
  Notable changes:
  - `qwen-3.5-27b` is removed. Use `qwen-3.6-27b`.
  - `gpt-5.5` works at chat endpoint. Add a constant and consider using it as
    the large/default flagship AGD GPT choice.
  - `gpt-5.3-codex`, `gpt-5.1-codex-max`, and `gpt-5.1-codex-mini` are not
    valid chat-completions models, but the existing comment in
    [my_ai_constants.lua](lua/utils/my_ai_constants.lua) says some Codex models
    work in Avante. Do not remove them globally from shared `top_choices` just
    to fix CodeCompanion prompt-library generation.
  - `gemini-3.1-pro-preview`, `gemini-3.1-flash-lite-preview`, and
    `gemini-3-flash-preview` work through remapping. `gemini-3-pro-preview`
    returns 404 and must stay out of active choices.
- `M.providers.*.top_choices` is shared by more than the generated prompt
  library, including [my_avante_utils.lua](lua/utils/my_avante_utils.lua),
  [my_codecompanion_actions.lua](lua/utils/my_codecompanion_actions.lua),
  [myMinuet.lua](lua/plugins/extra/myMinuet.lua), and
  [my_ai_default_config.lua](lua/utils/my_ai_default_config.lua).
  CodeCompanion chat-only exclusions need to live in the prompt-library
  generator path or in a clearly scoped CodeCompanion-chat exclusion table.

## Implementation Plan

- [ ] Change `utils.my_codecompanion_prompt_library.build()` to accept an
      optional provider filter, for example:
      `M.build(empty_prompt, { enabled_providers = { openai_agd = true, copilot = ENABLE_COPILOT } })`.
- [ ] Preserve current behavior when no filter is passed so any other caller of
      `M.build(empty_prompt)` still gets all providers.
- [ ] In the provider loop, skip a provider when the filter explicitly resolves
      that provider key to `false` or `nil`.
- [ ] Update the [myAi.lua](lua/plugins/extra/myAi.lua) call site to pass the
      enabled-provider set using the existing `ENABLE_COPILOT` local.
- [ ] Add or rename constants in [my_ai_constants.lua](lua/utils/my_ai_constants.lua):
      `M.models.qwen.QWEN_3_6_27B = "qwen-3.6-27b"` and
      `M.models.gpt.GPT_5_5 = "gpt-5.5"`.
- [ ] Replace `openai_agd.top_choices.inhouse.default.S` with
      `M.models.qwen.QWEN_3_6_27B`.
- [ ] Add a CodeCompanion-chat-specific exclusion table in
      [my_ai_constants.lua](lua/utils/my_ai_constants.lua), for example
      `M.codecompanion_chat_excluded_models[adapter][model] = true`. Keep this
      near `M.providers` / `M.filters` so future proxy-model audits update the
      model choices and CodeCompanion-chat exclusions in one place.
- [ ] Use that exclusion mechanism in `my_codecompanion_prompt_library.build()`
      to skip AGD chat-incompatible models such as `gpt-5.3-codex`,
      `gpt-5.1-codex-max`, `gpt-5.1-codex-mini`, and
      `gemini-3-pro-preview` without removing them from shared `top_choices`.
- [ ] Update `openai_agd.top_choices.gpt` for newly routable chat models such
      as `gpt-5.5` only where that does not regress existing Avante/model-picker
      use cases.
- [ ] Probe `qwen-3.6-27b` once through `/v1/chat/completions` before promoting
      it to `inhouse.default.S`, because the previous Qwen model broke at chat
      endpoint near removal time.
- [ ] Keep Gemini choices backed by `provider_model_remap` for working preview
      suffixes. Do not add `gemini-3-pro`/`gemini-3-pro-preview` to active
      choices.
- [ ] Recheck Copilot choices separately. Copilot may support models AGD chat
      does not, but Copilot entries must still disappear completely when
      `ENABLE_COPILOT = false`.
- [ ] Do not run project-wide formatting unless explicitly requested; this repo
      currently says to skip `stylua`.

## Success Criteria

- With `ENABLE_COPILOT = false`, `:CodeCompanionActions` shows zero entries titled `Copilot ...`.
- With `ENABLE_COPILOT = true`, all current Copilot tier entries still appear.
- AGD generated prompt-library entries only use model IDs that route through
  `/v1/chat/completions`, including `qwen-3.6-27b` and no removed
  `qwen-3.5-27b`.
- No generated AGD CodeCompanion chat action points at known response-only or
  unavailable models (`gpt-5.3-codex`, `gpt-5.1-codex-max`,
  `gpt-5.1-codex-mini`, `gemini-3-pro-preview`).
- Avante and other shared `top_choices` consumers do not lose existing
  Codex-model slots solely because CodeCompanion chat cannot use those models.

## Verification

### How to verify

Toggle `ENABLE_COPILOT` in `lua/utils/my_ai_config.lua` (or wherever `AI_CFG` lives), restart Neovim, and inspect the action picker. Then validate a couple of AGD model entries actually respond.

### Commands

```bash
NVIM_APPNAME=nvim3_jelly_tinynvim nvim
```

```vim
:CodeCompanionActions
" Filter the picker for "Copilot" — expect 0 results when disabled
:lua print(vim.tbl_count(require("codecompanion.config").prompt_library))
```

Optional headless check for generated titles:

```bash
NVIM_APPNAME=nvim3_jelly_tinynvim nvim --headless +'lua local p=require("utils.my_codecompanion_prompt_library"); local lib=p.build({{role="user",content=""}}, { enabled_providers = { openai_agd = true, copilot = false } }); local blocked={["gpt-5.3-codex"]=true,["gpt-5.1-codex-max"]=true,["gpt-5.1-codex-mini"]=true,["gemini-3-pro-preview"]=true}; for title,entry in pairs(lib) do if title:match("^Copilot ") then error(title) end; local model=entry.opts and entry.opts.adapter and entry.opts.adapter.model; if blocked[model] then error(title .. " -> " .. model) end end; vim.cmd("qa")'
```

### Checklist

- [ ] No `Copilot ...` entries visible in `:CodeCompanionActions` when disabled.
- [ ] `Copilot gpt 4.1 [alt-S]` and other Copilot entries reappear when re-enabled.
- [ ] AGD `inhouse` entry uses `qwen-3.6-27b` and successfully replies in a chat.
- [ ] AGD GPT entries do not include chat-incompatible codex-only models.
- [ ] No errors on Neovim startup; `:checkhealth codecompanion` clean.

## References

- [proxy-models.md](~/dotfiles/ai/agents/docs/agoda/proxy-models.md) — source of truth for model availability
- [investigate-codecompanion-adapter-switching.md](tasks/open/investigate-codecompanion-adapter-switching.md) — adjacent CC adapter work
