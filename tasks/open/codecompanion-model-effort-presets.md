---
title: "CC: model+effort presets (gpt-5.5-high, gpt-5.3-codex-medium, etc.)"
status: open
priority: low
created: 2026-06-01
updated: 2026-09-30
related:
  - [my_codecompanion_utils.lua](lua/utils/my_codecompanion_utils.lua)
  - [my_ai_constants.lua](lua/utils/my_ai_constants.lua)
  - [myCodecomp.lua](lua/plugins/extra/myCodecomp.lua)
  - [codecompanion-reasoning-effort task](tasks/review/codecompanion-reasoning-effort.md)
---

## Objective

Expose synthetic model+effort presets (e.g. `gpt-5.5 [high]`, `gpt-5.4-mini [low]`) in the CodeCompanion model picker so switching model simultaneously sets `reasoning_effort`. This avoids editing the YAML header for commonly-used combinations.

Candidate initial set (from user): `gpt-5.5`, `gpt-5.3-codex`, `gpt-5.4-mini`, `gpt-5.4-nano` × `{high, medium, low}` for the ones that support reasoning.

## 2026-09-30 update

- The route-policy registry in [my_codecompanion_thinking.lua](lua/utils/my_codecompanion_thinking.lua) maps local aliases to canonical wire model IDs and is also the source for strict verified capability rules; add a newly proven model once rather than maintaining separate preset and validation lists.
- GPT-5.6 Sol/Terra/Luna expose an explicit Chat `none` preset as well as their proven reasoning presets. GPT-6 Sol/Luna now expose exact route-proven Chat presets (`none|low|medium|high|xhigh`) and Responses presets (`none|low|medium|high|xhigh|max`); `minimal` is intentionally omitted.
- Grok 4.7 exposes exact Chat and Responses presets (`minimal|low|medium|high|xhigh`). Gemini 3.7/3.8 Flash expose exact Chat presets (`low|medium|high`). Claude Sonnet 5/5.5 expose exact Chat presets across the common levels (`none|minimal|low|medium|high|xhigh|max`).
- A CodeCompanion popup detects the exact observed GPT-5.6 Luna/GPT-6 Sol/GPT-6 Luna Chat + active-tool + non-`none` combination and offers to set `reasoning_effort` to `none`; a submit guard prevents that known-invalid request. If the submitted prompt adds the first tool too late for a choice, a final request guard safely applies `none` with a warning. A non-`none` preset prompt omits automatic file tools, preserving the requested effort; manually added tools still invoke the popup/guard. Responses retains GPT-6 reasoning with function tools.
- Read-only authenticated AGD catalog lookup (2026-09-30) lists `gpt-6-sol`, `gpt-6-luna`, `grok-4.7`, `gemini-3.7-flash`, `gemini-3.8-flash`, `claude-sonnet-5`, `claude-sonnet-5-5`, `claude-opus-5`, and `claude-opus-5-5`. Every listed candidate advertises Chat Completions and Function Calling; GPT-6 and Grok 4.7 also advertise Responses. GPT-6.1 Sol/Luna are intentionally predeclared as future Chat choices, although no catalog item was returned.
- Live probes (2026-09-30): Grok 4.7, Gemini 3.7/3.8 Flash, and Claude Sonnet 5/5.5 accepted Chat function tools at `high`; they do not inherit the GPT tool restriction. Claude Opus 5/5.5 returned the account's monthly-cap `403`, so their common-level Chat aliases are explicitly advisory. GPT-6.1 Sol/Luna returned `404`, so their GPT-6-shaped Chat aliases are advisory and have no Responses or tools policy.
- Catalog `thinkingCapability` is availability metadata, not the accepted `reasoning_effort` set or a function-tools compatibility contract. The ongoing live gate remains: probe each exact adapter + endpoint + effort + tool combination before exposing a preset alias or adding a tool-conflict policy.

## Historical design notes (superseded)

The route-policy implementation above supersedes these pre-implementation options. They are retained only for provenance; do not reintroduce either approach in place of the shared canonical-model/effort mapper.

At the time of investigation, there was **no upstream decoupling layer** between `schema.model.choices` keys and the `parameters.model` wire value. Keys were sent verbatim as the API `model` field (`adapters/http/init.lua:192-233`). Synthetic names like `gpt-5.5-high` would be rejected by the API.

Per-choice `opts` (e.g. `opts.can_reason`) IS accessible via `adapter_utils.model_choice(self)` which merges `opts` into `self.opts` during `handlers.setup`. But there is no built-in `opts.reasoning_effort` → `parameters.reasoning_effort` plumbing.

### Previously considered approaches

Two options (pick one):

### Option A: `handlers.setup` override in adapter extension

In `get_agoda_adapters()` in `lua/utils/my_codecompanion_utils.lua`, override `handlers.setup`:

```lua
handlers = {
  lifecycle = {
    setup = function(self)
      -- Call parent setup first
      local ok = require("codecompanion.adapters.http.openai").handlers.lifecycle.setup(self)
      -- Inject reasoning_effort from per-model opts if set
      local model_opts = require("codecompanion.utils.adapters").model_choice(self)
      if model_opts and model_opts.opts and model_opts.opts.reasoning_effort then
        self.parameters.reasoning_effort = model_opts.opts.reasoning_effort
      end
      return ok
    end,
  },
},
```

Then in `schema.model.choices`, add preset variants with `opts.reasoning_effort`:
```lua
["gpt-5.5 [high]"] = { opts = { can_reason = true, reasoning_effort = "high" }, _model = "gpt-5.5" },
```

And add a `provider_model_remap`-style lookup to translate `"gpt-5.5 [high]"` → `"gpt-5.5"` before the API call.

### Option B: Extend `provider_model_remap` to support struct returns

Update `my_ai_constants.lua:289-298` so `provider_model_remap` can return `{ model = "gpt-5.5", reasoning_effort = "high" }`. Update the lookup in `my_codecompanion_actions.lua:505` or `my_codecompanion_utils.lua` to write both the remapped model name and `reasoning_effort` into parameters.

**Recommendation:** Option A is closer to how CodeCompanion's `opts` mechanism already works. Option B is simpler to understand but requires more plumbing.

## Action Items

- [ ] Decide on Option A (`handlers.setup` override) or Option B (`provider_model_remap` structured return).
- [ ] Define the first preset set in [my_ai_constants.lua](lua/utils/my_ai_constants.lua).
- [ ] Implement the chosen remap/setup path in [my_codecompanion_utils.lua](lua/utils/my_codecompanion_utils.lua).
- [ ] Verify the outgoing request payload uses the base model name plus `reasoning_effort`.

## Points to Confirm

- [ ] Confirm the exact model IDs are available in the Agoda proxy before adding presets.
- [ ] Confirm display-name style: `gpt-5.5 [high]`, `gpt-5.5-high`, or grouped picker labels.
- [ ] Confirm YAML header `reasoning_effort` should override picker presets when both are present.

## Implementation Plan

- [ ] Decide between Option A and Option B
- [ ] Add preset model constants in `my_ai_constants.lua` (display names with effort suffix)
- [ ] Implement the remap / setup hook in `get_agoda_adapters()` in `my_codecompanion_utils.lua`
- [ ] Add preset choices to `schema.model.choices` (or a separate `preset_choices` function that merges with dynamic list)
- [ ] Test: pick `gpt-5.5 [high]` → API request should have `model: "gpt-5.5"` + `reasoning_effort: "high"`
- [ ] Ensure existing models still work (gpt-5.5 without suffix → no effort injected)

## Success Criteria

- Model picker shows preset variants alongside plain model names
- Selecting a preset sends the correct base model name + effort level
- YAML `show_settings` block still works as override (higher priority)
- No regression on plain model selection

## Verification

```bash
NVIM_APPNAME=nvimwt3a nvim
```

```vim
:CodeCompanionChat
" Switch adapter to openai_agd, pick "gpt-5.5 [high]"
" Send a message
```

```bash
# Verify request payload
grep -i "reasoning_effort\|model" ~/.local/state/nvimwt3a/log | tail -10
```

### Checklist

- [ ] `gpt-5.5 [high]` visible in model picker
- [ ] Request contains `"model": "gpt-5.5"` (not `"gpt-5.5 [high]"`)
- [ ] Request contains `"reasoning_effort": "high"`
- [ ] `gpt-5.5` without suffix works as before (no effort key)
- [ ] YAML block override still works

## References

- [Adapter factory](lua/utils/my_codecompanion_utils.lua:65-158)
- model choice utility: `~/.local/share/nvim3_jelly_tinynvim/lazy/codecompanion.nvim/lua/codecompanion/utils/adapters.lua:423`
- `map_schema_to_params`: `~/.local/share/nvim3_jelly_tinynvim/lazy/codecompanion.nvim/lua/codecompanion/adapters/http/init.lua:192`
- [Reasoning effort task](tasks/review/codecompanion-reasoning-effort.md)
