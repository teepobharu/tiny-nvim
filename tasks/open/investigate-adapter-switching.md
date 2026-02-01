Title: Investigate adapter/model switch mid-chat causing unsupported-parameter errors

Short description
- Reproduce and fix an error seen when switching adapters/models mid-chat (e.g. from `gpt-4o` to `5mini`) that returns:

```json
{"error":{"message":"Unsupported parameter: 'temperature' is not supported with this model.","code":"invalid_request_body"}}
```

Why this matters
- Switching the inference adapter or target model during an active chat can produce requests that include parameters unsupported by the new model. That causes 400s and breaks ongoing conversations.

Goals
- Reproduce reliably, find the code path that performs adapter/model switching, add parameter-capability checks, add tests and improved logging, and provide a safe fallback strategy.

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
