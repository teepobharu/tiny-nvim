vim.notify = function() end

local adapters = require "codecompanion.adapters"
local schema = require "codecompanion.schema"
local constants = require "utils.my_ai_constants"
local thinking = require "utils.my_codecompanion_thinking"
local adapter_utils = require "utils.my_codecompanion_utils"

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
        name = "qwen-3.6-27b",
        maker = "ALIBABA",
        isChatModel = true,
        thinkingCapability = "None",
        features = {},
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
  eq("unsupported", thinking.resolve_capability(flat_adapter("qwen-3.6-27b")).status, "Qwen advisory")
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
  "claude-sonnet-5",
  "gemini-3.5-flash",
  "qwen-3.6-27b",
  "kimi-k2.7-code",
  "future-model",
}) do
  local chat = flat_chat(model)
  eq(true, thinking.set("vendor-new-level", { chat = chat }), model .. " set")
  eq("vendor-new-level", chat.settings.reasoning_effort, model .. " free-form effort")
  eq(0.42, chat.settings.temperature, model .. " temperature preserved")
  eq(0.8, chat.settings.top_p, model .. " top_p preserved")
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

for _, model in ipairs({ "qwen-3.6-27b", "future-model" }) do
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

for _, model in ipairs({ "o3", "qwen-3.6-27b", "future-model" }) do
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
  local factory = adapter_utils.get_agoda_responses_adapters()[constants.providers.openai_responses_agd.adapter_name]
  local adapter = factory()
  eq(nil, adapter.schema["reasoning.effort"].default, "Responses effort has no implicit default")
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
