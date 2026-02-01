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
    GPT_5_MINI = "gpt-5-mini",
    GPT_5_1 = "gpt-5.1",
    GPT_5_2 = "gpt-5.2",
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
    CLAUDE_HAIKU_4_5 = "claude-haiku-4-5",
    CLAUDE_SONNET_4_5 = "claude-sonnet-4-5",
    CLAUDE_OPUS_4_5 = "claude-opus-4-5",
  },

  -- Gemini models
  gemini = {
    GEMINI_3_PRO_PREVIEW = "gemini-3-pro-preview",
  },

  -- DeepSeek models
  deepseek = {
    DEEPSEEK_R1 = "deepseek-r1",
    DEEPSEEK_R1_DISTILL = "deepseek-r1-distill",
  },
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
    "^claude%-", -- Starts with "claude-" (for AGD proxy that doesn't support Claude)
    "^ft%-", -- Fine-tuned models
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

M.static_models = {
  -- Fast models (for quick operations)
  fast = {
    M.models.gpt.GPT_4_1_MINI,
    M.models.gpt.GPT_5_MINI,
  },

  -- Heavy models (for complex operations)
  heavy = {
    M.models.claude.CLAUDE_SONNET_4_5,
    M.models.claude.CLAUDE_OPUS_4_5,
  },

  -- Codex models (for code-specific operations)
  codex = {
    M.models.gpt.GPT_5_1_CODEX_MAX,
    M.models.gpt.GPT_5_1_CODEX_MINI,
  },

  -- Default priority order for CodeCompanion
  codecompanion_default = {
    M.models.gpt.GPT_5_2,
    M.models.gpt.GPT_4O,
    M.models.gpt.GPT_4O_MINI,
    M.models.gpt.GPT_3_5_TURBO,
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
function M.filter_models(models, opts)
  opts = opts or {}
  local filtered = {}

  for _, model in ipairs(models) do
    if not M.matches_blacklist(model, opts.additional_blacklist) and not M.contains_filtered_keyword(model, opts.additional_keywords) then
      table.insert(filtered, model)
    end
  end

  return filtered
end

return M
