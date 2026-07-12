# CodeCompanion Adapter Customization & Model Parameter Handling

**Date:** 2026-02-12  
**Status:** Research & Knowledge Base  
**Related Issues:** GPT-5.2 parameter incompatibilities with OpenAI Proxy

---

## Orphaned `tool_use` Error (Vertex AI / Anthropic via OpenAI Proxy)

**Date Added:** 2026-04-24

**Error:**
```
litellm.BadRequestError: Vertex_aiException BadRequestError -
"messages.N: `tool_use` ids were found without `tool_result` blocks immediately after"
```

**Root Cause:**
Anthropic's API (and Vertex AI Claude via the Agoda OpenAI proxy) enforces strict message pairing:
every assistant `tool_use` block must be **immediately followed** by a user message containing `tool_result`.
When the user types a new message while a tool call is in flight (interrupting the cycle), the chat history
contains an orphaned `tool_use` without a corresponding `tool_result` in the next message.

**Fix:**
An `on_submitted` callback in `myAi.lua` (around line 445) sanitizes the payload before it is sent:
1. Strips empty-content messages (`"text content blocks must be non-empty"` guard).
2. Strips orphaned tool_use assistant messages — any assistant message whose `tools.calls` are not
   answered by consecutive following tool result messages (`role="tool"` with matching `tools.call_id`).

**CRITICAL: Internal vs Wire Format:**
At `on_submitted` time, `payload.messages` uses the **internal** CC format, NOT the OpenAI wire format:
- Tool calls: `{ role = "assistant", tools = { calls = [{id, function, type}, ...] } }` (NOT `tool_calls`)
- Tool results: `{ role = "tool", tools = { call_id = "tooluse_xxx" } }` (NOT `tool_call_id`)
- The `form_messages` handler (which converts to `tool_calls`/`tool_call_id`) runs LATER inside `http.lua`
  at the `build_messages` step, AFTER `on_submitted` has already fired.

**Workaround (in-session):**
Press `<C-c>` (stop keymap) to cancel the current tool-calling request before typing a follow-up message.

**Fix location:** `lua/plugins/extra/myAi.lua` → `on_submitted` callback inside `CodeCompanionChatCreated` autocmd.

---

## ⚠️ IMPORTANT: Configuration Location

**All CodeCompanion configuration is newer and more updated in `lua/plugins/extra/myAi.lua`**

The old fork config that is not updated anymore `lua/plugins/extra/codecompanion.lua` file has been **disabled** to avoid conflicts.

### Common Issues & Solutions

**If you see errors like:**

- ❌ `Could not find '<alias>' in the prompt library`
- Wrong configuration field
- ❌ Duplicate prompt definitions
- ❌ Conflicting slash commands

**Solution - Check these files:**

TO Decide later: use Single source of truth:

- ✅ `lua/plugins/extra/myAi.lua` - Active configuration
- ❌ `lua/plugins/extra/codecompanion.lua.disabled` - Not maintained

### Why This Matters

**Root Cause of Conflicts:**

- Having both files enabled loads duplicate CodeCompanion configurations
- Different aliases in each file create "not found" errors
- Last loaded file wins ?, but aliases from both remain in memory
- Result: Confusing errors and broken slash commands

---

## 1. Adapter Schema Architecture

### How Schema Maps to Request Parameters

CodeCompanion uses a **schema-to-parameters mapping system** via the `mapping` key:

```lua
schema = {
  max_tokens = {
    mapping = "parameters",      -- Emits to adapter.parameters.max_tokens
    type = "integer",
    default = 4096,
  },
  ["reasoning.effort"] = {
    mapping = "parameters",      -- Emits to adapter.parameters.reasoning.effort
    type = "string",
  },
  verbosity = {
    mapping = "parameters.text", -- Emits to adapter.parameters.text.verbosity
    type = "string",
  },
}
```

**Mapping resolution** (from `adapters/http/init.lua:185-226`):

- Schema keys are split by `.` (e.g., `reasoning.effort`)
- Mapping path is split by `.` (e.g., `parameters.text`)
- CodeCompanion creates nested objects and emits the final value there
- All schema defaults are collected and applied via `map_schema_to_params()`

### Critical Implication

If your schema lists `max_tokens`, CodeCompanion **will always send it** in the request. The proxy/endpoint must accept it, or you get a 400 error.

---

## 2. OpenAI Endpoints & Parameter Requirements

### Chat Completions (`/v1/chat/completions`)

**CodeCompanion Adapter:** `openai.lua`  
**Current Schema (v18.3.1):**

- `model` → `parameters.model`
- `reasoning_effort` → `parameters.reasoning_effort` (reasoning models only)
- `temperature` → `parameters.temperature`
- `top_p` → `parameters.top_p`
- `max_tokens` → `parameters.max_tokens` ⚠️

**GPT-5.2 Compatibility (per OpenAI docs):**

- ✅ Supports: `max_completion_tokens` (not `max_tokens`)
- ❌ Does NOT support: `temperature`, `top_p` when `reasoning_effort` > `none`
- ⚠️ Default reasoning_effort: `none` (allows temperature/top_p)

**Issue:** CodeCompanion's `openai.lua` uses `max_tokens` which GPT-5.2 rejects. No parameter auto-renaming happens.

### Responses API (`/v1/responses`)

**CodeCompanion Adapter:** `openai_responses.lua`  
**Schema Parameters:**

- `["reasoning.effort"]` → `parameters.reasoning.effort`
- `["reasoning.summary"]` → `parameters.reasoning.summary`
- `temperature` → `parameters.temperature`
- `top_p` → `parameters.top_p`
- `max_output_tokens` → `parameters.max_output_tokens` ✅
- `verbosity` → `parameters.text.verbosity`

**Note:** Responses API is newer, preferred for reasoning models. Not covered by your current setup.

---

## 3. Custom Adapter Implementation Pattern

### File Structure (from `openai_compatible.lua`)

```lua
return {
  name = "adapter_name",
  formatted_name = "Display Name",
  roles = { llm = "assistant", user = "user" },
  opts = { stream = true, tools = true, vision = true },
  features = { text = true, tokens = true },
  url = "${url}${chat_url}",
  env = {
    api_key = "OPENAI_API_KEY",
    url = "http://openai-proxy.agoda.is",
    chat_url = "/v1/chat/completions",
  },
  headers = { ["Content-Type"] = "application/json", Authorization = "Bearer ${api_key}" },
  handlers = { /* response parsing, setup, teardown */ },
  schema = { /* model, temperature, max_tokens, etc. */ },
}
```

### Env Variable Substitution

- `env` table defines variable sources (hardcoded, env vars, commands)
- Variables are resolved via `adapter_utils.get_env_vars()` → `adapter.env_replaced`
- In `url`, headers, anywhere with `${var}` pattern, CodeCompanion substitutes values
- Supports: plain strings, env var names (e.g., `"OPENAI_API_KEY"`), `"cmd:..."` for shell commands, functions

### Schema Key Features

**Example:**

```lua
max_tokens = {
  order = 6,                           -- UI display order
  mapping = "parameters",              -- Where to emit in request
  type = "integer|number|string|enum", -- Validation type
  optional = true,                     -- Can be omitted
  default = 4096,                      -- Default value (or function)
  desc = "The maximum number of...",   -- UI description
  validate = function(n)               -- Custom validation
    return n > 0, "Must be > 0"
  end,
  enabled = function(self)             -- Conditionally show (reasoning models)
    return self.schema.model.default == "gpt-5.2"
  end,
}
```

**Conditional Parameters** (e.g., reasoning_effort only for reasoning models):

The following is the upstream pattern, but do **not** copy it for a field that must reappear after a model switch. In CodeCompanion 19.17, settings rendering may delete a schema key whose function-valued `enabled` returns false. The local reasoning controller keeps the field present and treats capability as advisory instead.

```lua
reasoning_effort = {
  enabled = function(self)
    local model = self.schema.model.default
    if type(model) == "function" then model = model(self) end
    local choices = self.schema.model.choices
    if type(choices) == "function" then choices = choices(self) end
    return choices and choices[model] and choices[model].opts and choices[model].opts.can_reason
  end,
  -- ...rest of schema
}
```

---

## 4. Model-Specific Configuration

### Model Choices with Options

From `openai.lua:391-442`:

```lua
choices = {
  ["gpt-5.2"] = {
    formatted_name = "GPT 5.2",
    opts = { has_vision = true, can_reason = true },
  },
  ["gpt-4.1"] = {
    formatted_name = "GPT 4.1",
    opts = { has_vision = true },
  },
  "gpt-3.5-turbo",  -- Simple string (no opts)
}
```

**How it works:**

1. If model is a string key in `choices` map, and it has `opts`, those opts are merged into `adapter.opts`
2. Handlers can check `adapter.opts.can_reason`, `adapter.opts.has_vision`, etc.
3. Schema `enabled` functions check `choices[model].opts.can_reason` to conditionally enable reasoning params

**Setup Handler Pattern** (from `openai.lua:64-89`):

```lua
setup = function(self)
  local model = self.schema.model.default
  if type(model) == "function" then model = model(self) end
  local model_opts = self.schema.model.choices
  if type(model_opts) == "function" then model_opts = model_opts(self) end

  if model_opts and model_opts[model] and model_opts[model].opts then
    self.opts = vim.tbl_deep_extend("force", self.opts, model_opts[model].opts)
  end
  return true
end
```

---

## 5. OpenAI Proxy / Custom Endpoint Considerations

### Pass-Through Behavior

Your Agoda OpenAI Proxy at `http://openai-proxy.agoda.is/v1` is **OpenAI API-compatible** but:

- **Does not rename parameters** (e.g., won't auto-convert `max_tokens` → `max_completion_tokens`)
- **May enforce model-specific constraints** (e.g., GPT-5.2 rejects `max_tokens`, only accepts `max_completion_tokens`)
- **Acts as a transparent forwarder**, not a translator

### Implication for Your Setup

Since the proxy is pass-through, **all parameter naming must be correct at the client level** (CodeCompanion). CodeCompanion doesn't have built-in parameter translation, so your adapter schema must emit exactly what the backend expects.

---

## 6. GPT-5.2 Specific Constraints

From OpenAI docs (https://platform.openai.com/docs/guides/latest-model):

| Parameter          | Constraint                              | Workaround                                                            |
| ------------------ | --------------------------------------- | --------------------------------------------------------------------- |
| `max_tokens`       | ❌ Not supported                        | Use `max_completion_tokens` (chat) or `max_output_tokens` (responses) |
| `temperature`      | ❌ Only when reasoning_effort = `none`  | Default is `none`, so OK if reasoning not used                        |
| `top_p`            | ❌ Only when reasoning_effort = `none`  | Same as temperature                                                   |
| `reasoning_effort` | ✅ Supports: none/low/medium/high/xhigh | Default: `none`                                                       |

**For chat/completions with GPT-5.2:**

1. Use `max_completion_tokens` instead of `max_tokens`
2. Keep editable `temperature` and `top_p` in chat settings; they remain useful when effort is unset/`none`
3. Explicit reasoning can conflict with non-default sampling on OpenAI models
4. Normalize those conflicts on the outgoing request copy rather than hiding schema fields or deleting user settings

---

## 7. Current Resolution (supersedes the March 2026 setup notes)

The earlier `max_tokens` / `temperature = 0` investigation is resolved:

- `openai_agd` uses `max_completion_tokens = 4096`; the obsolete `max_tokens` override is gone.
- Thinking effort is optional and defaults to unset, not an implicit local level.
- The reasoning schema stays present across model switches. Avoid a function-valued `enabled` gate here: CodeCompanion 19.17 can permanently delete a disabled schema key while rendering settings.
- Clearing effort removes the old flat/nested adapter parameter before remapping, preventing stale request state.
- Known OpenAI sampling conflicts are normalized only on the outgoing request copy; editable chat settings remain intact.
- Capability metadata controls advice and warnings, never whether a manual value is mapped.

The isolated regression suite is [tests/test_codecompanion_thinking.lua](../../tests/test_codecompanion_thinking.lua). Live Agoda observations and the manual verification checklist are documented in the reasoning-control section below and in [the review task](../../tasks/review/codecompanion-reasoning-effort.md).

## 8. Adapter Best Practices

1. Schema keys map directly to request parameters; the proxy does not rename them.
2. An optional setting that must survive model switches should stay in the schema and use advisory capability metadata rather than a destructive visibility gate.
3. Model choices/options are useful hints but can be stale or missing for dynamically fetched models.
4. Extend the correct parent handler shape: flat legacy handlers for OpenAI chat-completions, nested request handlers for Responses.
5. Reset managed parameter paths before schema mapping because upstream mapping sets values but does not unset absent ones.
6. Mutate only the deep-copied outgoing request for model-specific conflicts; preserve `chat.settings` and manual YAML/debug edits.

---

## 11. Commit Message Generation Commands

**Date Added:** 2026-03-11  
**Feature:** Dual commit message generation with smart diff filtering

### Overview

Two complementary commands for generating git commit messages:

1. **Full Diff Command** (`<leader>Amm`) - All staged changes with full diffs
2. **Large Files Summary** (`<leader>AmM`) - Large file summaries + small file diffs

### Command Details

#### Full Diff: `<leader>Amm`

- **Alias:** `/short-staged-commit`
- **Behavior:** Sends complete `git diff --staged` output to AI
- **Use case:** Small changesets, detailed commit messages needed
- **Output:** Complete diff content for all staged files

#### Large Files Summary: `<leader>AmM`

- **Alias:** `/large-files-commit`
- **Behavior:** Smart filtering of staged diff:
  - Files >50 lines → Summary only (`M filepath +added -deleted`)
  - Files ≤50 lines → Full diff content
  - Renames → Summary (`R old/path -> new/path`)
  - Binary files → Summary (`M filepath (binary)`)
- **Use case:** Large changesets, reduce token usage, focus AI on small changes
- **Implementation:** `utils.my_codecompanion_utils.get_filtered_staged_diff(50)`

### Output Format Example

```
M lua/plugins/extra/myAi.lua +141 -378
M tasks/AGENTS.md +76 -0
A tasks/new_file.md +94 -0
D tasks/old_file.md +0 -180
R tasks/done/task.md -> tasks/completed/task.md
B assets/image.png (binary)

diff --git c/small_file.lua i/small_file.lua
index e380f04..c5340cc 100644
--- c/small_file.lua
+++ i/small_file.lua
@@ -1,3 +1,5 @@
+-- New content
 local M = {}
...
```

### Implementation Details

**Function:** `get_filtered_staged_diff(threshold)` in `lua/utils/my_codecompanion_utils.lua`

**Algorithm:**

1. Run `git diff --staged --numstat` to get line change counts
2. Run `git diff --staged --name-status` to get file status (M/A/D/R)
3. Categorize files:
   - `added + deleted > threshold` → Large files (summary only)
   - `added == "-" and deleted == "-"` → Binary files
   - `filename contains "{old => new}"` → Renames
   - Otherwise → Small files (full diff)
4. Build output:
   - Large files: `<status> <filepath> +<added> -<deleted>`
   - Renames: `R <old_path> -> <new_path>`
   - Binary files: `<status> <filepath> (binary)`
   - Small files: Full `git diff` content

**Status Symbols:**

- `M` - Modified
- `A` - Added
- `D` - Deleted
- `R` - Renamed
- `B` - Binary (inferred from status + binary marker)

### Configuration

**Threshold:** Default 50 lines (hardcoded in prompt function)
**Location:** `lua/plugins/extra/myAi.lua:739-789`

To change threshold, modify the function call:

```lua
local filtered_diff = require("utils.my_codecompanion_utils").get_filtered_staged_diff(100) -- 100 line threshold
```

### Keymaps

Defined in `lua/utils/editor_keymaps.lua:303-311`:

```lua
{
  "<leader>Amm",  -- All staged files (full diff)
  "<cmd>CodeCompanion /short-staged-commit<cr>",
  desc = "Code Companion - Git commit (all staged)",
},
{
  "<leader>AmM",  -- Large files summary
  "<cmd>CodeCompanion /large-files-commit<cr>",
  desc = "Code Companion - Git commit (large files summary)",
},
```

**Which-key group:** `<leader>Am` → "Commit Message"

### Benefits

1. **Token efficiency:** Large refactors don't overwhelm the AI with diffs
2. **Focused analysis:** AI can still see detailed changes for small modifications
3. **Rename clarity:** Clearly distinguishes file moves from content changes
4. **Binary handling:** Prevents binary content from polluting prompt
5. **Consistent format:** Same commit message style for both commands

### Testing

```bash
# Test the filtering function directly
NVIM_APPNAME=nvim3_jelly_tinynvim nvim --headless \
  -c "lua print(require('utils.my_codecompanion_utils').get_filtered_staged_diff(50))" \
  -c "qa"

# Stage some changes and test keymaps
git add <files>
# In Neovim: <leader>Amm or <leader>AmM
```

### Related Files

- **Utility:** `lua/utils/my_codecompanion_utils.lua:150-268`
- **Prompts:** `lua/plugins/extra/myAi.lua:700-789`
- **Keymaps:** `lua/utils/editor_keymaps.lua:303-311`
- **Which-key:** `lua/plugins/extra/myAi.lua:110-117`

---

## 12. Custom Actions with Visual Mode Line Range Filtering

**Date Added:** 2026-03-11  
**Pattern:** Creating CodeCompanion actions that filter git diffs by visual selection

### Key Findings

**Visual Mode Context:**
CodeCompanion actions receive visual selection context automatically when invoked with `:'<,'>CodeCompanionActions`:

```lua
prompts = {
  {
    role = "user",
    content = function(context)
      -- context.start_line and context.end_line available in visual mode
      local start_line = context and context.start_line
      local end_line = context and context.end_line
      -- Use these to filter content
    end,
  },
}
```

**Git Diff Hunk Filtering:**
To filter git diff by line range, parse hunk headers (`@@ -old +new @@`):

```lua
-- Example hunk header: @@ -10,5 +15,8 @@
local new_start, new_count = line:match "^@@%s*%-(%d+),?(%d*)%s*%+(%d+),?(%d*)%s*@@"

-- Check if hunk overlaps with [start_line, end_line]
local hunk_end = new_start + new_count - 1
local overlaps = (new_start <= end_line and hunk_end >= start_line)
```

**Full File Context Pattern:**
Include full file content as context for better AI analysis:

```lua
context = {
  {
    type = "file",
    path = function()
      return vim.api.nvim_buf_get_name(0)
    end,
  },
}
```

This provides AI with complete file structure while the prompt contains specific changes to review.

**Reusable Prompts:**
Extract common prompts to `lua/utils/my_ai_prompts.lua` for sharing across actions:

```lua
-- In my_ai_prompts.lua
M.MY_PROMPT = function(param1, param2)
  return string.format([[Your prompt template with %s and %s]], param1, param2)
end

-- In myAi.lua
local prompts = require("utils.my_ai_prompts")
content = function(context)
  return prompts.MY_PROMPT(arg1, arg2)
end
```

### Example Implementation

See `tasks/review/codecompanion-code-review-actions.md` for complete implementation example with:

- Visual mode line range filtering for git diffs
- Full file context integration
- Reusable prompt templates
- Error handling patterns

---

---

## 13. Chat History Extension (`ravitemer/codecompanion-history.nvim`)

**Date Added:** 2026-03-24

### Overview

Persists CodeCompanion chat sessions to disk and provides a picker to browse/restore them. Registered as a CodeCompanion extension under `extensions.history`.

### Configuration (in `myAi.lua`)

```lua
-- dependency added to olimorris/codecompanion.nvim deps
{ "ravitemer/codecompanion-history.nvim" }

-- extension block
extensions = {
  history = {
    enabled = true,
    opts = {
      keymap = "gh",              -- open history picker from chat buffer
      save_chat_keymap = "sc",    -- manual save from chat buffer
      auto_save = true,           -- auto-save all chats on close
      expiration_days = 30,       -- delete chats older than 30 days (0 = never)
      picker = "snacks",          -- snacks / telescope / fzf-lua / default
      auto_generate_title = true,
      continue_last_chat = false,
      delete_on_clearing_chat = false,
      dir_to_save = vim.fn.stdpath("data") .. "/codecompanion-history", -- ie: ~/.local/share/nvim3_jelly_tinynvim/codecompanion-history
    },
  },
  -- mcphub = { ... }
}
```

### Keymaps

| Keymap | Scope | Action |
|--------|-------|--------|
| `<leader>AH` | Normal (global) | `:CodeCompanionHistory` — open history browser |
| `gh` | Chat buffer | Open history picker |
| `sc` | Chat buffer | Manually save current chat |

### Browser Actions (in picker)

| Key (normal) | Key (insert) | Action |
|---|---|---|
| `<CR>` | `<CR>` | Restore selected session |
| `r` | `<M-r>` | Rename session |
| `d` | `<M-d>` | Delete session |
| `<C-y>` | `<C-y>` | Duplicate session |

### Storage

Saved to `~/.local/share/nvim3_jelly_tinynvim/codecompanion-history/` (stdpath data).

### Title Generation vs Core Background Titles

CodeCompanion core and `codecompanion-history.nvim` have separate title systems:

- Core CodeCompanion background title generation is configured with
  `interactions.background.chat.opts.enabled = true` and action
  `interactions.background.builtin.chat_make_title`.
- The core title generator filters out rules and config system prompts before
  generating a title, then calls `chat:set_title(title)`.
- `chat:set_title(title)` updates `chat.title`, the UI title, registry
  description, and buffer name, but it does not write `chat.opts.title`.
- The history extension persists `chat.opts.title`, not `chat.title`.
- The history extension already has its own title generator. It runs on
  `CodeCompanionChatSubmitted`, filters tagged/reference/context messages, sets
  `chat.opts.title`, updates the buffer title, and saves the chat.

Practical implication: enabling CodeCompanion core background title generation
alongside history auto-title creates a second title request and does not
reliably populate the history picker. Prefer the history extension's title
generator for persisted titles, or patch/bridge core title updates into
`chat.opts.title` before saving.

### Compatibility Note

This extension integrates with CodeCompanion's internal APIs. If pinned version `19.6.x` causes issues, check [ravitemer/codecompanion-history.nvim](https://github.com/ravitemer/codecompanion-history.nvim) for a compatible release.

---

## Reasoning Effort — Practical Control

[`lua/utils/my_codecompanion_thinking.lua`](../../lua/utils/my_codecompanion_thinking.lua) provides current-chat controls while keeping manually edited settings authoritative.

- `openai_agd` uses the flat `reasoning_effort` proxy field for GPT, Claude, Gemini, DeepSeek, Kimi, and other models routed through the OpenAI-compatible Agoda endpoint.
- `openai_responses_agd` uses the nested `reasoning.effort` field.
- Both schema fields are always present, optional, default to `nil`, and accept free-form strings. Capability metadata changes picker advice; it never blocks or deletes an explicit value.
- Overrides are remembered per chat, adapter, and model. Switching GPT → Claude → GPT restores each model's own override rather than carrying one family's value to another.
- A toggle/reconcile updates both the editable YAML header and any open `CodeCompanion_debug` snapshot, so neither can overwrite the effective value later.
- Before each schema mapping, only the managed wire path is reset. Clearing an override therefore cannot leave stale reasoning parameters in `adapter.parameters`.
- Sampling cleanup happens only on the outgoing request copy for known OpenAI conflicts and only for non-default `temperature` / `top_p`. `chat.settings` is never mutated.

### Commands and keymaps

Commands:

```vim
:CodeCompanionThinking          " model-aware picker plus free-form input
:CodeCompanionThinking high     " set current chat override
:CodeCompanionThinking xhigh    " arbitrary values are allowed
:CodeCompanionThinking none     " explicitly request no thinking (when supported)
:CodeCompanionThinking clear    " remove override and inherit provider behavior
:CodeCompanionThinking inspect  " show model, wire field, source, and capability
:CodeCompanionThinking refresh  " refresh cached Agoda model metadata
```

Keymaps:

- `<leader>At`: picker for the current chat
- `<leader>AT`: inspect effective thinking state

`clear` / `inherit` is intentionally different from `none`: clear omits the parameter, while `none` is an explicit wire value. Required-thinking models may ignore or reject `none`.

### Capability discovery is advisory

At startup, the helper asynchronously caches `GET /v1/internal/models?format=detailed` for one hour. It classifies a model as thinking-capable when `thinkingCapability` is not `None` or its feature list contains `Thinking`; Agoda's `Obligatory` value is normalized to required. The internal endpoint is VPN-dependent and unversioned, so static family hints and runtime registration remain available when discovery fails.

New models remain immediately controllable even before metadata knows about them. Add durable advice without changing the toggle path:

```lua
require("utils.my_codecompanion_thinking").register_capability("openai_agd", "future-model", {
  status = "supported",
  source = "verified_proxy_probe",
  mode = "optional",
  levels = { "none", "low", "medium", "high" },
})
```

For a future model that needs a different native request shape on the same adapter, the registered capability may also provide `request_transform(params, context)`. The canonical per-chat setting stays the same while the transform maps `context.effort` to that model's wire format.

Known-unsupported models such as the current Qwen proxy deployment show a warning, but a manual value is still passed through unchanged. This is deliberate: proxy behavior can change before local metadata or code is updated.

### Editable settings and live debugging

- `show_settings = true` renders an editable YAML block at the top of every chat buffer
- Open a chat buffer, position cursor on the YAML block, press `gd` (go-to-definition) — opens the schema so you can inspect all available fields and their current values
- Edit a value and press `Enter` (or just send the next message) to apply it
- Picker/command changes rewrite the matching YAML line, because CodeCompanion reparses this block immediately before every request

With `show_settings = false`, `/debug` renders the same settings as editable Lua. Manual entries such as `reasoning_effort = "high"` remain valid and are captured before a later model switch.

### Schema key differs by adapter

| Adapter | YAML key | API wire path |
|---|---|---|
| `openai_agd` (chat completions) | `reasoning_effort: high` | `parameters.reasoning_effort` |
| `openai_responses_agd` (responses API) | `reasoning.effort: high` | `parameters.reasoning.effort` |

### Sample settings block for `openai_responses_agd`

`/debug` form:

```lua
model = "gpt-5.3-codex"
-- available models: gpt-5-codex, gpt-5.1-codex, gpt-5.2-codex, gpt-5.3-codex, gpt-5.4-pro, gpt-5.1-codex-max
["reasoning.effort"] = "high"   -- free-form; common values: none / low / medium / high
temperature = 1
max_output_tokens = 4096
verbosity = "medium"
```

Editable chat-header form:

```yaml
---
model: gpt-5.3-codex
reasoning.effort: high
---
```

### Agoda proxy observations (2026-07-12)

- GPT-5.4: `high` and `xhigh` changed reported reasoning-token use; `none` disabled it; `minimal` was rejected. Non-default sampling conflicted with active effort.
- Gemini 2.5 Flash: reasoning effort changed reported reasoning use. Some Gemini/DeepSeek models are obligatory, so `none` does not mean the same as clear/inherit.
- Claude Sonnet 5 accepted `high` together with `temperature=0.42` and `top_p=0.8`; acceptance is verified, but effort-level differentiation was not observable in the small probe.
- o3 rejected `none`. Qwen 3.6 rejected `reasoning_effort`; both remain manually forceable with a warning so future proxy changes are not blocked.

### Clearing and stale parameter prevention

Use `:CodeCompanionThinking clear` (or set the debug field to `nil`) to inherit provider behavior. The adapter mapping wrapper removes the old flat/nested parameter path before remapping, so a previously sent effort does not leak into the next request.

### ACP adapters

For `codex` / `claude_code` ACP adapters: use the `/acp_session_options` slash command instead (HTTP `show_settings` YAML does not apply to ACP).

---

## References

- **CodeCompanion Repo:** https://github.com/olimorris/codecompanion.nvim
- **OpenAI GPT-5.2 Guide:** https://platform.openai.com/docs/guides/latest-model
- **Adapter Code:** `~/.local/share/nvim3_jelly_tinynvim/lazy/codecompanion.nvim/lua/codecompanion/adapters/http/`
- **Config Schema:** `~/.local/share/nvim3_jelly_tinynvim/lazy/codecompanion.nvim/lua/codecompanion/adapters/http/init.lua`
- **OpenAI Adapter:** `~/.local/share/nvim3_jelly_tinynvim/lazy/codecompanion.nvim/lua/codecompanion/adapters/http/openai.lua`
- **OpenAI Responses Adapter:** `~/.local/share/nvim3_jelly_tinynvim/lazy/codecompanion.nvim/lua/codecompanion/adapters/http/openai_responses.lua`
