---
title: CodeCompanion Dynamic Model Toggle & Inline Adapter Support
created: 2026-01-25
updated: 2026-02-09
status: wip
priority: medium
tags: [codecompanion, feature, model-selection, inline-chat]
related:
  - docs/codecompanion_20260107_update.md
  - lua/utils/my_codecompanion_actions.lua
  - lua/plugins/extra/codecompanion.lua
---

# CodeCompanion Dynamic Model Toggle & Inline Adapter Support

## Overview

Enhance CodeCompanion integration with three key features:
1. **Toggle inline with adapter** - Enable inline edits with adapter selection
2. **Toggle chat with model select** - Quick chat toggle with model picker
3. **Dynamic model list for openai_agd** - Fetch models from API instead of hardcoded choices

## Problem Statement

### Current Limitations (from source investigation)

**Inline Commands:**
- `:CodeCompanion adapter=copilot <prompt>` - ✅ Supports adapter
- `:CodeCompanion adapter=copilot model=gpt-4.1 <prompt>` - ❌ Model parameter NOT parsed
- Source: [lua/codecompanion/interactions/inline/init.lua:238-239](lua/codecompanion/interactions/inline/init.lua)

**Chat Commands:**
- `:CodeCompanionChat adapter=copilot model=gpt-4.1` - ✅ Both supported
- Source: [lua/codecompanion/commands.lua:158-194](lua/codecompanion/commands.lua)

**Model Configuration:**
- Current: Hardcoded choices in adapter config
- Needed: Dynamic fetching from OpenAI API for openai_agd adapter

## Source Code References

### Key Files Analyzed

1. **Commands Parser** - [lua/codecompanion/commands.lua](lua/codecompanion/commands.lua)
   - Line 68-96: Inline adapter parsing (no model support)
   - Line 158-194: Chat adapter + model parsing with completion

2. **Inline Interaction** - [lua/codecompanion/interactions/inline/init.lua](lua/codecompanion/interactions/inline/init.lua)
   - Line 205: `self:set_adapter(args.adapter or config.interactions.inline.adapter)`
   - Line 234-261: `parse_special_syntax()` only handles `adapter=` pattern
   - Line 238: `local adapter_pattern = "adapter=([%w_]+)"` (no model pattern)

3. **Chat Adapter Switching** - [lua/codecompanion/interactions/chat/keymaps/change_adapter.lua](lua/codecompanion/interactions/chat/keymaps/change_adapter.lua)
   - Line 148-218: `select_model()` for HTTP adapters
   - Line 51-122: `list_http_models()` with dynamic choices support

4. **Adapter Schema** - [lua/codecompanion/config.lua:14-36](lua/codecompanion/config.lua)
   - Line 35: `show_model_choices = true` controls model picker visibility

## Feature 1: Toggle Inline with Adapter

### Current Workaround

From [lua/utils/my_codecompanion_actions.lua:168-189](lua/utils/my_codecompanion_actions.lua):

```lua
-- Direct API usage (works)
local context = require("codecompanion.utils.context").get(bufnr, {})
local adapter = require("codecompanion.adapters").resolve(adapter_config)
adapter.schema.model.default = model  -- Override model

local inline = require("codecompanion.interactions.inline").new({
  adapter = adapter,
  buffer_context = context,
})
inline:prompt(user_input)
```

### Proposed Enhancement

**Option A: Extend inline command parser** (Upstream contribution)

Modify [lua/codecompanion/interactions/inline/init.lua:234-261](lua/codecompanion/interactions/inline/init.lua):

```lua
function Inline:parse_special_syntax(prompt)
  local adapter_pattern = "adapter=([%w_]+)"
  local model_pattern = "model=([%w_%.%-]+)"  -- NEW

  local adapter_match = prompt:match(adapter_pattern)
  local model_match = prompt:match(model_pattern)  -- NEW

  -- ... existing adapter logic ...

  -- NEW: Handle model parameter
  if model_match then
    if self.adapter then
      self.adapter.schema.model.default = model_match
      prompt = prompt:gsub(model_pattern, "", 1)
    end
  end

  return vim.trim(prompt)
end
```

**Option B: Custom wrapper function** (Local solution)

Add to [lua/utils/my_codecompanion_actions.lua](lua/utils/my_codecompanion_actions.lua):

```lua
-- Toggle inline with adapter + model picker
M.toggle_inline_with_picker = function()
  local adapters = get_available_adapters()

  vim.ui.select(adapters, {
    prompt = "Select Adapter:",
    format_item = function(item) return item end,
  }, function(adapter_name)
    if not adapter_name then return end

    local adapter_config = config.adapters.http[adapter_name]
    local adapter = require("codecompanion.adapters").resolve(adapter_config)
    local models = adapter.schema.model.choices

    if type(models) == "function" then
      models = models(adapter, { async = false })
    end

    vim.ui.select(models, {
      prompt = "Select Model:",
      format_item = function(item)
        return type(item) == "table" and item.id or item
      end,
    }, function(selected_model)
      if not selected_model then return end

      local model_id = type(selected_model) == "table"
        and selected_model.id or selected_model

      M.inline_with_adapter(adapter_name, model_id)
    end)
  end)
end
```

**Keymap:**
```lua
vim.keymap.set("v", "<leader>ASmm", function()
  require("utils.my_codecompanion_actions").toggle_inline_with_picker()
end, { desc = "CC Inline: Pick Adapter+Model" })
```

## Feature 2: Toggle Chat with Model Select

### Current Implementation

Chat already supports model selection via keymaps:

From [lua/codecompanion/interactions/chat/keymaps/change_adapter.lua:223-248](lua/codecompanion/interactions/chat/keymaps/change_adapter.lua):

```lua
function M.callback(chat)
  -- Select adapter first
  vim.ui.select(adapters_list, select_opts("Select Adapter", current_adapter), function(selected_adapter)
    if not selected_adapter then return end

    chat:change_adapter(selected_adapter)

    -- Then select model
    return M.select_model(chat)
  end)
end
```

### Proposed Enhancement

**Add quick toggle wrapper** in [lua/utils/my_codecompanion_actions.lua](lua/utils/my_codecompanion_actions.lua):

```lua
-- Quick chat toggle with adapter+model picker
M.toggle_chat_with_picker = function()
  local chat = require("codecompanion").last_chat()

  if not chat then
    -- No chat exists, create new with picker
    M.toggle_inline_with_picker()  -- Reuse picker logic
    return
  end

  -- Chat exists, use built-in adapter change keymap
  local change_adapter = require("codecompanion.interactions.chat.keymaps.change_adapter")
  change_adapter.callback(chat)
end
```

**Keymap:**
```lua
vim.keymap.set("n", "<leader>ASM", function()
  require("utils.my_codecompanion_actions").toggle_chat_with_picker()
end, { desc = "CC Chat: Toggle with Model Picker" })
```

## Feature 3: Dynamic Model List for openai_agd

### Current Implementation

From [lua/utils/my_codecompanion_utils.lua](lua/utils/my_codecompanion_utils.lua) (likely hardcoded):

```lua
openai_agd = function()
  return require("codecompanion.adapters").extend("openai", {
    env = { api_key = "cmd:op read op://Agoda/OpenAI_AGD/credential --no-newline" },
    url = "https://api.openai.agoda.io/v1/chat/completions",
    schema = {
      model = {
        default = "gpt-5.2",
        choices = {  -- ❌ Hardcoded
          "gpt-4.1-mini",
          "gpt-5-mini",
          "gpt-5.2",
          "claude-3.7-sonnet-20250219",
          -- ... manual list
        },
      },
    },
  })
end
```

### Proposed Solution: Dynamic Fetching

Based on [lua/codecompanion/interactions/chat/keymaps/change_adapter.lua:63-66](lua/codecompanion/interactions/chat/keymaps/change_adapter.lua):

```lua
models = adapter.schema.model.choices

if type(models) == "function" then
  models = models(adapter, { async = false })
end
```

**Implementation in [lua/utils/my_codecompanion_utils.lua](lua/utils/my_codecompanion_utils.lua):**

```lua
local AI = require("utils.my_ai_constants")

M.adapters = {
  openai_agd = function()
    return require("codecompanion.adapters").extend("openai", {
      env = {
        api_key = "cmd:op read op://Agoda/OpenAI_AGD/credential --no-newline"
      },
      url = AI.endpoints.agoda.OPENAI_PROXY,
      schema = {
        model = {
          default = function(self, opts)
            -- Fetch and return first available model
            local models = self.schema.model.choices(self, opts)
            return models[1] or AI.models.gpt.GPT_5_2
          end,

          -- Dynamic choices function
          choices = function(self, opts)
            opts = opts or {}

            -- Check cache first (30min TTL from config.lua:32)
            local cache_key = "openai_agd_models"
            local cached = vim.g[cache_key]
            local cache_time = vim.g[cache_key .. "_time"]
            local now = os.time()

            if cached and cache_time and (now - cache_time) < 1800 then
              return cached
            end

            -- Fetch models from API
            local curl = require("plenary.curl")
            local response = curl.get(AI.endpoints.agoda.OPENAI_PROXY .. "/models", {
              headers = {
                ["Authorization"] = "Bearer " .. vim.fn.system(self.env.api_key.cmd),
              },
              timeout = 5000,
            })

            if response.status ~= 200 then
              vim.notify("Failed to fetch models from AGD: " .. response.status, vim.log.levels.WARN)
              return AI.get_openai_models()  -- Fallback to static list
            end

            local ok, data = pcall(vim.json.decode, response.body)
            if not ok or not data.data then
              vim.notify("Failed to parse models response", vim.log.levels.WARN)
              return AI.get_openai_models()
            end

            -- Extract model IDs
            local models = vim.tbl_map(function(model)
              return model.id
            end, data.data)

            -- Apply filters from AI constants
            models = AI.filter_models(models)

            -- Cache results
            vim.g[cache_key] = models
            vim.g[cache_key .. "_time"] = now

            return models
          end,
        },
      },
    })
  end,
}
```

### Alternative: Use fetch_model_helper

From [lua/utils/my_codecompanion_actions.lua](lua/utils/my_codecompanion_actions.lua), there's already a `fetch_model_helper` function:

```lua
openai_agd = function()
  local cc_actions = require("utils.my_codecompanion_actions")

  return require("codecompanion.adapters").extend("openai", {
    -- ... env and url ...
    schema = {
      model = {
        default = function(self, opts)
          return cc_actions.fetch_model_helper(self, opts)[1] or "gpt-5.2"
        end,
        choices = function(self, opts)
          return cc_actions.fetch_model_helper(self, opts)
        end,
      },
    },
  })
end
```

**Need to verify:** Check if [lua/utils/my_codecompanion_actions.lua](lua/utils/my_codecompanion_actions.lua) already has `fetch_model_helper` implementation or if it needs to be created.

## Implementation Plan

### Phase 0: Consolidation (Prerequisite)
- [x] Move CodeCompanion plugin spec from [lua/plugins/extra/myEditor.lua](lua/plugins/extra/myEditor.lua) to [lua/plugins/extra/myAi.lua](lua/plugins/extra/myAi.lua)
- [x] Replace inline `openai_agd` with `merge_agoda_adapters()` from [lua/utils/my_codecompanion_utils.lua](lua/utils/my_codecompanion_utils.lua)
- [x] Remove debug print in `inline_with_adapter`

### Phase 1: Local Wrappers (Quick Win)
- [x] Add `toggle_inline_with_picker()` to [lua/utils/my_codecompanion_actions.lua](lua/utils/my_codecompanion_actions.lua)
- [x] Add `toggle_chat_with_picker()` to [lua/utils/my_codecompanion_actions.lua](lua/utils/my_codecompanion_actions.lua)
- [x] Add keymaps in `generate_codecompanion_keymaps()`:
  - `<leader>ASmm` - Inline with picker (visual mode)
  - `<leader>ASM` - Chat toggle with picker (normal mode)

### Phase 2: Dynamic Model Fetching
- [x] Verify `fetch_model_helper` exists in [lua/utils/my_codecompanion_actions.lua](lua/utils/my_codecompanion_actions.lua)
- [x] Wire `fetch_model_helper` as `choices` function in `openai_agd` adapter schema
- [x] Dual fetch mode: Static (default) vs Dynamic (requires VPN)
  - Static mode: Uses `my_ai_constants` models only (no network dependency)
  - Dynamic mode: Fetches from AGD proxy `/v1/models` endpoint (produces error notifications when offline)
  - Added `use_dynamic_fetch` parameter to `fetch_model_helper` and `get_adapter_models`
  - Added dynamic variants: `toggle_inline_with_picker_dynamic()` and `toggle_chat_with_picker_dynamic()`
  - New keymaps for dynamic fetch:
    - `<leader>ASSMM` - Inline with dynamic picker (visual mode)
    - `<leader>ASSM` - Chat toggle with dynamic picker (normal mode)
  - Original keymaps use static fetch:
    - `<leader>ASmm` - Inline with static picker (visual mode)
    - `<leader>ASM` - Chat toggle with static picker (normal mode)

### Phase 3: Upstream Contribution (Optional)
- [ ] Submit PR to codecompanion.nvim to support `model=` in inline commands
- [ ] Add model parameter parsing in [lua/codecompanion/interactions/inline/init.lua:238-261](lua/codecompanion/interactions/inline/init.lua)
- [ ] Update command completion in [lua/codecompanion/commands.lua:67-118](lua/codecompanion/commands.lua)

## Testing Checklist

### Toggle Inline with Picker (Static)
- [ ] Visual select code → `<leader>ASmm` → Select adapter → Select model → Inline edit works
- [ ] Model override persists for that inline session
- [ ] Falls back to default if picker cancelled
- [ ] Uses static models from `my_ai_constants` (no network dependency)

### Toggle Chat with Picker (Static)
- [ ] No chat exists → `<leader>ASM` → Creates chat with selected adapter+model
- [ ] Chat exists → `<leader>ASM` → Changes adapter+model in existing chat
- [ ] Model persists across chat toggle
- [ ] Uses static models from `my_ai_constants` (no network dependency)

### Toggle Inline with Picker (Dynamic) - Requires VPN
- [ ] Visual select code → `<leader>ASSMM` → Select adapter → Select model → Inline edit works
- [ ] Shows models fetched from AGD proxy `/v1/models` endpoint
- [ ] Produces error notification when proxy unreachable (no VPN) - expected behavior
- [ ] Falls back to static list on API error

### Toggle Chat with Picker (Dynamic) - Requires VPN
- [ ] No chat exists → `<leader>ASSM` → Creates chat with selected adapter+model
- [ ] Chat exists → `<leader>ASSM` → Changes adapter+model in existing chat
- [ ] Shows models fetched from AGD proxy `/v1/models` endpoint
- [ ] Produces error notification when proxy unreachable (no VPN) - expected behavior
- [ ] Falls back to static list on API error

### Model Filtering (Both Modes)
- [ ] Filters apply (blacklist/keywords from [lua/utils/my_ai_constants.lua](lua/utils/my_ai_constants.lua))
- [ ] Works with both `openai_agd` and potential future adapters

## Documentation Updates

After implementation, update:
- [ ] [docs/codecompanion_20260107_update.md](docs/codecompanion_20260107_update.md) - Add new features section
- [ ] [lua/utils/my_codecompanion_actions.lua](lua/utils/my_codecompanion_actions.lua) - Add JSDoc comments
- [ ] [myKeys.md](myKeys.md) - Document new keymaps
- [ ] Create [docs/memory/codecompanion.md](docs/memory/codecompanion.md) with caveats and patterns

## Notes

### Why Not Use Command Line?

Command-line approach has limitations:
- `:CodeCompanion adapter=x model=y` - Model NOT parsed for inline (source confirmed)
- `:CodeCompanionChat adapter=x model=y` - Works but no completion until adapter selected
- Picker UI is more user-friendly for model selection

### Compatibility with Existing Keymaps

Current keymaps in [lua/utils/my_codecompanion_actions.lua](lua/utils/my_codecompanion_actions.lua):
- `<leader>ASf/F/h/H/c/C` - Direct model selection (keep these)
- `<leader>ASmm` - NEW: Inline picker
- `<leader>ASM` - NEW: Chat picker
- `<leader>ASi` - Current adapter info (existing)

No conflicts - new keymaps complement existing workflow.

## References

- CodeCompanion Commands: [lua/codecompanion/commands.lua](lua/codecompanion/commands.lua)
- Inline Interaction: [lua/codecompanion/interactions/inline/init.lua](lua/codecompanion/interactions/inline/init.lua)
- Adapter Change: [lua/codecompanion/interactions/chat/keymaps/change_adapter.lua](lua/codecompanion/interactions/chat/keymaps/change_adapter.lua)
- Config Schema: [lua/codecompanion/config.lua](lua/codecompanion/config.lua)
- Current Utilities: [lua/utils/my_codecompanion_actions.lua](lua/utils/my_codecompanion_actions.lua)
- AI Constants: [lua/utils/my_ai_constants.lua](lua/utils/my_ai_constants.lua)
