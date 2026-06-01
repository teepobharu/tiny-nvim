---
title: "Expose reasoning_effort (thinking control) in CodeCompanion"
status: review
priority: medium
created: 2026-05-31
updated: 2026-06-01
related:
  - [my_codecompanion_utils.lua](lua/utils/my_codecompanion_utils.lua)
  - [my_ai_constants.lua](lua/utils/my_ai_constants.lua)
  - [myCodecomp.lua](lua/plugins/extra/myCodecomp.lua)
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

**Local gap:** `lua/utils/my_codecompanion_utils.lua:65-158` builds the `openai_agd` adapter. No `reasoning_effort` entry and no model carried `opts.can_reason = true` until this task.

**Where model choices come from:** The `choices` closure calls `fetch_model_helper` (`lua/utils/my_codecompanion_actions.lua`) which returns models from the AGD `/v1/models` endpoint dynamically. Static `opts.can_reason` flags must be injected at the adapter-build layer, keyed by model name.

**Runtime plumbing exists:** Reasoning round-tripping is wired in `interactions/chat/init.lua:347, 1152, 1375-1445` and `types.lua:101-119`. ACP also notes "Change ACP session config options like mode and reasoning level" at `config.lua:372` — the UI change path already exists.

## Implementation Plan

- [x] Read `~/.local/share/nvim3_jelly_tinynvim/lazy/codecompanion.nvim/lua/codecompanion/adapters/http/openai.lua:460-495` to confirm exact `can_reason` gate and `reasoning_effort` schema shape
- [x] Identify which models support reasoning on AGD (o-series + deepseek-r1; added `M.codecompanion_reasoning_models` in `my_ai_constants.lua`)
- [x] In `lua/utils/my_codecompanion_utils.lua:97-122`, updated `choices` to normalize `fetch_model_helper`'s flat array into keyed table and inject `opts.can_reason = true` for reasoning models
- [x] Added `reasoning_effort` schema entry in the `openai_agd` adapter factory (`my_codecompanion_utils.lua:130-153`) with live-model `enabled` gate (`self.parameters.model` fallback `schema.model.default`)

### Iteration 2 notes (2026-06-01)

**`show_settings = true` is the canonical control.** The YAML settings block at the top of the chat buffer (`myCodecomp.lua:257`) lets you edit `reasoning_effort: high` directly; it overwrites `chat.settings` on every submit via `interactions/chat/init.lua:1144`. A runtime keymap toggle would conflict and be silently overwritten — the `toggle_reasoning` keymap has been removed.

- `openai_agd` adapter: YAML key is `reasoning_effort` (flat)
- `openai_responses_agd` adapter: YAML key is `reasoning.effort` (dotted, responses API format)
- ACP adapters (codex/claude_code): use `/acp_session_options` slash command

Model+effort preset approach (e.g. `gpt-5.5-high`) requires a `form_parameters` hook — no upstream decoupler exists. Tracked separately in `tasks/open/codecompanion-model-effort-presets.md`.

- [ ] Test that `reasoning_effort` appears in YAML header when o3/o4-mini is active
- [ ] Document AGD default behavior in `docs/memory/codecompanion.md`

## Success Criteria

- When a `can_reason`-tagged model is active, `reasoning_effort` appears as a tunable field in CodeCompanion's adapter schema (accessible via `change_adapter` keymap)
- Changing the value to `low`/`medium`/`high` affects outbound requests (verify via `:CodeCompanionDebug` or `nvim.log`)
- Non-thinking models do not show `reasoning_effort` (gate respected)
- Default thinking level for AGD is documented

## Verification

### How to verify

With `show_settings = true` the YAML block at the top of the chat buffer is the canonical control. To debug the settings live: open the buffer, position cursor on the YAML block, run `gd` (go-to-definition) — this opens the schema definition so you can inspect all available fields and their current values. Edit a value and press `Enter` to save.

**Testing trick:** enter an invalid value (e.g. `reasoning_effort: xxhigh`) and send — CodeCompanion will show a validation error if the field is schema-gated, confirming the field is active and being read.

**Caveat:** if you set an invalid value and then _remove_ the line entirely, the last-set value persists for that session (`chat.settings` retains the last parsed value; removal just means the YAML key is absent and the default is not re-applied until the next adapter change or buffer reload).

```bash
NVIM_APPNAME=nvimwt3a nvim
```

```vim
:CodeCompanionChat
" For openai_agd (chat completions) — edit YAML header directly:
"   reasoning_effort: high
" For openai_responses_agd (responses API) — use dotted key:
"   reasoning.effort: high
" Send a message to confirm the value is picked up
```

**Sample settings block** (for `openai_responses_agd` / responses API):
```yaml
model = "gpt-5.3-codex"  -- or: gpt-5-codex, gpt-5.1-codex, gpt-5.2-codex, gpt-5.4-pro, gpt-5.1-codex-max
["reasoning.effort"] = "high"   -- low / medium / high / minimal
temperature = 1
max_output_tokens = 4096
verbosity = "medium"
```

```bash
# Confirm reasoning key in the outbound payload
grep -i "reasoning" ~/.local/state/nvimwt3a/log
```

### Checklist

- [ ] YAML header shows `reasoning_effort` (for `openai_agd`) or `reasoning.effort` (for `openai_responses_agd`) when a reasoning-capable model is active
- [ ] Setting `reasoning_effort: xxhigh` (invalid) triggers a validation error on send — confirms the field is schema-gated and active
- [ ] Setting `reasoning_effort: high` → log shows `"reasoning_effort":"high"` in outbound payload
- [ ] Removing the key after setting it leaves the last value in effect (expected behavior — note in docs)
- [ ] Non-reasoning model (e.g. `gpt-5.4`) does not show `reasoning_effort` in YAML header
- [ ] No regressions — regular chat with `gpt-5.4` / `gpt-5.5` still works
- [ ] `docs/memory/codecompanion.md` updated with AGD default effort findings

## References

- [Adapter factory — openai_agd schema](lua/utils/my_codecompanion_utils.lua:65-158)
- [Reasoning models list](lua/utils/my_ai_constants.lua:278-290)
- [Model constants](lua/utils/my_ai_constants.lua:25-40)
- [show_settings comment + YAML reasoning docs](lua/plugins/extra/myCodecomp.lua:255-260)
- [Upstream reasoning_effort schema (openai.lua)](~/.local/share/nvim3_jelly_tinynvim/lazy/codecompanion.nvim/lua/codecompanion/adapters/http/openai.lua:463-484)
- [Upstream reasoning.effort schema (openai_responses.lua)](~/.local/share/nvim3_jelly_tinynvim/lazy/codecompanion.nvim/lua/codecompanion/adapters/http/openai_responses.lua:663-691)
- [show_settings YAML parse flow](~/.local/share/nvim3_jelly_tinynvim/lazy/codecompanion.nvim/lua/codecompanion/interactions/chat/init.lua:1144)
- [Model+effort presets follow-up](tasks/open/codecompanion-model-effort-presets.md)
- [CodeCompanion memory](docs/memory/codecompanion.md)
- [CodeCompanion debug memory](docs/memory/codecompanion_debug.md)
