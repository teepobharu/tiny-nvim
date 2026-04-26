-- Avante utility functions for Agoda-specific provider configurations
local M = {}

local AI = require "utils.my_ai_constants"
local AI_CFG = require "utils.my_ai_default_config"

local DEFAULT_PROVIDER = AI_CFG.DEFAULT_PROVIDER
local DEFAULT_MODEL = AI_CFG.preferred_model()
local ENABLE_COPILOT = AI_CFG.ENABLE_COPILOT

local function prune_copilot_provider()
  if ENABLE_COPILOT then
    return
  end
  local cfg = require "avante.config"
  if cfg.providers then
    cfg.providers.copilot = nil
  end
end
-- Get Agoda-specific provider configurations
-- Derived from M.providers.openai_agd in my_ai_constants
-- model_names: filtered + remapped AGD provider models for Avante selector
--- @param opts? AgdModelNameOpts
function M.get_agoda_providers(opts)
  local p = AI.providers.openai_agd
  local avante = p.avante_opts
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
      __inherited_from = avante.avante_inherited_from,
      endpoint = avante.endpoint,
      model = p.top_choices.gpt.default.M, -- default to gpt default M tier
      timeout = AI.defaults.timeout,
      model_names = AI.get_agd_model_names(opts),
      extra_request_body = avante.request_defaults,
    },
    -- TODO: fix avante warning later after enter mappings <leader-r>S+ any agoda models is it because initially not have ?
    --    Error  03:21:22 msg_show.lua_error Error executing Lua callback: ..._tinynvim/lazy/avante.nvim/lua/avante/providers/init.lua:162: The configuration of your provider "openai_agd" is incorrect, missing the `__inherited_from` attribute or a custom `parse_curl_args` function. Please fix your provider configuration. For more details, see: https://github.com/yetone/avante.nvim/wiki/Custom-providers
    --     openai_agd = {
    --   __inherited_from = avante.avante_inherited_from,
    --   endpoint = avante.endpoint,
    --   model = p.top_choices.gpt.default.M, -- default to gpt default M tier
    --   timeout = AI.defaults.timeout,
    --   model_names = AI.get_agd_model_names(),
    --   extra_request_body = avante.request_defaults,
    -- },
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
  for name, _ in pairs(agd_providers) do
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
  local current_provider, current_model = M.current_provider_and_model()
  local model = current_provider == DEFAULT_PROVIDER and current_model or DEFAULT_MODEL

  prune_copilot_provider()

  local providers = {
    [DEFAULT_PROVIDER] = {
      model = model,
    },
  }

  -- If the default provider is AGD, include the full provider config so AvanteModels
  -- doesn't try to fall back to other providers (e.g. copilot) or error on missing fields.
  if DEFAULT_PROVIDER == "openai_agd" then
    local agd = M.get_agoda_providers { source = "top_choices" }
    providers.openai_agd = vim.tbl_extend("force", agd.openai_agd, { model = model })
  end

  require("avante.config").override {
    provider = DEFAULT_PROVIDER,
    providers = providers,
  }

  -- Avante override deep-merges provider tables; prune again to keep selector
  -- from calling copilot:list_models() when Copilot is disabled.
  prune_copilot_provider()

  -- Open model selection
  vim.cmd "AvanteModels"
end

-- Open AvanteModels with AGD provider only
--- @param opts? AgdModelNameOpts
function M.select_model_agd(opts)
  local current_provider, current_model = M.current_provider_and_model()
  local agd_providers = M.get_agoda_providers(opts)
  local default_agd_model = AI.providers.openai_agd.top_choices.gpt.default.M

  prune_copilot_provider()

  require("avante.config").override {
    provider = "openai_agd",
    providers = {
      openai_agd = vim.tbl_extend("force", agd_providers.openai_agd, {
        model = current_provider == "openai_agd" and current_model or default_agd_model,
      }),
    },
  }

  prune_copilot_provider()

  -- Open model selection
  vim.cmd "AvanteModels"
end

-- Open AvanteModels with all providers (including AGD)
--- @param opts? AgdModelNameSource
function M.select_model_all(opts)
  -- Restore full provider list including Agoda providers
  local full_providers = vim.tbl_extend("force", M.get_lean_providers(), M.get_agoda_providers(opts))

  prune_copilot_provider()

  require("avante.config").override {
    providers = full_providers,
  }

  prune_copilot_provider()

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
-- Derived from AI.providers.copilot.top_choices via KEYMAP_SLOT_PATTERN
function M.get_copilot_models_config()
  return AI.build_keymap_slots "copilot"
end

-- Get default model configurations for OpenAI AGD provider
-- Derived from AI.providers.openai_agd.top_choices via KEYMAP_SLOT_PATTERN
function M.get_openai_agd_models_config()
  return AI.build_keymap_slots "openai_agd"
end

-- Get default model configurations for Vertex Claude AGD provider
-- Kept manual — not actively used, not in M.providers
function M.get_vertex_claude_agd_models_config()
  return {
    h = { model = AI.models.claude.CLAUDE_3_7_SONNET, desc = "Claude 3.7 Sonnet" },
    H = { model = AI.models.claude.CLAUDE_OPUS_4_5, desc = "Claude Opus 4.5" },
  }
end

-- Generate all Avante keymaps for model selection
-- Returns a complete keymap table ready to use in editor_keymaps
function M.generate_avante_keymaps(baseKeymap)
  local keymaps = baseKeymap or {}

  -- Model selection keymaps
  -- Copilot models with <leader>rs prefix
  if ENABLE_COPILOT then
    local copilot_keymaps = M.generate_model_keymaps {
      prefix = "<leader>rs",
      provider = "copilot",
      label = "",
      models = M.get_copilot_models_config(),
    }

    vim.list_extend(keymaps, copilot_keymaps)
  end

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
