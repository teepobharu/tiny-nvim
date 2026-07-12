-- Shared defaults for AI plugins (CodeCompanion, Avante, etc.)
-- Single place to pick default provider/adapter + preferred model by size.

local AI = require "utils.my_ai_constants"

local M = {}

--- Default provider key (must match AI.providers keys, e.g. "openai_agd"|"copilot")
--- Override via `vim.g.ai_default_provider`.
M.DEFAULT_PROVIDER = vim.g.ai_default_provider or AI.defaults.adapter

--- Whether Copilot-backed providers/keymaps should be enabled.
--- When false, we avoid registering `copilot` provider configs in Avante and avoid Copilot model pickers.
M.ENABLE_COPILOT = vim.g.ai_enable_copilot == true

--- Default CodeCompanion adapter id (must be a string)
--- For built-in providers, this equals DEFAULT_PROVIDER.
M.DEFAULT_ADAPTER = (AI.providers[M.DEFAULT_PROVIDER] and AI.providers[M.DEFAULT_PROVIDER].adapter_name)
  or M.DEFAULT_PROVIDER

--- Preferred tier choice for defaults.
--- Override via `vim.g.ai_default_family`, `vim.g.ai_default_tier`, `vim.g.ai_model_size_preference`.
M.PREFERRED = {
  family = vim.g.ai_default_family or "inhouse",
  tier = vim.g.ai_default_tier or "default",
  size = vim.g.ai_model_size_preference or "S", -- "S"|"M"|"L"
}

--- Pick a model from provider top_choices using family/tier/size preferences.
--- Falls back to AI.defaults.model.
--- @param opts? {provider?: string, family?: string, tier?: string, size?: "S"|"M"|"L"}
--- @return string
function M.preferred_model(opts)
  opts = opts or {}
  local provider = opts.provider or M.DEFAULT_PROVIDER
  local family = opts.family or M.PREFERRED.family
  local tier = opts.tier or M.PREFERRED.tier
  local size = opts.size or M.PREFERRED.size

  local p = AI.providers[provider]
  local model = p
    and p.top_choices
    and p.top_choices[family]
    and p.top_choices[family][tier]
    and p.top_choices[family][tier][size]
  return model or AI.defaults.model
end

--- Convenience: the first "fast" model.
--- @return string
function M.fast_model()
  return (AI.static_models and AI.static_models.fast and AI.static_models.fast[1]) or AI.defaults.model
end

return M
