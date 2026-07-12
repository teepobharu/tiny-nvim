-- Shared AI constants for Avante, CodeCompanion, and other AI tools
-- Centralized model names, endpoints, and configurations to avoid duplication
-- Source of truth for AGD model defaults: ~/dotfiles/.bash_exports (AGD_* env).
-- DEFAULT_AGD_MODEL and the static_models lists below honor those env vars first
-- and fall back to the literals listed here. Override AGD_LATEST / AGD_CODE_* /
-- AGD_COMMIT_* in ~/.bash.local to retarget without editing this file.
local M = {}

local function env_or(name, fallback)
  local v = os.getenv(name)
  if v and v ~= "" then return v end
  return fallback
end

-- ============================================================================
-- Model Names (shared across Avante and CodeCompanion)
-- ============================================================================

M.models = {
  -- OpenAI/GPT models
  gpt = {
    GPT_4_1 = "gpt-4.1",
    GPT_4_1_MINI = "gpt-4.1-mini",
    GPT_4_1_NANO = "gpt-4.1-nano",
    GPT_5 = "gpt-5",
    GPT_5_5 = "gpt-5.5",
    GPT_5_NANO = "gpt-5-nano",
    GPT_5_4_NANO = "gpt-5.4-nano",
    GPT_5_MINI = "gpt-5-mini",
    GPT_5_4_MINI = "gpt-5.4-mini",
    GPT_5_1 = "gpt-5.1",
    GPT_5_2 = "gpt-5.2",
    GPT_5_3_CODEX = "gpt-5.3-codex",
    GPT_5_4 = "gpt-5.4",
    GPT_5_1_CODEX_MAX = "gpt-5.1-codex-max",
    GPT_5_1_CODEX_MINI = "gpt-5.1-codex-mini",
    GPT_5_3_CHAT_LATEST = "gpt-5.3-chat-latest",
    GPT_4O = "gpt-4o",
    GPT_4O_MINI = "gpt-4o-mini",
    GPT_3_5_TURBO = "gpt-3.5-turbo",
  },

  -- Claude models
  claude = {
    CLAUDE_3_5_HAIKU = "claude-3-5-haiku",
    CLAUDE_SONNET_4 = "claude-sonnet-4",
    CLAUDE_HAIKU_4_5 = "claude-haiku-4-5",
    CLAUDE_SONNET_5 = "claude-sonnet-5",
    CLAUDE_SONNET_4_5 = "claude-sonnet-4-5",
    CLAUDE_SONNET_4_6 = "claude-sonnet-4-6",
    CLAUDE_OPUS_4_5 = "claude-opus-4-5",
    CLAUDE_OPUS_4_6 = "claude-opus-4-6",
    CLAUDE_OPUS_4_7 = "claude-opus-4-7",
    CLAUDE_OPUS_4_8 = "claude-opus-4-8",
  },

  gemini = {
    GEMINI_3_1_PRO = "gemini-3.1-pro",
    GEMINI_3_1_PRO_PREVIEW = "gemini-3.1-pro-preview",
    GEMINI_3_1_FLASH_LITE = "gemini-3.1-flash-lite",
    GEMINI_3_5_FLASH = "gemini-3.5-flash",
    GEMINI_3_PRO = "gemini-3-pro",
    GEMINI_3_FLASH = "gemini-3-flash",
    GEMINI_2_5_PRO = "gemini-2.5-pro",
    GEMINI_2_5_FLASH = "gemini-2.5-flash",
    GEMINI_2_5_FLASH_LITE = "gemini-2.5-flash-lite",
    GEMMA_4 = "gemma4",
    GEMMA_4_26B_A4B_IT_MAAS = "gemma-4-26b-a4b-it-maas",
  },

  -- O-series reasoning models
  o_series = {
    O3 = "o3",
    O3_MINI = "o3-mini",
    O4_MINI = "o4-mini",
  },

  -- DeepSeek models
  deepseek = {
    DEEPSEEK_R1 = "deepseek-r1-0528-maas",
    -- DEEPSEEK = "deepseek", -- bare name broken (400 Invalid model name) as of 2026-06-07
  },

  -- Qwen models (AGD proxy IDs)
  qwen = {
    QWEN_3_6_27B = "qwen-3.6-27b",
    -- QWQ_32B = "qwq-32b", -- 400 Invalid model name at chat endpoint
    -- QWEN_3_5_27B = "qwen-3.5-27b", -- removed from proxy
  },

  -- Kimi (Moonshot) models
  kimi = {
    KIMI_K2_6 = "kimi-k2.6",
    KIMI_K2_7_CODE = "kimi-k2.7-code",
  },

  others = {
    GROK_FAST_1 = "grok-code-fast-1",
  },
}

--- @alias ModelSize "S"|"M"|"L"
--- @alias TierName "default"|"alt"|"max"

--- @class FilterModelOpts
--- @field additional_blacklist? string[]
--- @field additional_keywords? string[]

--- @class AgdModelNameOpts : FilterModelOpts
--- @field source? AgdModelNameSource
--- @alias AgdModelNameSource '"all"' | '"top_choices"'

--- Sparse size-indexed table (not every size is required)
--- @class ModelSizeMap
--- @field S? string
--- @field M? string
--- @field L? string

--- Each model family's tiered selections within a provider
--- @class ModelTiers
--- @field default ModelSizeMap   Standard picks
--- @field alt? ModelSizeMap      Alternative/lighter picks
--- @field max? ModelSizeMap      Maximum capability picks

--- Avante-specific provider settings (endpoint, inherited_from, request body)
--- @class AvanteProviderOpts
--- @field avante_inherited_from string  Avante __inherited_from key
--- @field endpoint string               API endpoint URL
--- @field request_defaults table        Extra request body params

--- Per-provider configuration with per-family tiered model selections
--- @class ProviderConfig
--- @field adapter_name string                     Adapter key for CC/Avante
--- @field display_label string                    Short label for titles (e.g. "AGD", "Copilot")
--- @field top_choices table<string, ModelTiers>   Keyed by model family ("gpt", "claude", etc.)
--- @field avante_opts? AvanteProviderOpts         Avante-specific settings (AGD only)

--- @class AvailableProviderConfig
--- @field openai_agd ProviderConfig
--- @field copilot ProviderConfig

--- @type ModelSizeMap
M.models_sizing = {
  S = "S",
  M = "M",
  L = "L",
}

-- ============================================================================
-- Agoda Endpoints
-- ============================================================================

-- AG_OPENAIPROXY is the local canonical variable. OPENAI_BASE_URL remains a
-- compatible fallback for shells/tools that only expose the OpenAI convention.
-- Normalize both forms so consumers can safely append either /v1/* or /*.
local function normalize_openai_proxy_base(url)
  url = (url or "http://openai-proxy.agoda.is"):gsub("/+$", "")
  return (url:gsub("/v1$", ""))
end

local BASE_OPENAPI_URL = normalize_openai_proxy_base(vim.env.AG_OPENAIPROXY or vim.env.OPENAI_BASE_URL)
local OPENAI_PROXY_V1 = BASE_OPENAPI_URL .. "/v1"

local GEN_AI_GATEWAY_BASE = vim.env.AG_GENAIGW or "https://genai-gateway.agoda.is"
local CLAUDE_AGD = GEN_AI_GATEWAY_BASE:gsub("/?$", "") .. "/claude"

M.endpoints = {
  agoda = {
    GENAI_GATEWAY_CLAUDE = CLAUDE_AGD,
    OPENAI_PROXY_BASE = BASE_OPENAPI_URL,
    OPENAI_PROXY = OPENAI_PROXY_V1,
    OPENAI_PROXY_MODELS = OPENAI_PROXY_V1 .. "/models",
    OPENAI_PROXY_CHAT = OPENAI_PROXY_V1 .. "/chat/completions",
  },
}

-- ============================================================================
-- Provider Configurations (single source of truth for model tiers)
-- ============================================================================

--- @class AvailableProviderConfig
M.providers = {
  openai_agd = {
    adapter_name = "openai_agd",
    display_label = "AGD",
    top_choices = {
      gpt = {
        -- default=current tier, alt=previous tier; env overrides from ~/dotfiles/.bash_exports
        default = {
          XS = env_or("AGD_GPT_NANO", M.models.gpt.GPT_5_4_NANO),
          S = env_or("AGD_GPT_MINI", M.models.gpt.GPT_5_MINI),
          M = M.models.gpt.GPT_5_2,
          L = env_or("AGD_GPT_FLAGSHIP", M.models.gpt.GPT_5_5),
        },
        alt = {
          S = M.models.gpt.GPT_4_1_MINI,
          L = env_or("AGD_GPT_PREV_FLAGSHIP", M.models.gpt.GPT_5_4),
        },
        -- avante works but codex models fail codecompanion /completions (not a chat model)
        max = { L = M.models.gpt.GPT_5_5, M = M.models.gpt.GPT_5_1_CODEX_MAX },
      },
      claude = {
        -- default=current tier, alt=previous tier; env overrides from ~/dotfiles/.bash_exports
        default = {
          S = env_or("AGD_CLAUDE_S", M.models.claude.CLAUDE_HAIKU_4_5),
          M = env_or("AGD_CLAUDE_SONNET", M.models.claude.CLAUDE_SONNET_5),
          L = env_or("AGD_CLAUDE_L", M.models.claude.CLAUDE_OPUS_4_8),
        },
        alt = {
          M = env_or("AGD_CLAUDE_M_PREV", M.models.claude.CLAUDE_SONNET_4_6),
          L = env_or("AGD_CLAUDE_L_PREV", M.models.claude.CLAUDE_OPUS_4_7),
        },
      },
      gemini = {
        -- default=current tier, alt=previous tier; env overrides from ~/dotfiles/.bash_exports
        default = {
          S = env_or("AGD_GEMINI_FLASH_LITE", M.models.gemini.GEMINI_3_1_FLASH_LITE),
          M = env_or("AGD_GEMINI_FLASH_BALANCED", M.models.gemini.GEMINI_3_5_FLASH),
          L = env_or("AGD_GEMINI_PRO", M.models.gemini.GEMINI_3_1_PRO_PREVIEW),
        },
        alt = {
          S = env_or("AGD_GEMINI_FLASH_LITE_PREV", M.models.gemini.GEMINI_2_5_FLASH_LITE),
          M = env_or("AGD_GEMINI_PRO_PREV", M.models.gemini.GEMINI_2_5_FLASH),
        },
      },
      inhouse = { -- in-house / MaaS; env overrides from ~/dotfiles/.bash_exports
        default = {
          S = env_or("AGD_INHOUSE_QWEN", M.models.qwen.QWEN_3_6_27B),
          M = env_or("AGD_INHOUSE_DEEPSEEK", M.models.deepseek.DEEPSEEK_R1),
          L = env_or("AGD_INHOUSE_GEMMA", M.models.gemini.GEMMA_4),
        },
        alt = {
          M = env_or("AGD_INHOUSE_KIMI", M.models.kimi.KIMI_K2_6),
          L = env_or("AGD_INHOUSE_GEMMA_MAAS", M.models.gemini.GEMMA_4_26B_A4B_IT_MAAS),
        },
      },
      -- not exists
      -- grok = {
      --   default = { S = M.models.others.GROK_FAST_1 },
      -- },
    },
    avante_opts = {
      avante_inherited_from = "openai",
      endpoint = M.endpoints.agoda.OPENAI_PROXY,
      request_defaults = {
        temperature = 0,
        max_completion_tokens = 4096,
      },
    },
  },
  -- Provider for codex models using /v1/responses endpoint
  openai_responses_agd = {
    adapter_name = "openai_responses_agd",
    display_label = "AGD Responses",
  },
  copilot = {
    adapter_name = "copilot",
    display_label = "Copilot",
    top_choices = {
      gpt = {
        default = { S = M.models.gpt.GPT_5_MINI, M = M.models.gpt.GPT_5_5 },
        alt = { S = M.models.gpt.GPT_4_1, M = M.models.gpt.GPT_5_4 },
        max = { M = M.models.gpt.GPT_5_1_CODEX_MAX, L = M.models.gpt.GPT_5_1_CODEX_MINI },
      },
      claude = {
        default = {
          S = M.models.claude.CLAUDE_HAIKU_4_5,
          M = M.models.claude.CLAUDE_SONNET_4_6,
          L = M.models.claude.CLAUDE_OPUS_4_7,
        },
        alt = {
          M = M.models.claude.CLAUDE_SONNET_4_5,
          L = M.models.claude.CLAUDE_OPUS_4_6,
        },
      },
      grok = {
        default = { S = M.models.others.GROK_FAST_1 },
      },
    },
  },
}

-- ==========================================================================
-- CodeCompanion chat-specific model exclusions
-- ==========================================================================
-- Some models listed in shared top_choices are not compatible with
-- CodeCompanion's chat-completions transport, while remaining valid for
-- other consumers (e.g. Avante). Keep exclusions here so audits happen in one
-- place alongside providers/filters.

M.codecompanion_chat_excluded_models = {
  [M.providers.openai_agd.adapter_name] = {
    [M.models.gemini.GEMINI_3_PRO] = true, -- maps to -preview but 404 on proxy
  },
}

-- Models that require /v1/responses endpoint (not /v1/chat/completions).
-- Note: gpt-5.1-codex-mini is NOT present on AGD proxy — excluded intentionally.
M.codecompanion_responses_models = {
  M.models.gpt.GPT_5_3_CODEX,
  M.models.gpt.GPT_5_1_CODEX_MAX,
}

-- Models that support reasoning_effort (o-series + DeepSeek R1)
-- Used to inject opts.can_reason = true in the adapter choices table so that
-- CodeCompanion's upstream reasoning_effort.enabled gate activates.
M.codecompanion_reasoning_models = {
  M.models.o_series.O3,
  M.models.o_series.O3_MINI,
  M.models.o_series.O4_MINI,
  -- DeepSeek R1 also supports reasoning
  M.models.deepseek.DEEPSEEK_R1,
}

M.provider_model_remap = {
  [M.providers.openai_agd.adapter_name] = {
    -- Gemini models (3.x/3.1.x REQUIRE -preview suffix on AGD proxy chat endpoint)
    [M.models.gemini.GEMINI_3_1_PRO] = M.models.gemini.GEMINI_3_1_PRO .. "-preview",
    -- [M.models.gemini.GEMINI_3_PRO] = M.models.gemini.GEMINI_3_PRO .. "-preview", -- works on hurl but get vertex error on codecompanion : body = "{\"error\":{\"message\":\"litellm.NotFoundError: Vertex_ai_betaException - b'{\\\\n  \\\"error\\\": {\\\\n    \\\"code\\\": 404,\\\\n    \\\"message\\\": \\\"Publisher Model `projects/llmgatewayprod-17939/locations/us-central1/publishers/google/models/gemini-3-pro-preview` was not found or your project does not have access to it.
    [M.models.gemini.GEMINI_3_1_FLASH_LITE] = M.models.gemini.GEMINI_3_1_FLASH_LITE .. "-preview",
    [M.models.gemini.GEMINI_3_FLASH] = M.models.gemini.GEMINI_3_FLASH .. "-preview",
  },
}

-- ============================================================================
-- Environment Variable Keys
-- ============================================================================

M.env_keys = {
  OPENAI_API_KEY = "OPENAI_API_KEY",
  ANTHROPIC_API_KEY = "ANTHROPIC_API_KEY",
  AG_OPENAIPROXY = "AG_OPENAIPROXY",
}

-- ============================================================================
-- Model Filtering Configuration
-- ============================================================================

M.filters = {
  -- Blacklist patterns (Lua pattern matching) - models to exclude completely
  blacklist = {
    "agoda", -- Contains "agoda"
    -- "^claude%-", -- Starts with "claude-" (for AGD proxy that doesn't support Claude)
    "^ft%-", -- Fine-tuned models
    -- no computer-use
    "^computer-use",
    "^dalle-e",
    -- "^gpt-realtime",
    -- M.models.gemini.GEMINI_3_PRO,
  },
  -- TODO: add opts to model
  withNoTemp = {
    "^claude%-",
  },

  -- Keyword filters - exclude models containing these substrings
  keywords = {
    "ada:ft",
    "babbage",
    "davinci",
    "2024%-", -- Date-stamped models
    "2025%-", -- Date-stamped models
    "image",
    "audio",
    "embedding",
    "moderation",
    "tts",
    "whisper",
  },

  -- Additional filters for CodeCompanion model selection
  codecompanion_additional = {
    "4o", -- Exclude gpt-4o variants from main list (keep in static)
  },
}

-- ============================================================================
-- Static Model Lists (fallback/priority)
-- ============================================================================

M.static_models = { -- Fast models (for quick operations)
  fast = {
    M.models.gpt.GPT_4_1_MINI,
    M.models.gpt.GPT_5_MINI,
    M.models.gpt.GPT_5_NANO,
  },

  -- Commit-short — mirrors $AGD_COMMIT_SHORT_* in ~/dotfiles/.bash_exports.
  commit_short = {
    env_or("AGD_COMMIT_SHORT_1", M.models.gpt.GPT_5_4_NANO),
    env_or("AGD_COMMIT_SHORT_2", M.models.gpt.GPT_4_1_MINI),
    env_or("AGD_COMMIT_SHORT_3", M.models.gemini.GEMINI_3_1_FLASH_LITE),
    env_or("AGD_COMMIT_SHORT_4", M.models.gpt.GPT_4_1_MINI),
  },

  -- Commit-long — every entry supports up to 1M context window.
  -- Mirrors $AGD_COMMIT_LONG_* in ~/dotfiles/.bash_exports.
  commit_long = {
    env_or("AGD_COMMIT_LONG_1", M.models.gpt.GPT_4_1_MINI),
    env_or("AGD_COMMIT_LONG_2", M.models.gemini.GEMINI_3_1_FLASH_LITE),
    env_or("AGD_COMMIT_LONG_3", M.models.gpt.GPT_5_4_MINI),
    env_or("AGD_COMMIT_LONG_4", M.models.gemini.GEMINI_3_1_PRO_PREVIEW),
  },

  -- Heavy models (for complex operations)
  heavy = {
    env_or("AGD_CODE_LARGE", M.models.gpt.GPT_5_5),
    env_or("AGD_CLAUDE_L", M.models.claude.CLAUDE_OPUS_4_8),
    env_or("AGD_CLAUDE_SONNET", M.models.claude.CLAUDE_SONNET_5),
    M.models.claude.CLAUDE_OPUS_4_7,
    M.models.claude.CLAUDE_SONNET_4_6,
    M.models.claude.CLAUDE_SONNET_4_5,
    M.models.claude.CLAUDE_SONNET_4,
    M.models.claude.CLAUDE_OPUS_4_6,
    M.models.claude.CLAUDE_OPUS_4_5,
  },

  -- Codex models (for code-specific operations); env AGD_CODE_CODEX → ~/dotfiles/.bash_exports
  codex = {
    env_or("AGD_CODE_CODEX", M.models.gpt.GPT_5_5),
    M.models.gpt.GPT_5_3_CODEX,
    M.models.gpt.GPT_5_1_CODEX_MAX,
    M.models.gpt.GPT_5_1_CODEX_MINI,
  },

  -- Default priority order for CodeCompanion
  agd_default = {
    env_or("AGD_CODE_LARGE", M.models.gpt.GPT_5_5),
    M.models.gpt.GPT_5_4,
    M.models.gpt.GPT_5_2,
    M.models.gpt.GPT_5_1,
    M.models.gpt.GPT_5_MINI,
    env_or("AGD_GEMINI_FLASH_BALANCED", M.models.gemini.GEMINI_3_5_FLASH),
    env_or("AGD_GEMINI_FLASH_LITE", M.models.gemini.GEMINI_3_1_FLASH_LITE),
    env_or("AGD_INHOUSE_QWEN", M.models.qwen.QWEN_3_6_27B),
    env_or("AGD_INHOUSE_GEMMA_MAAS", M.models.gemini.GEMMA_4_26B_A4B_IT_MAAS),
    M.models.gpt.GPT_4O,
    M.models.gpt.GPT_4O_MINI,
    M.models.gpt.GPT_3_5_TURBO,
    M.models.claude.CLAUDE_SONNET_4_6,
    M.models.claude.CLAUDE_SONNET_4_5,
    M.models.claude.CLAUDE_HAIKU_4_5,
  },
}

-- ============================================================================
-- Default Configurations
-- ============================================================================

M.defaults = {
  adapter = M.providers.openai_agd.adapter_name,
  model = M.models.qwen.QWEN_3_6_27B,
  -- Default parameters
  temperature = 0.75,
  max_tokens = 20480,
  timeout = 30000,
}

-- ============================================================================
-- Helper Functions
-- ============================================================================

-- Get all GPT models as array
function M.get_gpt_models()
  local result = {}
  for _, model in pairs(M.models.gpt) do
    table.insert(result, model)
  end
  return result
end

-- Get all Claude models as array
function M.get_claude_models()
  local result = {}
  for _, model in pairs(M.models.claude) do
    table.insert(result, model)
  end
  return result
end

-- Get all models as array
function M.get_all_models()
  local result = {}
  for _, models in pairs(M.models) do
    for _, model in pairs(models) do
      table.insert(result, model)
    end
  end
  return result
end

-- Check if model matches any blacklist pattern
function M.matches_blacklist(model_name, additional_patterns)
  local patterns = vim.tbl_extend("force", {}, M.filters.blacklist)
  if additional_patterns then
    vim.list_extend(patterns, additional_patterns)
  end

  for _, pattern in ipairs(patterns) do
    if model_name:match(pattern) then
      return true
    end
  end
  return false
end

-- Check if model contains any filtered keyword
function M.contains_filtered_keyword(model_name, additional_keywords)
  local keywords = vim.tbl_extend("force", {}, M.filters.keywords)
  if additional_keywords then
    vim.list_extend(keywords, additional_keywords)
  end

  for _, keyword in ipairs(keywords) do
    if model_name:find(keyword, 1, true) then
      return true
    end
  end
  return false
end

-- Filter models based on blacklist and keywords
--- @param models string[]
--- @param opts? FilterModelOpts
--- @param provider? string
--- @return string[]
function M.filter_models(models, opts, provider)
  opts = opts or {}
  local filtered = {}

  for _, model in ipairs(models) do
    if
      not M.matches_blacklist(model, opts.additional_blacklist)
      and not M.contains_filtered_keyword(model, opts.additional_keywords)
    then
      -- remap eligible name for agoda proxy (known issue in agoda proxy model name return response)
      local remapprovider = provider and M.provider_model_remap[provider]
      if remapprovider and remapprovider[model] then
        table.insert(filtered, remapprovider[model])
      else
        table.insert(filtered, model)
      end
    end
  end

  return filtered
end

-- M.DEFAULT_COPILOT_MODEL = M.models.others.GROK_FAST_1 -- x0.33
M.DEFAULT_COPILOT_MODEL = env_or("AGD_LATEST", M.models.gpt.GPT_5_MINI)
M.DEFAULT_AGD_MODEL = env_or("AGD_INHOUSE_QWEN", M.models.qwen.QWEN_3_6_27B)

-- ============================================================================
-- Provider Keymap Slot Pattern
-- ============================================================================

--- Fixed slot pattern for keymap generation. Each entry maps a keyboard key to a
--- specific model family + tier + size position within a provider's top_choices.
--- Used by both Avante and CodeCompanion keymap generators.
--- @type {key: string, family: string, tier: TierName, size: ModelSize}[]
M.KEYMAP_SLOT_PATTERN = {
  { key = "f", family = "gpt", tier = "alt", size = "S" },
  { key = "F", family = "gpt", tier = "default", size = "S" },
  { key = "g", family = "grok", tier = "default", size = "S" },
  { key = "G", family = "claude", tier = "default", size = "S" },
  { key = "h", family = "claude", tier = "default", size = "M" },
  { key = "H", family = "claude", tier = "default", size = "L" },
  { key = "c", family = "gpt", tier = "default", size = "M" },
  { key = "C", family = "gpt", tier = "default", size = "L" },
  { key = "x", family = "gpt", tier = "max", size = "M" },
  { key = "X", family = "gpt", tier = "max", size = "L" },
}

--- Build a key→{model,desc} mapping from a provider's top_choices using the
--- fixed KEYMAP_SLOT_PATTERN. Skips slots where the provider has no model.
--- @param provider_name string Key in M.providers (e.g. "openai_agd", "copilot")
--- @return table<string, {model: string, desc: string}>
function M.build_keymap_slots(provider_name)
  local pconfig = M.providers[provider_name]
  if not pconfig then
    return {}
  end
  local tc = pconfig.top_choices
  local result = {}
  for _, slot in ipairs(M.KEYMAP_SLOT_PATTERN) do
    local family = tc[slot.family]
    local tier = family and family[slot.tier]
    local model = tier and tier[slot.size]
    if model then
      result[slot.key] = { model = model, desc = model }
    end
  end
  return result
end

--- Flatten all models from a provider's top_choices into a unique flat array.
--- Iterates all families → tiers → sizes.
--- @param provider_name string
--- @return string[]
function M.get_top_choice_models(provider_name)
  local pconfig = M.providers[provider_name]
  if not pconfig then
    return {}
  end
  local seen, result = {}, {}
  for _, tiers in pairs(pconfig.top_choices) do
    for _, sizes in pairs(tiers) do
      for _, model in pairs(sizes) do
        if not seen[model] then
          seen[model] = true
          table.insert(result, model)
        end
      end
    end
  end
  return result
end

--- Return filtered + remapped model names for the openai_agd Avante provider.
--- By default this uses provider top_choices instead of all models so Avante's
--- selector only shows concrete model IDs, not size aliases like openai_agd/S.
--- @param opts? AgdModelNameOpts
--- @return string[]
function M.get_agd_model_names(opts)
  opts = opts or {}
  local source = opts.source or "all"
  local models = source == "top_choices" and M.get_top_choice_models "openai_agd" or M.get_all_models()

  return M.filter_models(models, {
    additional_blacklist = opts.additional_blacklist,
    additional_keywords = opts.additional_keywords,
  }, M.providers.openai_agd.adapter_name)
end

return M
