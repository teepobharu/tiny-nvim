-- Helper to generate CodeCompanion prompt_library entries
-- from my_ai_constants.providers (AGD + Copilot) with per-family tiered top_choices
--
-- Iterates M.providers → top_choices → family → tier → size to generate entries.
-- Title format: "<Label> <family> <model_stripped> [<tier_abbrev>-<size>]"
-- Alias format: "<adapter>_<model_dashes_to_underscores_dots_removed>"

local ai_constants = require "utils.my_ai_constants"

local M = {}

--- Tier name abbreviations for display in prompt_library titles
local TIER_ABBREV = { default = "def", alt = "alt", max = "max" }

--- Strip model family prefix from model name for display.
--- e.g. ("gpt", "gpt-5.2") → "5.2", ("claude", "claude-sonnet-4-6") → "sonnet-4-6"
--- For "grok", strips "grok-" prefix; model "grok-code-fast-1" → "code-fast-1"
---@param family string Model family name (e.g. "gpt", "claude", "gemini", "grok")
---@param model string Full model name
---@return string Stripped model name
local function strip_family_prefix(family, model)
  return (model:gsub("^" .. family .. "%-", ""))
end

--- Build an alias string from adapter prefix and model name.
--- Replaces "-" with "_" and removes "." entirely.
--- e.g. ("agd", "gpt-5.2") → "agd_gpt_52"
---@param prefix string Alias prefix (e.g. "agd", "copilot")
---@param model string Full model name
---@return string Alias string
local function make_alias(prefix, model)
  return prefix .. "_" .. model:gsub("%.", ""):gsub("%-", "_")
end

--- Build a display title for a prompt_library entry.
--- Format: "<label> <family> <stripped_model> [<tier_abbrev>-<size>]"
--- e.g. "AGD gpt 5-mini [def-S]", "Copilot claude sonnet-4-6 [def-M]"
---@param label string Display label prefix (e.g. "AGD", "Copilot")
---@param family string Model family for prefix stripping
---@param model string Full model name
---@param tier_abbrev string Tier abbreviation (e.g. "def", "alt", "max")
---@param size string Size label (e.g. "S", "M", "L")
---@return string Display title
local function make_title(label, family, model, tier_abbrev, size)
  local display_model = strip_family_prefix(family, model)
  return label .. " " .. family .. " " .. display_model .. " [" .. tier_abbrev .. "-" .. size .. "]"
end

--- Build a single prompt_library entry table.
---@param adapter_name string Adapter name (e.g. "openai_agd", "copilot")
---@param model string Model name to use
---@param alias string Slash command alias
---@param empty_prompt table Empty prompt template
---@return table prompt_library entry
local function make_entry(adapter_name, model, alias, empty_prompt)
  return {
    interaction = "chat",
    opts = {
      adapter = {
        name = adapter_name,
        model = model,
      },
      is_slash_cmd = true,
      alias = alias,
    },
    prompts = empty_prompt,
  }
end

--- Build prompt_library entries from ai_constants.providers.
--- Iterates each provider → top_choices → family → tier → size.
---
--- Returns a table ready to merge into CodeCompanion's prompt_library config.
---@param empty_prompt table The empty prompt template (EMPTY_PROMPT_CODECOMPANION)
---@return table<string, table> prompt_library entries keyed by display title
function M.build(empty_prompt)
  local lib = {}

  for _, pconfig in pairs(ai_constants.providers) do
    local label = pconfig.display_label
    local adapter = pconfig.adapter_name

    for family, tiers in pairs(pconfig.top_choices) do
      for tier_name, sizes in pairs(tiers) do
        local tier_abbrev = TIER_ABBREV[tier_name] or tier_name
        for size, model in pairs(sizes) do
          local title = make_title(label, family, model, tier_abbrev, size)
          local alias = make_alias(adapter, model)
          -- Apply provider-specific remap for the adapter when sending the
          -- model name to the API (AGD gemini models require "-preview").
          local send_model = model
          local remap_table = ai_constants.provider_model_remap and ai_constants.provider_model_remap[adapter]
          if remap_table and remap_table[model] then
            send_model = remap_table[model]
          end
          lib[title] = make_entry(adapter, send_model, alias, empty_prompt)
        end
      end
    end
  end

  return lib
end

--- Build the 12 jellydn/tiny-nvim prompt_library entries with v19 fields.
--- Migrated from lua/plugins/extra/codecompanion.lua (strategy→interaction, short_name→alias).
---@return table<string, table> prompt_library entries keyed by prompt name
function M.build_jellydn_prompts()
  local prompts = require "utils.my_ai_prompts"
  local COPILOT_EXPLAIN = prompts.COPILOT_EXPLAIN
  local COPILOT_REVIEW = prompts.COPILOT_REVIEW
  local COPILOT_REFACTOR = prompts.COPILOT_REFACTOR

  return {
    ["Generate a Commit Message"] = {
      prompts = {
        {
          role = "user",
          content = function()
            return "Write commit message with commitizen convention. Write clear, informative commit messages that explain the 'what' and 'why' behind changes, not just the 'how'."
              .. "\n\n```\n"
              .. vim.fn.system "git diff"
              .. "\n```"
          end,
          opts = {
            contains_code = true,
          },
        },
      },
    },
    ["Explain"] = {
      interaction = "chat",
      description = "Explain how code in a buffer works",
      opts = {
        default_prompt = true,
        modes = { "v" },
        alias = "explain",
        auto_submit = true,
        user_prompt = false,
        stop_context_insertion = true,
      },
      prompts = {
        {
          role = "system",
          content = COPILOT_EXPLAIN,
          opts = { visible = false },
        },
        {
          role = "user",
          content = function(context)
            local code = require("codecompanion.helpers.actions").get_code(context.start_line, context.end_line)
            return "Please explain how the following code works:\n\n```"
              .. context.filetype
              .. "\n"
              .. code
              .. "\n```\n\n"
          end,
          opts = { contains_code = true },
        },
      },
    },
    ["Explain Code"] = {
      interaction = "chat",
      description = "Explain how code works",
      opts = {
        alias = "explain-code",
        auto_submit = false,
        is_slash_cmd = true,
      },
      prompts = {
        {
          role = "system",
          content = COPILOT_EXPLAIN,
          opts = { visible = false },
        },
        {
          role = "user",
          content = [[Please explain how the following code works.]],
        },
      },
    },
    ["Generate a Commit Message for Staged"] = {
      interaction = "chat",
      description = "Generate a commit message for staged change",
      opts = {
        alias = "staged-commit-jelly",
        auto_submit = true,
        is_slash_cmd = true,
      },
      prompts = {
        {
          role = "user",
          content = function()
            return "Write commit message for the change with commitizen convention. Write clear, informative commit messages that explain the 'what' and 'why' behind changes, not just the 'how'."
              .. "\n\n```\n"
              .. vim.fn.system "git diff --staged"
              .. "\n```"
          end,
          opts = { contains_code = true },
        },
      },
    },
    ["Inline Document"] = {
      interaction = "inline",
      description = "Add documentation for code.",
      opts = {
        modes = { "v" },
        alias = "inline-doc",
        auto_submit = true,
        user_prompt = false,
        stop_context_insertion = true,
      },
      prompts = {
        {
          role = "user",
          content = function(context)
            local code = require("codecompanion.helpers.actions").get_code(context.start_line, context.end_line)
            return "Please provide documentation in comment code for the following code and suggest to have better naming to improve readability.\n\n```"
              .. context.filetype
              .. "\n"
              .. code
              .. "\n```\n\n"
          end,
          opts = { contains_code = true },
        },
      },
    },
    ["Document"] = {
      interaction = "chat",
      description = "Write documentation for code.",
      opts = {
        modes = { "v" },
        alias = "doc",
        auto_submit = true,
        user_prompt = false,
        stop_context_insertion = true,
      },
      prompts = {
        {
          role = "user",
          content = function(context)
            local code = require("codecompanion.helpers.actions").get_code(context.start_line, context.end_line)
            return "Please brief how it works and provide documentation in comment code for the following code. Also suggest to have better naming to improve readability.\n\n```"
              .. context.filetype
              .. "\n"
              .. code
              .. "\n```\n\n"
          end,
          opts = { contains_code = true },
        },
      },
    },
    ["Review"] = {
      interaction = "chat",
      description = "Review the provided code snippet.",
      opts = {
        modes = { "v" },
        alias = "review",
        auto_submit = true,
        user_prompt = false,
        stop_context_insertion = true,
      },
      prompts = {
        {
          role = "system",
          content = COPILOT_REVIEW,
          opts = { visible = false },
        },
        {
          role = "user",
          content = function(context)
            local code = require("codecompanion.helpers.actions").get_code(context.start_line, context.end_line)
            return "Please review the following code and provide suggestions for improvement then refactor the following code to improve its clarity and readability:\n\n```"
              .. context.filetype
              .. "\n"
              .. code
              .. "\n```\n\n"
          end,
          opts = { contains_code = true },
        },
      },
    },
    ["Review Code"] = {
      interaction = "chat",
      description = "Review code and provide suggestions for improvement.",
      opts = {
        alias = "review-code",
        auto_submit = false,
        is_slash_cmd = true,
      },
      prompts = {
        {
          role = "system",
          content = COPILOT_REVIEW,
          opts = { visible = false },
        },
        {
          role = "user",
          content = "Please review the following code and provide suggestions for improvement then refactor the following code to improve its clarity and readability.",
        },
      },
    },
    ["Refactor"] = {
      interaction = "inline",
      description = "Refactor the provided code snippet.",
      opts = {
        modes = { "v" },
        alias = "refactor",
        auto_submit = true,
        user_prompt = false,
        stop_context_insertion = true,
      },
      prompts = {
        {
          role = "system",
          content = COPILOT_REFACTOR,
          opts = { visible = false },
        },
        {
          role = "user",
          content = function(context)
            local code = require("codecompanion.helpers.actions").get_code(context.start_line, context.end_line)
            return "Please refactor the following code to improve its clarity and readability:\n\n```"
              .. context.filetype
              .. "\n"
              .. code
              .. "\n```\n\n"
          end,
          opts = { contains_code = true },
        },
      },
    },
    ["Refactor Code"] = {
      interaction = "chat",
      description = "Refactor the provided code snippet.",
      opts = {
        alias = "refactor-code",
        auto_submit = false,
        is_slash_cmd = true,
      },
      prompts = {
        {
          role = "system",
          content = COPILOT_REFACTOR,
          opts = { visible = false },
        },
        {
          role = "user",
          content = "Please refactor the following code to improve its clarity and readability.",
        },
      },
    },
    ["Naming"] = {
      interaction = "inline",
      description = "Give betting naming for the provided code snippet.",
      opts = {
        modes = { "v" },
        alias = "naming",
        auto_submit = true,
        user_prompt = false,
        stop_context_insertion = true,
      },
      prompts = {
        {
          role = "user",
          content = function(context)
            local code = require("codecompanion.helpers.actions").get_code(context.start_line, context.end_line)
            return "Please provide better names for the following variables and functions:\n\n```"
              .. context.filetype
              .. "\n"
              .. code
              .. "\n```\n\n"
          end,
          opts = { contains_code = true },
        },
      },
    },
    ["Better Naming"] = {
      interaction = "chat",
      description = "Give betting naming for the provided code snippet.",
      opts = {
        alias = "better-naming",
        auto_submit = false,
        is_slash_cmd = true,
      },
      prompts = {
        {
          role = "user",
          content = "Please provide better names for the following variables and functions.",
        },
      },
    },
  }
end

return M
