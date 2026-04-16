# GPT-5.2 OpenAI Proxy Adapter Fix Summary

**Issue:** CodeCompanion sends `max_tokens` parameter, but GPT-5.2 rejects it and requires `max_completion_tokens` instead.

**Error:**
```
[ERROR] 2026-02-11 20:21:45
Error: {
  "error": {
    "message": "Unsupported parameter: 'max_tokens' is not supported with this model. Use 'max_completion_tokens' instead.",
    "type": "invalid_request_error",
    "param": "max_tokens",
    "code": "unsupported_parameter"
  }
}
```

---

## Root Cause

1. Your custom adapter in `lua/utils/my_codecompanion_utils.lua` extends the default OpenAI adapter
2. The default OpenAI adapter (`codecompanion/adapters/http/openai.lua`) uses `max_tokens` in its schema
3. CodeCompanion's schema-to-parameters mapping is **1:1 pass-through** (no renaming)
4. Your Agoda OpenAI Proxy is **pass-through** (no parameter translation)
5. GPT-5.2 API endpoint rejects `max_tokens` and requires `max_completion_tokens`

**Result:** Request fails at 400 level before reaching your model logic.

---

## How CodeCompanion Schema Works

Schema → Parameters Mapping:
```lua
schema = {
  max_tokens = {
    mapping = "parameters",  -- Emits to: adapter.parameters.max_tokens
    type = "integer",
    default = 4096,
  }
}
```

This means: whatever you name in `schema`, CodeCompanion will emit to the request with that exact name.

---

## Solutions (In Order of Preference)

### Solution 1: Switch to `max_completion_tokens` (Recommended)

**File:** `lua/utils/my_codecompanion_utils.lua`

**What to change:**
```lua
openai_agd = function()
  return require("codecompanion.adapters").extend("openai", {
    env = { ... },
    schema = {
      model = { ... },
      temperature = { ... },
      -- CHANGE THIS:
      max_completion_tokens = {  -- was: max_tokens
        order = 6,
        mapping = "parameters",
        type = "integer",
        optional = true,
        default = 4096,
        desc = "The maximum number of tokens to generate in the chat completion.",
        validate = function(n)
          return n > 0, "Must be greater than 0"
        end,
      },
    },
  })
end
```

**Pros:**
- ✅ Explicit and correct for GPT-5.2
- ✅ Aligns with OpenAI's new naming convention
- ✅ Minimal change

**Cons:**
- May not work if your proxy doesn't forward `max_completion_tokens` to older OpenAI models
- Current setup uses GPT-5.2 default, so should be fine

**Testing:** After fix, test with GPT-5.2 via CodeCompanion

---

### Solution 2: Remove `max_tokens` Entirely (Fallback)

If Solution 1 doesn't work, try removing the parameter entirely:

```lua
schema = {
  model = { ... },
  temperature = { ... },
  -- DELETE: max_tokens block entirely
}
```

**Pros:**
- ✅ Simplest, no parameter sent
- ✅ Uses model's default limit

**Cons:**
- ❌ May hit unexpected truncation
- ❌ Lose control over output length
- Only if renaming doesn't work

---

### Solution 3: Model-Gated Parameter (Advanced)

If you support multiple model families (e.g., gpt-4, gpt-5, claude), gate the parameter per model:

```lua
schema = {
  model = { /* choices: ["gpt-5.2"] = {opts: {uses_completion_tokens: true}}, ... */ },
  max_completion_tokens = {
    enabled = function(self)
      local model = self.schema.model.default
      if type(model) == "function" then model = model(self) end
      -- Only enable for gpt-5.x and newer
      return string.match(model, "gpt%-5") ~= nil
    end,
    mapping = "parameters",
    type = "integer",
    optional = true,
    default = 4096,
    desc = "Maximum tokens for GPT-5.x models (requires max_completion_tokens, not max_tokens)",
  },
  -- Optional: keep max_tokens for older models
  max_tokens = {
    enabled = function(self)
      local model = self.schema.model.default
      if type(model) == "function" then model = model(self) end
      -- Only enable for older models
      return model and not string.match(model, "gpt%-5") ~= nil
    end,
    mapping = "parameters",
    type = "integer",
    optional = true,
    default = 4096,
    desc = "Maximum tokens (for pre-GPT-5 models)",
  },
}
```

**Pros:**
- ✅ Supports mixed model families
- ✅ Future-proof

**Cons:**
- More complex
- Requires managing model metadata in schema

---

## Secondary Issue: Temperature/Top_p with Reasoning

**From OpenAI docs:** `temperature` and `top_p` are **only supported when `reasoning_effort = none`** (the default).

**Current setup:**
- `temperature = 0` (always sent)
- No explicit `reasoning_effort` in schema (defaults to `none` in OpenAI adapter)

**If user changes reasoning_effort to "low", "medium", "high":**
- New error: `temperature` and `top_p` no longer allowed

**Future fix (optional):**
```lua
temperature = {
  enabled = function(self)
    local reasoning = self.schema.reasoning_effort
    -- Only allow temp if reasoning_effort is none or unset
    return not (reasoning and reasoning.default and reasoning.default ~= "none")
  end,
  -- ...rest of schema
}
```

**Status:** Not blocking now (default reasoning = none), but document for future reference.

---

## Testing Plan

**Before:** GPT-5.2 requests fail with `max_tokens` error

1. **Apply Solution 1:** Rename `max_tokens` → `max_completion_tokens` in `my_codecompanion_utils.lua`
2. **Restart Neovim** (reload plugin)
3. **Test with CodeCompanion:**
   - Open file
   - `<leader>av` (CodeCompanion toggle chat)
   - Ask a simple question
   - Check: Does response succeed or fail?
4. **If success:** ✅ Done. Document in memory file.
5. **If still fails:** ❌ Try Solution 2 (remove entirely) or check proxy logs

**Expected after fix:**
- Requests to GPT-5.2 via proxy succeed
- No 400 error about unsupported parameter

---

## Files to Change

1. **`lua/utils/my_codecompanion_utils.lua`** (Line ~85)
   - Change: `max_tokens` → `max_completion_tokens` in schema

2. **`docs/memory/codecompanion.md`** (Reference only)
   - Comprehensive guide on adapter schema, parameter handling, GPT-5.2 constraints

3. **`docs/GPT52_ADAPTER_FIX_SUMMARY.md`** (This file)
   - Quick reference for the issue and fix

---

## Key Learnings

1. **CodeCompanion does NOT rename parameters** → parameter names in schema must match API expectations exactly
2. **Proxy endpoints do NOT translate parameters** → pass-through only
3. **Schema keys are emitted verbatim** → `max_tokens` in schema = `max_tokens` in request
4. **GPT-5.2 has strict parameter constraints** → `max_completion_tokens` (not `max_tokens`), temperature only with reasoning=none
5. **Model-specific configuration** → use model `choices` with `opts` metadata to gate parameters conditionally

---

## References

- **Error context:** Agoda OpenAI Proxy with GPT-5.2 (custom endpoint)
- **CodeCompanion adapter code:** `~/.local/share/nvim3_jelly_tinynvim/lazy/codecompanion.nvim/lua/codecompanion/adapters/http/`
- **OpenAI GPT-5.2 docs:** https://platform.openai.com/docs/guides/latest-model
- **Detailed reference:** `docs/memory/codecompanion.md`

---

## Status

- [x] Root cause identified
- [x] Solutions documented
- [x] Testing plan created
- [ ] Solution 1 applied (ready to do)
- [ ] Testing completed
- [ ] Documentation updated

