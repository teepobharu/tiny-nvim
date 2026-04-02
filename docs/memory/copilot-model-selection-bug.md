# Copilot Adapter Model Selection Bug Research

## Executive Summary

**Root Cause Found:** The `#models == 0` check (lines 452, 505, 545, 604 in `my_codecompanion_actions.lua`) is **buggy** because Copilot's `schema.model.choices` returns a **hash table** (dictionary), not an array. In Lua, the `#` length operator only works for array/sequence tables; it returns `0` for hash tables.

This causes the code to incorrectly skip the model picker UI every time, preventing users from selecting models from the returned Copilot models.

---

## 1. CodeCompanion Copilot Schema Model Structure

### File Location
`~/.local/share/nvim3_jelly_tinynvim/lazy/codecompanion.nvim/lua/codecompanion/adapters/http/copilot/init.lua` (lines 356-377)

### Schema Definition
```lua
schema = {
  model = {
    order = 1,
    mapping = "parameters",
    type = "enum",
    desc = "ID of the model to use...",
    ---@type string|fun(): string
    default = "gpt-4.1",
    ---@type fun(self: CodeCompanion.HTTPAdapter, opts?: table): table
    choices = function(self, opts)
      opts = opts or {}
      local force = opts.async == false
      local fetched = token.fetch({ force = force })
      if not fetched or not fetched.copilot_token then
        return { ["gpt-4.1"] = { opts = {} } }
      end
      return get_models.choices(self, { token = fetched, async = opts.async })
    end,
  },
  -- ... more schema fields ...
}
```

### Key Observations
1. **`choices` is a function**, not a static array/table
2. When called, it returns data from `get_models.choices()`
3. **Return type is a hash table** (keyed by model ID strings), NOT an array

---

## 2. Actual Structure: get_models.lua

### File Location
`~/.local/share/nvim3_jelly_tinynvim/lazy/codecompanion.nvim/lua/codecompanion/adapters/http/copilot/get_models.lua`

### Return Structure (lines 156-164)

The function builds and returns a hash table:

```lua
models[model.id] = {
  billing = billing,
  description = description,
  endpoint = internal_endpoint,
  formatted_name = model.name,
  limits = limits,
  opts = choice_opts,
  vendor = model.vendor,
}
```

### Example Structure
```lua
{
  ["gpt-4.1"] = {
    billing = { is_premium = false, multiplier = 1 },
    description = "GPT-4.1",
    endpoint = "completions",
    formatted_name = "GPT-4.1",
    limits = { max_output_tokens = 4096, ... },
    opts = { can_stream = true, can_use_tools = true, has_vision = true },
    vendor = "openai"
  },
  ["gpt-5-mini"] = {
    -- ... similar structure ...
  },
  ["claude-3-5-sonnet"] = {
    -- ... similar structure ...
  }
}
```

**Not an array like:**
```lua
{ "gpt-4.1", "gpt-5-mini", "claude-3-5-sonnet" }
```

---

## 3. The Bug: `#models == 0` Check

### Affected Locations
File: `lua/utils/my_codecompanion_actions.lua`

1. **Line 452** - `toggle_inline_with_picker()`
2. **Line 505** - `toggle_chat_with_picker()`  
3. **Line 545** - `toggle_inline_with_picker_dynamic()`
4. **Line 604** - `toggle_chat_with_picker_dynamic()`

### Example (lines 445-456)
```lua
local models = get_adapter_models(adapter_name)
-- TODO: check copilot model logic does not allow select from log and is #models check works ?:
-- 03:21:30 msg_show.lua_print M.toggle_inline_with_picker#(anon) models: {
--   ["gpt-4.1"] = {
--     opts = {}
--   }
-- }
if #models == 0 then  -- ❌ BUG: Always true for hash tables!
  M.inline_with_adapter(adapter_name, nil, preserved_context)
  return
end

vim.ui.select(models, {
  prompt = "Select Model:",
  format_item = function(item)
    return type(item) == "table" and item.id or item  -- ❌ Expects item.id but hash key IS the ID
  end,
}, ...)
```

### Why It Fails

In Lua, the `#` operator:
- ✅ **Works for arrays:** `{ "a", "b", "c" }` → `#models == 3`
- ❌ **Returns 0 for hash tables:** `{ ["a"] = {}, ["b"] = {} }` → `#models == 0`

**Proof from Lua test:**
```
Hash table: { ["gpt-4.1"] = {...}, ["gpt-5-mini"] = {...} }
Length (#): 0  ← Always 0!

Array: { "gpt-4.1", "gpt-5-mini" }
Length (#): 2  ← Works correctly
```

---

## 4. Impact on Model Selection UI

### What Currently Happens
1. User triggers model picker (e.g., `<leader>ASm`)
2. `toggle_inline_with_picker()` is called
3. `get_adapter_models("copilot")` is called
4. Returns hash table: `{ ["gpt-4.1"] = {...}, ["gpt-5-mini"] = {...} }`
5. **`if #models == 0` evaluates to TRUE** (hash tables always have #=0)
6. **Model picker UI is skipped**
7. Inline chat starts with default model instead of letting user select

### Expected Behavior
1. Hash table is returned with multiple models
2. `vim.ui.select(models, ...)` should display all available models
3. User picks a model from the list
4. Inline/chat starts with selected model

---

## 5. User's Copilot Override

### File Location
`lua/plugins/extra/myAi.lua` (lines 462-472)

```lua
copilot = function()
  return require("codecompanion.adapters").extend("copilot", {
    schema = {
      model = {
        default = require("utils.my_ai_constants").DEFAULT_COPILOT_MODEL or "gpt-5-mini",
        -- choices -> currently no temperature opts check for 5mini
      },
    },
  })
end,
```

**Note:** The override doesn't replace `choices`, so it inherits the base copilot's function which returns a hash table.

---

## 6. Available Copilot Model Choices

Based on `get_models.lua` (lines 106-168), Copilot fetches models from the GitHub API with these capabilities being tracked:

### Model Selection Criteria
Only models with `model.model_picker_enabled = true` are included.

### Capability Tracking
```lua
opts = {
  can_stream: boolean,      -- supports streaming
  can_use_tools: boolean,   -- supports tool calls
  has_vision: boolean       -- supports vision/images
}

limits = {
  max_output_tokens: number,
  max_prompt_tokens: number,
  max_context_window_tokens: number
}

billing = {
  is_premium: boolean,
  multiplier: number  -- cost multiplier (e.g., 2x, 3.5x)
}
```

### Known Models (from Copilot docs)
Based on the schema default and common Copilot models:

- `gpt-4.1` (default)
- `gpt-5-mini`
- `gpt-5` 
- `gpt-5-turbo`
- `o1`
- `o1-mini`
- `claude-3-5-sonnet`
- `claude-opus-4-1`
- `claude-opus-4-5`
- `gemini-3`

**Note:** The exact list is **fetched dynamically** from the GitHub API endpoint `/models` at runtime.

---

## 7. How `vim.ui.select()` Works with Models

### Current Code (Buggy)
```lua
vim.ui.select(models, {
  prompt = "Select Model:",
  format_item = function(item)
    return type(item) == "table" and item.id or item
  end,
})
```

### Issue with Hash Table
```lua
-- Hash table (what Copilot returns)
models = {
  ["gpt-4.1"] = { opts = {...} },
  ["gpt-5-mini"] = { opts = {...} }
}

-- vim.ui.select expects array
models_array = {
  { id = "gpt-4.1", opts = {...} },
  { id = "gpt-5-mini", opts = {...} }
}
```

---

## Summary Table

| Aspect | Detail |
|--------|--------|
| **Copilot schema.model.choices type** | Function returning a hash table |
| **Hash table structure** | `{ ["model-id"] = { opts = {...}, endpoint = "...", ... }, ... }` |
| **`#models` result for hash** | `0` (always) |
| **`#models` result for array** | Count of items (correct) |
| **Bug location** | 4 places in `my_codecompanion_actions.lua` (lines 452, 505, 545, 604) |
| **Symptom** | Model picker UI skipped; default model used instead |
| **Fix required** | Check `vim.tbl_isempty(models)` instead of `#models == 0` |

---

## Fix Recommendations

1. **Replace all `#models == 0` checks** with:
   ```lua
   if not models or vim.tbl_isempty(models) then
   ```

2. **Convert hash table to array** in `get_adapter_models()`:
   ```lua
   local models_array = {}
   for model_id, model_info in pairs(models) do
     model_info.id = model_id
     table.insert(models_array, model_info)
   end
   return models_array
   ```

3. **Fix the `format_item` function** to handle the new array structure:
   ```lua
   format_item = function(item)
     return item.formatted_name or item.id or item
   end
   ```


# User section
To followup
- [x] 2026-03-31 01:39 improve the model picker to jump directly to model selection when is in sub key for provider copilot or openai agoda but add another visual map to show all providers available
- [ ]
Explain these observation found explain
1. inline mnemonic works but with open_agd provider key it show in log as adapter=openai is this expected ?
```
2026-03-31 01:28:17 [CodeCompanionRequestFinished] adapter=openai model=gpt-4.1-mini id=7510272
2026-03-31 01:28:17 [CodeCompanionInlineStarted] adapter=openai model=gpt-4.1-mini id=7510272
2026-03-31 01:28:43 [CodeCompanionRequestStarted] adapter=copilot model=gpt-4.1 id=8316924
2026-03-31 01:28:43 [CodeCompanionInlineStarted] adapter=copilot model=gpt-4.1 id=8316924
2026-03-31 01:28:45 [CodeCompanionInlineFinished] adapter=- model=- id=-
2026-03-31 01:28:45 [CodeCompanionRequestStarted] adapter=copilot model=gpt-4.1 id=1541565
2026-03-31 01:28:45 [CodeCompanionRequestFinished] adapter=copilot model=gpt-4.1 id=8316924
```
- [x] 2. the model picker for both provider mapping (m) in v mode actually send to chat buffer instead of do inline like in action <leader>ASf use opts mode = replace

3. it's better to call actual model fetching / list to get the list because in copilot (only) openai agoda seems working fine with some prepopulated list somehow, seems like it only show one default model (gpt 4.1)  initially until I trigger the ga model picker inside chat to get full model list next time when I use visual inline model picker in copilot source. can we show default list and do background fetch so next time it's available  

4. fix ui flow for model picker improve the model picker to jump directly to model selection on each provider prefix subkey for provider copilot or openai_agoda but add another visual map to show all providers available


