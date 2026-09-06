-- Requires normal nvimwt3a init because Lazy supplies the registered mappings
-- and CodeCompanion runtime path. Run with:
-- NVIM_APPNAME=nvimwt3a nvim --headless -c 'luafile tests/test_main_worktree_carryover.lua' +qa

local constants = require "utils.my_ai_constants"

assert(
  constants.providers.openai_agd.top_choices.gpt.default.L == constants.models.gpt.GPT_5_6_SOL,
  "GPT-5.6 Sol should be the default flagship"
)
assert(
  constants.providers.openai_agd.top_choices.gpt.alt.L == constants.models.gpt.GPT_5_5,
  "GPT-5.5 should remain the previous-flagship fallback"
)

local adapter_name = constants.providers.openai_responses_agd.adapter_name
local adapter_factory = require("utils.my_codecompanion_utils").get_agoda_responses_adapters()[adapter_name]
local adapter = adapter_factory()
for _, model in ipairs {
  constants.models.gpt.GPT_5_6_SOL,
  constants.models.gpt.GPT_5_6_TERRA,
  constants.models.gpt.GPT_5_6_LUNA,
  constants.models.gpt.GPT_5_5,
} do
  assert(adapter.schema.model.choices[model], "missing Responses model choice " .. model)
end
assert(
  adapter.schema.model.choices[constants.models.gpt.GPT_5_5].opts.has_vision == false,
  "GPT-5.5 must remain marked non-vision"
)

local claude_shortcut = vim.fn.maparg(" CE", "n", false, true)
assert(claude_shortcut.desc == "Toggle Claude GPT 5.5", "Claude GPT shortcut label is stale")

local actions_shortcut = vim.fn.maparg(" Aa", "n", false, true)
assert(actions_shortcut.desc == "Code Companion - Actions", "CodeCompanion action shortcut is missing")

local agd_picker = vim.fn.maparg(" ASm", "n", false, true)
assert(agd_picker.desc == "CC Chat: Pick AGD Model (Dynamic)", "AGD model picker shortcut is missing")

for _, lhs in ipairs { " ASC", " ASX" } do
  local shortcut = vim.fn.maparg(lhs, "n", false, true)
  assert(shortcut.desc == "CC Switch AGD: gpt-5.6-sol", "GPT-5.6 Sol shortcut is stale: " .. lhs)
end

local open_external = require "utils.open_external"
local codex
for _, app in ipairs(open_external.apps) do
  if app.name == "Codex" then
    codex = app
    break
  end
end
assert(codex, "Codex opener is missing")
local command = codex.command_string "/tmp/demo file.lua"
assert(command:match "^open ", "Codex copy command must be executable shell text")
assert(command:find("codex://new", 1, true), "Codex copy command must use a deep link")
assert(command:find("path=/tmp", 1, true), "Codex deep link must include the workspace")
assert(command:find "demo%%20file%.lua", "Codex deep-link prompt must URI-encode the file path")

local codex_detected = false
for _, app in ipairs(open_external.detect "/tmp/demo file.lua") do
  if app.name == "Codex" then
    codex_detected = true
    break
  end
end
assert(codex_detected, "Codex must be detected through ChatGPT.app or Codex.app")

print "main worktree carryover tests: ok"
