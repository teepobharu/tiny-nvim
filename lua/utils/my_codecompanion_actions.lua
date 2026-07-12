-- CodeCompanion action utilities for inline chat with specific provider/model
-- Similar pattern to my_avante_utils.lua for consistency
--
-- IMPORTANT: Uses correct CodeCompanion API (verified from source)
--   - Config access: require("codecompanion.config") not require("codecompanion").config
--   - Inline: Create instance directly with adapter parameter
--   - Chat: Use params table with adapter/model (v18+ feature)
--   - Switch: Modify config.interactions directly
--
-- Usage:
--   1. Basic inline chat:
--      require("utils.my_codecompanion_actions").inline_with_adapter("copilot", "gpt-5-mini")
--
--   2. Generate all keymaps (recommended):
--      local keymaps = require("utils.my_codecompanion_actions").generate_codecompanion_keymaps()
--      vim.list_extend(your_keymaps, keymaps)
--
--   3. Quick actions:
--      local actions = require("utils.my_codecompanion_actions").actions
--      actions.inline_fast()  -- Quick inline with GPT-5-mini
--      actions.inline_heavy() -- Quick inline with Claude Sonnet 4.5
--
-- Keymap Structure:
--   Copilot models: <leader>AS[fFhHcC]
--   AGD models:     <leader>ASS[fFhHcC]
--   Info:           <leader>ASi
--
--   Visual mode (v/x): Trigger inline chat with selected text
--   Normal mode (n):   Switch default adapter/model
--
local M = {}

-- Import shared AI constants for deduplication
local AI = require "utils.my_ai_constants"

local DEFAULT_ADAPTER = AI.defaults.adapter
local DEFAULT_MODEL = AI.defaults.model

-- ============================================================================
-- Model Fetching (from POC)
-- ============================================================================

-- Fetch and filter models for CodeCompanion adapter
-- Based on POC from tests/myTest.lua:codeCompanion_adapter_setup.fetch_model_helper
-- @param self adapter instance
-- @param opts table Options:
--   - async: boolean - if true, return static models immediately
--   - blacklist: table - additional patterns to blacklist
--   - keyword_filters: table - additional keywords to filter
-- @return table Filtered list of model names
function M.fetch_model_helper(self, opts, provider)
  opts = opts or {}

  -- Build complete blacklist (shared + CodeCompanion specific)
  local blacklist = AI.filters.blacklist
  if opts.blacklist then
    blacklist = vim.tbl_extend("force", {}, blacklist, opts.blacklist)
  end

  -- Build complete keyword filters (shared + CodeCompanion specific)
  local keyword_filters = vim.tbl_extend("force", {}, AI.filters.keywords, AI.filters.codecompanion_additional)
  if opts.keyword_filters then
    vim.list_extend(keyword_filters, opts.keyword_filters)
  end

  local filter_opts = {
    additional_blacklist = blacklist,
    additional_keywords = keyword_filters,
  }

  -- Dynamic fetch: call default openai_compatible choices fn, then apply our filters
  if opts.use_dynamic_fetch == true then
    local ok, openai_compatible = pcall(require, "codecompanion.adapters.http.openai_compatible")
    if ok and openai_compatible.schema and openai_compatible.schema.model then
      local choices_fn = openai_compatible.schema.model.choices
      if type(choices_fn) == "function" then
        -- Pass clean opts to codecompanion (strip our custom fields)
        local cc_opts = { async = opts.async }
        local fetch_ok, dynamic_models = pcall(choices_fn, self, cc_opts)
        if fetch_ok and type(dynamic_models) == "table" and #dynamic_models > 0 then
          return AI.filter_models(dynamic_models, filter_opts, provider)
        end
      end
    end
    -- Fallback to static on fetch error
  end

  -- Default: return filtered static models (no network dependency)
  local filteredModels = AI.filter_models(AI.static_models.agd_default, filter_opts, provider)
  -- TODO : after filter -> inject appropriate opts for some model to remove some fields in request
  -- ie. add appropriate
  -- for claudeX models get below error
  -- `temperature` and `top_p` cannot both be specified for this model.

  return filteredModels
end

-- ============================================================================
-- Core Actions
-- ============================================================================

-- Get current adapter and model from CodeCompanion config
function M.current_adapter_and_model()
  local config = require "codecompanion.config"
  local adapter = config.interactions.chat.adapter or DEFAULT_ADAPTER

  -- Get model from adapter config
  local adapter_config = config.adapters.http[adapter] or config.adapters.acp[adapter]
  if adapter_config then
    local resolved = require("codecompanion.adapters").resolve(adapter_config)
    if resolved and resolved.schema and resolved.schema.model then
      local model = resolved.schema.model.default
      if type(model) == "function" then
        model = model(resolved, {})
      end
      return adapter, model or DEFAULT_MODEL
    end
  end

  return adapter, DEFAULT_MODEL
end

-- Trigger CodeCompanion inline with specific adapter and model
-- Uses the inline interaction directly so the chosen model is guaranteed per call.
-- Visual selection is captured via range=2 (same marks used by :'<,'>CodeCompanion ...).
function M.inline_with_adapter(adapter_name, model, initial_context)
  local config = require "codecompanion.config"
  local context_utils = require "codecompanion.utils.context"
  local inline_interaction = require "codecompanion.interactions.inline"

  -- Validate adapter exists
  local adapter_config = config.adapters.http[adapter_name] or config.adapters.acp[adapter_name]
  if not adapter_config then
    vim.notify("Adapter not found: " .. adapter_name, vim.log.levels.ERROR)
    return
  end

  -- Resolve adapter instance and apply per-call model override
  local adapter = require("codecompanion.adapters").resolve(adapter_config)
  if model and adapter and adapter.schema and adapter.schema.model then
    adapter.schema.model.default = model
  end

  -- Preserve visual context captured before picker/input UIs, if provided.
  local preserved_context = initial_context

  -- Prompt for user input, then run inline directly with visual-range context
  vim.ui.input({ prompt = config.display.action_palette.prompt }, function(input)
    if not input or vim.trim(input) == "" then
      return
    end

    local context = preserved_context or context_utils.get(vim.api.nvim_get_current_buf(), { range = 2 })
    local inline = inline_interaction.new {
      adapter = adapter,
      buffer_context = context,
      opts = { placement = "replace" },
    }

    if not inline then
      vim.notify("Failed to create inline instance", vim.log.levels.ERROR)
      return
    end

    inline:prompt(input)
  end)
end

-- Trigger CodeCompanion chat with specific adapter and model
function M.chat_with_adapter(adapter_name, model)
  -- Use the chat function with adapter parameters (v18+ feature)
  local params = { adapter = adapter_name }
  if model then
    params.model = model
  end

  require("codecompanion").chat {
    params = params,
    subcommand = "toggle",
  }
end

-- Switch CodeCompanion default adapter and model
-- Updates the configuration and shows a notification
function M.switch_adapter(adapter_name, model)
  local config = require "codecompanion.config"

  -- Get adapter config and resolve it
  local adapter_config = config.adapters.http[adapter_name] or config.adapters.acp[adapter_name]
  if not adapter_config then
    vim.notify("Adapter not found: " .. adapter_name, vim.log.levels.ERROR)
    return
  end

  local adapter = require("codecompanion.adapters").resolve(adapter_config)

  -- Override model if specified
  if model and adapter.schema and adapter.schema.model then
    adapter.schema.model.default = model
  end

  -- Update the default adapter for chat and inline interactions
  config.interactions.chat.adapter = adapter_name
  config.interactions.inline.adapter = adapter_name

  -- Show notification
  local Snacks = require "snacks"
  Snacks.notify.warn(
    string.format("Switched CodeCompanion to %s/%s", adapter_name, model or "default"),
    { title = "CodeCompanion" }
  )
end

-- Generate keymaps for CodeCompanion model selection
-- @param config table Configuration with structure:
--   {
--     prefix = string,       -- Key prefix like "<leader>AS"
--     adapter = string,      -- Adapter name like "copilot" or "openai_agd"
--     label = string,        -- Label for descriptions like "CC" or "CC-AGD"
--     models = {             -- Table of model configurations
--       key_suffix = {       -- e.g., "f", "F", "h", "H", "c", "C"
--         model = string,    -- Model name
--         desc = string,     -- Short description
--       }
--     }
--   }
-- @return table Array of keymaps for both visual (inline) and normal (switch) modes
function M.generate_model_keymaps(config)
  local keymaps = {}

  for key_suffix, model_config in pairs(config.models) do
    -- Visual mode: Inline chat with adapter
    table.insert(keymaps, {
      config.prefix .. key_suffix,
      function()
        M.inline_with_adapter(config.adapter, model_config.model)
      end,
      desc = string.format("CC Inline %s: %s", config.label, model_config.desc),
      mode = { "v", "x" },
    })

    -- Normal mode: Switch adapter
    table.insert(keymaps, {
      config.prefix .. key_suffix,
      function()
        M.switch_adapter(config.adapter, model_config.model)
      end,
      desc = string.format("CC Switch %s: %s", config.label, model_config.desc),
      mode = "n",
    })
  end

  return keymaps
end

-- Get default model configurations for Copilot adapter
-- Derived from AI.providers.copilot.top_choices via KEYMAP_SLOT_PATTERN
function M.get_copilot_models_config()
  return AI.build_keymap_slots "copilot"
end

-- Get default model configurations for OpenAI AGD adapter
-- Derived from AI.providers.openai_agd.top_choices via KEYMAP_SLOT_PATTERN
function M.get_openai_agd_models_config()
  return AI.build_keymap_slots "openai_agd"
end

-- Get default model configurations for Vertex Claude AGD adapter (using shared constants)
function M.get_vertex_claude_agd_models_config()
  return {
    h = { model = AI.models.claude.CLAUDE_SONNET_5, desc = "Claude Sonnet 5" },
    H = { model = AI.models.claude.CLAUDE_OPUS_4_5, desc = "Claude Opus 4.5" },
  }
end

-- Forward declaration so picker helpers can call it before its definition.
local get_adapter_models

-- Trigger inline edit with a model picker for a specific adapter (skip adapter selection step).
-- @param adapter_name string  e.g. "copilot" or "openai_agd"
-- @param use_dynamic  boolean whether to do a live HTTP fetch for the model list
function M.inline_with_model_picker(adapter_name, use_dynamic)
  -- Capture visual context before picker UI opens so selection isn't lost
  local preserved_context = require("codecompanion.utils.context").get(vim.api.nvim_get_current_buf(), { range = 2 })

  local models = get_adapter_models(adapter_name, use_dynamic)
  if #models == 0 then
    M.inline_with_adapter(adapter_name, nil, preserved_context)
    return
  end

  vim.ui.select(models, {
    prompt = "Select Model:",
    format_item = function(item)
      return type(item) == "table" and item.id or item
    end,
  }, function(selected_model)
    if not selected_model then
      return
    end
    local model_id = type(selected_model) == "table" and selected_model.id or selected_model
    M.inline_with_adapter(adapter_name, model_id, preserved_context)
  end)
end

-- Open (or switch) chat for a specific adapter with a model picker (skip adapter selection step).
-- If a chat is already open, delegates to the built-in change_adapter keymap.
-- Otherwise shows a model picker for the given adapter and opens a new chat.
-- @param adapter_name string  e.g. "copilot" or "openai_agd"
-- @param use_dynamic  boolean whether to do a live HTTP fetch for the model list
function M.chat_with_model_picker(adapter_name, use_dynamic)
  local chat = require("codecompanion").last_chat()

  if chat then
    -- Chat already open: use built-in adapter switcher (shows full picker internally)
    local ok, change_adapter = pcall(require, "codecompanion.interactions.chat.keymaps.change_adapter")
    if ok and change_adapter and change_adapter.callback then
      change_adapter.callback(chat)
    else
      vim.notify("change_adapter keymap not available", vim.log.levels.WARN)
    end
    return
  end

  -- No existing chat — show model picker then open a new chat
  local models = get_adapter_models(adapter_name, use_dynamic)
  if #models == 0 then
    M.chat_with_adapter(adapter_name, nil)
    return
  end

  vim.ui.select(models, {
    prompt = "Select Model:",
    format_item = function(item)
      return type(item) == "table" and item.id or item
    end,
  }, function(selected_model)
    if not selected_model then
      return
    end
    local model_id = type(selected_model) == "table" and selected_model.id or selected_model
    M.chat_with_adapter(adapter_name, model_id)
  end)
end

-- Generate all CodeCompanion keymaps for model selection
-- Returns a complete keymap table ready to use in editor_keymaps
-- @param baseKeymap table Optional base keymap table to extend
function M.generate_codecompanion_keymaps(baseKeymap)
  local keymaps = baseKeymap or {}
  local mapping_prefix = vim.g.ai_prefix_key or "<leader>A"
  local model_key = "m"
  local copilot_prefix = mapping_prefix .. "s"
  local copilot_picker_prefix = copilot_prefix .. model_key
  local agd_prefix = mapping_prefix .. "S"
  local agd_picker_prefix = agd_prefix .. model_key

  -- Copilot models
  local copilot_keymaps = M.generate_model_keymaps {
    prefix = copilot_prefix,
    adapter = "copilot",
    label = "Copilot",
    models = M.get_copilot_models_config(),
  }

  vim.list_extend(keymaps, copilot_keymaps)

  -- AGD models

  local agd_keymaps = M.generate_model_keymaps {
    prefix = agd_prefix,
    adapter = "openai_agd", -- Default adapter for AGD
    label = "AGD",
    models = M.get_openai_agd_models_config(),
  }

  -- Fix adapter for Claude models in AGD keymaps
  for _, keymap in ipairs(agd_keymaps) do
    local key = keymap[1]
  end

  vim.list_extend(keymaps, agd_keymaps)

  -- <leader>Asm — Copilot direct model picker (skips adapter step)
  table.insert(keymaps, {
    copilot_picker_prefix,
    function()
      M.chat_with_model_picker("copilot")
    end,
    desc = "CC Chat: Pick Copilot Model",
    mode = "n",
  })

  table.insert(keymaps, {
    copilot_picker_prefix,
    function()
      M.inline_with_model_picker("copilot")
    end,
    desc = "CC Inline: Pick Copilot Model",
    mode = { "v", "x" },
  })

  -- <leader>ASm — AGD direct model picker (dynamic fetch, skips adapter step)
  table.insert(keymaps, {
    agd_picker_prefix,
    function()
      M.inline_with_model_picker("openai_agd", true)
    end,
    desc = "CC Inline: Pick AGD Model (Dynamic)",
    mode = { "v", "x" },
  })

  table.insert(keymaps, {
    agd_picker_prefix,
    function()
      M.chat_with_model_picker("openai_agd", true)
    end,
    desc = "CC Chat: Pick AGD Model (Dynamic)",
    mode = "n",
  })

  -- Model picker + inline edit (visual only)
  -- Triggers adapter -> model picker, then inline edit on visual selection
  -- This is the <leader>AM mapping for visual mode
  table.insert(keymaps, {
    mapping_prefix .. "M",
    function()
      M.toggle_inline_with_picker()
    end,
    desc = "CC Inline: Model Picker + Inline Edit",
    mode = { "v", "x" },
  })

  -- Additional utility keymaps
  table.insert(keymaps, {
    mapping_prefix .. "i",
    function()
      local adapter, model = M.current_adapter_and_model()
      local Snacks = require "snacks"
      vim.print(string.format("CodeCompanion: %s/%s", adapter, model), { title = "Current Config" })
    end,
    desc = "CC: Show current adapter/model", -- hello
    mode = "n",
  })

  return keymaps
end

-- ============================================================================
-- Picker-based Adapter/Model Selection
-- ============================================================================

-- Get available adapter names from configured providers (AI.providers)
-- Only returns adapters that are explicitly configured, not all built-in ones.
-- Derived from my_ai_constants.providers as single source of truth.
local function get_available_adapters()
  local providers = AI.providers
  local adapters = {}
  for _, provider in pairs(providers) do
    table.insert(adapters, provider.adapter_name)
  end
  table.sort(adapters)
  return adapters
end

-- Get model choices for a given adapter
-- Handles both array (openai_agd) and hash-table (Copilot) return formats
get_adapter_models = function(adapter_name, use_dynamic)
  local config = require "codecompanion.config"
  local adapter_config = config.adapters.http[adapter_name] or config.adapters.acp[adapter_name]
  if not adapter_config then
    return {}
  end
  local adapter = require("codecompanion.adapters").resolve(adapter_config)
  if not adapter or not adapter.schema or not adapter.schema.model then
    return {}
  end

  --- @field openai CodeCompanion.HTTPAdapter.OpenAI[model]
  local models = adapter.schema.model.choices
  if type(models) == "function" then
    -- async behavior differs per adapter:
    --
    -- Copilot: choices() respects the async param.
    --   async=true  → returns nil cache miss on first call → falls back to { ["gpt-4.1"] = {} }
    --   async=false → blocks on vim.wait(3000) to fetch full model list, then caches for 30 min.
    --   So Copilot always needs async=false to return more than one model.
    --
    -- openai_agd: choices() captures use_dynamic_fetch=true from the outer
    --   get_agoda_adapters(true) closure (set by merge_agoda_adapters()).
    --   When use_dynamic_fetch=true it always calls openai_compatible.get_models()
    --   which uses Curl.get(sync=true) — the async param is ignored entirely.
    --   This always hits the internal HTTP endpoint (http://openai-proxy.agoda.is/v1/models).
    --
    -- Rule: Copilot always needs async=false; openai_agd ignores it.
    -- Use async=false unconditionally — harmless for openai_agd, required for Copilot.
    local async_val = false
    models = models(adapter, { async = async_val, use_dynamic_fetch = use_dynamic or false })
  end

  -- Normalize: Copilot returns hash { ["model-id"] = { opts = {} } },
  -- openai_agd returns array { "model-a", "model-b" }.
  -- vim.islist() distinguishes the two (Neovim 0.11+).
  if type(models) == "table" and not vim.islist(models) then
    local keys = vim.tbl_keys(models)
    table.sort(keys)
    models = keys
  end

  return models or {}
end

-- Toggle inline with adapter + model picker (visual mode)
-- Presents adapter selection -> model selection -> triggers inline edit
function M.toggle_inline_with_picker()
  -- Capture visual context before picker UI opens so selection isn't lost
  local preserved_context = require("codecompanion.utils.context").get(vim.api.nvim_get_current_buf(), { range = 2 })
  local adapters = get_available_adapters()

  vim.ui.select(adapters, {
    prompt = "Select Adapter:",
    format_item = function(item)
      return item
    end,
  }, function(adapter_name)
    if not adapter_name then
      return
    end

    local models = get_adapter_models(adapter_name)
    if #models == 0 then
      -- No model choices, use default
      M.inline_with_adapter(adapter_name, nil, preserved_context)
      return
    end

    vim.ui.select(models, {
      prompt = "Select Model:",
      format_item = function(item)
        return type(item) == "table" and item.id or item
      end,
    }, function(selected_model)
      if not selected_model then
        return
      end

      local model_id = type(selected_model) == "table" and selected_model.id or selected_model

      M.inline_with_adapter(adapter_name, model_id, preserved_context)
    end)
  end)
end

-- Toggle chat with adapter + model picker (normal mode)
-- If chat exists, use built-in change_adapter; if no chat, create new with picker
function M.toggle_chat_with_picker()
  local chat = require("codecompanion").last_chat()

  if chat then
    -- Chat exists, use built-in adapter change keymap
    local ok, change_adapter = pcall(require, "codecompanion.interactions.chat.keymaps.change_adapter")
    if ok and change_adapter and change_adapter.callback then
      change_adapter.callback(chat)
    else
      vim.notify("change_adapter keymap not available", vim.log.levels.WARN)
    end
    return
  end

  -- No chat exists, create new with picker
  local adapters = get_available_adapters()

  vim.ui.select(adapters, {
    prompt = "Select Adapter for New Chat:",
    format_item = function(item)
      return item
    end,
  }, function(adapter_name)
    if not adapter_name then
      return
    end

    local models = get_adapter_models(adapter_name)
    if #models == 0 then
      M.chat_with_adapter(adapter_name, nil)
      return
    end

    vim.ui.select(models, {
      prompt = "Select Model:",
      format_item = function(item)
        return type(item) == "table" and item.id or item
      end,
    }, function(selected_model)
      if not selected_model then
        return
      end

      local model_id = type(selected_model) == "table" and selected_model.id or selected_model

      M.chat_with_adapter(adapter_name, model_id)
    end)
  end)
end

-- Toggle inline with adapter + model picker (visual mode) - DYNAMIC FETCH
-- Fetches models from AGD proxy (requires VPN). Produces error notifications when offline.
function M.toggle_inline_with_picker_dynamic()
  -- Capture visual context before picker UI opens so selection isn't lost
  local preserved_context = require("codecompanion.utils.context").get(vim.api.nvim_get_current_buf(), { range = 2 })
  local adapters = get_available_adapters()

  vim.ui.select(adapters, {
    prompt = "Select Adapter for Inline (Dynamic):",
    format_item = function(item)
      return item
    end,
  }, function(adapter_name)
    if not adapter_name then
      return
    end


    local models = get_adapter_models(adapter_name, true) -- use_dynamic = true
    if #models == 0 then
      M.inline_with_adapter(adapter_name, nil, preserved_context)
      return
    end

    vim.ui.select(models, {
      prompt = "Select Model:",
      format_item = function(item)
        return type(item) == "table" and item.id or item
      end,
    }, function(selected_model)
      if not selected_model then
        return
      end

      local model_id = type(selected_model) == "table" and selected_model.id or selected_model

      M.inline_with_adapter(adapter_name, model_id, preserved_context)
    end)
  end)
end

-- Toggle chat with adapter + model picker (normal mode) - DYNAMIC FETCH
-- If chat exists, use built-in change_adapter; if no chat, create new with picker
-- Fetches models from AGD proxy (requires VPN). Produces error notifications when offline.
function M.toggle_chat_with_picker_dynamic()
  local chat = require("codecompanion").last_chat()
  -- v19.6.0 note:
  -- CodeCompanion moved chat editor_context modules to interactions.shared.editor_context.
  -- If MCP resources are registered into config.interactions.chat.editor_context
  -- (old mcphub patch behavior), CodeCompanion can try resolving the stale path
  -- `interactions.chat.editor_context.buffer` and fail. Keep the mcphub patch on
  -- `config.interactions.shared.editor_context` and pin CodeCompanion to v19.6.0.

  if chat then
    -- Chat exists, use built-in adapter change keymap
    local ok, change_adapter = pcall(require, "codecompanion.interactions.chat.keymaps.change_adapter")
    if ok and change_adapter and change_adapter.callback then
      change_adapter.callback(chat)
    else
      vim.notify("change_adapter keymap not available", vim.log.levels.WARN)
    end
    return
  end

  -- No chat exists, create new with picker (dynamic fetch)
  local adapters = get_available_adapters()

  vim.ui.select(adapters, {
    prompt = "Select Adapter for New Chat (Dynamic):",
    format_item = function(item)
      return item
    end,
  }, function(adapter_name)
    if not adapter_name then
      return
    end

    local models = get_adapter_models(adapter_name, true) -- use_dynamic = true
    if #models == 0 then
      M.chat_with_adapter(adapter_name, nil)
      return
    end

    vim.ui.select(models, {
      prompt = "Select Model:",
      format_item = function(item)
        return type(item) == "table" and item.id or item
      end,
    }, function(selected_model)
      if not selected_model then
        return
      end

      local model_id = type(selected_model) == "table" and selected_model.id or selected_model

      M.chat_with_adapter(adapter_name, model_id)
    end)
  end)
end

-- Quick actions for common use cases
M.actions = {
  -- Inline chat with current selection
  inline_current = function()
    vim.cmd "CodeCompanionChat Add"
  end,

  -- Open chat toggle
  chat_toggle = function()
    vim.cmd "CodeCompanionChat Toggle"
  end,

  -- Quick inline with fast model (using shared constants)
  inline_fast = function()
    M.inline_with_adapter(AI.defaults.adapter, AI.models.gpt.GPT_5_MINI)
  end,

  -- Quick inline with heavy model (using shared constants)
  inline_heavy = function()
    M.inline_with_adapter(AI.defaults.adapter, AI.agd_models.claude.CLAUDE_SONNET_4_5)
  end,
}

-- TEST INLINE
-- M.inline_with_adapter(AI.defaults.adapter, AI.models.gpt.GPT_5_MINI)

return M
