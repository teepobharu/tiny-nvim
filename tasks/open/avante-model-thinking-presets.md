---
title: "Avante: model+thinking presets shared with CodeCompanion"
status: open
priority: low
created: 2026-10-05
updated: 2026-10-05
refs:
  - 90a0e77 @2026-06-24 avante.nvim ci: attempt to build without docker (pinned in myAi.lua for Neovim 0.11)
related:
  - [myAi.lua](lua/plugins/extra/myAi.lua)
  - [avante.lua (legacy stub)](lua/plugins/extra/avante.lua)
  - [my_avante_utils.lua](lua/utils/my_avante_utils.lua)
  - [my_codecompanion_thinking.lua](lua/utils/my_codecompanion_thinking.lua)
  - [my_codecompanion_utils.lua](lua/utils/my_codecompanion_utils.lua)
  - [my_ai_constants.lua](lua/utils/my_ai_constants.lua)
  - [codecompanion-model-effort-presets task](tasks/open/codecompanion-model-effort-presets.md)
  - [Avante memory doc](docs/memory/avante.md)
  - [lazy.nvim config merging doc](docs/memory/lazy-nvim-config-merging.md)
---

## Objective

Give Avante the same model+thinking preset support as CodeCompanion.
Selecting a preset (e.g. `gpt-5.5 [high]`) must set both the model and the thinking level on the outgoing request.
The preset table and resolution logic must be shared, so both pickers are driven by the same canonical alias generation.
Also verify that thinking can be controlled separately from the model in Avante.

## Context

**CodeCompanion (existing source of truth).**
[my_codecompanion_thinking.lua](lua/utils/my_codecompanion_thinking.lua) is the single source for presets.
`VERIFIED_ROUTE_POLICIES` ([lines 83-157](lua/utils/my_codecompanion_thinking.lua:83-157)) maps canonical AGD models (from [my_ai_constants.lua](lua/utils/my_ai_constants.lua)) to the exact thinking levels live-proven per adapter + endpoint.
`ADVISORY_SELECTOR_POLICIES` ([lines 158-199](lua/utils/my_codecompanion_thinking.lua:158-199)) adds advisory aliases that are not route-proven.
`M.model_selector_presets` ([lines 201-224](lua/utils/my_codecompanion_thinking.lua:201-224)) emits both, `M.resolve_model_selector_preset` / `M.canonical_model` resolve aliases, and `M.expand_model_choices` ([line 257](lua/utils/my_codecompanion_thinking.lua:257-257)) injects aliases into the picker (wired in [my_codecompanion_utils.lua](lua/utils/my_codecompanion_utils.lua:212-212) and :288).
A new model needs one registry entry, not parallel selector and capability edits.
"Same presets" between tools therefore means the same shared generation logic, filtered per consumer by that route's proven capability.

**Avante (current state).**
The canonical Avante spec is [myAi.lua](lua/plugins/extra/myAi.lua:229-240), which conditionally pins the 0.11-compatible commit, sets providers, and binds `mappings.select_model = "<leader>rM"` ([myAi.lua](lua/plugins/extra/myAi.lua:321)).
Its comment states it is the single canonical spec and that a second fragment's `config` would replace it (lazy.nvim merges tables but not `config`).
[lua/plugins/extra/avante.lua](lua/plugins/extra/avante.lua) is a legacy fragment superseded by that spec; it still sets a broken `<leader>rM` -> `:AvanteModel<CR>` keymap even though the installed Avante only defines `:AvanteModels`.
The active model UX lives in [my_avante_utils.lua](lua/utils/my_avante_utils.lua) (AGD provider, `model_names`, `select_model_*` helpers) plus existing `<leader>rs*` keymaps.

Model selection is Avante's built-in picker: `<Plug>(AvanteSelectModel)` -> `require("avante.api").select_model()`, command `:AvanteModels`.
`model_selector.lua` builds entries from `provider.model` / `model_names` (plain strings, no per-choice metadata), and `on_select` calls `Config.override({ model = choice.model })` with the raw entry name, which the provider then serializes into the request body as-is.
There is no hook that maps a display alias to a canonical model + effort.

Thinking today is static per provider: the installed `openai` and `azure` defaults set `extra_request_body.reasoning_effort = "medium"` (the `low|medium|high` space is a comment convention, not enforced).
The `copilot` default defines no `reasoning_effort`, but the copilot provider inherits OpenAI request handling and deep-merges `extra_request_body`, so it can transport a custom value - unverified, needs a live probe of both Chat Completions and Responses request shapes.
Claude and Gemini use separate internal handling (extended thinking / generationConfig), no `reasoning_effort` field.
Avante does no client-side level validation (unlike `M.validate_effort`), so an unsupported level would silently pass to the wire.
Persistence gap: the selected model is saved and restored via `apply_model_selection` (installed `config.lua:1174-1196`), which restores provider + model only - a set `reasoning_effort` is lost on restart.

## Gaps to verify during implementation

- Resolve the legacy [avante.lua](lua/plugins/extra/avante.lua) fragment and the duplicate `<leader>rM` binding (broken `:AvanteModel<CR>` vs the working `mappings.select_model` in [myAi.lua](lua/plugins/extra/myAi.lua:321)) before adding preset logic.
- Injection point: alias entries in `model_names` alone would send the alias as the wire model. A mapping/interception layer is required (wrap `on_select` / `Config.override` in `model_selector.lua`, analogous to CodeCompanion's `wrap_chat` pattern), or keep preset state separately and wrap provider request construction.
- Restart behavior: decide whether preset state must survive restart (needs a startup reconciliation hook) and what a plain model change outside the preset picker does to the active level (reset vs inherit).
- Copilot wire: live-probe that the endpoint accepts the chosen `reasoning_effort` values in both Chat and Responses modes; record the exact request shape for each.
- Level mapping: CodeCompanion levels go to `minimal|xhigh|max`; the Avante copilot wire is documented as `low|medium|high`. No silent downgrades - only expose tested mappings, and label any mapped preset honestly.

## Implementation Plan

- [ ] Decide the fate of the legacy `avante.lua` fragment (consolidate/remove) and remove the stale `<leader>rM` -> `:AvanteModel<CR>` binding
- [ ] Investigate installed Avante: `model_selector.lua` entry building and `on_select` / `Config.override`, where `extra_request_body` is read at request time, and the persistence path (`last_model` save/restore)
- [ ] Extract a provider-agnostic preset registry (verified + advisory entries, alias generation, alias resolution) from [my_codecompanion_thinking.lua](lua/utils/my_codecompanion_thinking.lua:83-260) into a shared module (e.g. `lua/utils/my_ai_model_presets.lua`); keep CodeCompanion-specific capability enforcement and request hooks in the thinking module; canonical IDs stay in [my_ai_constants.lua](lua/utils/my_ai_constants.lua)
- [ ] Regression-check CodeCompanion before and after the extraction: same picker aliases, same canonical IDs, same effort resolution, unchanged request output
- [ ] Add a per-route consumer policy so Avante only surfaces entries proven for its provider + endpoint (CodeCompanion keeps showing its verified + advisory sets)
- [ ] Define the level mapping policy (no silent downgrade) and live-probe the exact model + endpoint + level combos through the copilot provider in both request modes
- [ ] Add the Avante preset surface: aliases in the picker style of CodeCompanion; selecting one writes the canonical model and the effective effort to the request
- [ ] Add separate thinking control for the current Avante model, restricted to that model's verified levels, with a defined reset/inherit rule on model or provider changes
- [ ] Add the restart/reconciliation behavior for the active effort (or document that presets intentionally do not persist)
- [ ] Update [docs/memory/avante.md](docs/memory/avante.md): canonical config locations, picker paths, verified request behavior (it currently has stale config guidance)

## Success Criteria

- Avante presets come from the same shared table as CodeCompanion, filtered by Avante's proven capability - no duplicated preset lists.
- Selecting an Avante preset changes the real request: correct wire model ID and `reasoning_effort` (verified in the outgoing request).
- Thinking level can be changed in Avante without changing the model, restricted to the verified levels for that model, and behaves predictably across model switches and restarts.
- No regression in CodeCompanion: same picker entries, same resolution behavior.

## Verification

### How to verify

Test in the isolated worktree profile first, then the main profile.
Open the Avante model picker and compare its preset entries against CodeCompanion's picker.
Send one Avante request using a non-default thinking preset and confirm the wire model and effort in the outgoing request.
The request-inspection mechanism must be established during implementation (Avante debug log location, or a local proxy capture) and recorded in the memory doc.

### Commands

```bash
# Worktree profile first (per repo guide)
NVIM_APPNAME=nvimwt3a nvim
# Main profile after worktree passes
NVIM_APPNAME=nvim3_jelly_tinynvim nvim
```

```vim
" Avante model picker (live binding from myAi.lua)
<leader>rM

" CodeCompanion model picker (exact keymap/command to be named during implementation)
" <leader>??  (TBD)

" Separate thinking control (final binding decided in implementation)
<leader>rt
```

### Checklist

- [ ] Avante model list shows `model [thinking]` presets, generated from the shared table and limited to Avante-proven levels
- [ ] Outgoing request for a preset shows the canonical model ID (not the alias) and the preset's `reasoning_effort`
- [ ] Thinking level can be changed without changing the model, and only verified levels are offered
- [ ] After restart (or a plain model change), the active effort matches the documented reset/inherit rule
- [ ] CodeCompanion model picker is unchanged (same aliases, same resolution, same request output)
- [ ] The stale `<leader>rM` -> `:AvanteModel<CR>` binding is gone and `<leader>rM` opens the picker without errors
- [ ] [docs/memory/avante.md](docs/memory/avante.md) reflects the canonical config locations and verified request behavior

## References

- [Preset registry (verified)](lua/utils/my_codecompanion_thinking.lua:83-157) and [advisory](lua/utils/my_codecompanion_thinking.lua:158-199)
- [Preset generation and resolution](lua/utils/my_codecompanion_thinking.lua:201-260)
- [Canonical Avante spec](lua/plugins/extra/myAi.lua:229-240) and [select_model binding](lua/plugins/extra/myAi.lua:321)
- [Legacy Avante fragment](lua/plugins/extra/avante.lua)
- [Avante model helpers](lua/utils/my_avante_utils.lua)
- [CC preset task](tasks/open/codecompanion-model-effort-presets.md)
- Installed source: `~/.local/share/nvim3_jelly_tinynvim/lazy/avante.nvim/` (90a0e77 @ 2026-06-24; pinned in [myAi.lua](lua/plugins/extra/myAi.lua:235-237) for Neovim 0.11)
