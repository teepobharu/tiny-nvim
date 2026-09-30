vim.notify = function() end

local adapters = require "codecompanion.adapters"
local schema = require "codecompanion.schema"
local constants = require "utils.my_ai_constants"
local thinking = require "utils.my_codecompanion_thinking"
local adapter_utils = require "utils.my_codecompanion_utils"
local actions = require "utils.my_codecompanion_actions"

local function eq(expected, actual, label)
  assert(vim.deep_equal(expected, actual), ("%s: expected %s, got %s"):format(
    label,
    vim.inspect(expected),
    vim.inspect(actual)
  ))
end

local function flat_adapter(model)
  return {
    name = "openai_agd",
    model = { name = model },
    parameters = { model = model },
    schema = {
      model = { default = model, mapping = "parameters" },
      reasoning_effort = { mapping = "parameters", type = "string", optional = true },
      temperature = { mapping = "parameters", type = "number", optional = true },
      top_p = { mapping = "parameters", type = "number", optional = true },
    },
  }
end

local function flat_responses_adapter(model)
  return {
    name = "openai_responses_agd",
    model = { name = model },
    parameters = { model = model },
    schema = {
      model = { default = model, mapping = "parameters" },
      ["reasoning.effort"] = { mapping = "parameters", type = "string", optional = true },
      temperature = { mapping = "parameters", type = "number", optional = true },
      top_p = { mapping = "parameters", type = "number", optional = true },
    },
  }
end

local function flat_chat(model)
  local chat = {
    adapter = flat_adapter(model),
    settings = { model = model, temperature = 0.42, top_p = 0.8 },
    callbacks = {},
  }
  function chat:add_callback(name, callback)
    self.callbacks[name] = callback
  end
  function chat:change_model(args)
    local next_model = args.model
    self.adapter.model.name = next_model
    self.adapter.parameters.model = next_model
    self.adapter.schema.model.default = next_model
    self.settings = { model = next_model, temperature = 0.42, top_p = 0.8 }
    return self
  end
  return chat
end

do
  local ok, count = thinking.ingest_capability_metadata({
    models = {
      {
        name = "gpt-5.4",
        maker = "OPENAI",
        isChatModel = true,
        thinkingCapability = "None",
        features = { { name = "Thinking" } },
        supported_endpoints = { "/v1/chat/completions" },
      },
      {
        name = "claude-sonnet-5",
        maker = "ANTHROPIC",
        isChatModel = true,
        thinkingCapability = "Optional",
        features = {},
        supported_endpoints = { "/v1/chat/completions" },
      },
      {
        name = "deepseek-r1-0528-maas",
        maker = "DEEPSEEK",
        isChatModel = true,
        thinkingCapability = "Obligatory",
        features = {},
        supported_endpoints = { "/v1/chat/completions" },
      },
      {
        name = "qwen-3.8-27b",
        maker = "ALIBABA",
        isChatModel = true,
        thinkingCapability = "Optional",
        features = { { name = "Thinking" } },
        supported_endpoints = { "/v1/chat/completions" },
      },
      {
        name = "gpt-5.99-future",
        maker = "OPENAI",
        isChatModel = true,
        thinkingCapability = "None",
        features = {},
        supported_endpoints = { "/v1/chat/completions" },
      },
      {
        name = "future-enabled-enum",
        maker = "FUTURE_VENDOR",
        isChatModel = true,
        thinkingCapability = "Enabled",
        features = {},
        supported_endpoints = { "/v1/chat/completions" },
      },
    },
  })
  eq(true, ok, "metadata accepted")
  eq(6, count, "metadata count")
  eq("supported", thinking.resolve_capability(flat_adapter("gpt-5.4"), "gpt-5.4").status, "GPT feature hint")
  eq("required", thinking.resolve_capability(flat_adapter("deepseek-r1-0528-maas")).mode, "Obligatory normalized")
  local qwen = thinking.resolve_capability(flat_adapter("qwen-3.8-27b"))
  eq("supported", qwen.status, "Qwen transport override")
  eq(true, qwen.enforce_levels, "Qwen transport rule is exact")
  eq("unknown", thinking.resolve_capability(flat_adapter("future-model")).status, "future model remains controllable")
  local future_gpt = thinking.resolve_capability(flat_adapter("gpt-5.99-future"))
  eq("unsupported", future_gpt.status, "metadata remains advisory for a future GPT")
  eq("non_default", future_gpt.conflicts.temperature, "GPT transport normalization survives stale metadata")
  eq("supported", thinking.resolve_capability(flat_adapter("future-enabled-enum")).status, "future enum is advisory")

  local stale_adapter = flat_adapter("gpt-5.4")
  stale_adapter.model.opts = { can_reason = true }
  local unrelated = thinking.resolve_capability(stale_adapter, "unrelated-future-model")
  eq("unknown", unrelated.status, "model hint is identity scoped")
end

for _, model in ipairs({
  "o3",
  "gpt-5.4",
  "gemini-3.5-flash",
  "future-model",
}) do
  local chat = flat_chat(model)
  eq(true, thinking.set("vendor-new-level", { chat = chat }), model .. " set")
  eq("vendor-new-level", chat.settings.reasoning_effort, model .. " free-form effort")
  eq(0.42, chat.settings.temperature, model .. " temperature preserved")
  eq(0.8, chat.settings.top_p, model .. " top_p preserved")
end

do
  local capability = thinking.resolve_capability(flat_adapter("qwen-3.8-27b"))
  eq({ "none", "low", "medium", "xhigh" }, capability.levels, "Qwen Chat exposes verified reasoning levels")

  local chat = flat_chat("qwen-3.8-27b")
  eq(true, thinking.set("none", { chat = chat }), "Qwen Chat accepts none")
  eq("none", chat.settings.reasoning_effort, "accepted Qwen none is stored")
  eq(true, thinking.set("xhigh", { chat = chat }), "Qwen Chat accepts xhigh")
  eq("xhigh", chat.settings.reasoning_effort, "accepted Qwen effort is stored")
  eq(false, thinking.set("high", { chat = chat }), "Qwen Chat rejects high")
  eq(false, thinking.set("max", { chat = chat }), "Qwen Chat rejects max")
end

for _, model in ipairs({ "grok-4.3", "grok-4.5", "grok-4.6" }) do
  local capability = thinking.resolve_capability(flat_adapter(model))
  eq(true, capability.enforce_levels, model .. " Chat rule is exact")
  eq({ "low", "medium", "high", "xhigh" }, capability.levels, model .. " Chat exposes verified reasoning levels")

  local chat = flat_chat(model)
  eq(true, thinking.set("xhigh", { chat = chat }), model .. " Chat accepts xhigh")
  eq(false, thinking.set("max", { chat = chat }), model .. " Chat rejects max")
end

for _, model in ipairs({ "kimi-k2.6", "kimi-k2.7-code" }) do
  local capability = thinking.resolve_capability(flat_adapter(model))
  eq(true, capability.enforce_levels, model .. " Chat rule is exact")
  eq({ "low", "medium", "high", "xhigh", "max" }, capability.levels, model .. " Chat exposes verified reasoning levels")

  local chat = flat_chat(model)
  eq(true, thinking.set("max", { chat = chat }), model .. " Chat accepts max")
end

do
  local capability = thinking.resolve_capability(flat_adapter("gpt-5.6-luna"))
  eq(true, capability.enforce_levels, "GPT-5.6 chat rule is exact")
  eq({ "none", "low", "medium", "high", "xhigh" }, capability.levels, "GPT-5.6 chat levels")

  local chat = flat_chat("gpt-5.6-luna")
  eq(false, thinking.set("max", { chat = chat }), "GPT-5.6 chat rejects max")
  eq(nil, chat.settings.reasoning_effort, "rejected GPT-5.6 effort is not stored")
  eq(false, thinking.set("minimal", { chat = chat }), "GPT-5.6 chat rejects minimal")
  eq(true, thinking.set("xhigh", { chat = chat }), "GPT-5.6 chat accepts xhigh")
  eq("xhigh", chat.settings.reasoning_effort, "accepted GPT-5.6 effort is stored")
end

do
  local chat_cases = {
    { "gpt-6-sol", { "none", "low", "medium", "high", "xhigh" }, "minimal", "optional" },
    { "gpt-6-luna", { "none", "low", "medium", "high", "xhigh" }, "max", "optional" },
    { "grok-4.7", { "minimal", "low", "medium", "high", "xhigh" }, "none", "required" },
    { "gemini-3.7-flash", { "low", "medium", "high" }, "none", "required" },
    { "gemini-3.8-flash", { "low", "medium", "high" }, "xhigh", "required" },
    { "claude-sonnet-5", { "none", "minimal", "low", "medium", "high", "xhigh", "max" }, "vendor-new-level", "optional" },
    { "claude-sonnet-5-5", { "none", "minimal", "low", "medium", "high", "xhigh", "max" }, "vendor-new-level", "required" },
  }
  for _, case in ipairs(chat_cases) do
    local model, levels, unsupported, mode = unpack(case)
    local capability = thinking.resolve_capability(flat_adapter(model))
    eq(levels, capability.levels, model .. " Chat exposes its verified efforts")
    eq(mode, capability.mode, model .. " Chat mode")
    eq(true, capability.enforce_levels, model .. " Chat effort rule is strict")
    eq(false, thinking.validate_effort(flat_adapter(model), unsupported, model), model .. " Chat rejects unproven effort")
  end

  for _, model in ipairs({ "gpt-6-sol", "gpt-6-luna" }) do
    eq("none", thinking.tool_required_effort(flat_adapter(model), model), model .. " tool fallback")
    local tool_chat = flat_chat(model .. "-high")
    tool_chat.settings.reasoning_effort = "high"
    tool_chat.tool_registry = { schemas = { ["<tool>read_file</tool>"] = {} } }
    local conflict = thinking.tool_reasoning_conflict(tool_chat)
    eq(model, conflict.model, model .. " exact Chat tool conflict")
    eq("none", conflict.required_effort, model .. " Chat tool conflict requires none")
  end

  for _, model in ipairs({ "grok-4.7", "gemini-3.7-flash", "gemini-3.8-flash", "claude-sonnet-5", "claude-sonnet-5-5" }) do
    local tool_chat = flat_chat(model)
    tool_chat.settings.reasoning_effort = "high"
    tool_chat.tool_registry = { schemas = { ["<tool>read_file</tool>"] = {} } }
    eq(nil, thinking.tool_reasoning_conflict(tool_chat), model .. " does not inherit the GPT-6 Chat tool restriction")
  end

  local responses_cases = {
    { "gpt-6-sol", { "none", "low", "medium", "high", "xhigh", "max" }, "minimal" },
    { "gpt-6-luna", { "none", "low", "medium", "high", "xhigh", "max" }, "minimal" },
    { "grok-4.7", { "minimal", "low", "medium", "high", "xhigh" }, "max" },
  }
  for _, case in ipairs(responses_cases) do
    local model, levels, unsupported = unpack(case)
    local capability = thinking.resolve_capability(flat_responses_adapter(model))
    eq(levels, capability.levels, model .. " Responses exposes its verified efforts")
    eq(true, capability.enforce_levels, model .. " Responses effort rule is strict")
    eq(false, thinking.validate_effort(flat_responses_adapter(model), unsupported, model), model .. " Responses rejects unproven effort")
  end
end

do
  eq(97, #thinking.model_selector_presets("openai_agd"), "Chat selector includes route-proven and requested advisory presets")
  eq(29, #thinking.model_selector_presets("openai_responses_agd"), "Responses selector includes GPT-6 and Grok route-proven presets")

  local top_choices = constants.get_top_choice_models(constants.providers.openai_agd.adapter_name)
  for _, model in ipairs({
    "gpt-6-sol",
    "gpt-6-luna",
    "gpt-6.1-sol",
    "gpt-6.1-luna",
    "grok-4.7",
    "gemini-3.7-flash",
    "gemini-3.8-flash",
    "claude-sonnet-5",
    "claude-sonnet-5-5",
    "claude-opus-5",
    "claude-opus-5-5",
  }) do
    eq(true, vim.tbl_contains(top_choices, model), model .. " is in the shared selectable model list")
  end

  local chat_preset = thinking.resolve_model_selector_preset("openai_agd", "gpt-5.6-luna-xhigh")
  eq("gpt-5.6-luna", chat_preset.model, "Chat selector alias resolves canonical Luna")
  eq("xhigh", chat_preset.effort, "Chat selector alias resolves effort")
  eq(nil, thinking.resolve_model_selector_preset("openai_agd", "gpt-5.6-luna-max"), "Chat does not advertise max alias")

  for _, model in ipairs({ "gpt-5.6-sol", "gpt-5.6-terra", "gpt-5.6-luna" }) do
    local no_reasoning_preset = thinking.resolve_model_selector_preset("openai_agd", model .. "-none")
    eq(model, no_reasoning_preset.model, model .. " Chat selector resolves canonical none")
    eq("none", no_reasoning_preset.effort, model .. " Chat selector exposes explicit none")
  end

  local qwen_preset = thinking.resolve_model_selector_preset("openai_agd", "qwen-3.8-27b-xhigh")
  eq("qwen-3.8-27b", qwen_preset.model, "Chat selector alias resolves canonical Qwen")
  eq("xhigh", qwen_preset.effort, "Qwen selector alias resolves effort")
  eq(nil, thinking.resolve_model_selector_preset("openai_agd", "qwen-3.8-27b-high"), "Chat omits unsupported Qwen high alias")
  eq(nil, thinking.resolve_model_selector_preset("openai_agd", "qwen-3.8-27b-max"), "Chat omits unsupported Qwen max alias")

  local grok_preset = thinking.resolve_model_selector_preset("openai_agd", "grok-4.6-xhigh")
  eq("grok-4.6", grok_preset.model, "Chat selector alias resolves canonical Grok")
  eq("xhigh", grok_preset.effort, "Grok selector alias resolves effort")
  eq(nil, thinking.resolve_model_selector_preset("openai_agd", "grok-4.6-max"), "Chat omits unsupported Grok max alias")

  local kimi_preset = thinking.resolve_model_selector_preset("openai_agd", "kimi-k2.7-code-max")
  eq("kimi-k2.7-code", kimi_preset.model, "Chat selector alias resolves canonical Kimi")
  eq("max", kimi_preset.effort, "Kimi selector alias resolves max")

  local claude_preset = thinking.resolve_model_selector_preset("openai_agd", "claude-sonnet-5-high")
  eq("claude-sonnet-5", claude_preset.model, "Chat selector alias resolves canonical Claude")
  eq("high", claude_preset.effort, "Chat selector exposes Claude's verified high preset")
  eq("max", thinking.resolve_model_selector_preset("openai_agd", "claude-sonnet-5-max").effort, "Chat selector exposes Claude 5 max")
  eq("max", thinking.resolve_model_selector_preset("openai_agd", "claude-sonnet-5-5-max").effort, "Chat selector exposes Claude 5.5 max")

  local gpt6_preset = thinking.resolve_model_selector_preset("openai_agd", "gpt-6-luna-medium")
  eq("gpt-6-luna", gpt6_preset.model, "Chat selector resolves canonical GPT-6 Luna")
  eq("medium", gpt6_preset.effort, "Chat selector exposes GPT-6 medium")
  eq(nil, thinking.resolve_model_selector_preset("openai_agd", "gpt-6-luna-max"), "Chat omits unsupported GPT-6 max")

  for _, model in ipairs({ "gpt-6.1-sol", "gpt-6.1-luna" }) do
    local preset = thinking.resolve_model_selector_preset("openai_agd", model .. "-high")
    eq(model, preset.model, model .. " advisory selector resolves canonical model")
    eq("high", preset.effort, model .. " advisory selector exposes GPT-6-shaped high")
    eq(true, thinking.validate_effort(flat_adapter(model), "vendor-new-level", model), model .. " advisory selector stays non-strict")
  end

  eq("xhigh", thinking.resolve_model_selector_preset("openai_agd", "grok-4.7-xhigh").effort, "Chat selector exposes Grok 4.7 xhigh")
  eq(nil, thinking.resolve_model_selector_preset("openai_agd", "grok-4.7-none"), "Chat omits unsupported Grok 4.7 none")
  eq("high", thinking.resolve_model_selector_preset("openai_agd", "gemini-3.8-flash-high").effort, "Chat selector exposes Gemini 3.8 high")
  eq(nil, thinking.resolve_model_selector_preset("openai_agd", "gemini-3.8-flash-xhigh"), "Chat omits unsupported Gemini 3.8 xhigh")
  for _, model in ipairs({ "claude-opus-5", "claude-opus-5-5" }) do
    local preset = thinking.resolve_model_selector_preset("openai_agd", model .. "-high")
    eq(model, preset.model, model .. " advisory selector resolves canonical model")
    eq("high", preset.effort, model .. " advisory selector exposes high")
    eq(true, thinking.validate_effort(flat_adapter(model), "vendor-new-level", model), model .. " advisory selector stays non-strict")
  end

  local responses_preset = thinking.resolve_model_selector_preset("openai_responses_agd", "gpt-5.6-luna-max")
  eq("gpt-5.6-luna", responses_preset.model, "Responses selector alias resolves canonical Luna")
  eq("max", responses_preset.effort, "Responses selector alias resolves max")
  eq("max", thinking.resolve_model_selector_preset("openai_responses_agd", "gpt-6-sol-max").effort, "Responses selector exposes GPT-6 max")
  eq(nil, thinking.resolve_model_selector_preset("openai_responses_agd", "gpt-6-sol-minimal"), "Responses selector omits unsupported GPT-6 minimal")
  eq("xhigh", thinking.resolve_model_selector_preset("openai_responses_agd", "grok-4.7-xhigh").effort, "Responses selector exposes Grok 4.7 xhigh")
  eq(nil, thinking.resolve_model_selector_preset("openai_responses_agd", "gpt-6.1-sol-high"), "future GPT-6.1 has no unproven Responses alias")

  local chat_choices = thinking.expand_model_choices("openai_agd", {
    ["gpt-5.6-luna"] = { formatted_name = "GPT 5.6 Luna" },
  })
  eq("GPT 5.6 Luna [xhigh]", chat_choices["gpt-5.6-luna-xhigh"].formatted_name, "Chat selector label is readable")
  assert(chat_choices["gpt-5.6-luna-none"], "Chat selector exposes Luna none")
  assert(chat_choices["gpt-5.6-luna-low"], "Chat selector exposes Luna low")
  assert(chat_choices["gpt-5.6-luna-high"], "Chat selector exposes Luna high")
  eq(nil, chat_choices["gpt-5.6-luna-max"], "Chat selector omits Luna max")

  local advisory_choices = thinking.expand_model_choices("openai_agd", {
    ["gpt-6.1-luna"] = { formatted_name = "GPT 6.1 Luna" },
    ["claude-opus-5"] = { formatted_name = "Claude Opus 5" },
  })
  assert(advisory_choices["gpt-6.1-luna-high"], "future GPT-6.1 aliases wait for a base choice")
  assert(advisory_choices["claude-opus-5-high"], "catalog Opus exposes advisory alias")
end

do
  local chat = flat_chat("gpt-5.6-luna-xhigh")
  thinking.attach(chat)
  eq("xhigh", chat.settings.reasoning_effort, "selector alias initializes the visible effort")
  eq(true, thinking.set("high", { chat = chat }), "manual selector override is accepted")
  thinking.reconcile(chat)
  eq("high", chat.settings.reasoning_effort, "manual selector override wins over preset")
  thinking.clear({ chat = chat })
  thinking.reconcile(chat)
  eq("xhigh", chat.settings.reasoning_effort, "clear restores the model selector preset")
end

do
  local original_select = vim.ui.select
  local popup
  local select_popup
  local popup_count = 0
  vim.ui.select = function(items, opts, callback)
    popup = { items = vim.deepcopy(items), prompt = opts.prompt }
    select_popup = callback
    popup_count = popup_count + 1
  end

  eq(false, thinking.warn_if_tool_reasoning_conflict(nil), "a tool event without a live chat is ignored")

  local chat = flat_chat("gpt-5.4")
  chat.tool_registry = { schemas = { ["<tool>read_file</tool>"] = {} } }
  thinking.attach(chat)
  chat:change_model({ model = "gpt-5.6-luna-xhigh" })
  eq(true, vim.wait(1000, function() return popup ~= nil end, 10), "Luna tool conflict popup is shown")
  eq("Set reasoning_effort=none (recommended)", popup.items[1], "popup offers explicit none")
  assert(popup.prompt:find("1 active function tool", 1, true), "popup reports active tool count")
  local stale_popup = select_popup
  chat.tool_registry.schemas["<tool>grep_search</tool>"] = {}
  eq(false, thinking.warn_if_tool_reasoning_conflict(chat), "same model/effort does not re-prompt per added tool")
  eq(1, popup_count, "same conflict has one popup")

  chat:change_model({ model = "gpt-5.4" })
  stale_popup(popup.items[1])
  eq(nil, chat.settings.reasoning_effort, "stale popup cannot alter a later model")

  popup = nil
  chat:change_model({ model = "gpt-5.6-luna-xhigh" })
  eq(true, vim.wait(1000, function() return popup ~= nil end, 10), "returning to a conflict re-prompts")
  select_popup(popup.items[1])
  eq("none", chat.settings.reasoning_effort, "popup action synchronizes explicit none")
  eq(nil, thinking.tool_reasoning_conflict(chat), "none resolves Luna tool conflict")

  popup = nil
  local restored = flat_chat("gpt-5.6-luna-high")
  restored.tool_registry = { schemas = { ["<tool>read_file</tool>"] = {} } }
  thinking.attach(restored)
  eq(true, vim.wait(1000, function() return popup ~= nil end, 10), "existing Luna tool chat shows conflict popup")
  select_popup(popup.items[1])
  eq("none", restored.settings.reasoning_effort, "existing Luna tool chat applies explicit none")

  popup = nil
  local guarded = flat_chat("gpt-5.6-luna-high")
  guarded.tool_registry = { schemas = { ["<tool>read_file</tool>"] = {} } }
  thinking.attach(guarded)
  eq(false, guarded.callbacks.on_before_submit(guarded, {}), "submit guard blocks the known failing request")
  eq(true, vim.wait(1000, function() return popup ~= nil end, 10), "submit guard retains the remediation popup")
  select_popup(popup.items[1])
  eq(nil, guarded.callbacks.on_before_submit(guarded, {}), "submit guard allows explicit none")

  popup = nil
  local clearable = flat_chat("gpt-5.6-luna-high")
  clearable.tool_registry = { schemas = { ["<tool>read_file</tool>"] = {} } }
  thinking.attach(clearable)
  eq(true, vim.wait(1000, function() return popup ~= nil end, 10), "clearable Luna conflict shows an initial popup")
  local before_clear = popup_count
  thinking.clear({ chat = clearable })
  thinking.set("high", { chat = clearable })
  eq(true, vim.wait(1000, function() return popup_count > before_clear end, 10), "clear resets popup deduplication")

  local late_tool = flat_chat("gpt-5.6-luna-high")
  late_tool.bufnr = 90123
  late_tool.tool_registry = { schemas = {} }
  thinking.attach(late_tool)
  late_tool.tool_registry.schemas["<tool>read_file</tool>"] = {}
  local late_payload = thinking.prepare_request(vim.deepcopy(late_tool.adapter), {
    model = "gpt-5.6-luna",
    reasoning_effort = "high",
  })
  eq("none", late_payload.reasoning_effort, "post-parse or auto-submit tool is forced to Luna's safe effort")
  eq("none", late_tool.settings.reasoning_effort, "late tool guard synchronizes the original chat after adapter copying")
  late_payload = thinking.prepare_request(vim.deepcopy(late_tool.adapter), {
    model = "gpt-5.6-luna",
    reasoning_effort = "high",
  })
  eq("none", late_payload.reasoning_effort, "late guard uses outgoing effort even when the visible setting is already none")

  local advisory = flat_chat("gpt-6.1-sol")
  advisory.settings.reasoning_effort = "high"
  advisory.tool_registry = { schemas = { ["<tool>read_file</tool>"] = {} } }
  eq(nil, thinking.tool_reasoning_conflict(advisory), "advisory GPT-6.1 does not inherit Luna tool policy")
  vim.ui.select = original_select
end

do
  local selected
  local listed
  local chat = {
    adapter = { name = constants.providers.openai_agd.adapter_name },
    change_model = function(_, args)
      selected = args.model
    end,
  }
  actions.pick_current_provider_model(chat, {
    models = { "grok-4.6", "grok-4.6-xhigh" },
    select = function(models, choose)
      listed = vim.deepcopy(models)
      choose("grok-4.6-xhigh")
    end,
  })
  eq({ "grok-4.6", "grok-4.6-xhigh" }, listed, "current-provider picker skips adapter selection")
  eq("grok-4.6-xhigh", selected, "current-provider picker changes the active chat model")
end

do
  local original_select = vim.ui.select
  local choices
  vim.ui.select = function(items, _, callback)
    choices = vim.deepcopy(items)
    callback(nil)
  end

  thinking.pick(flat_chat("gpt-5.6-luna"))
  eq(false, vim.tbl_contains(choices, "minimal"), "GPT-5.6 picker hides minimal")
  eq(false, vim.tbl_contains(choices, "max"), "GPT-5.6 picker hides max")
  eq(false, vim.tbl_contains(choices, "<custom value…>"), "GPT-5.6 picker hides custom input")

  thinking.pick(flat_chat("future-picker-model"))
  for _, level in ipairs({ "none", "minimal", "low", "medium", "high", "xhigh", "max" }) do
    eq(true, vim.tbl_contains(choices, level), "unknown picker shows " .. level)
  end
  eq(true, vim.tbl_contains(choices, "<custom value…>"), "unknown picker keeps custom input")
  vim.ui.select = original_select
end

do
  local chat = flat_chat("gpt-5.4")
  thinking.attach(chat)
  thinking.set("high", { chat = chat })
  chat:change_model({ model = "claude-sonnet-5" })
  eq(nil, chat.settings.reasoning_effort, "new model does not inherit GPT effort")
  thinking.set("low", { chat = chat })
  chat:change_model({ model = "gpt-5.4" })
  eq("high", chat.settings.reasoning_effort, "return restores GPT effort")
  chat:change_model({ model = "claude-sonnet-5" })
  eq("low", chat.settings.reasoning_effort, "return restores Claude effort")

  chat.settings.reasoning_effort = "manual-custom"
  thinking.prepare(chat)
  chat:change_model({ model = "gpt-5.4" })
  chat:change_model({ model = "claude-sonnet-5" })
  eq("manual-custom", chat.settings.reasoning_effort, "manual edit wins")

  chat.settings.reasoning_effort = nil
  thinking.prepare(chat)
  chat:change_model({ model = "gpt-5.4" })
  chat:change_model({ model = "claude-sonnet-5" })
  eq(nil, chat.settings.reasoning_effort, "manual clear wins")

  chat.settings = {
    model = "gpt-5.4",
    reasoning_effort = "high",
    temperature = 0.42,
    top_p = 0.8,
  }
  chat.adapter.model.name = "gpt-5.4"
  chat.adapter.parameters.model = "gpt-5.4"
  thinking.prepare(chat)
  -- Match CodeCompanion debug save order: apply the edited table, then change model.
  chat.settings = {
    model = "claude-sonnet-5",
    reasoning_effort = "debug-manual",
    temperature = 0.42,
    top_p = 0.8,
  }
  chat:change_model({ model = "claude-sonnet-5" })
  eq("debug-manual", chat.settings.reasoning_effort, "debug model plus effort save survives reset")
end

do
  local chat_bufnr = vim.api.nvim_create_buf(false, true)
  local debug_bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(debug_bufnr, "CodeCompanion_debug")
  vim.api.nvim_buf_set_lines(debug_bufnr, 0, -1, false, {
    "-- Buffer Number: " .. chat_bufnr,
    "",
    "local settings = {",
    '  model = "gpt-5.4",',
    "  reasoning_effort = nil,",
    "}",
  })
  local chat = flat_chat("gpt-5.4")
  chat.bufnr = chat_bufnr
  thinking.set("xhigh", { chat = chat })
  local text = table.concat(vim.api.nvim_buf_get_lines(debug_bufnr, 0, -1, false), "\n")
  assert(text:find('reasoning_effort = "xhigh",', 1, true), "debug snapshot should track toggle")
  thinking.clear({ chat = chat })
  text = table.concat(vim.api.nvim_buf_get_lines(debug_bufnr, 0, -1, false), "\n")
  assert(text:find("reasoning_effort = nil,", 1, true), "debug snapshot should track clear")
  vim.api.nvim_buf_delete(debug_bufnr, { force = true })
  vim.api.nvim_buf_delete(chat_bufnr, { force = true })
end

local chat_factory = adapter_utils.get_agoda_adapters(false)[constants.providers.openai_agd.adapter_name]

do
  local configured_adapters = adapter_utils.get_agoda_adapters(false)
  eq(nil, configured_adapters.openai_agd_luna_xhigh, "no Luna xhigh chat adapter alias")
  eq(nil, configured_adapters.openai_agd_luna_max, "no Luna max chat adapter alias")

  local adapter = chat_factory()
  eq(nil, adapter.schema.reasoning_effort.default, "chat effort has no implicit default")
  for _, name in ipairs({
    "setup",
    "build_parameters",
    "build_messages",
    "build_tools",
    "parse_chat",
    "parse_inline",
    "parse_tokens",
  }) do
    assert(adapters.get_handler(adapter, name), "missing inherited OpenAI handler: " .. name)
  end
end

for _, model in ipairs({ "future-model" }) do
  local adapter = chat_factory()
  adapter:map_schema_to_params({
    model = model,
    reasoning_effort = "manual-force",
    temperature = 0.42,
    top_p = 0.8,
  })
  local payload = adapters.call_handler(adapter, "build_parameters", vim.deepcopy(adapter.parameters), {})
  eq("manual-force", payload.reasoning_effort, model .. " explicit effort survives")
  eq(0.42, payload.temperature, model .. " unverified sampling survives")
  eq(0.8, payload.top_p, model .. " unverified top_p survives")
end

do
  local adapter = chat_factory()
  adapter:map_schema_to_params({
    model = "qwen-3.8-27b",
    reasoning_effort = "xhigh",
    temperature = 0.42,
    top_p = 0.8,
  })
  local payload = adapters.call_handler(adapter, "build_parameters", vim.deepcopy(adapter.parameters), {})
  eq("xhigh", payload.reasoning_effort, "Qwen Chat keeps verified xhigh")
  eq(0.42, payload.temperature, "Qwen Chat preserves temperature with effort")
  eq(0.8, payload.top_p, "Qwen Chat preserves top_p with effort")
  eq(true, adapter.schema.reasoning_effort.validate("xhigh"), "Qwen Chat schema accepts xhigh")

  adapter:map_schema_to_params({ model = "qwen-3.8-27b", reasoning_effort = "high" })
  payload = adapters.call_handler(adapter, "build_parameters", vim.deepcopy(adapter.parameters), {})
  eq(nil, payload.reasoning_effort, "Qwen Chat strips unsupported high")
  eq(false, adapter.schema.reasoning_effort.validate("high"), "Qwen Chat schema rejects high")
end

for _, model in ipairs({ "o3", "qwen-3.8-27b", "future-model" }) do
  local adapter = chat_factory()
  adapter.schema.model.default = model
  adapter.schema.model.choices = function()
    error "reasoning visibility must not fetch models"
  end
  schema.get_ordered_keys(adapter)
  assert(adapter.schema.reasoning_effort, "reasoning schema removed for " .. model)
end

do
  local adapter = chat_factory()
  adapter:map_schema_to_params({
    model = "gpt-5.4",
    reasoning_effort = "high",
    temperature = 0.42,
    top_p = 0.8,
  })
  local payload = adapters.call_handler(adapter, "build_parameters", vim.deepcopy(adapter.parameters), {})
  eq("high", payload.reasoning_effort, "GPT flat effort")
  eq(nil, payload.temperature, "GPT request-only temperature normalization")
  eq(nil, payload.top_p, "GPT request-only top_p normalization")

  adapter:map_schema_to_params({ model = "gpt-5.4", temperature = 0.42, top_p = 0.8 })
  eq(nil, adapter.parameters.reasoning_effort, "flat clear removes stale effort")
  payload = adapters.call_handler(adapter, "build_parameters", vim.deepcopy(adapter.parameters), {})
  eq(0.42, payload.temperature, "sampling preserved without effort")
  eq(0.8, payload.top_p, "top_p preserved without effort")
end

do
  local adapter = chat_factory()
  local source = {
    model = "claude-sonnet-5",
    reasoning_effort = "high",
    temperature = 0.42,
    top_p = 0.8,
  }
  adapter:map_schema_to_params(source)
  local payload = adapters.call_handler(adapter, "build_parameters", vim.deepcopy(adapter.parameters), {})
  eq("high", payload.reasoning_effort, "Claude flat effort")
  eq(0.42, payload.temperature, "Claude verified-compatible temperature")
  eq(0.8, payload.top_p, "Claude verified-compatible top_p")
  eq(0.42, source.temperature, "source settings never mutated")
end

do
  local adapter = chat_factory()
  adapter:map_schema_to_params({
    model = "gpt-5.4",
    reasoning_effort = "none",
    temperature = 0.42,
    top_p = 0.8,
  })
  local payload = adapters.call_handler(adapter, "build_parameters", vim.deepcopy(adapter.parameters), {})
  eq(0.42, payload.temperature, "none preserves temperature")
  eq(0.8, payload.top_p, "none preserves top_p")
end

do
  for _, model in ipairs({ "gpt-5.6-sol", "gpt-5.6-terra", "gpt-5.6-luna" }) do
    local adapter = chat_factory()
    adapter.schema.model.default = model
    adapter:map_schema_to_params({
      model = model,
      reasoning_effort = "xhigh",
      temperature = 0.42,
      top_p = 0.8,
    })
    local payload = adapters.call_handler(adapter, "build_parameters", vim.deepcopy(adapter.parameters), {})
    eq("xhigh", payload.reasoning_effort, model .. " chat keeps xhigh")
    eq(nil, payload.temperature, model .. " chat normalizes temperature with xhigh")
    eq(nil, payload.top_p, model .. " chat normalizes top_p with xhigh")
    eq(true, adapter.schema.reasoning_effort.validate("xhigh"), model .. " schema accepts xhigh")

    for _, invalid_effort in ipairs({ "minimal", "max" }) do
      adapter.schema.model.default = model
      adapter:map_schema_to_params({ model = model, reasoning_effort = invalid_effort })
      payload = adapters.call_handler(adapter, "build_parameters", vim.deepcopy(adapter.parameters), {})
      eq(nil, payload.reasoning_effort, model .. " chat omits " .. invalid_effort)
      eq(false, adapter.schema.reasoning_effort.validate(invalid_effort), model .. " schema rejects " .. invalid_effort)
    end
  end
end

do
  local adapter = chat_factory()
  local alias = "gpt-5.6-luna-xhigh"
  local source = { model = alias, temperature = 0.42, top_p = 0.8 }
  adapter.schema.model.default = alias
  adapter:map_schema_to_params(source)
  local payload = adapters.call_handler(adapter, "build_parameters", vim.deepcopy(adapter.parameters), {})
  eq("gpt-5.6-luna", payload.model, "Chat selector alias sends canonical model")
  eq("xhigh", payload.reasoning_effort, "Chat selector alias supplies effort")
  eq(nil, payload.temperature, "Chat selector alias normalizes incompatible temperature")
  eq(alias, source.model, "Chat selector mapping does not mutate YAML settings")
  eq(true, adapter.schema.reasoning_effort.validate("xhigh"), "Chat alias inherits canonical validation")
  eq(false, adapter.schema.reasoning_effort.validate("max"), "Chat alias still rejects max")
end

do
  local adapter = chat_factory()
  local alias = "gpt-5.6-luna-none"
  adapter.schema.model.default = alias
  adapter:map_schema_to_params({ model = alias, temperature = 0.42, top_p = 0.8 })
  local payload = adapters.call_handler(adapter, "build_parameters", vim.deepcopy(adapter.parameters), {})
  eq("gpt-5.6-luna", payload.model, "Chat none alias sends canonical model")
  eq("none", payload.reasoning_effort, "Chat none alias sends explicit none")
  eq(0.42, payload.temperature, "Chat none alias preserves temperature")
  eq(0.8, payload.top_p, "Chat none alias preserves top_p")
end

for _, preset in ipairs({
  { alias = "qwen-3.8-27b-xhigh", model = "qwen-3.8-27b", effort = "xhigh" },
  { alias = "grok-4.6-xhigh", model = "grok-4.6", effort = "xhigh" },
  { alias = "kimi-k2.7-code-max", model = "kimi-k2.7-code", effort = "max" },
  { alias = "claude-sonnet-5-high", model = "claude-sonnet-5", effort = "high" },
  { alias = "gpt-6-sol-high", model = "gpt-6-sol", effort = "high" },
  { alias = "gpt-6-luna-none", model = "gpt-6-luna", effort = "none" },
  { alias = "grok-4.7-xhigh", model = "grok-4.7", effort = "xhigh" },
  { alias = "gemini-3.8-flash-high", model = "gemini-3.8-flash", effort = "high" },
  { alias = "claude-sonnet-5-5-max", model = "claude-sonnet-5-5", effort = "max" },
}) do
  local adapter = chat_factory()
  adapter.schema.model.default = preset.alias
  adapter:map_schema_to_params({ model = preset.alias })
  local payload = adapters.call_handler(adapter, "build_parameters", vim.deepcopy(adapter.parameters), {})
  eq(preset.model, payload.model, preset.alias .. " sends the canonical model")
  eq(preset.effort, payload.reasoning_effort, preset.alias .. " supplies the verified effort")
end

do
  local factory = adapter_utils.get_agoda_responses_adapters()[constants.providers.openai_responses_agd.adapter_name]
  local configured_adapters = adapter_utils.get_agoda_responses_adapters()
  eq(nil, configured_adapters.openai_responses_agd_luna_xhigh, "no Luna xhigh Responses adapter alias")
  eq(nil, configured_adapters.openai_responses_agd_luna_max, "no Luna max Responses adapter alias")
  local adapter = factory()
  eq(nil, adapter.schema["reasoning.effort"].default, "Responses effort has no implicit default")
  assert(adapter.schema.model.choices["gpt-5.6-luna-low"], "Responses selector exposes Luna low")
  assert(adapter.schema.model.choices["gpt-5.6-luna-high"], "Responses selector exposes Luna high")
  assert(adapter.schema.model.choices["gpt-5.6-luna-xhigh"], "Responses selector exposes Luna xhigh")
  assert(adapter.schema.model.choices["gpt-5.6-luna-max"], "Responses selector exposes Luna max")
  assert(adapter.schema.model.choices["gpt-6-sol"], "Responses exposes GPT-6 Sol")
  assert(adapter.schema.model.choices["gpt-6-sol-max"], "Responses selector exposes GPT-6 Sol max")
  assert(adapter.schema.model.choices["gpt-6-luna-none"], "Responses selector exposes GPT-6 Luna none")
  assert(adapter.schema.model.choices["grok-4.7"], "Responses exposes Grok 4.7")
  assert(adapter.schema.model.choices["grok-4.7-xhigh"], "Responses selector exposes Grok 4.7 xhigh")
  for _, name in ipairs({ "setup", "build_parameters", "build_messages", "parse_chat", "parse_tokens" }) do
    assert(adapters.get_handler(adapter, name), "missing inherited Responses handler: " .. name)
  end
  adapter:map_schema_to_params({
    model = "gpt-5.3-codex",
    ["reasoning.effort"] = "high",
    temperature = 0.42,
  })
  local payload = adapters.call_handler(adapter, "build_parameters", vim.deepcopy(adapter.parameters), {})
  eq("high", payload.reasoning.effort, "Responses nested effort")
  eq(nil, payload.temperature, "Responses request-only normalization")
  adapter:map_schema_to_params({ model = "gpt-5.3-codex" })
  eq(nil, adapter.parameters.reasoning, "nested clear removes stale effort")

  for _, model in ipairs({ "gpt-5.6-sol", "gpt-5.6-terra", "gpt-5.6-luna" }) do
    for _, effort in ipairs({ "xhigh", "max" }) do
      adapter.schema.model.default = model
      adapter:map_schema_to_params({ model = model, ["reasoning.effort"] = effort })
      payload = adapters.call_handler(adapter, "build_parameters", vim.deepcopy(adapter.parameters), {})
      eq(effort, payload.reasoning.effort, model .. " Responses keeps " .. effort)
      eq(true, adapter.schema["reasoning.effort"].validate(effort), model .. " Responses schema keeps " .. effort)
    end
  end

  local alias = "gpt-5.6-luna-max"
  adapter.schema.model.default = alias
  adapter:map_schema_to_params({ model = alias })
  payload = adapters.call_handler(adapter, "build_parameters", vim.deepcopy(adapter.parameters), {})
  eq("gpt-5.6-luna", payload.model, "Responses selector alias sends canonical model")
  eq("max", payload.reasoning.effort, "Responses selector alias supplies max")

  for _, preset in ipairs({
    { alias = "gpt-6-sol-max", model = "gpt-6-sol", effort = "max" },
    { alias = "gpt-6-luna-none", model = "gpt-6-luna", effort = "none" },
    { alias = "grok-4.7-xhigh", model = "grok-4.7", effort = "xhigh" },
  }) do
    adapter.schema.model.default = preset.alias
    adapter:map_schema_to_params({ model = preset.alias })
    payload = adapters.call_handler(adapter, "build_parameters", vim.deepcopy(adapter.parameters), {})
    eq(preset.model, payload.model, preset.alias .. " Responses selector sends canonical model")
    eq(preset.effort, payload.reasoning.effort, preset.alias .. " Responses selector supplies effort")
  end
end

do
  local prompt_library = require "utils.my_codecompanion_prompt_library"
  local chat_factory = adapter_utils.get_agoda_adapters()[constants.providers.openai_agd.adapter_name]
  local responses_factory = adapter_utils.get_agoda_responses_adapters()[constants.providers.openai_responses_agd.adapter_name]
  local library = prompt_library.build({ { role = "user", content = "" } }, {
    enabled_providers = { openai_agd = true, copilot = false },
  })

  for _, preset in ipairs(thinking.model_selector_presets(constants.providers.openai_agd.adapter_name)) do
    local title = "AGD Chat " .. preset.model .. " [" .. preset.effort .. "]"
    local entry = library[title]
    assert(entry, "missing reusable Chat prompt: " .. title)
    eq(constants.providers.openai_agd.adapter_name, entry.opts.adapter.name, title .. " generic adapter")
    eq(preset.model, entry.opts.adapter.model, title .. " canonical model")
    assert(entry.opts.callbacks and entry.opts.callbacks.on_created, title .. " applies a preset")

    local adapter = chat_factory()
    adapter.schema.model.default = preset.model
    local chat = { adapter = adapter, settings = { model = preset.model } }
    entry.opts.callbacks.on_created(chat)
    eq(preset.effort, chat.settings.reasoning_effort, title .. " preset applied")
  end

  for _, model in ipairs({ "gpt-6-sol", "gpt-6-luna" }) do
    local high = library["AGD Chat " .. model .. " [high]"]
    local none = library["AGD Chat " .. model .. " [none]"]
    assert(high and none, model .. " prompts are generated")
    eq(nil, high.prompts[1].content:find("@{read_file}", 1, true), model .. " high prompt omits implicit function tools")
    assert(none.prompts[1].content:find("@{read_file}", 1, true), model .. " none prompt retains function tools")
  end
  assert(library["AGD gpt 6.1-luna [future-S]"], "future GPT-6.1 Luna base prompt is predeclared")
  assert(library["AGD gpt 6.1-sol [future-L]"], "future GPT-6.1 Sol base prompt is predeclared")
  assert(library["AGD claude opus-5 [catalog-M]"], "catalog-only Opus 5 remains selectable")
  assert(library["AGD claude opus-5-5 [catalog-L]"], "catalog-only Opus 5.5 remains selectable")
  assert(library["AGD Chat claude-opus-5 [high]"], "catalog Opus 5 advisory prompt is generated")

  for _, preset in ipairs(thinking.model_selector_presets(constants.providers.openai_responses_agd.adapter_name)) do
    local family = preset.model:match("^([^-]+)%-") or "model"
    local title = "AGD Responses " .. family .. " " .. preset.model:gsub("^" .. family .. "%-", "") .. " [" .. preset.effort .. "]"
    local entry = library[title]
    assert(entry, "missing reusable Responses prompt: " .. title)
    eq(constants.providers.openai_responses_agd.adapter_name, entry.opts.adapter.name, title .. " generic adapter")
    eq(preset.model, entry.opts.adapter.model, title .. " model")
    assert(entry.opts.callbacks and entry.opts.callbacks.on_created, title .. " applies a preset")

    local adapter = responses_factory()
    adapter.schema.model.default = preset.model
    local chat = { adapter = adapter, settings = { model = preset.model } }
    entry.opts.callbacks.on_created(chat)
    eq(preset.effort, chat.settings["reasoning.effort"], title .. " preset applied")
  end
end

thinking.register_capability("openai_agd", "future-model", {
  status = "supported",
  source = "test_runtime_registration",
  levels = { "low", "high", "vendor-new-level" },
})
local registered_future = thinking.resolve_capability(flat_adapter("future-model"))
eq("test_runtime_registration", registered_future.source, "runtime registration")

thinking.register_capability("openai_agd", "native-shape-model", {
  status = "supported",
  source = "test_native_transform",
  request_transform = function(params, context)
    params.thinking = { type = "enabled", effort = context.effort }
    params.reasoning_effort = nil
    return params
  end,
})
local native_adapter = flat_adapter("native-shape-model")
thinking.map_settings(native_adapter, { model = "native-shape-model", reasoning_effort = "high" })
local native_payload = thinking.prepare_request(native_adapter, vim.deepcopy(native_adapter.parameters))
eq(nil, native_payload.reasoning_effort, "model-specific transform removes canonical field")
eq("high", native_payload.thinking.effort, "model-specific transform receives effort")

thinking.register_capability("openai_agd", "broken-transform-model", {
  status = "supported",
  source = "test_broken_transform",
  request_transform = function(params)
    params.reasoning_effort = nil
    error "transform failed after mutation"
  end,
})
local broken_adapter = flat_adapter("broken-transform-model")
thinking.map_settings(broken_adapter, { model = "broken-transform-model", reasoning_effort = "high" })
local broken_payload = thinking.prepare_request(broken_adapter, vim.deepcopy(broken_adapter.parameters))
eq("high", broken_payload.reasoning_effort, "failed transform cannot partially mutate request")

if vim.env.CODECOMPANION_THINKING_LIVE == "1" then
  local started = thinking.refresh_capabilities({ force = true, timeout = 10 })
  eq(true, started, "live metadata refresh started")
  local loaded = vim.wait(12000, function()
    return thinking.resolve_capability(flat_adapter("claude-opus-4-8")).source == "agd_model_metadata"
  end, 100)
  eq(true, loaded, "live AGD metadata loaded")
end

thinking.setup({ fetch_metadata = false })
eq(2, vim.fn.exists ":CodeCompanionThinking", "thinking command registered")

require("codecompanion").setup({
  adapters = { http = adapter_utils.get_agoda_adapters(false) },
  display = { chat = { show_settings = true } },
  interactions = { chat = { adapter = constants.providers.openai_agd.adapter_name } },
})
local live_chat = require("codecompanion").chat({
  params = { adapter = constants.providers.openai_agd.adapter_name, model = "gpt-5.4" },
})
assert(live_chat, "real CodeCompanion chat should be created")
assert(rawget(live_chat, "change_model"), "ChatCreated hook should wrap the real chat")
thinking.set("high", { chat = live_chat })
local parsed = require("codecompanion.interactions.chat.parser").settings(
  live_chat.bufnr,
  live_chat.parsers.yaml,
  live_chat.adapter
)
eq("high", parsed.reasoning_effort, "picker synchronizes editable YAML")
live_chat:change_model({ model = "claude-sonnet-5" })
eq(nil, live_chat.settings.reasoning_effort, "real chat model switch isolates override")
thinking.set("low", { chat = live_chat })
live_chat:change_model({ model = "gpt-5.4" })
eq("high", live_chat.settings.reasoning_effort, "real chat restores GPT override")
local live_debug = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_name(live_debug, "CodeCompanion_debug")
vim.api.nvim_buf_set_lines(live_debug, 0, -1, false, {
  "-- Buffer Number: " .. live_chat.bufnr,
  "",
  "local settings = {",
  '  model = "gpt-5.4",',
  '  reasoning_effort = "high",',
  "}",
})
local debug_model_only = vim.deepcopy(live_chat.settings)
debug_model_only.model = "claude-sonnet-5"
require("codecompanion.interactions.chat.helpers").apply_settings_and_model(live_chat, debug_model_only)
eq("low", live_chat.settings.reasoning_effort, "debug model-only switch keeps target override")
local live_debug_text = table.concat(vim.api.nvim_buf_get_lines(live_debug, 0, -1, false), "\n")
assert(live_debug_text:find('model = "claude-sonnet-5",', 1, true), "debug snapshot model should reconcile")
assert(live_debug_text:find('reasoning_effort = "low",', 1, true), "debug snapshot effort should reconcile")
vim.api.nvim_buf_delete(live_debug, { force = true })

live_chat:change_model({ model = "gpt-5.4" })
local yaml_lines = vim.api.nvim_buf_get_lines(live_chat.bufnr, 0, -1, false)
for index, line in ipairs(yaml_lines) do
  if line:match("^model:") then
    yaml_lines[index] = "model: claude-sonnet-5"
  elseif line:match("^reasoning_effort:") then
    yaml_lines[index] = "reasoning_effort: high"
  end
end
vim.api.nvim_buf_set_lines(live_chat.bufnr, 0, -1, false, yaml_lines)
vim.bo[live_chat.bufnr].modifiable = false
require("codecompanion.interactions.chat.helpers").apply_settings_and_model(live_chat, {
  model = "claude-sonnet-5",
  reasoning_effort = "high",
})
eq(false, vim.bo[live_chat.bufnr].modifiable, "YAML sync preserves CodeCompanion's buffer lock")
local locked_yaml = table.concat(vim.api.nvim_buf_get_lines(live_chat.bufnr, 0, -1, false), "\n")
assert(locked_yaml:find("reasoning_effort: low", 1, true), "locked YAML should reconcile target effort")
vim.bo[live_chat.bufnr].modifiable = true

do
  local original_select = vim.ui.select
  local popup
  vim.ui.select = function(items, opts, callback)
    popup = { items = vim.deepcopy(items), prompt = opts.prompt }
    callback(items[1])
  end

  live_chat:change_model({ model = "gpt-5.6-luna-xhigh" })
  live_chat.tool_registry.schemas["<tool>read_file</tool>"] = {}
  vim.api.nvim_exec_autocmds("User", {
    pattern = "CodeCompanionChatToolAdded",
    data = { bufnr = live_chat.bufnr },
  })
  eq(true, vim.wait(1000, function() return popup ~= nil end, 10), "tool-added event shows Luna conflict popup")
  eq("Set reasoning_effort=none (recommended)", popup.items[1], "tool-added event offers explicit none")
  eq("none", live_chat.settings.reasoning_effort, "tool-added event applies explicit none")
  vim.ui.select = original_select
end

do
  -- CodeCompanion parses the editable YAML only inside _submit_http, after
  -- on_before_submit. The guard must honor a pending safe YAML value rather
  -- than block based on the stale in-memory setting.
  live_chat.settings.reasoning_effort = "high"
  eq(
    false,
    live_chat:dispatch_cancellable("on_before_submit", { adapter = live_chat.adapter }),
    "pending YAML none bypasses the Luna submit guard"
  )
  eq("high", live_chat.settings.reasoning_effort, "preflight leaves the pending YAML value for CodeCompanion to apply")
end

vim.api.nvim_buf_delete(live_chat.bufnr, { force = true })

local manual_yaml_chat = require("codecompanion").chat({
  params = { adapter = constants.providers.openai_agd.adapter_name, model = "gpt-5.4" },
})
local manual_lines = vim.api.nvim_buf_get_lines(manual_yaml_chat.bufnr, 0, -1, false)
for index, line in ipairs(manual_lines) do
  if line:match("^model:") then
    manual_lines[index] = "model: claude-sonnet-5"
  elseif line:match("^reasoning_effort:") then
    manual_lines[index] = "reasoning_effort: manual-custom"
  end
end
vim.api.nvim_buf_set_lines(manual_yaml_chat.bufnr, 0, -1, false, manual_lines)
manual_yaml_chat:dispatch("on_submitted", { payload = {} })
local before_parse = table.concat(vim.api.nvim_buf_get_lines(manual_yaml_chat.bufnr, 0, -1, false), "\n")
assert(before_parse:find("model: claude-sonnet-5", 1, true), "on_submitted must not erase manual model")
assert(before_parse:find("reasoning_effort: manual-custom", 1, true), "on_submitted must not erase manual effort")
local manual_settings = require("codecompanion.interactions.chat.parser").settings(
  manual_yaml_chat.bufnr,
  manual_yaml_chat.parsers.yaml,
  manual_yaml_chat.adapter
)
require("codecompanion.interactions.chat.helpers").apply_settings_and_model(manual_yaml_chat, manual_settings)
eq("claude-sonnet-5", manual_yaml_chat.settings.model, "manual YAML model applies")
eq("manual-custom", manual_yaml_chat.settings.reasoning_effort, "manual YAML effort applies")
vim.api.nvim_buf_delete(manual_yaml_chat.bufnr, { force = true })

local two_debug_chat = require("codecompanion").chat({
  params = { adapter = constants.providers.openai_agd.adapter_name, model = "gpt-5.4" },
})
local chat_helpers = require "codecompanion.interactions.chat.helpers"
chat_helpers.apply_settings_and_model(two_debug_chat, {
  model = "gpt-5.4",
  reasoning_effort = "manual-high",
})
chat_helpers.apply_settings_and_model(two_debug_chat, {
  model = "claude-sonnet-5",
  reasoning_effort = "manual-high",
})
eq(nil, two_debug_chat.settings.reasoning_effort, "model-only debug save does not carry manual GPT effort")
two_debug_chat:change_model({ model = "gpt-5.4" })
eq("manual-high", two_debug_chat.settings.reasoning_effort, "same-model debug save is remembered for GPT")
vim.api.nvim_buf_delete(two_debug_chat.bufnr, { force = true })

print "CodeCompanion thinking tests passed"
vim.cmd "qa!"
