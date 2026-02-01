-- CodeCompanion utility functions for Agoda-specific adapter configurations
-- Similar pattern to my_avante_utils.lua for consistency
-- TODO: extract common model name, url, env keys to be in common place to be reused in both avante, codecomponion, others 
local M = {}

-- Get Agoda-specific adapter configurations
-- These adapters use internal Agoda endpoints and are separated from the main config
-- for easier maintenance and to optionally exclude them from adapter selection
function M.get_agoda_adapters()
  return {
    -- Claude via Agoda GenAI Gateway
    claude_agd = function()
      return require("codecompanion.adapters").extend("anthropic", {
        env = {
          api_key = "ANTHROPIC_API_KEY",
        },
        url = "https://genai-gateway.agoda.is/claude",
        schema = {
          model = {
            default = "claude-3-7-sonnet",
            choices = {
              "claude-3-5-haiku",
              "claude-3-7-sonnet",
              "claude-haiku-4-5",
              "claude-opus-4-5",
            },
          },
        },
      })
    end,

    -- Vertex Claude via Agoda OpenAI Proxy (OpenAI-compatible endpoint)
    vertex_claude_agd = function()
      return require("codecompanion.adapters").extend("openai", {
        env = {
          api_key = "OPENAI_API_KEY",
        },
        url = "http://openai-proxy.agoda.is/v1",
        schema = {
          model = {
            default = "claude-3-7-sonnet",
            choices = {
              "claude-3-5-haiku",
              "claude-3-7-sonnet",
              "claude-haiku-4-5",
              "claude-opus-4-5",
            },
          },
          temperature = {
            default = 0.75,
          },
          max_tokens = {
            default = 20480,
          },
        },
      })
    end,

    -- OpenAI/GPT via Agoda OpenAI Proxy
    openai_agd = function()
      return require("codecompanion.adapters").extend("openai", {
        env = {
          api_key = "OPENAI_API_KEY",
        },
        url = "http://openai-proxy.agoda.is/v1",
        schema = {
          model = {
            default = "gpt-5.2",
            choices = {
              "gpt-4.1",
              "gpt-4.1-mini",
              "gpt-5-mini",
              "gpt-5.1",
              "gpt-5.2",
              "gemini-3-pro-preview",
            },
          },
          temperature = {
            default = 0,
          },
          max_tokens = {
            default = 4096,
          },
        },
      })
    end,
  }
end

-- Get list of Agoda adapter names (for filtering)
function M.get_agoda_adapter_names()
  local adapters = M.get_agoda_adapters()
  local names = {}
  for name, _ in pairs(adapters) do
    table.insert(names, name)
  end
  return names
end

-- Remove Agoda adapters from an adapters table
-- Useful for creating a "lean" adapter list for faster model selection
function M.remove_agoda_adapters(adapters)
  local result = vim.deepcopy(adapters)
  local agoda_names = M.get_agoda_adapter_names()

  for _, name in ipairs(agoda_names) do
    result[name] = nil
  end

  return result
end

-- Check if current adapter is an Agoda adapter
function M.is_agoda_adapter(adapter_name)
  local agoda_names = M.get_agoda_adapter_names()
  for _, name in ipairs(agoda_names) do
    if name == adapter_name then
      return true
    end
  end
  return false
end

-- Merge Agoda adapters with existing adapters configuration
-- Usage in codecompanion config:
--   adapters = {
--     http = vim.tbl_extend("force",
--       require("utils.my_codecompanion_utils").merge_agoda_adapters(),
--       { -- your other custom adapters }
--     )
--   }
function M.merge_agoda_adapters(base_adapters)
  base_adapters = base_adapters or {}
  local agoda_adapters = M.get_agoda_adapters()
  return vim.tbl_extend("force", base_adapters, agoda_adapters)
end

return M
