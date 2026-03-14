-- Shared AI constants for Avante, CodeCompanion, and other AI tools
-- Centralized model names, endpoints, and configurations to avoid duplication
local M = {}

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
    GPT_5_NANO = "gpt-5-nano",
    GPT_5_MINI = "gpt-5-mini",
    GPT_5_1 = "gpt-5.1",
    GPT_5_2 = "gpt-5.2",
    GPT_5_3_CODEX = "gpt-5.3-codex",
    GPT_5_4 = "gpt-5.4",
    GPT_5_1_CODEX_MAX = "gpt-5.1-codex-max",
    GPT_5_1_CODEX_MINI = "gpt-5.1-codex-mini",
    GPT_4O = "gpt-4o",
    GPT_4O_MINI = "gpt-4o-mini",
    GPT_3_5_TURBO = "gpt-3.5-turbo",
  },

  -- Claude models
  claude = {
    CLAUDE_3_5_HAIKU = "claude-3-5-haiku",
    CLAUDE_3_7_SONNET = "claude-3-7-sonnet",
    CLAUDE_SONNET_4 = "claude-sonnet-4",
    CLAUDE_HAIKU_4_5 = "claude-haiku-4-5",
    CLAUDE_SONNET_4_5 = "claude-sonnet-4-5",
    CLAUDE_SONNET_4_6 = "claude-sonnet-4-6",
    CLAUDE_OPUS_4_5 = "claude-opus-4-5",
    CLAUDE_OPUS_4_6 = "claude-opus-4-6",
  },

  gemini = {
    GEMINI_3_1_PRO = "gemini-3.1-pro",
    GEMINI_3_1_FLASH_LITE = "gemini-3.1-flash-lite",
    GEMINI_3_PRO = "gemini-3-pro",
    GEMINI_3_FLASH = "gemini-3-flash",
    GEMINI_2_5_PRO = "gemini-2.5-pro",
    GEMINI_2_5_FLASH = "gemini-2.5-flash",
    GEMINI_2_5_FLASH_LITE = "gemini-2.5-flash-lite",
  },

  -- O-series reasoning models
  o_series = {
    O3 = "o3",
    O3_MINI = "o3-mini",
    O4_MINI = "o4-mini",
  },

  -- DeepSeek models
  deepseek = {
    DEEPSEEK = "deepseek",
    DEEPSEEK_R1 = "deepseek-r1-0528-maas",
  },

  -- Qwen models (AGD proxy IDs)
  qwen = {
    QWQ_32B = "qwq-32b",
    QWEN_3_5_27B = "qwen-3.5-27b",
  },

  others = {
    GROK_FAST_1 = "grok-code-fast-1",
  },
}

M.providers = {
  OPENAI_AGD = "openai_agd",
}

M.provider_model_remap = {
  [M.providers.OPENAI_AGD] = {
    -- Gemini models (3.x/3.1.x REQUIRE -preview suffix on AGD proxy chat endpoint)
    [M.models.gemini.GEMINI_3_1_PRO] = M.models.gemini.GEMINI_3_1_PRO .. "-preview",
    -- [M.models.gemini.GEMINI_3_PRO] = M.models.gemini.GEMINI_3_PRO .. "-preview", -- works on hurl but get vertex error on codecompanion : body = "{\"error\":{\"message\":\"litellm.NotFoundError: Vertex_ai_betaException - b'{\\\\n  \\\"error\\\": {\\\\n    \\\"code\\\": 404,\\\\n    \\\"message\\\": \\\"Publisher Model `projects/llmgatewayprod-17939/locations/us-central1/publishers/google/models/gemini-3-pro-preview` was not found or your project does not have access to it.
    [M.models.gemini.GEMINI_3_1_FLASH_LITE] = M.models.gemini.GEMINI_3_1_FLASH_LITE .. "-preview",
    [M.models.gemini.GEMINI_3_FLASH] = M.models.gemini.GEMINI_3_FLASH .. "-preview",
  }
}

-- ============================================================================
-- Agoda Endpoints
-- ============================================================================

M.endpoints = {
  agoda = {
    GENAI_GATEWAY_CLAUDE = "https://genai-gateway.agoda.is/claude",
    OPENAI_PROXY = "http://openai-proxy.agoda.is/v1",
    OPENAI_PROXY_MODELS = "http://openai-proxy.agoda.is/v1/models",
    OPENAI_PROXY_CHAT = "http://openai-proxy.agoda.is/v1/chat/completions",
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
    M.models.gemini.GEMINI_3_PRO
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

  -- Heavy models (for complex operations)
  heavy = {
    M.models.claude.CLAUDE_SONNET_4_6,
    M.models.claude.CLAUDE_SONNET_4_5,
    M.models.claude.CLAUDE_SONNET_4,
    M.models.claude.CLAUDE_OPUS_4_6,
    M.models.claude.CLAUDE_OPUS_4_5,
  },

  -- Codex models (for code-specific operations)
  codex = {
    M.models.gpt.GPT_5_3_CODEX,
    M.models.gpt.GPT_5_1_CODEX_MAX,
    M.models.gpt.GPT_5_1_CODEX_MINI,
  },

  -- Default priority order for CodeCompanion
  agd_default = {
    M.models.gpt.GPT_5_4,
    M.models.gpt.GPT_5_2,
    M.models.gpt.GPT_5_1,
    M.models.gpt.GPT_5_MINI,
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
  adapter = "copilot",
  model = M.models.gpt.GPT_5_MINI,

  -- Default parameters
  temperature = 0.75,
  max_tokens = 20480,
  timeout = 30000,

  -- AGD specific
  agd = {
    temperature = 0,
    max_completion_tokens = 4096,
  },
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
function M.filter_models(models, opts, provider)
  opts = opts or {}
  local filtered = {}

  for _, model in ipairs(models) do
    if
      not M.matches_blacklist(model, opts.additional_blacklist)
      and not M.contains_filtered_keyword(model, opts.additional_keywords)
    then
      -- remap eligible name for agoda proxy (known issue in agoda proxy model name return response)
      local remapprovider = M.provider_model_remap[provider]
      if provider and remapprovider[model] then
        table.insert(filtered, remapprovider[model])
      else
        table.insert(filtered, model)
      end
    end
  end

  return filtered
end

-- M.DEFAULT_COPILOT_MODEL = M.models.others.GROK_FAST_1 -- x0.33
M.DEFAULT_COPILOT_MODEL = M.models.gpt.GPT_5_MINI

return M
