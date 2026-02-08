-- Avante utility functions for Agoda-specific provider configurations
local M = {}

local DEFAULT_PROVIDER = "copilot"
local DEFAULT_MODEL = vim.env.DEFAULT_MODEL_COPILOT or "gpt-5-mini"
-- Get Agoda-specific provider configurations
-- These providers use internal Agoda endpoints and are separated from the main config
-- for easier maintenance and to optionally exclude them from model selection
function M.get_agoda_providers()
  return {
    -- claude_agd = {
    --   __inherited_from = "claude",
    --   model = "claude-3-7-sonnet",
    --   endpoint = "https://genai-gateway.agoda.is/claude",
    -- },
    -- vertex_vclaude_2 = {
    --   __inherited_from = "vertex",
    --   endpoint = "https://genai-gateway.agoda.is/claude",
    --   model = "claude-3-7-sonnet",
    --   timeout = 30000,
    --   extra_request_body = {
    --     temperature = 0.75,
    --     max_tokens = 20480,
    --   },
    --   model_names = {
    --     "claude-3-5-haiku",
    --     "claude-3-7-sonnet",
    --     "claude-haiku-4-5",
    --     "claude-opus-4-5",
    --   },
    --   api_key = "OPENAI_API_KEY",
    -- },
    -- vertex_claude_agd = {
    --   __inherited_from = "vertex",
    --   endpoint = "http://openai-proxy.agoda.is/v1",
    --   model = "claude-3-7-sonnet",
    --   timeout = 30000,
    --   extra_request_body = {
    --     temperature = 0.75,
    --     max_tokens = 20480,
    --   },
    --   model_names = {
    --     "claude-3-5-haiku",
    --     "claude-3-7-sonnet",
    --     "claude-haiku-4-5",
    --     "claude-opus-4-5",
    --   },
    --   api_key = "OPENAI_API_KEY",
    -- },
    openai_agd = {
      __inherited_from = "openai",
      -- api_key = "OPENAI_API_KEY",
      -- endpoint = "https://genai-gateway.agoda.is/v1",
      endpoint = "http://openai-proxy.agoda.is/v1",
      -- http://openai-proxy.agoda.is/v1
      model = "gpt-5.2",
      timeout = 30000,
      model_names = {
        -- can cross check codecompanion with lua/plugins/extra/myEditor.lua:228:1
        "gpt-4.1",
        "gpt-4.1-mini",
        "grok-code-fast-1",
        "gpt-5-mini",
        "gpt-5.1",
        "gpt-5.2",
        "gemini-3-pro-preview",
        "gemini-2.5-flash",
        "deepseek-r1-0528-maas",
      },
      extra_request_body = {
        temperature = 0,
        max_completion_tokens = 4096,
      },
    },
  }
end

-- Get list of Agoda provider names (for filtering)
function M.get_agoda_provider_names()
  local providers = M.get_agoda_providers()
  local names = {}
  for name, _ in pairs(providers) do
    table.insert(names, name)
  end
  return names
end

-- Remove Agoda providers from a providers table
-- Useful for creating a "lean" provider list for faster model selection
function M.remove_agoda_providers(providers)
  local result = vim.deepcopy(providers)
  local agoda_names = M.get_agoda_provider_names()

  for _, name in ipairs(agoda_names) do
    result[name] = nil
  end

  return result
end

function M.current_provider_and_model()
  local current_provider = require("avante.config").provider
  local current_model = require("avante.config").providers[current_provider].model
  return current_provider, current_model
end

-- Check if current provider is an Agoda provider
function M.is_agoda_provider(provider_name)
  local agoda_names = M.get_agoda_provider_names()
  for _, name in ipairs(agoda_names) do
    if name == provider_name then
      return true
    end
  end
  return false
end

-- Ask with a specific provider and model
-- Temporarily overrides the provider configuration and calls ask/edit
function M.edit_with_provider(provider, model)
  -- Temporarily override the provider configuration
  require("avante.config").override {
    provider = provider,
    providers = {
      [provider] = {
        model = model,
      },
    },
  }
  require("avante.api").edit()
end

-- Switch to a specific provider and model without asking
-- Just updates the configuration and shows a notification
function M.switch_provider(provider, model)
  -- Override the provider configuration
  require("avante.config").override {
    provider = provider,
    providers = {
      [provider] = {
        model = model,
      },
    },
  }

  -- Show notification
  local Snacks = require "snacks"
  Snacks.notify.warn(string.format("Switched to %s/%s", provider, model), { title = "Avante Provider" })
end

-- Get lean providers (base providers without Agoda-specific ones)
-- Explicitly sets all AGD provider keys to false to ensure they are disabled
function M.get_lean_providers()
  local lean = {
    [DEFAULT_PROVIDER] = {
      model = DEFAULT_MODEL,
    },
  }
  -- Explicitly disable all AGD providers by setting them to false
  -- not sure if helps - slow load init but next faster
  -- local agd_names = M.get_agoda_provider_names()
  -- for _, name in ipairs(agd_names) do
  -- local agd_providers = M.get_agoda_providers()

  local agd_providers = M.get_agoda_providers()
  for name, value in ipairs(agd_providers) do
    lean[name] = {
      -- DOES NOT REALLY WORK WILL NOT OVERRIDE / THROW ERRORS
      -- __inherited_from = value["__inherited_from"],
      -- endpoint = false,
      -- model = false,
      -- model_names = {},
    }
  end

  return lean
end

-- Open AvanteModels with lean providers (without AGD)
function M.select_model_lean()
  -- Temporarily override to use only lean providers, does not seem to override why ?
  local lean_providers = M.get_lean_providers()
  -- print([==[M.select_model_lean lean_providers:]==], vim.inspect(lean_providers)) -- __AUTO_GENERATED_PRINT_VAR_END__
  local current_provider, current_model = M.current_provider_and_model()
  -- TODO: revise if active provider / current model is not in lean provider switch to default provider
  local override_config = {
    providers = lean_providers,
  }
  if
    not lean_providers[current_provider]
    or lean_providers[current_provider].model == false
    or lean_providers[current_provider].model ~= current_model
  then
    Snacks.notify.warn(
      string.format(
        "Current provider %s/%s not in lean providers, switch to default %s/%s",
        current_provider,
        current_model,
        DEFAULT_PROVIDER,
        DEFAULT_MODEL
      ),
      { title = "Avante Model Selection" }
    )
    override_config.provider = DEFAULT_PROVIDER
  end

  require("avante.config").override(override_config)
  -- __AUTO_GENERATED_PRINT_VAR_START__
  -- print(
  --   [==[M.select_model_lean require('avante.config').get().providers:]==],
  --   vim.inspect(require("avante.config").providers)
  -- ) -- __AUTO_GENERATED_PRINT_VAR_END__

  -- Open model selection
  vim.cmd "AvanteModels"
end

-- Open AvanteModels with all providers (including AGD)
function M.select_model_all()
  -- Restore full provider list including Agoda providers
  local full_providers = vim.tbl_extend("force", M.get_lean_providers(), M.get_agoda_providers())
  require("avante.config").override {
    providers = full_providers,
  }

  -- Open model selection
  vim.cmd "AvanteModels"
end

-- Generate keymaps for model selection based on configuration
-- This reduces duplication and provides a clear mapping structure
-- @param config table Configuration with structure:
--   {
--     prefix = string,  -- Key prefix like "<leader>rs"
--     provider = string, -- Provider name like "copilot" or "openai_agd"
--     label = string,    -- Label for descriptions like "Copilot" or "AGD"
--     models = {         -- Table of model configurations
--       key_suffix = {   -- e.g., "f", "F", "h", "H", "c", "C"
--         model = string,      -- Model name
--         desc = string,       -- Short description
--       }
--     }
--   }
-- @return table Array of keymaps for both visual (ask) and normal (switch) modes
function M.generate_model_keymaps(config)
  local keymaps = {}

  for key_suffix, model_config in pairs(config.models) do
    -- Visual mode: Ask with provider
    table.insert(keymaps, {
      config.prefix .. key_suffix,
      function()
        M.edit_with_provider(config.provider, model_config.model)
      end,
      desc = string.format("Ask %s: %s", config.label, model_config.desc),
      mode = { "v", "x" },
    })

    -- Normal mode: Switch provider
    table.insert(keymaps, {
      config.prefix .. key_suffix,
      function()
        M.switch_provider(config.provider, model_config.model)
      end,
      desc = string.format("Switch %s: %s", config.label, model_config.desc),
      mode = "n",
    })
  end

  return keymaps
end

-- Get default model configurations for Copilot provider
function M.get_copilot_models_config()
  return {
    f = { model = "gpt-4.1-mini", desc = "GPT-4.1-mini (fast)" },
    F = { model = "gpt-5-mini", desc = "GPT-5-mini (fast-2)" },
    g = { model = "grok-code-fast-1", desc = "Grok code (fast)" },
    G = { model = "claude-haiku-4-5", desc = "Claude Haiku 4.5" },
    h = { model = "claude-sonnet-4-5", desc = "Claude Sonnet 4.5 (heavy)" },
    H = { model = "claude-opus-4-5", desc = "Claude Opus 4.5" },
    c = { model = "gpt-5.1-codex-max", desc = "GPT-5.1-codex-max" },
    C = { model = "gpt-5.1-codex-mini", desc = "GPT-5.1-codex-mini" },
  }
end

-- Get default model configurations for OpenAI AGD provider
function M.get_openai_agd_models_config()
  return {
    f = { model = "gpt-4.1-mini", desc = "GPT-4.1-mini" },
    F = { model = "gpt-5-mini", desc = "GPT-5-mini" },
    g = { model = "grok-code-fast-1", desc = "Grok code (fast)" },
    G = { model = "claude-haiku-4-5", desc = "Claude Haiku 4.5" },
    c = { model = "gpt-5.2", desc = "GPT-5.2" },
  }
end

-- Get default model configurations for Vertex Claude AGD provider
function M.get_vertex_claude_agd_models_config()
  return {
    h = { model = "claude-3-7-sonnet", desc = "Claude 3.7 Sonnet" },
    H = { model = "claude-opus-4-5", desc = "Claude Opus 4.5" },
  }
end

-- Generate all Avante keymaps for model selection
-- Returns a complete keymap table ready to use in editor_keymaps
function M.generate_avante_keymaps(baseKeymap)
  local keymaps = baseKeymap or {}

  -- Model selection keymaps
  -- Copilot models with <leader>rs prefix
  local copilot_keymaps = M.generate_model_keymaps {
    prefix = "<leader>rs",
    provider = "copilot",
    label = "",
    models = M.get_copilot_models_config(),
  }

  vim.list_extend(keymaps, copilot_keymaps)

  -- AGD models with <leader>rS prefix (OpenAI + Vertex Claude combined)
  local agd_models = vim.tbl_extend("force", M.get_openai_agd_models_config(), M.get_vertex_claude_agd_models_config())

  local agd_keymaps = M.generate_model_keymaps {
    prefix = "<leader>rS",
    provider = "openai_agd", -- Default provider for AGD
    label = "AGD",
    models = agd_models,
  }

  -- Fix provider for Claude models in AGD keymaps
  for _, keymap in ipairs(agd_keymaps) do
    local key = keymap[1]
    -- If key ends with 'h' or 'H', use vertex_claude_agd provider
    if key:match "[hH]$" then
      if keymap.mode == "n" then
        -- Normal mode: switch provider
        keymap[2] = function()
          local model_key = key:match "[hH]$"
          local model_config = M.get_vertex_claude_agd_models_config()[model_key]
          M.switch_provider("vertex_claude_agd", model_config.model)
        end
      else
        -- Visual mode: ask with provider
        keymap[2] = function()
          local model_key = key:match "[hH]$"
          local model_config = M.get_vertex_claude_agd_models_config()[model_key]
          M.edit_with_provider("vertex_claude_agd", model_config.model)
        end
      end
    end
  end

  vim.list_extend(keymaps, agd_keymaps)

  return keymaps
end

return M
