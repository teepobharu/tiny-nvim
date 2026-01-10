# CodeCompanion Upgrade & Model Support Research

**Date:** 2026-01-07
**Status:** Research Complete ✅

---

## 1. Current State Analysis

### Current Version
- **Installed commit:** `8ad65eef735b31bb47d76f59d878ee1bac4bdc85` (main branch)
- **Latest release:** v18.3.1 (December 28, 2025)
- **Status:** Likely close to latest, need to check commit date vs release

### Current Configuration
- File: `lua/plugins/extra/codecompanion.lua`
- Adapter: Using `copilot` adapter for all strategies (chat, inline, agent)
- Custom prompts: Extensive custom prompt library for various tasks
- No custom model/endpoint configuration currently

---

## 2. Research Findings

### Breaking Changes (v18.0.0+)
- **Adapter configuration structure** may have changed in v18.0.0
- **New features in v18.3.x:**
  - Added `max_context_window_tokens` parameter for Copilot
  - Enhanced Anthropic model support
  - Mistral adapter reasoning capabilities
  - Improved system prompts with filepath support
  - Better adapter/model switching during chat sessions

### Adapter Configuration Pattern

CodeCompanion uses a similar pattern to other plugins for custom adapters:

```lua
require("codecompanion").setup({
  adapters = {
    http = {
      my_custom_adapter = function()
        return require("codecompanion.adapters").extend("base_adapter", {
          env = {
            api_key = "MY_API_KEY",
          },
          url = "custom_endpoint",
          schema = {
            model = {
              default = "specific_model",
              choices = { "model1", "model2" }
            },
            temperature = {
              default = 0.75
            },
            max_tokens = {
              default = 4096
            }
          }
        })
      end
    }
  }
})
```

**Key Components:**
- `extend()` - Extends an existing adapter (anthropic, openai, etc.)
- `env` - Environment variables for API keys
- `url` - Custom endpoint URL
- `schema` - Model and parameter configuration
  - `model.default` - Default model
  - `model.choices` - Available model options
  - Other params like temperature, max_tokens

---

## 3. Implementation Plan

### ✅ Phase 1: Create Utility Module (COMPLETED)
**File:** `lua/utils/my_codecompanion_utils.lua`

Created utility module with Agoda-specific adapter configurations:
- `claude_agd` - Claude via GenAI Gateway
- `vertex_claude_agd` - Claude via OpenAI Proxy
- `openai_agd` - GPT via OpenAI Proxy

**Pattern matches** `my_avante_utils.lua`:
- `get_agoda_adapters()` - Returns adapter configurations
- `get_agoda_adapter_names()` - Returns list of adapter names
- `remove_agoda_adapters()` - Filters out Agoda adapters
- `is_agoda_adapter()` - Checks if adapter is Agoda-specific
- `merge_agoda_adapters()` - Helper to merge with existing config

### Phase 2: Update CodeCompanion Configuration
**File:** `lua/plugins/extra/myCodecompanion.lua` (new file following CLAUDE.md guidelines)

**Changes needed:**
1. Import the utility module
2. Configure custom adapters in the `adapters.http` section
3. Option to switch default adapter from `copilot` to Agoda adapters
4. Maintain all existing custom prompts and keybindings

**Example configuration:**
```lua
local cc_utils = require("utils.my_codecompanion_utils")

return {
  "olimorris/codecompanion.nvim",
  opts = function(_, opts)
    -- Merge Agoda adapters with existing adapters
    opts.adapters = opts.adapters or {}
    opts.adapters.http = cc_utils.merge_agoda_adapters(opts.adapters.http)

    -- Optionally change default adapter
    -- opts.strategies.chat.adapter = "vertex_claude_agd"
    -- opts.strategies.inline.adapter = "vertex_claude_agd"

    return opts
  end
}
```

### Phase 3: Testing & Verification
- [ ] Test adapter switching via `:CodeCompanionActions`
- [ ] Verify custom endpoints are reachable
- [ ] Test all existing custom prompts work with new adapters
- [ ] Check model selection UI shows Agoda models
- [ ] Verify API key environment variables are correctly loaded

### Phase 4: Documentation
- [ ] Update internal docs with adapter usage
- [ ] Document environment variable requirements
- [ ] Create examples for switching between adapters

---

## 4. Migration Considerations

### Backward Compatibility
- Keep `copilot` as default adapter to avoid breaking existing workflow
- Agoda adapters are opt-in via configuration override
- Existing prompts and keybindings remain unchanged

### Environment Variables Required
```bash
export ANTHROPIC_API_KEY="your-key"  # For claude_agd
export OPENAI_API_KEY="your-key"     # For vertex_claude_agd and openai_agd
```

### Syntax Updates (if upgrading from pre-v18)
- Check for deprecated configuration keys
- Run `:checkhealth codecompanion` after upgrade
- Review adapter configuration structure

---

## 5. Next Steps

1. ✅ Create `my_codecompanion_utils.lua` utility module
2. Create `lua/plugins/extra/myCodecompanion.lua` configuration override
3. Test the new adapters with existing prompts
4. Update `.env` or shell profile with required API keys
5. Optionally update to latest CodeCompanion version if significant fixes exist

---

## 6. References

- **CodeCompanion Repo:** https://github.com/olimorris/codecompanion.nvim
- **Latest Release:** v18.3.1
- **Documentation:** https://codecompanion.olimorris.dev
- **Similar Pattern:** `lua/utils/my_avante_utils.lua` (lines 9-67)
- **Current Config:** `lua/plugins/extra/codecompanion.lua`

