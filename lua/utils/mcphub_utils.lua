--- MCPHub utilities for CodeCompanion integration
--- Patches MCP tool schemas to be compatible with OpenAI/Copilot function-calling API.
--- channel: https://api.slack.com/apps/A09LET76CQK/search-app?
--- Two problems solved:
---   1. $ref/$defs: MCP servers (e.g., Slack) return JSON Schema with $ref references.
---      ALL LLM APIs reject these — they need fully inlined schemas.
---   2. Missing additionalProperties: OpenAI strict mode (used by Copilot with gpt-5 via
---      responses endpoint) requires additionalProperties=false on every object node,
---      including inside anyOf/oneOf/allOf. CC's built-in enforce_strictness misses those.
---      We ONLY add additionalProperties=false — required/type changes are left to CC's
---      own handler which is more conservative with union types.
---
--- vim.g flags (set in lua/config/myopts.lua, override in mydefault-nvim-config.lua):
---   vim.g.mcphub_schema_resolve_refs    = true  -- inline $ref/$defs
---   vim.g.mcphub_schema_enforce_strict  = true  -- additionalProperties in anyOf/oneOf
---   vim.g.mcphub_schema_debug           = false -- log schema fixes and tool call args
---
--- See: docs/memory/mcphub.md for architecture context.
local M = {}

local LOG_TAG = "[mcphub_utils]"

--- Check if a vim.g flag is enabled (defaults to true if not explicitly set to false)
---@param name string The vim.g variable name
---@return boolean
local function flag_enabled(name)
  local val = vim.g[name]
  if val == false then
    return false
  end
  return true
end

--- Check if debug logging is enabled (defaults to false — must be explicitly true)
---@return boolean
local function debug_enabled()
  return vim.g.mcphub_schema_debug == true
end

--- Log a debug message via vim.notify (only when mcphub_schema_debug = true)
---@param msg string
---@param ... any format args
local function log_debug(msg, ...)
  if not debug_enabled() then
    return
  end
  local formatted = string.format(msg, ...)
  vim.schedule(function()
    vim.notify(LOG_TAG .. " " .. formatted, vim.log.levels.DEBUG, { title = "MCPHub Schema" })
  end)
end

--- Log a info-level message via vim.notify (only when mcphub_schema_debug = true)
---@param msg string
---@param ... any format args
local function log_info(msg, ...)
  if not debug_enabled() then
    return
  end
  local formatted = string.format(msg, ...)
  vim.schedule(function()
    vim.notify(LOG_TAG .. " " .. formatted, vim.log.levels.INFO, { title = "MCPHub Schema" })
  end)
end

--- Truncate a string for display
---@param s string
---@param max_len? number Default 800
---@return string
local function truncate(s, max_len)
  max_len = max_len or 800
  if #s > max_len then
    return s:sub(1, max_len) .. "...(truncated)"
  end
  return s
end

--- Quick recursive check: does the schema have anyOf/oneOf/allOf containing objects
--- without additionalProperties? If yes, we need to add it.
--- Returns false for schemas that are already compliant or have no combo keywords.
---@param node any A JSON Schema node
---@return boolean
local function needs_strict_fix(node)
  if type(node) ~= "table" then
    return false
  end
  for _, key in ipairs { "anyOf", "oneOf", "allOf" } do
    if type(node[key]) == "table" then
      for _, item in ipairs(node[key]) do
        if item.properties and item.additionalProperties == nil then
          return true
        end
        if needs_strict_fix(item) then
          return true
        end
      end
    end
  end
  if node.properties then
    for _, v in pairs(node.properties) do
      if needs_strict_fix(v) then
        return true
      end
    end
  end
  if node.items and needs_strict_fix(node.items) then
    return true
  end
  return false
end

--- Recursively add additionalProperties = false on all object nodes in a JSON Schema.
--- This is the MINIMUM OpenAI strict mode requires for anyOf/oneOf/allOf containers.
--- We intentionally do NOT touch required or property types here — CC's built-in
--- enforce_strictness (tool_transformers.lua) handles those at the adapter level
--- and is more conservative with union types (anyOf).
--- Touching required/types here causes issues: e.g., marking "text" as required
--- on a Slack Block union type makes the LLM send text=null on divider blocks
--- which Slack rejects as an invalid additional property.
---@param node any A JSON Schema node
local function enforce_strict(node)
  if type(node) ~= "table" then
    return
  end

  -- If this node has properties, it's an object — set additionalProperties = false
  if node.properties then
    node.additionalProperties = false
    -- Recurse into each property value
    for _, v in pairs(node.properties) do
      enforce_strict(v)
    end
  end

  -- Recurse into items (arrays)
  if node.items then
    enforce_strict(node.items)
  end

  -- Recurse into anyOf / oneOf / allOf / prefixItems
  for _, combo_key in ipairs { "anyOf", "oneOf", "allOf", "prefixItems" } do
    if type(node[combo_key]) == "table" then
      for _, item in ipairs(node[combo_key]) do
        enforce_strict(item)
      end
    end
  end

  -- Recurse into additionalProperties if it's a schema (not boolean)
  if type(node.additionalProperties) == "table" then
    enforce_strict(node.additionalProperties)
  end
end

--- Resolve all $ref references in a JSON Schema by inlining definitions from $defs.
--- Handles recursive/circular refs with a visited set to prevent infinite loops.
--- Removes $defs from the final output.
--- Optionally enforces strict mode based on vim.g.mcphub_schema_enforce_strict.
---
---@param schema table The JSON Schema (with potential $ref and $defs)
---@return table The resolved schema with all $ref inlined and $defs removed
function M.resolve_json_schema_refs(schema)
  if type(schema) ~= "table" then
    return schema
  end

  local defs = schema["$defs"] or schema["definitions"]
  if not defs then
    return schema
  end

  -- Deep copy to avoid mutating the original
  local resolved = vim.deepcopy(schema)
  local root_defs = resolved["$defs"] or resolved["definitions"]

  --- Recursively resolve $ref in a node
  ---@param node any
  ---@param visited table<string, boolean> Set of ref paths currently being resolved (cycle detection)
  ---@return any
  local function resolve_node(node, visited)
    if type(node) ~= "table" then
      return node
    end

    -- Handle $ref
    local ref = node["$ref"]
    if type(ref) == "string" then
      -- Only handle local refs: #/$defs/Foo or #/definitions/Foo
      local def_name = ref:match "^#/%$defs/(.+)$" or ref:match "^#/definitions/(.+)$"
      if def_name and root_defs and root_defs[def_name] then
        -- Circular reference guard
        if visited[def_name] then
          log_debug("Circular $ref detected: %s — using stub", def_name)
          return { type = "object", description = "(circular ref: " .. def_name .. ")" }
        end
        visited[def_name] = true
        local inlined = resolve_node(vim.deepcopy(root_defs[def_name]), visited)
        visited[def_name] = nil
        return inlined
      end
      log_debug("Unknown $ref: %s — stripping", ref)
      -- Unknown $ref — return the node as-is minus the $ref key to avoid API errors
      local cleaned = {}
      for k, v in pairs(node) do
        if k ~= "$ref" then
          cleaned[k] = v
        end
      end
      if vim.tbl_isempty(cleaned) then
        return { type = "object" }
      end
      return cleaned
    end

    -- Recurse into all keys
    local out = {}
    for k, v in pairs(node) do
      if k == "$defs" or k == "definitions" then
        -- Skip $defs in output — they've been inlined
        goto continue_key
      end
      if type(v) == "table" then
        -- Handle arrays (ipairs) vs objects (pairs)
        if vim.islist(v) then
          local arr = {}
          for i, item in ipairs(v) do
            arr[i] = resolve_node(item, visited)
          end
          out[k] = arr
        else
          out[k] = resolve_node(v, visited)
        end
      else
        out[k] = v
      end
      ::continue_key::
    end
    return out
  end

  local result = resolve_node(resolved, {})

  -- Enforce strict mode on the resolved schema if enabled and needed
  if flag_enabled "mcphub_schema_enforce_strict" and needs_strict_fix(result) then
    enforce_strict(result)
  end

  return result
end

--- Patch MCPHub's CodeCompanion extension to fix tool schemas before they reach the LLM API.
--- Wraps the original register function so that after MCPHub populates CC's tool config,
--- each mcp_dynamic tool's lazy callback is wrapped to fix schemas when invoked.
---
--- What it fixes per tool callback invocation:
---   1. If schema has $defs/$ref AND resolve_refs=true → resolve + optionally enforce strict
---   2. Elif schema has non-compliant anyOf AND mcphub_schema_enforce_strict=true → enforce strict only
---   3. Otherwise → pass through unchanged
---
--- When mcphub_schema_debug=true, logs:
---   - Each tool registration wrap
---   - Schema fix actions taken (resolve_refs, enforce_strict, skipped)
---   - Tool call args sent to MCP server
---
--- Usage in myAi.lua (call once, early — before MCPHub registers tools):
---   require("utils.mcphub_utils").patch_mcphub_cc_tool_schemas()
function M.patch_mcphub_cc_tool_schemas()
  local ok, tools_mod = pcall(require, "mcphub.extensions.codecompanion.tools")
  if not ok or not tools_mod then
    return
  end

  local original_register = tools_mod.register
  if not original_register then
    return
  end

  tools_mod.register = function(opts, ...)
    -- Call original to populate tools and groups in CC config
    original_register(opts, ...)

    -- Patch mcp_dynamic tool callbacks to fix schemas
    local cc_ok, cc_config = pcall(require, "codecompanion.config")
    if not cc_ok or not cc_config then
      return
    end
    -- v19+: tools live under config.interactions.chat.tools
    local all_tools = cc_config.interactions and cc_config.interactions.chat and cc_config.interactions.chat.tools
    if not all_tools then
      return
    end

    local patched_count = 0
    for tool_name, tool_def in pairs(all_tools) do
      if type(tool_def) == "table" and tool_def.callback then
        local orig_callback = tool_def.callback
        -- Only patch mcp_dynamic tools (from MCPHub)
        if type(tool_def.id) == "string" and tool_def.id:match "^mcp_dynamic:" then
          patched_count = patched_count + 1

          tool_def.callback = function(...)
            local result = orig_callback(...)
            if not result or not result.schema or not result.schema["function"] then
              return result
            end
            local func_def = result.schema["function"]
            local params = func_def.parameters
            if not params then
              return result
            end

            local action = "none"
            if flag_enabled "mcphub_schema_resolve_refs" and (params["$defs"] or params["definitions"]) then
              local def_count = 0
              for _ in pairs(params["$defs"] or params["definitions"] or {}) do
                def_count = def_count + 1
              end
              result.schema["function"].parameters = M.resolve_json_schema_refs(params)
              action = string.format("resolved %d $ref defs", def_count)
              if flag_enabled "mcphub_schema_enforce_strict" then
                action = action .. " + enforce_strict"
              end
            elseif flag_enabled "mcphub_schema_enforce_strict" and needs_strict_fix(params) then
              enforce_strict(params)
              action = "enforce_strict (anyOf fix)"
            end

            if action ~= "none" then
              log_info("schema fix [%s]: %s", func_def.name or tool_name, action)
              log_debug(
                "schema fix [%s] result:\n%s",
                func_def.name or tool_name,
                truncate(vim.inspect(result.schema["function"].parameters))
              )
            else
              log_debug("schema fix [%s]: skipped (already compliant)", func_def.name or tool_name)
            end

            return result
          end
        end
      end
    end

    if patched_count > 0 then
      log_info("patched %d mcp_dynamic tool callbacks", patched_count)
    end
  end

  -- Also wrap the tool execution path to log args and results
  M._patch_tool_call_logging()
end

--- Wrap MCPHub's core.execute_mcp_tool to log tool call args and results.
--- Only produces output when mcphub_schema_debug = true.
--- Wraps the execute function to intercept params (args from LLM) and output_handler (results).
function M._patch_tool_call_logging()
  local ok, core = pcall(require, "mcphub.extensions.codecompanion.core")
  if not ok or not core then
    return
  end

  local original_execute = core.execute_mcp_tool
  if not original_execute then
    return
  end

  core.execute_mcp_tool = function(params, tools, output_handler, context)
    if not debug_enabled() then
      return original_execute(params, tools, output_handler, context)
    end

    -- Log the call args
    local server = params and params.server_name or "?"
    local tool = params and params.tool_name or "?"
    local args = params and params.tool_input or {}
    local ctx_name = context and context.tool_display_name or (server .. "." .. tool)
    log_info("tool call [%s] args:\n%s", ctx_name, truncate(vim.inspect(args)))

    -- Wrap the output handler to also log results
    local wrapped_handler = function(result)
      if result then
        local status = result.status or "?"
        local data = result.data
        if status == "error" then
          vim.schedule(function()
            vim.notify(
              string.format("%s tool error [%s]: %s", LOG_TAG, ctx_name, truncate(tostring(data), 500)),
              vim.log.levels.ERROR,
              { title = "MCPHub Tool" }
            )
          end)
        else
          log_info("tool result [%s] %s:\n%s", ctx_name, status, truncate(vim.inspect(data), 1200))
        end
      end
      -- Call original handler
      return output_handler(result)
    end

    return original_execute(params, tools, wrapped_handler, context)
  end
end

return M
