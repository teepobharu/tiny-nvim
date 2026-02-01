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
local AI = require("utils.my_ai_constants")

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
function M.fetch_model_helper(self, opts)
  opts = opts or {}

  -- Use shared static models with CodeCompanion additional filters
  local static_models = AI.static_models.codecompanion_default

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

  -- For immediate display, return filtered static models
  if opts.async ~= false then
    return AI.filter_models(static_models, {
      additional_blacklist = blacklist,
      additional_keywords = keyword_filters,
    })
  end

  -- For model selection UI, try to fetch dynamic models
  local ok, openai_compatible = pcall(require, "codecompanion.adapters.http.openai_compatible")

  if ok and openai_compatible.schema and openai_compatible.schema.model and openai_compatible.schema.model.choices then
    local dynamic_models = openai_compatible.schema.model.choices(self, opts)

    if dynamic_models and #dynamic_models > 0 then
      -- Create lookup set for dynamic models
      local dynamic_set = {}
      for _, model in ipairs(dynamic_models) do
        dynamic_set[model] = true
      end

      -- Filter static models to only those present in dynamic models
      local filtered_static = {}
      for _, model in ipairs(static_models) do
        if dynamic_set[model] then
          table.insert(filtered_static, model)
        end
      end

      -- Merge: prioritize filtered static models first, then remaining dynamic models
      local merged = {}
      local seen = {}

      -- Add filtered static models first (for priority positioning)
      for _, model in ipairs(filtered_static) do
        merged[#merged + 1] = model
        seen[model] = true
      end

      -- Add remaining dynamic models
      for _, model in ipairs(dynamic_models) do
        if not seen[model] then
          merged[#merged + 1] = model
          seen[model] = true
        end
      end

      -- Apply blacklist and keyword filters to merged list
      return AI.filter_models(merged, {
        additional_blacklist = blacklist,
        additional_keywords = keyword_filters,
      })
    end
  end

  -- Fallback: return filtered static models
  return AI.filter_models(static_models, {
    additional_blacklist = blacklist,
    additional_keywords = keyword_filters,
  })
end

-- ============================================================================
-- Core Actions
-- ============================================================================

-- Get current adapter and model from CodeCompanion config
function M.current_adapter_and_model()
  local config = require("codecompanion.config")
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
-- Creates an inline instance with the specified adapter
function M.inline_with_adapter(adapter_name, model)
  local api = vim.api
  local config = require("codecompanion.config")
  print([==[M.inline_with_adapter config:]==], vim.inspect(config)) -- __AUTO_GENERATED_PRINT_VAR_END__

  -- Get current buffer context
  local bufnr = api.nvim_get_current_buf()
  local context = require("codecompanion.utils.context").get(bufnr, {})

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

  -- Create inline instance with specific adapter
  local inline = require("codecompanion.interactions.inline").new({
    adapter = adapter,
    buffer_context = context,
  })

  if not inline then
    vim.notify("Failed to create inline instance", vim.log.levels.ERROR)
    return
  end

  -- Prompt for user input
  vim.ui.input({ prompt = config.display.action_palette.prompt }, function(input)
    if not input or vim.trim(input) == "" then
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

  require("codecompanion").chat({
    params = params,
    subcommand = "toggle",
  })
end

-- Switch CodeCompanion default adapter and model
-- Updates the configuration and shows a notification
function M.switch_adapter(adapter_name, model)
  local config = require("codecompanion.config")

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
  Snacks.notify.warn(string.format("Switched CodeCompanion to %s/%s", adapter_name, model or "default"), { title = "CodeCompanion" })
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

-- Get default model configurations for Copilot adapter (using shared constants)
function M.get_copilot_models_config()
  return {
    f = { model = AI.models.gpt.GPT_4_1_MINI, desc = "GPT-4.1-mini (fast)" },
    F = { model = AI.models.gpt.GPT_5_MINI, desc = "GPT-5-mini (fast-2)" },
    h = { model = AI.models.claude.CLAUDE_SONNET_4_5, desc = "Claude Sonnet 4.5 (heavy)" },
    H = { model = AI.models.claude.CLAUDE_OPUS_4_5, desc = "Claude Opus 4.5" },
    c = { model = AI.models.gpt.GPT_5_1_CODEX_MAX, desc = "GPT-5.1-codex-max" },
    C = { model = AI.models.gpt.GPT_5_1_CODEX_MINI, desc = "GPT-5.1-codex-mini" },
  }
end

-- Get default model configurations for OpenAI AGD adapter (using shared constants)
function M.get_openai_agd_models_config()
  return {
    f = { model = AI.models.gpt.GPT_4_1_MINI, desc = "GPT-4.1-mini" },
    F = { model = AI.models.gpt.GPT_5_MINI, desc = "GPT-5-mini" },
    c = { model = AI.models.gpt.GPT_5_2, desc = "GPT-5.2" },
  }
end

-- Get default model configurations for Vertex Claude AGD adapter (using shared constants)
function M.get_vertex_claude_agd_models_config()
  return {
    h = { model = AI.models.claude.CLAUDE_3_7_SONNET, desc = "Claude 3.7 Sonnet" },
    H = { model = AI.models.claude.CLAUDE_OPUS_4_5, desc = "Claude Opus 4.5" },
  }
end

-- Generate all CodeCompanion keymaps for model selection
-- Returns a complete keymap table ready to use in editor_keymaps
-- @param baseKeymap table Optional base keymap table to extend
function M.generate_codecompanion_keymaps(baseKeymap)
  local keymaps = baseKeymap or {}

  -- Copilot models with <leader>AS prefix
  local copilot_keymaps = M.generate_model_keymaps {
    prefix = "<leader>AS",
    adapter = "copilot",
    label = "Copilot",
    models = M.get_copilot_models_config(),
  }

  vim.list_extend(keymaps, copilot_keymaps)

  -- AGD models with <leader>ASS prefix (OpenAI + Vertex Claude combined)
  local agd_models = vim.tbl_extend("force", M.get_openai_agd_models_config(), M.get_vertex_claude_agd_models_config())

  local agd_keymaps = M.generate_model_keymaps {
    prefix = "<leader>ASS",
    adapter = "openai_agd", -- Default adapter for AGD
    label = "AGD",
    models = agd_models,
  }

  -- Fix adapter for Claude models in AGD keymaps
  for _, keymap in ipairs(agd_keymaps) do
    local key = keymap[1]
    -- If key ends with 'h' or 'H', use vertex_claude_agd adapter
    if key:match "[hH]$" then
      if keymap.mode == "n" then
        -- Normal mode: switch adapter
        keymap[2] = function()
          local model_key = key:match "[hH]$"
          local model_config = M.get_vertex_claude_agd_models_config()[model_key]
          M.switch_adapter("vertex_claude_agd", model_config.model)
        end
      else
        -- Visual mode: inline with adapter
        keymap[2] = function()
          local model_key = key:match "[hH]$"
          local model_config = M.get_vertex_claude_agd_models_config()[model_key]
          M.inline_with_adapter("vertex_claude_agd", model_config.model)
        end
      end
    end
  end

  vim.list_extend(keymaps, agd_keymaps)

  -- Additional utility keymaps
  table.insert(keymaps, {
    "<leader>ASi",
    function()
      local adapter, model = M.current_adapter_and_model()
      local Snacks = require "snacks"
      Snacks.notify.info(string.format("CodeCompanion: %s/%s", adapter, model), { title = "Current Config" })
    end,
    desc = "CC: Show current adapter/model",
    mode = "n",
  })

  return keymaps
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
    M.inline_with_adapter(AI.defaults.adapter, AI.models.claude.CLAUDE_SONNET_4_5)
  end,
}

-- TEST INLINE
-- M.inline_with_adapter(AI.defaults.adapter, AI.models.gpt.GPT_5_MINI)

return M
