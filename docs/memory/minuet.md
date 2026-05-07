# minuet-ai.nvim

## AGD default model

`myMinuet.lua` sets `model = AI.models.gemini.GEMINI_3_FLASH .. "-preview"` (→ `gemini-3-flash-preview`) for the `openai_compatible` AGD slot. The `openai` slot covers GPT models (`gpt-5.4-nano`). Use `:Minuet change_model` / `<leader>aS` to switch at runtime; use `:Minuet change_provider` to flip provider without restart.

## AGD proxy 401 `invalid_issuer`

Error: `"code": "invalid_issuer", "status": 401` from `http://openai-proxy.agoda.is`.

Cause: `GENAIAG` env var token stale. Fix: re-auth SSO / rotate token. This is env-scope — no code change needed. Verify: `echo $GENAIAG | cut -c1-20` should be non-empty + match current SSO token format. If still 401 after re-auth → escalate platform team.

## `:Minuet change_model` — subprovider key mechanism

For `openai_compatible` / `openai_fim_compatible` providers, `change_model` builds its picker list by looking up `modelcard.models[provider][lower(provider_options[provider].name)]`. Default `modelcard.lua` has no `agd` subprovider key → AGD models never appear.

`myMinuet.lua` patches this at setup: after `require("minuet").setup(opts)` it injects `modelcard.models.openai_compatible.agd = AI.get_top_choice_models("openai_agd")` when AGD profile is active. This surfaces `openai_compatible:<model>` entries in the picker (`<leader>aS`).

## `change_model` switches WHOLE BACKEND — not just model ID

Each top-level provider key (`gemini`, `claude`, `openai`, `openai_compatible`) routes to a separate backend module with its own endpoint + API key:

| Picker choice | Backend | Auth env |
|---|---|---|
| `openai_compatible:*` | `openai_compatible.lua` → AGD proxy | `AG_OPENAIPROXY` |
| `gemini:*` | `gemini.lua` → `generativelanguage.googleapis.com` | `GEMINI_API_KEY` |
| `claude:*` | `claude.lua` → `api.anthropic.com` | `ANTHROPIC_API_KEY` |
| `openai:*` | `openai.lua` → `api.openai.com` | `OPENAI_API_KEY` |

**Always pick `openai_compatible:*`** to stay on AGD. Picking `gemini:*` works if `GEMINI_API_KEY` is set (direct to Google, NOT through AGD proxy).

## Live status — `<leader>aM`

Shows live `require("minuet").config` so it reflects `change_model` / `change_provider` at runtime:

```
provider=openai_compatible  subprovider.name=AGD  model=gpt-4.1-mini  endpoint=http://openai-proxy.agoda.is/...
```

AGD is active iff `subprovider.name = "AGD"` AND endpoint contains `openai-proxy.agoda.is`.

## Gemini CLI via sidekick

Separate OS process — not routed through minuet or AGD proxy. Gemini in Avante/CodeCompanion routes through AGD proxy (with `-preview` suffix remap in `my_ai_constants.lua:provider_model_remap`).

## `stream` setting trade-off

`stream = true` + `request_timeout = 3` (recommended): SSE — timeout cancels mid-flight but keeps partial tokens. First tokens arrive sub-second.

`stream = false`: blocks until full JSON. Timeout before completion → **empty result**. Use `request_timeout ≥ 10` if forced to `stream = false` (e.g. proxy buffers SSE).

AGD caveat: if `openai-proxy.agoda.is` buffers the SSE response → completions empty even with `stream = true`. Test first; if empty → flip `stream = false` with `request_timeout = 10` in the `openai_compatible` slot.

## All-profiles-loaded pattern

`myMinuet.lua` populates all four `provider_options` slots at startup:

| Slot | Backend | Auth env | Default model |
|------|---------|----------|---------------|
| `openai_compatible` | AGD proxy | `GENAIAG` | `gemini-3-flash-preview` |
| `openai_fim_compatible` | ollama or llama.cpp | `TERM` (dummy) | `qwen2.5-coder:3b-base` |
| `openai` | AGD proxy (OpenAI format) | `GENAIAG` | `gpt-5.4-nano` |
| `gemini` / `claude` | minuet defaults (direct) | `GEMINI_API_KEY` / `ANTHROPIC_API_KEY` | — |

Switch at runtime: `:Minuet change_provider openai_fim_compatible` (→ FIM/local) or `:Minuet change_model` (→ within current provider). No restart needed.

FIM backend swap: `:MinuetFimSwitch ollama` / `:MinuetFimSwitch llamacpp` — updates live config. Per-project default: `vim.g.ai_minuet_fim_profile = "llamacpp"` in `.nvim-config.lua`.

## Helper commands

| Command | Action |
|---------|--------|
| `:MinuetOllamaStart` | Start `ollama serve` in background (`OLLAMA_NUM_PARALLEL=2`) |
| `:MinuetOllamaPull [model]` | `ollama pull <model>` in terminal buffer |
| `:MinuetLlamacppStart [model]` | Start `llama-server` on port 8012 in background |
| `:MinuetFimSwitch ollama\|llamacpp` | Swap FIM backend at runtime |

## NES keymap remap (copilot OFF)

`editor_keymaps.lua` maps `<leader>aN{t,e,d,u}` to `sidekick.nes.*`. When `ENABLE_COPILOT=false`, sidekick.nes no-ops (copilot-only adapter). `myMinuet.lua` overrides these via last-spec-wins:

| Key | Minuet action |
|-----|--------------|
| `<leader>aNt` | `:Minuet virtualtext toggle` |
| `<leader>aNe` | `require("minuet.virtualtext").action.enable()` |
| `<leader>aNd` | `require("minuet.virtualtext").action.dismiss()` |
| `<leader>aNu` | `:Minuet duet predict` |

When copilot is ON, `myMinuet.lua` early-returns `{}` → sidekick bindings take effect.

## FIM presets require `template` field

`openai_base.complete_openai_fim_base` (line 141) unconditionally calls `options.template.prompt(...)`. Deepseek/Codestral upstream defaults set `template = M.default_fim_template`; a full slot override (custom fim_presets) loses it → `attempt to index field 'template' (a nil value)` crash.

Fix: load `M.default_fim_template` from `minuet.config` before building fim_presets:

```lua
local ok_cfg, minuet_cfg = pcall(require, "minuet.config")
local default_fim_template = (ok_cfg and minuet_cfg.default_fim_template) or {
  prompt = function(before, _, _) return before end,
  suffix = function(_, after, _) return after end,
}
-- then in each fim_preset: template = default_fim_template
```

Inline fallback loses language/tab comment prefix but prevents crash. `pcall` required — module available at load time (leaf, no side effects) but guard for safety.

## `:Minuet change_preset` vs `:MinuetFimSwitch`

| | `change_preset` | `MinuetFimSwitch` |
|---|---|---|
| Trigger | `<leader>aP` → picker | `:MinuetFimSwitch ollama\|llamacpp` |
| Switches | provider + endpoint + model atomically via `vim.tbl_deep_extend` | endpoint + model only (fim slot); also sets `provider = openai_fim_compatible` |
| Presets | `agd`, `fim_ollama`, `fim_llamacpp`, `original` | `ollama`, `llamacpp` |
| Use when | full profile swap (AGD ↔ FIM ↔ back to original) | quick toggle between local backends |

Both coexist. `change_preset fim_ollama` = `MinuetFimSwitch ollama` + resets provider. `original` preset captured by minuet at setup — restores full initial state.

## Modelcard injection for FIM model picker

Without injection, `:Minuet change_model` shows no FIM model options (upstream modelcard has no ollama/llama.cpp entries). Inject after `require("minuet").setup(opts)`:

```lua
modelcard.models.openai_fim_compatible = modelcard.models.openai_fim_compatible or {}
modelcard.models.openai_fim_compatible.ollama = {
  "qwen2.5-coder:1.5b-base", "qwen2.5-coder:3b-base",
  "qwen2.5-coder:7b-base", "deepseek-coder-v2:16b-lite-base",
}
modelcard.models.openai_fim_compatible["llama.cpp"] = {
  "qwen2.5-coder-0.5b", "qwen2.5-coder-1.5b", "qwen2.5-coder-3b",
}
```

Key = `string.lower(fim_presets.*.name)`: `"Ollama"` → `"ollama"`, `"llama.cpp"` → `"llama.cpp"`.

Selecting a FIM model via picker updates `provider_options.openai_fim_compatible.model` only — does NOT switch endpoint. Pair with `:MinuetFimSwitch <backend>` or `change_preset` to switch endpoint + model atomically.

## Key keymaps

All minuet/duet normal-mode keys under `<leader>am*`. Sidekick NES under `<leader>aMm*` (which-key groups registered in `myAi.lua`).

Desc prefix convention: `Duet:`, `Virttext:`, `Pick model`/`Pick preset`, `Start <Provider> in bg (:<cmd>)`, `Switch FIM → <backend>`, `Status`, `Sidekick NES:`.

| Key | Action |
|-----|--------|
| `<C-c>` (insert) | unified AI completion: minuet blink (copilot when `ENABLE_COPILOT`) |
| `<A-]>` / `<A-[>` | virtualtext cycle next / prev |
| `<A-d>` / `<A-c>` / `<A-x>` (insert) | duet predict / apply / dismiss |
| `<leader>amm` | virttext toggle |
| `<leader>ame` / `<leader>amE` | virttext enable (action / cmd) |
| `<leader>amd` / `<leader>amD` | virttext dismiss / disable |
| `<leader>amp` / `<leader>ama` / `<leader>amx` | duet predict / apply / dismiss |
| `<leader>amu` | duet predict (alt) |
| `<leader>amM` | `:Minuet change_model` picker |
| `<leader>amP` | preset picker (`:MinuetPresetPick`) — wraps `change_preset` with `vim.ui.select` |
| `<leader>amSo` | start Ollama in bg (`:MinuetOllamaStart`) |
| `<leader>amSc` | start llama.cpp in bg (`:MinuetLlamacppStart`) |
| `<leader>amSf` / `<leader>amSF` | switch FIM → Ollama / llama.cpp |
| `<leader>amSs` | status (live provider/model/endpoint) |
| `<leader>aMmt` / `<leader>aMme` / `<leader>aMmd` / `<leader>aMmu` | sidekick NES toggle / enable / disable / update |

## `:Minuet change_preset` needs arg — wrap in picker

`init.lua:158-167` errors `"The preset is not supported."` when `fargs[2]` is `nil`. Direct `<cmd>Minuet change_preset<cr>` from a keymap fails. Solution: `:MinuetPresetPick` user-command runs `vim.ui.select(keys(M.presets))` then `m.change_preset(choice)`.

## AGD model injection — apply `provider_model_remap`

`get_top_choice_models("openai_agd")` returns raw IDs (`gemini-3.1-flash-lite`). AGD chat endpoint requires `-preview` suffix for Gemini 3.x → 400 `Invalid model name`. Apply `M.provider_model_remap[adapter_name]` to injected list:

```lua
local agd_remap = (AI.provider_model_remap or {})[AI.providers.openai_agd.adapter_name] or {}
for _, m in ipairs(agd_models) do
  table.insert(agd_models_remapped, agd_remap[m] or m)
end
modelcard.models.openai_compatible.agd = agd_models_remapped
```

Without remap, picker exposes raw IDs that fail at request time.

## Blink source_icon — `ctx.source_id` not `ctx.source_icon`

Upstream blink.cmp render context (`context.lua:14-15`) exposes `source_id` and `source_name`, NOT `source_icon`. `appearance.source_icons` top-level key is also NOT upstream — blink ignores it.

Custom `source_icon` component must read `ctx.source_id` inside the `text` function:
```lua
text = function(ctx)
  local map = { minuet = "󱗻", nvim_lsp = "", ... }
  return map[ctx.source_id] or ""
end
```

Two independent visual axes in blink menu:
- **kind_icon**: for minuet rows — shows active provider glyph (AGD=󱢆, Ollama=󰳆, Claude=󰋦…). For LSP rows — shows standard `CompletionItemKind` glyphs. Provider keys in `kind_icons` only match minuet rows; LSP rows untouched.
- **source_icon**: spans ALL sources. `ctx.source_id` lookup: `minuet`→󱗻, `nvim_lsp`→, `buffer`→, etc.
