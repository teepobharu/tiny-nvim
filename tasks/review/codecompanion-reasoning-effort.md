---
title: "Expose reasoning_effort (thinking control) in CodeCompanion"
status: review
priority: medium
created: 2026-05-31
updated: 2026-06-01
related:
  - [my_codecompanion_utils.lua](lua/utils/my_codecompanion_utils.lua)
  - [my_ai_constants.lua](lua/utils/my_ai_constants.lua)
  - [myAi.lua](lua/plugins/extra/myAi.lua)
  - [codecompanion.md](docs/memory/codecompanion.md)
---

## Objective

CodeCompanion's upstream OpenAI adapter supports `reasoning_effort` (`low` / `medium` / `high`) but the field is hidden behind a `can_reason` gate that no local model declares. Make the thinking level visible and configurable: expose the schema field and mark o-series / thinking-capable models appropriately. Document what the AGD default is (currently unknown to user).

## Context

**Upstream support:** `~/.local/share/nvim3_jelly_tinynvim/lazy/codecompanion.nvim/lua/codecompanion/adapters/http/openai.lua:463-484`
```lua
reasoning_effort = {
  optional = true,
  default = "medium",
  -- enabled only when model.choices[m].opts.can_reason == true
}
```
The `enabled` function gates on `model.choices[selected].opts.can_reason`. Without `can_reason = true` on any model entry, the field never appears in the adapter schema UI.

**Local gap:** `lua/utils/my_codecompanion_utils.lua:68-106` builds the `openai_agd` adapter with `schema = { model = { choices = <function>, … }, max_completion_tokens = … }`. No `reasoning_effort` entry and no model carries `opts.can_reason = true`.

**Where model choices come from:** The `choices` closure calls `fetch_model_helper` (`lua/utils/my_codecompanion_actions.lua`) which returns models from the AGD `/v1/models` endpoint dynamically. Static `opts.can_reason` flags must be injected at the adapter-build layer, keyed by model name.

**Runtime plumbing exists:** Reasoning round-tripping is wired in `interactions/chat/init.lua:347, 1152, 1375-1445` and `types.lua:101-119`. ACP also notes "Change ACP session config options like mode and reasoning level" at `config.lua:372` — the UI change path already exists.

## Implementation Plan

- [x] Read `~/.local/share/nvim3_jelly_tinynvim/lazy/codecompanion.nvim/lua/codecompanion/adapters/http/openai.lua:460-495` to confirm exact `can_reason` gate and `reasoning_effort` schema shape
- [x] Identify which models support reasoning on AGD (o-series + deepseek-r1; added `M.codecompanion_reasoning_models` in `my_ai_constants.lua`)
- [x] In `lua/utils/my_codecompanion_utils.lua`, updated the `choices` function to normalize `fetch_model_helper`'s flat string array into keyed table and inject `opts.can_reason = true` for reasoning models
- [x] Added `reasoning_effort` schema entry in the `openai_agd` adapter factory — deep-merges with upstream's `enabled` gate via `tbl_deep_extend`
- [ ] Test that the field appears in the adapter schema UI when a reasoning-capable model is selected (`:CodeCompanionActions` → Chat → Change model)
- [ ] Document the AGD default behavior in `docs/memory/codecompanion.md`

## Success Criteria

- When a `can_reason`-tagged model is active, `reasoning_effort` appears as a tunable field in CodeCompanion's adapter schema (accessible via `change_adapter` keymap)
- Changing the value to `low`/`medium`/`high` affects outbound requests (verify via `:CodeCompanionDebug` or `nvim.log`)
- Non-thinking models do not show `reasoning_effort` (gate respected)
- Default thinking level for AGD is documented

## Verification

### How to verify

```bash
NVIM_APPNAME=nvimwt3a nvim
```

```vim
:CodeCompanionChat
" Select a reasoning-capable model (e.g. an o-series or annotated GPT-5 model)
" Run the change_adapter keymap (see config.lua:372 — check actual keymap binding)
" Look for "reasoning_effort" in the schema options
```

```bash
# Check debug log for reasoning_effort in the outbound payload
grep -i "reasoning" ~/.local/state/nvimwt3a/log
```

### Checklist

- [ ] `reasoning_effort` option visible in adapter schema for thinking-capable model
- [ ] Field NOT shown for non-thinking model (gate respected)
- [ ] Changing the effort level logs the updated value in debug output
- [ ] No regressions — regular chat with `gpt-5.4` / `gpt-5.5` still works
- [ ] `docs/memory/codecompanion.md` updated with default effort findings

## References

- [Adapter factory (schema entry point)](lua/utils/my_codecompanion_utils.lua:60-110)
- [Model constants](lua/utils/my_ai_constants.lua:25-40)
- [Upstream reasoning_effort schema](~/.local/share/nvim3_jelly_tinynvim/lazy/codecompanion.nvim/lua/codecompanion/adapters/http/openai.lua)
- [CodeCompanion memory](docs/memory/codecompanion.md)
- [CodeCompanion debug memory](docs/memory/codecompanion_debug.md)
