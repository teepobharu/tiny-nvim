---
title: "Investigate CodeCompanion adapter/model switch parameter errors"
status: open
priority: high
created: 2026-01-29
updated: 2026-07-02
related:
  - [my_codecompanion_utils.lua](lua/utils/my_codecompanion_utils.lua)
  - [my_codecompanion_actions.lua](lua/utils/my_codecompanion_actions.lua)
  - [my_ai_constants.lua](lua/utils/my_ai_constants.lua)
  - [CodeCompanion memory](docs/memory/codecompanion.md)
---

Title: Investigate adapter/model switch mid-chat causing unsupported-parameter errors

Short description

- Reproduce and fix an error seen when switching adapters/models mid-chat (e.g. from `gpt-4o` to `5mini`) that returns:

```json
{
  "error": {
    "message": "Unsupported parameter: 'temperature' is not supported with this model.",
    "code": "invalid_request_body"
  }
}
```

Why this matters

- Switching the inference adapter or target model during an active chat can produce requests that include parameters unsupported by the new model. That causes 400s and breaks ongoing conversations.

Goals

- Reproduce reliably, find the code path that performs adapter/model switching, add parameter-capability checks, add tests and improved logging, and provide a safe fallback strategy.

## Action Items

- [ ] Reproduce the unsupported `temperature` failure in `NVIM_APPNAME=nvimwt3a` with a captured request body.
- [ ] Trace the active model location during runtime switching; do not rely only on `self.schema.model.default`.
- [ ] Decide whether sanitization belongs in adapter setup, request serialization, or the local model-selection action.
- [ ] Add a minimal model capability map only after confirming the active-model lookup path.
- [ ] Document the final CodeCompanion adapter-switching caveat in [CodeCompanion memory](docs/memory/codecompanion.md).

## Points to Confirm

- [ ] Confirm the exact failing model pair, for example `gpt-4o` -> `gpt-5-mini` or the reverse.
- [ ] Confirm whether the fix should cover Copilot only or all Agoda/OpenAI-compatible adapters.
- [ ] Confirm whether unsupported optional parameters should be silently dropped or surfaced in a user notification.

Notes (initial research, 2026-01-29)

- Repository stamp: branch `main`, last commit `db6a205` (2026-01-28 17:23:58 +0700) — working tree has mixed changes and the new task file added.
- Observed code locations of interest: `lua/utils/my_codecompanion_utils.lua`, `lua/utils/my_codecompanion_actions.lua`, `lua/utils/my_ai_constants.lua`, `tests/myTest.lua`, and adapter overrides under `lua/plugins/extra/`.
- Root cause hypothesis: adapter/model switches update the adapter schema default model but do not sanitize active request parameters; global/default `temperature` and other params persist and are sent to a model that does not accept them (hence the 400 `invalid_request_body`).
- Quick triage suggestions:
  - Add a small capability map (starting with `temperature`, `max_tokens`, `top_p`) for common target models used in repo: `gpt-4o`, `gpt-4o-mini`, `gpt-5-mini`, `gpt-5.2`, Claude variants, and internal proxy endpoints. Store under `lua/utils/model_capabilities.lua`.
  - Implement sanitization in the adapter HTTP request serializer (likely `codecompanion.adapters.http.openai_compatible` or the generic HTTP adapter) to drop unsupported params per target model.
  - Add structured logs on adapter switches: `INFO adapter_switch session=<id> from=<old_adapter/model> to=<new_adapter/model> params_before=<json> params_after=<json> request_id=<header>`.

Checklist (high level)

- [ ] Reproduce the failure locally and capture full request/response (include headers and body). Save logs to `logs/adapters-switch-<timestamp>.log`.
- [ ] Locate adapter/model-selection code paths: inspect `ai/opencode/opencode.jsonc`, `ai/codex/config.toml`, `claude/.mcp.json`, and Lua/JS code that handles chat sessions (likely under `lua/` or `ai/`).
- [ ] Add a capabilities matrix for models (which parameters each model supports — e.g. `temperature`, `max_tokens`, `top_p`) and where adapters are mapped to models.
- [ ] Implement parameter sanitization before sending requests: remove or translate unsupported params when adapter/model changes mid-chat.
- [ ] Add automated tests that simulate a mid-chat switch (unit and integration): expect sanitized requests and no 400 response.
- [ ] Add structured logging/telemetry for adapter switches capturing: session id, previous model/adapter, new model/adapter, outgoing request body, response status, and request-id header.
- [ ] Propose runtime fallback: if sanitized request still fails, retry without optional params or choose a compatible adapter automatically and surface a clear message to the client.
- [ ] Document changes and update `docs/memory/<adapter_name>.md` with findings and fix details.

Investigation hints / places to look

- Where model selection is stored/changed in session state (session store, user state, or chat object in `lua/` or `ai/`).
- The HTTP request builder: find code that serializes `temperature`, `max_tokens`, etc. and check whether it's conditional on the model/adaptor.
- Any adapter mapping files or config: `ai/opencode/opencode.jsonc`, `ai/codex/config.toml`, `claude/.mcp.json`, plugin overrides under `lua/plugins/extra/`.

Verification steps

- Re-run reproduction flow and confirm requests to the model endpoint no longer include unsupported parameters.
- Run new tests and confirm CI passes locally.
- Confirm logs contain a structured record of the adapter switch event.

Owner / Priority

- Owner: @dev (assign in issue/PR when ready)
- Priority: high

Deliverables

- PR with capability map and sanitization, unit+integration tests, enhanced logging, and short docs entry at `docs/memory/<adapter_name>.md`.

Extra context

- Examples in repo show `temperature` declared in adapter schemas (e.g. `my_codecompanion_utils.openai_agd` and `vertex_claude_agd`) and a global default in `my_ai_constants.lua`. That makes it easy for a switched session to carry an unsupported `temperature` into an incompatible model call. (2026-01-29)
  Short: Investigation notes for temperature `enabled` logic in CodeCompanion Copilot adapter.

Summary

- Problem: `schema.temperature.enabled` still allows errors when switching to other models (e.g., non-gpt-5-mini), even though prints indicate the enabled check returns false.
- Location observed: /Users/tharutaipree/.local/share/nvim3_jelly_tinynvim/lazy/codecompanion.nvim/lua/codecompanion/adapters/http/copilot/init.lua

Reproduction steps

1. Load Neovim with current config.
2. Use Copilot adapter with model set to `gpt-5-mini` and check that `temperature.enabled` returns false.
3. Switch active model to another model (e.g. `gpt-4o`) and observe an error still occurs related to temperature option.

Observed sample code (investigation sample)

```lua
-- docs/memory: sample from investigation
schema = {
model = {
default = require("utils.my_ai_constants").DEFAULT_COPILOT_MODEL or "gpt-5-mini",
},
temperature = {
enabled = function(self)
-- calling upstream helper
local result = require("codecompanion.adapters.http.copilot").schema.temperature.enabled(self)
local model = self.schema.model.default
if type(model) == "function" then
model = model()
end
result = result and not vim.startswith(model, "gpt-5-mini") and not vim.startswith(model, "gpt-5")

print("copilot#enabled#if model:", vim.inspect(result))
return result
end,
},
}
```

Key observations

- The local `result` returned by the upstream helper call appears correct in logs (prints show false for `gpt-5-mini`).
- After switching to another model at runtime the same enabled check still yields the same value and an error happens when temperature option is used.
- `self.schema.model.default` may not represent the _active_ model at runtime. It might be a default/factory function rather than runtime selection. If the adapter uses a different key to track active model, the check will be wrong.
- The code guards with `vim.startswith(model, "gpt-5-mini")` and `gpt-5` — ensure these prefixes match exact runtime model names.

Immediate hypotheses

- The `enabled` function is reading the static schema default rather than the actual configured/active model.
- The model might be stored on a different table (e.g. `self.opts.model`, `self.config.model`, or on adapter instance state) or resolved lazily.
- The upstream helper `require("codecompanion.adapters.http.copilot").schema.temperature.enabled` may itself expect different `self` shape.

Suggested quick tests / overrides (temporary)

- Create a temporary override to wrap the adapter's `schema.temperature.enabled` and log `self` contents and the resolved model. This helps find where the active model lives.
