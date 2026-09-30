local M = {}
local AI_CONST = require "utils.my_ai_constants"

local COMMON_LEVELS = { "none", "minimal", "low", "medium", "high", "xhigh", "max" }
local REQUIRED_LEVELS = { "minimal", "low", "medium", "high" }
local CLEAR_VALUES = { clear = true, inherit = true, unset = true }

-- This is the one source of truth for route-proven reasoning presets. A catalog
-- entry alone must not be added here: it needs an exact model + endpoint +
-- effort probe first. `model_selector_presets` exposes aliases from this table,
-- while the registrations below enforce the same levels on the matching route.
-- New current/previous-generation models therefore need one entry, not parallel
-- selector and capability edits.
local REASONING_SAMPLING_CONFLICTS = { temperature = "non_default", top_p = "non_default" }

local function verified_route_policy(models, selector_efforts, source, opts)
  opts = opts or {}
  local capability = {
    status = "supported",
    source = source,
    mode = opts.mode or "optional",
    -- An empty table intentionally replaces a lower-priority family hint.
    conflicts = opts.conflicts or {},
  }
  if opts.levels ~= nil then
    capability.levels = opts.levels
  end
  if opts.enforce_levels then
    capability.enforce_levels = true
  end

  return {
    models = models,
    selector_efforts = selector_efforts,
    capability = capability,
    tool_required_effort = opts.tool_required_effort,
  }
end

local function strict_verified_route_policy(models, selector_efforts, source, opts)
  opts = opts or {}
  local strict_opts = vim.tbl_extend("force", {}, opts, {
    levels = opts.levels or selector_efforts,
    enforce_levels = true,
  })
  return verified_route_policy(models, selector_efforts, source, strict_opts)
end

local GPT_5_6_MODELS = {
  AI_CONST.models.gpt.GPT_5_6_SOL,
  AI_CONST.models.gpt.GPT_5_6_TERRA,
  AI_CONST.models.gpt.GPT_5_6_LUNA,
}
local GPT_6_MODELS = { AI_CONST.models.gpt.GPT_6_SOL, AI_CONST.models.gpt.GPT_6_LUNA }
local GPT_6_1_MODELS = { AI_CONST.models.gpt.GPT_6_1_SOL, AI_CONST.models.gpt.GPT_6_1_LUNA }
local QWEN_3_8_MODELS = { AI_CONST.models.qwen.QWEN_3_8_27B }
local GROK_OPTIONAL_CHAT_MODELS = { AI_CONST.models.others.GROK_4_3, AI_CONST.models.others.GROK_4_5 }
local GROK_REQUIRED_CHAT_MODELS = { AI_CONST.models.others.GROK_4_6 }
local GROK_4_7_MODELS = { AI_CONST.models.others.GROK_4_7 }
local GEMINI_3_7_3_8_FLASH_MODELS = {
  AI_CONST.models.gemini.GEMINI_3_7_FLASH,
  AI_CONST.models.gemini.GEMINI_3_8_FLASH,
}
local CLAUDE_SONNET_5_MODELS = { AI_CONST.models.claude.CLAUDE_SONNET_5 }
local CLAUDE_SONNET_5_5_MODELS = { AI_CONST.models.claude.CLAUDE_SONNET_5_5 }
local CLAUDE_OPUS_5_MODELS = { AI_CONST.models.claude.CLAUDE_OPUS_5, AI_CONST.models.claude.CLAUDE_OPUS_5_5 }
local KIMI_CHAT_MODELS = { AI_CONST.models.kimi.KIMI_K2_6, AI_CONST.models.kimi.KIMI_K2_7_CODE }
local GPT_5_6_CHAT_LEVELS = { "none", "low", "medium", "high", "xhigh" }
local GPT_5_6_CHAT_PRESETS = { "none", "low", "high", "xhigh" }
local GPT_6_CHAT_EFFORTS = { "none", "low", "medium", "high", "xhigh" }
local GPT_6_RESPONSES_EFFORTS = { "none", "low", "medium", "high", "xhigh", "max" }
local QWEN_CHAT_EFFORTS = { "none", "low", "medium", "xhigh" }
local GROK_CHAT_EFFORTS = { "low", "medium", "high", "xhigh" }
local GROK_4_7_EFFORTS = { "minimal", "low", "medium", "high", "xhigh" }
local GEMINI_3_7_3_8_FLASH_EFFORTS = { "low", "medium", "high" }
local KIMI_CHAT_EFFORTS = { "low", "medium", "high", "xhigh", "max" }
local PROBE_GPT_5_6 = "verified_proxy_probe_2026_08_19"
local PROBE_QWEN = "verified_proxy_probe_2026_08_27"
local PROBE_GROK_KIMI = "verified_proxy_probe_2026_08_23"
local PROBE_FRONTIER_CHAT = "verified_proxy_probe_2026_09_30_chat"
local PROBE_FRONTIER_RESPONSES = "verified_proxy_probe_2026_09_30_responses"

local VERIFIED_ROUTE_POLICIES = {
  openai_agd = {
    -- Chat Completions accepts xhigh but rejects minimal/max (2026-08-19).
    strict_verified_route_policy(GPT_5_6_MODELS, GPT_5_6_CHAT_PRESETS, PROBE_GPT_5_6, {
      levels = GPT_5_6_CHAT_LEVELS,
      conflicts = REASONING_SAMPLING_CONFLICTS,
      -- Luna's tools + non-none conflict was observed on Chat Completions
      -- (2026-09-29); no other model inherits this without its own probe.
      tool_required_effort = { [AI_CONST.models.gpt.GPT_5_6_LUNA] = "none" },
    }),
    strict_verified_route_policy(QWEN_3_8_MODELS, QWEN_CHAT_EFFORTS, PROBE_QWEN),
    strict_verified_route_policy(GROK_OPTIONAL_CHAT_MODELS, GROK_CHAT_EFFORTS, PROBE_GROK_KIMI),
    strict_verified_route_policy(
      GROK_REQUIRED_CHAT_MODELS,
      GROK_CHAT_EFFORTS,
      PROBE_GROK_KIMI,
      { mode = "required" }
    ),
    strict_verified_route_policy(KIMI_CHAT_MODELS, KIMI_CHAT_EFFORTS, PROBE_GROK_KIMI),
    -- GPT-6 Chat accepts the five values below. With function tools, both
    -- Sol and Luna require `none`; Responses retains reasoning + tools.
    strict_verified_route_policy(
      GPT_6_MODELS,
      GPT_6_CHAT_EFFORTS,
      PROBE_FRONTIER_CHAT,
      {
        conflicts = REASONING_SAMPLING_CONFLICTS,
        tool_required_effort = {
          [AI_CONST.models.gpt.GPT_6_SOL] = "none",
          [AI_CONST.models.gpt.GPT_6_LUNA] = "none",
        },
      }
    ),
    strict_verified_route_policy(
      GROK_4_7_MODELS,
      GROK_4_7_EFFORTS,
      PROBE_FRONTIER_CHAT,
      { mode = "required" }
    ),
    strict_verified_route_policy(
      GEMINI_3_7_3_8_FLASH_MODELS,
      GEMINI_3_7_3_8_FLASH_EFFORTS,
      PROBE_FRONTIER_CHAT,
      { mode = "required" }
    ),
    strict_verified_route_policy(CLAUDE_SONNET_5_MODELS, COMMON_LEVELS, PROBE_FRONTIER_CHAT),
    strict_verified_route_policy(CLAUDE_SONNET_5_5_MODELS, COMMON_LEVELS, PROBE_FRONTIER_CHAT, {
      mode = "required",
    }),
  },
  openai_responses_agd = {
    -- Responses accepts xhigh/max for every 5.6 tier (2026-08-19).
    verified_route_policy(GPT_5_6_MODELS, { "low", "high", "xhigh", "max" }, PROBE_GPT_5_6, {
      conflicts = REASONING_SAMPLING_CONFLICTS,
    }),
    strict_verified_route_policy(
      GPT_6_MODELS,
      GPT_6_RESPONSES_EFFORTS,
      PROBE_FRONTIER_RESPONSES,
      { conflicts = REASONING_SAMPLING_CONFLICTS }
    ),
    strict_verified_route_policy(
      GROK_4_7_MODELS,
      GROK_4_7_EFFORTS,
      PROBE_FRONTIER_RESPONSES,
      { mode = "required" }
    ),
  },
}

-- User-requested catalog/future aliases deliberately remain separate from the
-- route-proven table above. They map to a canonical model and effort, but do
-- not create strict validation, a Responses capability, or a tools policy.
-- GPT-6.1 aliases appear in the normal selector only after dynamic discovery
-- exposes their base IDs; prompt entries remain labelled as future choices.
local ADVISORY_SELECTOR_POLICIES = {
  openai_agd = {
    { models = GPT_6_1_MODELS, selector_efforts = GPT_6_CHAT_EFFORTS },
    { models = CLAUDE_OPUS_5_MODELS, selector_efforts = COMMON_LEVELS },
  },
}

local profiles = {}
local capability_rules = {}
local metadata_capabilities = {}
local rule_sequence = 0
local chat_state = setmetatable({}, { __mode = "k" })
local attached_chats_by_bufnr = setmetatable({}, { __mode = "v" })
local metadata_state = {
  loading = false,
  fetched_at = nil,
  count = 0,
  error = nil,
}
local sync_chat_yaml
local sync_debug_buffers

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "CodeCompanion Thinking" })
end

local function copy(value)
  return type(value) == "table" and vim.deepcopy(value) or value
end

local function adapter_name(adapter)
  if type(adapter) == "string" then
    return adapter
  end
  return adapter and adapter.name or nil
end

---Return local model-selector presets for an adapter. Each preset is resolved
---to its canonical AGD model and reasoning field before the request is sent.
---Route-proven presets have strict capability rules; explicit future/catalog
---aliases are advisory until their exact route is tested.
---@param adapter CodeCompanion.HTTPAdapter|string|table
---@return table[]
function M.model_selector_presets(adapter)
  local presets = {}
  local name = adapter_name(adapter)
  for _, specs in ipairs({
    VERIFIED_ROUTE_POLICIES[name] or {},
    ADVISORY_SELECTOR_POLICIES[name] or {},
  }) do
    for _, spec in ipairs(specs) do
      for _, model in ipairs(spec.models) do
        for _, effort in ipairs(spec.selector_efforts or {}) do
          table.insert(presets, {
            alias = model .. "-" .. effort,
            model = model,
            effort = effort,
          })
        end
      end
    end
  end
  return presets
end

local function selector_preset_for(adapter, model)
  if type(model) ~= "string" then
    return nil
  end
  for _, preset in ipairs(M.model_selector_presets(adapter)) do
    if preset.alias == model then
      return preset
    end
  end
end

---Resolve a local selector alias such as `gpt-5.6-luna-xhigh`.
---@param adapter CodeCompanion.HTTPAdapter|string|table
---@param model string|nil
---@return table|nil
function M.resolve_model_selector_preset(adapter, model)
  return copy(selector_preset_for(adapter, model))
end

---Return the real proxy model for a selector alias, or the original model.
---@param adapter CodeCompanion.HTTPAdapter|string|table
---@param model string|nil
---@return string|nil
function M.canonical_model(adapter, model)
  local preset = selector_preset_for(adapter, model)
  return preset and preset.model or model
end

---Append supported selector aliases to a CodeCompanion model choices map.
---The base model must already be present, which keeps dynamic AGD discovery
---authoritative about availability.
---@param adapter CodeCompanion.HTTPAdapter|string|table
---@param choices table|nil
---@return table
function M.expand_model_choices(adapter, choices)
  local expanded = vim.deepcopy(choices or {})
  for _, preset in ipairs(M.model_selector_presets(adapter)) do
    local base_entry = expanded[preset.model]
    if base_entry ~= nil then
      local entry = type(base_entry) == "table" and vim.deepcopy(base_entry) or {}
      entry.formatted_name = ("%s [%s]"):format(entry.formatted_name or preset.model, preset.effort)
      entry.opts = vim.tbl_extend("force", type(entry.opts) == "table" and entry.opts or {}, { can_reason = true })
      expanded[preset.alias] = entry
    end
  end
  return expanded
end

local function resolve_value(value, adapter)
  if type(value) ~= "function" then
    return value
  end
  local ok, resolved = pcall(value, adapter)
  return ok and resolved or nil
end

local function adapter_model(adapter)
  if not adapter then
    return nil
  end
  -- `CodeCompanion.chat({ params = { model = ... } })` updates schema.default
  -- after resolving the adapter, so adapter.model.name can briefly be stale.
  local schema_model = adapter.schema and adapter.schema.model and adapter.schema.model.default
  local resolved_schema_model = resolve_value(schema_model, adapter)
  if type(resolved_schema_model) == "string" then
    return resolved_schema_model
  end
  if adapter.model and type(adapter.model.name) == "string" then
    return adapter.model.name
  end
  if adapter.parameters and type(adapter.parameters.model) == "string" then
    return adapter.parameters.model
  end
end

local function chat_model(chat)
  return adapter_model(chat and chat.adapter) or (chat and chat.settings and chat.settings.model)
end

local function get_path(root, path)
  local current = root
  for _, segment in ipairs(path or {}) do
    if type(current) ~= "table" then
      return nil
    end
    current = current[segment]
  end
  return current
end

local function set_path(root, path, value)
  if type(root) ~= "table" or type(path) ~= "table" or #path == 0 then
    return
  end

  local current = root
  for i = 1, #path - 1 do
    local segment = path[i]
    current[segment] = type(current[segment]) == "table" and current[segment] or {}
    current = current[segment]
  end
  current[path[#path]] = value
end

local function unset_path(root, path)
  if type(root) ~= "table" or type(path) ~= "table" or #path == 0 then
    return
  end

  local current = root
  local parents = {}
  for i = 1, #path - 1 do
    local segment = path[i]
    if type(current[segment]) ~= "table" then
      return
    end
    table.insert(parents, { parent = current, key = segment })
    current = current[segment]
  end
  current[path[#path]] = nil

  for i = #parents, 1, -1 do
    local item = parents[i]
    if type(item.parent[item.key]) == "table" and vim.tbl_isempty(item.parent[item.key]) then
      item.parent[item.key] = nil
    else
      break
    end
  end
end

function M.register_profile(name, profile)
  assert(type(name) == "string" and name ~= "", "thinking profile requires an adapter name")
  assert(type(profile) == "table" and type(profile.schema_key) == "string", "thinking profile requires schema_key")
  assert(type(profile.param_path) == "table" and #profile.param_path > 0, "thinking profile requires param_path")
  profiles[name] = vim.deepcopy(profile)
  return M
end

M.register_profile("openai_agd", {
  schema_key = "reasoning_effort",
  param_path = { "reasoning_effort" },
  sampling_defaults = { temperature = 1, top_p = 1 },
})

M.register_profile("openai_responses_agd", {
  schema_key = "reasoning.effort",
  param_path = { "reasoning", "effort" },
  sampling_defaults = { temperature = 1, top_p = 1 },
  default_conflicts = { temperature = "non_default", top_p = "non_default" },
})

function M.profile_for(adapter)
  local name = adapter_name(adapter)
  if name and profiles[name] then
    return profiles[name]
  end

  local schema = type(adapter) == "table" and adapter.schema or nil
  if schema and schema["reasoning.effort"] then
    return {
      schema_key = "reasoning.effort",
      param_path = { "reasoning", "effort" },
      sampling_defaults = { temperature = 1, top_p = 1 },
    }
  end
  if schema and schema.reasoning_effort then
    return {
      schema_key = "reasoning_effort",
      param_path = { "reasoning_effort" },
      sampling_defaults = { temperature = 1, top_p = 1 },
    }
  end
end

local function matches_rule(rule, adapter, model)
  if rule.adapter ~= "*" and rule.adapter ~= adapter_name(adapter) then
    return false
  end
  if type(rule.matcher) == "function" then
    local ok, matched = pcall(rule.matcher, model, adapter)
    return ok and matched == true
  end
  if rule.pattern then
    return type(model) == "string" and model:match(rule.matcher) ~= nil
  end
  return model == rule.matcher
end

function M.register_capability(adapter, matcher, capability, opts)
  opts = opts or {}
  assert(type(adapter) == "string", "capability requires an adapter name")
  assert(type(matcher) == "string" or type(matcher) == "function", "capability requires a model matcher")
  assert(type(capability) == "table", "capability must be a table")

  rule_sequence = rule_sequence + 1
  table.insert(capability_rules, {
    adapter = adapter,
    matcher = matcher,
    pattern = opts.pattern == true,
    priority = opts.priority or 100,
    sequence = rule_sequence,
    capability = vim.deepcopy(capability),
  })
  return M
end

local function register_verified_route_policies()
  for adapter, specs in pairs(VERIFIED_ROUTE_POLICIES) do
    for _, spec in ipairs(specs) do
      for _, model in ipairs(spec.models) do
        local capability = vim.deepcopy(spec.capability)
        local required_effort = spec.tool_required_effort and spec.tool_required_effort[model]
        if required_effort then
          capability.tool_required_effort = required_effort
        end
        M.register_capability(adapter, model, capability, { priority = 100 })
      end
    end
  end
end

local function merge_capability(target, source)
  for key, value in pairs(source or {}) do
    target[key] = copy(value)
  end
  return target
end

local function upstream_reasoning_hint(adapter, model)
  if type(adapter) ~= "table" then
    return nil
  end
  if adapter.model and adapter.model.name == model and adapter.model.opts and adapter.model.opts.can_reason then
    return true
  end

  local choices = adapter.schema and adapter.schema.model and adapter.schema.model.choices
  if type(choices) == "table" then
    local entry = choices[model]
    return entry and entry.opts and entry.opts.can_reason == true or nil
  end
end

function M.resolve_capability(adapter, model)
  model = M.canonical_model(adapter, model or adapter_model(adapter))
  local candidates = {}

  if upstream_reasoning_hint(adapter, model) then
    table.insert(candidates, {
      priority = 10,
      sequence = 0,
      capability = { status = "supported", source = "upstream_model_hint" },
    })
  end

  for _, rule in ipairs(capability_rules) do
    if matches_rule(rule, adapter, model) then
      table.insert(candidates, rule)
    end
  end

  if model and adapter_name(adapter) == "openai_agd" and metadata_capabilities[model] then
    table.insert(candidates, {
      priority = 70,
      sequence = 0,
      capability = metadata_capabilities[model],
    })
  end

  table.sort(candidates, function(a, b)
    if a.priority == b.priority then
      return a.sequence < b.sequence
    end
    return a.priority < b.priority
  end)

  local result = {
    status = "unknown",
    source = "unknown",
    mode = "unknown",
    levels = vim.deepcopy(COMMON_LEVELS),
    conflicts = {},
  }
  for _, candidate in ipairs(candidates) do
    merge_capability(result, candidate.capability)
  end
  return result
end

---Return the exact effort required when this Chat route has function tools.
---A nil return means the route has no verified tools/reasoning restriction.
---@param adapter CodeCompanion.HTTPAdapter|string|table
---@param model string|nil
---@return string|nil
function M.tool_required_effort(adapter, model)
  return M.resolve_capability(adapter, model).tool_required_effort
end

---Return the advertised reasoning levels for an adapter/model pair.
---Unknown capabilities deliberately fall back to the full common set so a
---new proxy model is not hidden behind stale local metadata.
---@param adapter CodeCompanion.HTTPAdapter|string|table
---@param model string|nil
---@return string[]
function M.levels_for(adapter, model)
  return vim.deepcopy(M.resolve_capability(adapter, model).levels or COMMON_LEVELS)
end

---Validate an explicitly selected effort only when the rule carries an exact,
---live-verified level set. Family hints and metadata remain advisory.
---@param adapter CodeCompanion.HTTPAdapter|string|table
---@param value any
---@param model string|nil
---@return boolean
---@return string|nil
function M.validate_effort(adapter, value, model)
  local capability = M.resolve_capability(adapter, model)
  if capability.enforce_levels ~= true or value == nil then
    return true
  end
  if type(value) == "string" and vim.tbl_contains(capability.levels or {}, value) then
    return true
  end

  local name = adapter_name(adapter) or "<unknown>"
  local selected_model = model or adapter_model(adapter) or "<unknown>"
  return false, ("%s is unsupported for %s/%s; supported values: %s"):format(
    tostring(value),
    name,
    selected_model,
    table.concat(capability.levels or {}, ", ")
  )
end

local function has_feature(record, feature_name)
  for _, feature in ipairs(record.features or {}) do
    local name = type(feature) == "table" and feature.name or feature
    if name == feature_name then
      return true
    end
  end
  return false
end

local function supports_chat_completions(record)
  if record.isChatModel == false then
    return false
  end
  local endpoints = record.supported_endpoints
  if type(endpoints) ~= "table" or #endpoints == 0 then
    return true
  end
  return vim.tbl_contains(endpoints, "/v1/chat/completions")
end

local function capability_from_metadata(record)
  local raw = tostring(record.thinkingCapability or "None"):lower()
  local thinking_feature = has_feature(record, "Thinking")
  local status = "unsupported"
  local mode = "none"
  local levels = vim.deepcopy(COMMON_LEVELS)

  if raw == "obligatory" or raw == "required" then
    status = "supported"
    mode = "required"
    levels = vim.deepcopy(REQUIRED_LEVELS)
  elseif raw == "optional" then
    status = "supported"
    mode = "optional"
  elseif raw ~= "" and raw ~= "none" then
    status = "supported"
    mode = "vendor_" .. raw
  elseif thinking_feature then
    status = "supported"
    mode = "vendor_reported"
  end

  local maker = tostring(record.maker or ""):upper()
  local capability = {
    status = status,
    source = "agd_model_metadata",
    mode = mode,
    levels = levels,
    observed = {
      maker = record.maker,
      thinking_capability = record.thinkingCapability,
      thinking_feature = thinking_feature,
    },
  }
  if status == "supported" and maker == "OPENAI" then
    capability.conflicts = { temperature = "non_default", top_p = "non_default" }
  end
  return capability
end

function M.ingest_capability_metadata(payload)
  if type(payload) == "string" then
    local ok, decoded = pcall(vim.json.decode, payload)
    if not ok then
      return false, "invalid JSON"
    end
    payload = decoded
  end

  local records = type(payload) == "table" and (payload.models or payload.data or payload) or nil
  if type(records) ~= "table" then
    return false, "model metadata has no records"
  end

  local next_capabilities = {}
  local count = 0
  for _, record in pairs(records) do
    if type(record) == "table" and type(record.name) == "string" and supports_chat_completions(record) then
      next_capabilities[record.name] = capability_from_metadata(record)
      count = count + 1
    end
  end
  metadata_capabilities = next_capabilities
  metadata_state.count = count
  metadata_state.fetched_at = os.time()
  metadata_state.error = nil
  return true, count
end

function M.refresh_capabilities(opts)
  opts = opts or {}
  local now = os.time()
  local ttl = opts.ttl or 3600
  if metadata_state.loading then
    return false, "already loading"
  end
  if not opts.force and metadata_state.fetched_at and now - metadata_state.fetched_at < ttl then
    return true, "cached"
  end
  if type(vim.system) ~= "function" then
    return false, "vim.system is unavailable"
  end

  local url = AI_CONST.endpoints.agoda.OPENAI_PROXY_MODEL_DETAILS
    or (AI_CONST.endpoints.agoda.OPENAI_PROXY .. "/internal/models?format=detailed")
  metadata_state.loading = true
  metadata_state.error = nil

  vim.system({ "curl", "--silent", "--show-error", "--fail", "--max-time", tostring(opts.timeout or 5), url }, {
    text = true,
  }, function(result)
    vim.schedule(function()
      metadata_state.loading = false
      if result.code ~= 0 then
        metadata_state.error = ("metadata request failed (exit %d)"):format(result.code or -1)
        if opts.notify then
          notify(metadata_state.error, vim.log.levels.WARN)
        end
        return
      end

      local ok, detail = M.ingest_capability_metadata(result.stdout or "")
      if not ok then
        metadata_state.error = detail
        if opts.notify then
          notify(detail, vim.log.levels.WARN)
        end
        return
      end
      if opts.notify then
        notify(("Loaded thinking metadata for %d chat models"):format(detail))
      end
    end)
  end)
  return true, "started"
end

local function state_for(chat)
  local state = chat_state[chat]
  if not state then
    state = { overrides = {}, attached = false }
    chat_state[chat] = state
  end
  return state
end

local function override_key(chat, model)
  local name = adapter_name(chat and chat.adapter) or "<unknown>"
  return name .. "\0" .. (model or chat_model(chat) or "<unknown>")
end

local function store_override(chat, model, value, source)
  local state = state_for(chat)
  local key = override_key(chat, model)
  if value == nil then
    state.overrides[key] = nil
    return
  end
  state.overrides[key] = {
    value = copy(value),
    source = source or "manual",
    last_applied = copy(value),
  }
end

function M.capture_manual(chat, opts)
  opts = opts or {}
  if not chat or type(chat.settings) ~= "table" then
    return false
  end
  local profile = M.profile_for(chat.adapter)
  if not profile then
    return false
  end

  local model = opts.model or chat_model(chat)
  local key = override_key(chat, model)
  local state = state_for(chat)
  local record = state.overrides[key]
  local current = chat.settings[profile.schema_key]

  if not record then
    if current ~= nil then
      local preset = selector_preset_for(chat.adapter, model)
      if preset and current == preset.effort then
        return false
      end
      store_override(chat, model, current, opts.source or "manual")
      return true
    end
    return false
  end

  if not vim.deep_equal(current, record.last_applied) then
    if current == nil then
      state.overrides[key] = nil
    else
      store_override(chat, model, current, opts.source or "manual")
    end
    return true
  end
  return false
end

function M.reconcile(chat)
  if not chat then
    return false
  end
  chat.settings = chat.settings or {}
  local profile = M.profile_for(chat.adapter)
  if not profile then
    return false
  end

  local model = chat_model(chat)
  local record = state_for(chat).overrides[override_key(chat, model)]
  local changed = false
  if record then
    chat.settings[profile.schema_key] = copy(record.value)
    record.last_applied = copy(record.value)
    changed = true
  else
    local preset = selector_preset_for(chat.adapter, model)
    if preset and chat.settings[profile.schema_key] == nil then
      chat.settings[profile.schema_key] = preset.effort
      changed = true
    end
  end

  if sync_chat_yaml then
    sync_chat_yaml(chat, "model", model)
    sync_chat_yaml(chat, profile.schema_key, chat.settings[profile.schema_key])
  end
  if sync_debug_buffers then
    sync_debug_buffers(chat, "model", model)
    sync_debug_buffers(chat, profile.schema_key, chat.settings[profile.schema_key])
  end
  return changed
end

local function bind_chat_to_adapter(chat)
  local bufnr = chat and chat.bufnr
  if type(bufnr) ~= "number" or type(chat.adapter) ~= "table" then
    return
  end
  attached_chats_by_bufnr[bufnr] = chat
  -- The HTTP client deep-copies adapters before forming a body. Retain only a
  -- scalar identity here, then resolve the original chat below.
  chat.adapter._thinking_chat_bufnr = bufnr
end

local function attached_chat_for_adapter(adapter)
  local bufnr = adapter and adapter._thinking_chat_bufnr
  if type(bufnr) ~= "number" then
    return nil
  end
  return attached_chats_by_bufnr[bufnr]
end

local function tool_schema_count(chat)
  local schemas = chat and chat.tool_registry and chat.tool_registry.schemas
  return type(schemas) == "table" and vim.tbl_count(schemas) or 0
end

local function tool_reasoning_conflict_for(adapter, model, effort, tool_count)
  if adapter_name(adapter) ~= "openai_agd" then
    return nil
  end

  model = M.canonical_model(adapter, model)
  local required_effort = M.tool_required_effort(adapter, model)
  if type(required_effort) ~= "string" or type(effort) ~= "string" or effort:lower() == required_effort then
    return nil
  end
  if tool_count == 0 then
    return nil
  end

  return {
    effort = effort,
    key = table.concat({ adapter_name(adapter), model, effort }, "\0"),
    model = model,
    required_effort = required_effort,
    tool_count = tool_count,
  }
end

---Return a verified Chat Completions tools/reasoning conflict for this chat.
---The model policy is intentionally exact: dynamic model discovery alone does
---not establish that an arbitrary catalog model shares the GPT-5.6 Luna or
---GPT-6 Sol/Luna contract.
---@param chat CodeCompanion.Chat|table
---@return table|nil
function M.tool_reasoning_conflict(chat)
  if not chat or adapter_name(chat.adapter) ~= "openai_agd" then
    return nil
  end

  local selected_model = chat_model(chat)
  local model = M.canonical_model(chat.adapter, selected_model)
  local profile = M.profile_for(chat.adapter)
  local effort = profile and chat.settings and chat.settings[profile.schema_key] or nil
  local preset = selector_preset_for(chat.adapter, selected_model)
  if effort == nil and preset then
    effort = preset.effort
  end
  return tool_reasoning_conflict_for(chat.adapter, model, effort, tool_schema_count(chat))
end

local function pending_submission_conflict(chat)
  if not chat then
    return nil
  end

  local settings
  if type(chat.bufnr) == "number" and chat.parsers and chat.parsers.yaml then
    local ok_parser, parser = pcall(require, "codecompanion.interactions.chat.parser")
    if ok_parser then
      local ok_settings, parsed = pcall(parser.settings, chat.bufnr, chat.parsers.yaml, chat.adapter)
      if ok_settings and type(parsed) == "table" then
        settings = parsed
      end
    end
  end
  if not settings then
    return M.tool_reasoning_conflict(chat)
  end

  local selected_model = settings.model or chat_model(chat)
  local model = M.canonical_model(chat.adapter, selected_model)
  local profile = M.profile_for(chat.adapter)
  local effort = profile and settings[profile.schema_key] or nil
  local preset = selector_preset_for(chat.adapter, selected_model)
  if effort == nil and preset then
    effort = preset.effort
  end
  return tool_reasoning_conflict_for(chat.adapter, model, effort, tool_schema_count(chat))
end

---Show one non-blocking warning per active model/effort/tool combination.
---Changing models remains synchronous because CodeCompanion can do it as part
---of a YAML submission. The explicit `none` action is safe before the next
---submission and keeps the visible YAML/debug settings in sync.
---@param chat CodeCompanion.Chat|table
---@return boolean whether a warning was scheduled
function M.warn_if_tool_reasoning_conflict(chat)
  if not chat then
    return false
  end
  local conflict = M.tool_reasoning_conflict(chat)
  local state = state_for(chat)
  if not conflict then
    state.tool_reasoning_warning_key = nil
    return false
  end

  if state.tool_reasoning_warning_key == conflict.key then
    return false
  end
  state.tool_reasoning_warning_key = conflict.key

  vim.schedule(function()
    local current = M.tool_reasoning_conflict(chat)
    if not current or current.key ~= conflict.key then
      return
    end

    local apply_none = ("Set reasoning_effort=%s (recommended)"):format(current.required_effort)
    local keep = "Keep current reasoning (use Responses for tools)"
    vim.ui.select({ apply_none, keep }, {
      prompt = (
        "%s has %d active function tool(s). AGD Chat Completions rejects %s reasoning_effort=%s with tools."
      ):format(current.model, current.tool_count, current.model, current.effort),
    }, function(choice)
      if choice == apply_none then
        local confirmed = M.tool_reasoning_conflict(chat)
        if confirmed and confirmed.key == current.key then
          state.tool_reasoning_warning_key = nil
          M.set(confirmed.required_effort, { chat = chat, source = "tool_reasoning_popup" })
        end
      end
    end)
  end)
  return true
end

function M.prepare(chat)
  M.capture_manual(chat)
  return M.reconcile(chat)
end

local function debug_chat_number(bufnr)
  local first_line = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] or ""
  return tonumber(first_line:match("^%-%- Buffer Number:%s*(%d+)"))
end

local function chat_from_debug_buffer(bufnr)
  local chat_bufnr = debug_chat_number(bufnr)
  if not chat_bufnr then
    return nil
  end
  local ok, codecompanion = pcall(require, "codecompanion")
  return ok and codecompanion.buf_get_chat(chat_bufnr) or nil
end

function M.resolve_chat(chat)
  if chat then
    return chat, "argument"
  end

  local ok, codecompanion = pcall(require, "codecompanion")
  if not ok then
    return nil, "CodeCompanion is not loaded"
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local current = codecompanion.buf_get_chat(bufnr)
  if current then
    return current, "chat"
  end

  local name = vim.api.nvim_buf_get_name(bufnr)
  if name:match("CodeCompanion_debug$") then
    local debug_chat = chat_from_debug_buffer(bufnr)
    if debug_chat then
      return debug_chat, "debug", bufnr
    end
  end

  return nil, "current buffer is not a CodeCompanion chat or debug window"
end

local function setting_key_on_line(line)
  return line:match('^%s*%["([^"]+)"%]%s*=') or line:match("^%s*([%w_]+)%s*=")
end

local function sync_debug_buffer(bufnr, schema_key, value)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local lhs = schema_key:find("%.") and ('["' .. schema_key .. '"]') or schema_key
  local rhs = value == nil and "nil" or string.format("%q", tostring(value))
  local replacement = "  " .. lhs .. " = " .. rhs .. ","
  local settings_start, settings_end

  for index, line in ipairs(lines) do
    if line:match("^local settings%s*=%s*{") then
      settings_start = index
    elseif settings_start and line:match("^}") then
      settings_end = index
      break
    elseif settings_start and setting_key_on_line(line) == schema_key then
      vim.api.nvim_buf_set_lines(bufnr, index - 1, index, false, { replacement })
      return
    end
  end

  if settings_start and settings_end then
    vim.api.nvim_buf_set_lines(bufnr, settings_end - 1, settings_end - 1, false, { replacement })
  end
end

sync_chat_yaml = function(chat, schema_key, value)
  local bufnr = chat and chat.bufnr
  if type(bufnr) ~= "number" or not vim.api.nvim_buf_is_loaded(bufnr) then
    return
  end
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  if lines[1] ~= "---" then
    return
  end

  local function set_lines(start_index, end_index, replacement)
    local was_modifiable = vim.bo[bufnr].modifiable
    if not was_modifiable then
      vim.bo[bufnr].modifiable = true
    end
    local ok = pcall(vim.api.nvim_buf_set_lines, bufnr, start_index, end_index, false, replacement)
    if not was_modifiable and vim.api.nvim_buf_is_valid(bufnr) then
      vim.bo[bufnr].modifiable = false
    end
    return ok
  end

  local closing
  for index = 2, #lines do
    local line = lines[index]
    if line == "---" then
      closing = index
      break
    end
    local key = line:match("^([^:]+):")
    if key and vim.trim(key) == schema_key then
      local encoded = require("codecompanion.utils.yaml").encode(value)
      set_lines(index - 1, index, { schema_key .. ": " .. encoded })
      return
    end
  end

  if closing then
    local encoded = require("codecompanion.utils.yaml").encode(value)
    set_lines(closing - 1, closing - 1, { schema_key .. ": " .. encoded })
  end
end

sync_debug_buffers = function(chat, schema_key, value)
  if not chat or type(chat.bufnr) ~= "number" then
    return
  end
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr)
      and vim.api.nvim_buf_get_name(bufnr):match("CodeCompanion_debug$")
      and debug_chat_number(bufnr) == chat.bufnr
    then
      sync_debug_buffer(bufnr, schema_key, value)
    end
  end
end

local function resolve_opts(opts)
  if opts and opts.adapter then
    return { chat = opts }
  end
  return opts or {}
end

function M.set(value, opts)
  opts = resolve_opts(opts)
  value = type(value) == "string" and vim.trim(value) or value
  if type(value) ~= "string" or value == "" then
    notify("Thinking value must be a non-empty string", vim.log.levels.WARN)
    return false
  end
  if CLEAR_VALUES[value:lower()] then
    return M.clear(opts)
  end

  local chat, source = M.resolve_chat(opts.chat)
  if not chat then
    notify(source, vim.log.levels.WARN)
    return false
  end
  local profile = M.profile_for(chat.adapter)
  if not profile then
    local name = adapter_name(chat.adapter) or "<unknown>"
    notify(("No thinking wire profile for adapter %s"):format(name), vim.log.levels.WARN)
    return false
  end

  local model = chat_model(chat) or "<unknown>"
  local capability = M.resolve_capability(chat.adapter, model)
  local valid, validation_error = M.validate_effort(chat.adapter, value, model)
  if not valid then
    notify(validation_error, vim.log.levels.WARN)
    return false
  end

  chat.settings = chat.settings or {}
  store_override(chat, model, value, opts.source or "toggle")
  chat.settings[profile.schema_key] = value
  sync_chat_yaml(chat, profile.schema_key, value)
  sync_debug_buffers(chat, profile.schema_key, value)

  local message = ("Set %s=%s for %s/%s (%s; capability=%s/%s)"):format(
    profile.schema_key,
    value,
    adapter_name(chat.adapter) or "<unknown>",
    model,
    source,
    capability.status,
    capability.source
  )
  local outside_advertised = capability.status == "supported"
    and type(capability.levels) == "table"
    and not vim.tbl_contains(capability.levels, value)
  if outside_advertised then
    message = message .. "; value is outside the advertised levels and will be passed through manually"
  end
  notify(
    message,
    (capability.status == "unsupported" or outside_advertised) and vim.log.levels.WARN or vim.log.levels.INFO
  )
  M.warn_if_tool_reasoning_conflict(chat)
  return true
end

M.apply = M.set

function M.clear(opts)
  opts = resolve_opts(opts)
  local chat, source = M.resolve_chat(opts.chat)
  if not chat then
    notify(source, vim.log.levels.WARN)
    return false
  end
  local profile = M.profile_for(chat.adapter)
  if not profile then
    local name = adapter_name(chat.adapter) or "<unknown>"
    notify(("No thinking wire profile for adapter %s"):format(name), vim.log.levels.WARN)
    return false
  end

  chat.settings = chat.settings or {}
  state_for(chat).overrides[override_key(chat)] = nil
  chat.settings[profile.schema_key] = nil
  sync_chat_yaml(chat, profile.schema_key, nil)
  sync_debug_buffers(chat, profile.schema_key, nil)
  state_for(chat).tool_reasoning_warning_key = nil
  notify(("Cleared thinking override for %s/%s (%s)"):format(
    adapter_name(chat.adapter) or "<unknown>",
    chat_model(chat) or "<unknown>",
    source
  ))
  return true
end

local function unique_levels(levels)
  local seen, result = {}, {}
  for _, level in ipairs(levels or COMMON_LEVELS) do
    if type(level) == "string" and not seen[level] then
      seen[level] = true
      table.insert(result, level)
    end
  end
  return result
end

function M.pick(chat)
  local resolved, source = M.resolve_chat(chat)
  if not resolved then
    notify(source, vim.log.levels.WARN)
    return
  end
  local profile = M.profile_for(resolved.adapter)
  if not profile then
    local name = adapter_name(resolved.adapter) or "<unknown>"
    notify(("No thinking wire profile for adapter %s"):format(name), vim.log.levels.WARN)
    return
  end

  local model = chat_model(resolved) or "<unknown>"
  local capability = M.resolve_capability(resolved.adapter, model)
  local choices = unique_levels(capability.levels)
  local current = resolved.settings and resolved.settings[profile.schema_key]
  if current and not vim.tbl_contains(choices, current) and capability.enforce_levels ~= true then
    table.insert(choices, 1, current)
  end
  if capability.enforce_levels ~= true then
    table.insert(choices, "<custom value…>")
  end
  table.insert(choices, "<clear / inherit>")

  vim.ui.select(choices, {
    prompt = ("Thinking for %s [%s/%s, current=%s]:"):format(
      model,
      capability.status,
      capability.mode,
      current == nil and "inherit" or tostring(current)
    ),
  }, function(choice)
    if choice == "<clear / inherit>" then
      M.clear({ chat = resolved })
    elseif choice == "<custom value…>" then
      vim.ui.input({ prompt = "reasoning effort: ", default = current and tostring(current) or "" }, function(custom)
        if custom and vim.trim(custom) ~= "" then
          M.set(custom, { chat = resolved })
        end
      end)
    elseif choice then
      M.set(choice, { chat = resolved })
    end
  end)
end

function M.inspect(chat)
  local resolved, source = M.resolve_chat(chat)
  if not resolved then
    notify(source, vim.log.levels.WARN)
    return
  end
  local profile = M.profile_for(resolved.adapter)
  local model = chat_model(resolved) or "<unknown>"
  local record = state_for(resolved).overrides[override_key(resolved)]
  notify(vim.inspect({
    adapter = adapter_name(resolved.adapter),
    model = model,
    field = profile and profile.schema_key or nil,
    capability = M.resolve_capability(resolved.adapter, model),
    override = record,
    effective = profile and resolved.settings and resolved.settings[profile.schema_key] or nil,
    metadata = vim.deepcopy(metadata_state),
  }))
end

function M.map_settings(adapter, settings)
  local profile = M.profile_for(adapter)
  if settings == nil and type(adapter.make_from_schema) == "function" then
    settings = adapter:make_from_schema()
  else
    settings = vim.deepcopy(settings or {})
  end

  local preset = selector_preset_for(adapter, settings.model)
  if preset then
    settings.model = preset.model
    -- A model alias supplies an initial value. An explicit setting in the YAML,
    -- picker, or prompt callback remains the user's later override.
    if profile and settings[profile.schema_key] == nil then
      settings[profile.schema_key] = preset.effort
    end
  end

  if profile then
    adapter.parameters = adapter.parameters or {}
    unset_path(adapter.parameters, profile.param_path)
  end
  return require("codecompanion.adapters.http").map_schema_to_params(adapter, settings)
end

local function should_drop_sampling(rule, value, default)
  if rule == true or rule == "always" then
    return value ~= nil
  end
  if rule == "non_default" then
    return value ~= nil and value ~= default
  end
  if type(rule) == "function" then
    local ok, drop = pcall(rule, value, default)
    return ok and drop == true
  end
  return false
end

function M.prepare_request(adapter, params)
  local profile = M.profile_for(adapter)
  if not profile or type(params) ~= "table" then
    return params
  end
  local model = params.model or adapter_model(adapter)
  local preset = selector_preset_for(adapter, model)
  if preset then
    params.model = preset.model
    model = preset.model
  end

  local effort = get_path(params, profile.param_path)
  if effort == nil and preset then
    set_path(params, profile.param_path, preset.effort)
    effort = preset.effort
  end
  if effort == nil then
    return params
  end

  -- on_before_submit runs before CodeCompanion parses @tool references in the
  -- current prompt, and it does not run for auto-submit. This final adapter
  -- guard therefore keeps an after-parse tool from reaching AGD with Luna's
  -- known-invalid effort. The earlier popup still lets the user choose before
  -- normal submissions; this late path must select the only safe value.
  local chat = attached_chat_for_adapter(adapter)
  local tool_conflict = tool_reasoning_conflict_for(adapter, model, effort, tool_schema_count(chat))
  if tool_conflict then
    effort = tool_conflict.required_effort
    set_path(params, profile.param_path, effort)
    if chat then
      M.set(effort, { chat = chat, source = "tool_reasoning_request_guard" })
    end
    notify(
      ("Changed %s reasoning_effort to %s before sending because this prompt added %d function tool(s)."):format(
        tool_conflict.model,
        effort,
        tool_conflict.tool_count
      ),
      vim.log.levels.WARN
    )
  end

  local capability = M.resolve_capability(adapter, model)
  local valid, validation_error = M.validate_effort(adapter, effort, model)
  if not valid then
    unset_path(params, profile.param_path)
    notify(("Omitting unsupported %s=%s for %s/%s: %s"):format(
      profile.schema_key,
      tostring(effort),
      adapter_name(adapter) or "<unknown>",
      model or "<unknown>",
      validation_error
    ), vim.log.levels.WARN)
    return params
  end
  local explicit_none = type(effort) == "string" and effort:lower() == "none"
  if not explicit_none then
    local conflicts = capability.conflicts
    if (not conflicts or vim.tbl_isempty(conflicts)) and capability.status == "supported" then
      conflicts = profile.default_conflicts
    end
    for parameter, rule in pairs(conflicts or {}) do
      local default = profile.sampling_defaults and profile.sampling_defaults[parameter]
      if should_drop_sampling(rule, params[parameter], default) then
        params[parameter] = nil
      end
    end
  end
  if type(capability.request_transform) == "function" then
    local ok, transformed = pcall(capability.request_transform, vim.deepcopy(params), {
      adapter = adapter,
      effort = effort,
      model = model,
      profile = profile,
    })
    if ok and type(transformed) == "table" then
      params = transformed
    elseif not ok then
      notify(("Ignoring failed thinking request transform for %s/%s"):format(
        adapter_name(adapter) or "<unknown>",
        model or "<unknown>"
      ), vim.log.levels.WARN)
    end
  end
  return params
end

local function capture_before_model_change(chat, target_model)
  local current_model = chat_model(chat)
  local settings_model = chat.settings and chat.settings.model
  local profile = M.profile_for(chat.adapter)

  if profile and target_model and settings_model == target_model and target_model ~= current_model then
    local state = state_for(chat)
    local source = state.overrides[override_key(chat, current_model)]
    local target = state.overrides[override_key(chat, target_model)]
    local pending = chat.settings[profile.schema_key]

    -- Debug.save applies the whole visible source-model table before it calls
    -- change_model. Do not mistake that carried value for a target-model edit.
    if source and vim.deep_equal(pending, source.last_applied) then
      return
    end
    if not source and pending == nil then
      return
    end
    if target and vim.deep_equal(pending, target.value) then
      return
    end
    store_override(chat, target_model, pending, "manual")
    return
  end
  M.capture_manual(chat, { model = current_model })
end

local function wrap_chat(chat)
  local state = state_for(chat)
  if state.wrapped then
    return
  end
  state.wrapped = true

  if type(chat.apply_settings) == "function" then
    local apply_settings = chat.apply_settings
    chat.apply_settings = function(self, settings)
      local current_model = chat_model(self)
      local result = apply_settings(self, settings)
      local target_model = settings and settings.model or current_model
      if settings ~= nil and target_model == current_model then
        M.capture_manual(self, { model = current_model, source = "manual" })
      end
      return result
    end
  end

  if type(chat.change_model) == "function" then
    local change_model = chat.change_model
    chat.change_model = function(self, args)
      capture_before_model_change(self, args and args.model)
      local result = change_model(self, args)
      M.reconcile(self)
      M.warn_if_tool_reasoning_conflict(self)
      return result
    end
  end

  if type(chat.change_adapter) == "function" then
    local change_adapter = chat.change_adapter
    chat.change_adapter = function(self, name, callback)
      M.capture_manual(self)
      local result = change_adapter(self, name, callback)
      if result ~= false then
        bind_chat_to_adapter(self)
        M.reconcile(self)
        M.warn_if_tool_reasoning_conflict(self)
      end
      return result
    end
  end

  if type(chat.add_callback) == "function" then
    chat:add_callback("on_before_submit", function(current_chat)
      local conflict = pending_submission_conflict(current_chat)
      if not conflict then
        return
      end
      M.warn_if_tool_reasoning_conflict(current_chat)
      notify(
        ("Blocked %s with %d active function tool(s): set reasoning_effort=%s or use Responses."):format(
          conflict.model,
          conflict.tool_count,
          conflict.required_effort
        ),
        vim.log.levels.WARN
      )
      return false
    end)
  end
end

function M.attach(chat)
  if not chat then
    return false
  end
  bind_chat_to_adapter(chat)
  local state = state_for(chat)
  if state.attached then
    return true
  end
  state.attached = true
  M.capture_manual(chat)
  wrap_chat(chat)
  M.reconcile(chat)
  M.warn_if_tool_reasoning_conflict(chat)
  return true
end

local function chat_for_buffer(bufnr)
  if type(bufnr) ~= "number" then
    return nil
  end
  local ok, codecompanion = pcall(require, "codecompanion")
  return ok and codecompanion.buf_get_chat(bufnr) or nil
end

function M.setup(opts)
  opts = opts or {}
  if M._setup_done then
    return
  end
  M._setup_done = true

  vim.api.nvim_create_user_command("CodeCompanionThinking", function(cmd)
    local arg = vim.trim(cmd.args or "")
    if arg == "" then
      return M.pick()
    end
    if arg == "inspect" then
      return M.inspect()
    end
    if arg == "refresh" then
      return M.refresh_capabilities({ force = true, notify = true })
    end
    return M.set(arg)
  end, {
    nargs = "?",
    force = true,
    complete = function()
      return vim.list_extend(vim.deepcopy(COMMON_LEVELS), { "clear", "inherit", "inspect", "refresh" })
    end,
    desc = "Control thinking on the current CodeCompanion chat/debug window",
  })

  local group = vim.api.nvim_create_augroup("CodeCompanionThinking", { clear = true })
  vim.api.nvim_create_autocmd("User", {
    pattern = "CodeCompanionChatCreated",
    group = group,
    callback = function(event)
      M.attach(chat_for_buffer(event.data and event.data.bufnr))
    end,
  })
  vim.api.nvim_create_autocmd("User", {
    pattern = { "CodeCompanionChatModel", "CodeCompanionChatAdapter" },
    group = group,
    callback = function(event)
      local chat = chat_for_buffer(event.data and event.data.bufnr)
      if chat then
        M.attach(chat)
        M.reconcile(chat)
        M.warn_if_tool_reasoning_conflict(chat)
      end
    end,
  })
  vim.api.nvim_create_autocmd("User", {
    pattern = "CodeCompanionChatToolAdded",
    group = group,
    callback = function(event)
      M.warn_if_tool_reasoning_conflict(chat_for_buffer(event.data and event.data.bufnr))
    end,
  })

  local prefix = vim.g.ai_prefix_key or "<leader>A"
  vim.keymap.set("n", prefix .. "t", function()
    M.pick()
  end, { desc = "Code Companion - Thinking level" })
  vim.keymap.set("n", prefix .. "T", function()
    M.inspect()
  end, { desc = "Code Companion - Inspect thinking settings" })

  if opts.fetch_metadata ~= false then
    M.refresh_capabilities()
  end
end

-- Family hints keep the picker useful before the async AGD metadata cache arrives.
-- They remain advisory; only exact route registrations opt into enforcement.
M.register_capability("openai_agd", "^gpt%-5", {
  status = "supported",
  source = "family_hint",
  mode = "optional",
  conflicts = REASONING_SAMPLING_CONFLICTS,
}, { pattern = true, priority = 20 })
M.register_capability("openai_agd", "^o%d", {
  status = "supported",
  source = "family_hint",
  mode = "optional",
  conflicts = REASONING_SAMPLING_CONFLICTS,
}, { pattern = true, priority = 20 })
M.register_capability("openai_agd", function(model)
  return type(model) == "string"
    and (
      model:match("^claude%-sonnet")
      or model:match("^claude%-opus")
      or model:match("^claude%-haiku%-4")
      or model:match("^claude%-fable")
    )
      ~= nil
end, { status = "supported", source = "family_hint", mode = "optional" }, { priority = 20 })
M.register_capability("openai_agd", "^gemini%-%d", {
  status = "supported",
  source = "family_hint",
  mode = "optional",
}, { pattern = true, priority = 20 })
M.register_capability("openai_agd", "^kimi%-", {
  status = "supported",
  source = "family_hint",
  mode = "optional",
}, { pattern = true, priority = 20 })
M.register_capability("openai_agd", "^deepseek", {
  status = "supported",
  source = "family_hint",
  mode = "required",
  levels = vim.deepcopy(REQUIRED_LEVELS),
}, { pattern = true, priority = 20 })
M.register_capability("openai_agd", "gpt-5.4", {
  status = "supported",
  source = "verified_proxy_probe_2026_07_12",
  mode = "optional",
  levels = { "none", "low", "medium", "high", "xhigh" },
  conflicts = REASONING_SAMPLING_CONFLICTS,
}, { priority = 90 })
M.register_capability("openai_agd", "o3", {
  status = "supported",
  source = "verified_proxy_probe_2026_07_12",
  mode = "optional",
  levels = { "low", "medium", "high" },
  conflicts = REASONING_SAMPLING_CONFLICTS,
}, { priority = 90 })
M.register_capability("openai_responses_agd", "^gpt%-", {
  status = "supported",
  source = "adapter_hint",
  mode = "optional",
  conflicts = REASONING_SAMPLING_CONFLICTS,
}, { pattern = true, priority = 20 })

register_verified_route_policies()

return M
