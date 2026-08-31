-- CodeCompanion utility functions for Agoda-specific adapter configurations
-- Similar pattern to my_avante_utils.lua for consistency
-- TODO: extract common model name, url, env keys to be in common place to be reused in both avante, codecomponion, others
local myAiC = require "utils.my_ai_constants"
local thinking = require "utils.my_codecompanion_thinking"
local M = {}

-- `CodeCompanionChat adapter=<adapter> model=<model>` - Open a chat buffer with a specific http adapter and model
local MODELS = require("utils.my_ai_constants").models

-- Get Agoda-specific adapter configurations
-- These adapters use internal Agoda endpoints and are separated from the main config
-- for easier maintenance and to optionally exclude them from adapter selection
--- @param use_dynamic_fetch boolean? whether to use dynamic model fetching for the OpenAI Agoda adapter (default: false)
function M.get_agoda_adapters(use_dynamic_fetch)
  local adapters = {
    -- not used
    -- Claude via Agoda GenAI Gateway
    -- claude_agd = function()
    --   return require("codecompanion.adapters").extend("anthropic", {
    --     env = {
    --       api_key = "ANTHROPIC_API_KEY",
    --     },
    --     url = "https://genai-gateway.agoda.is/claude",
    --     schema = {
    --       model = {
    --         default = "claude-3-7-sonnet",
    --         choices = {
    --           "claude-3-5-haiku",
    --           "claude-3-7-sonnet",
    --           "claude-haiku-4-5",
    --           "claude-opus-4-5",
    --         },
    --       },
    --     },
    --   })
    -- end,
    --
    -- -- Vertex Claude via Agoda OpenAI Proxy (OpenAI-compatible endpoint)
    -- vertex_claude_agd = function()
    --   return require("codecompanion.adapters").extend("openai", {
    --     env = {
    --       api_key = "OPENAI_API_KEY",
    --     },
    --     url = "http://openai-proxy.agoda.is/v1",
    --     schema = {
    --       model = {
    --         default = "claude-3-7-sonnet",
    --         choices = {
    --           "claude-3-5-haiku",
    --           "claude-3-7-sonnet",
    --           "claude-haiku-4-5",
    --           "claude-opus-4-5",
    --         },
    --       },
    --       temperature = {
    --         default = 0.75,
    --       },
    --       max_tokens = {
    --         default = 20480,
    --       },
    --     },
    --   })
    -- end,

    -- OpenAI/GPT via Agoda OpenAI Proxy
    -- Uses the normalized AGD proxy base from my_ai_constants.
    -- Uses dynamic model fetching via fetch_model_helper from my_codecompanion_actions
    [myAiC.providers.openai_agd.adapter_name] = function()
      local adapter
      adapter = require("codecompanion.adapters").extend("openai", {
        -- Override name so logs/notifications show "openai_agd" not the parent "openai"
        name = myAiC.providers.openai_agd.adapter_name,
        formatted_name = "OpenAI AGD",
        env = {
          api_key = "OPENAI_API_KEY",
          url = myAiC.endpoints.agoda.OPENAI_PROXY_BASE,
          chat_url = "/v1/chat/completions", -- Chat endpoint path
          models_endpoint = "/v1/models", -- Models listing endpoint
        },
        handlers = {
          form_parameters = function(self, params, messages)
            params = require("codecompanion.adapters.http.openai").handlers.form_parameters(self, params, messages)
            return thinking.prepare_request(self, params)
          end,
        },
        map_schema_to_params = function(self, settings)
          return thinking.map_settings(self, settings)
        end,
        -- Keep builtins first, then preserve the lean MCP proxy group when present,
        -- then fill remaining MCP tools up to OpenAI's hard 128-tool limit.
        form_tools = function(self, tools)
          local transformed = {}
          if self.opts.tools and tools then
            for _, tool_group in pairs(tools) do
              for _, schema in pairs(tool_group) do
                table.insert(transformed, schema)
              end
            end
          end

          local OPENAI_TOOL_LIMIT = 128
          if #transformed > OPENAI_TOOL_LIMIT then
            local original_count = #transformed
            local builtin = {}
            local lean = {}
            local mcp = {}
            for _, s in ipairs(transformed) do
              if not s.name or not s.name:match("__") then
                table.insert(builtin, s)
              elseif s.name:match("^mcphub_") then
                table.insert(lean, s)
              else
                table.insert(mcp, s)
              end
            end
            table.sort(lean, function(a, b)
              return (a.name or "") < (b.name or "")
            end)
            table.sort(mcp, function(a, b)
              return (a.name or "") < (b.name or "")
            end)

            local kept = {}
            local dropped = {}
            local function take(group)
              for _, s in ipairs(group) do
                if #kept < OPENAI_TOOL_LIMIT then
                  table.insert(kept, s)
                else
                  table.insert(dropped, s.name or "<unknown>")
                end
              end
            end

            take(builtin)
            take(lean)
            take(mcp)
            transformed = kept

            local servers = {}
            for _, name in ipairs(dropped) do
              local server = name:match("^([^_]+)__") or name:match("^mcphub_") and "mcphub_lean" or name:match("^(.-)__")
              if server then
                servers[server] = (servers[server] or 0) + 1
              end
            end
            local summary = {}
            for srv, cnt in pairs(servers) do
              table.insert(summary, srv .. " (" .. cnt .. ")")
            end
            table.sort(summary)
            vim.notify(
              "CodeCompanion: Tool limit exceeded (" .. original_count .. "/128). Dropped " .. #dropped .. " tool(s)" .. (#summary > 0 and " from: " .. table.concat(summary, ", ") or "") .. ". Builtins and mcphub_lean are prioritized.",
              vim.log.levels.WARN
            )
          end

          return #transformed > 0 and { tools = transformed } or nil
        end,
        url = "${url}${chat_url}",
        schema = {
          model = {
            default = MODELS.qwen.QWEN_3_8_27B,
            choices = function(self, opts)
              -- use_dynamic_fetch is captured from the outer get_agoda_adapters(use_dynamic_fetch) argument.
              -- merge_agoda_adapters() always calls get_agoda_adapters(true), so this closure
              -- always has use_dynamic_fetch=true at runtime — meaning it always hits the internal
              -- HTTP endpoint (http://openai-proxy.agoda.is/v1/models) via Curl.get(sync=true).
              -- The `async` param in opts is ignored by openai_compatible.get_models().
              local finalOpt = vim.tbl_deep_extend("force", {}, opts or {})
              finalOpt.use_dynamic_fetch = use_dynamic_fetch
              -- fetch_model_helper returns a flat string array: { "model-a", "model-b", ... }
              local raw = require("utils.my_codecompanion_actions").fetch_model_helper(
                self,
                finalOpt,
                myAiC.providers.openai_agd.adapter_name
              )
              -- Normalize to keyed table. Thinking support is resolved separately from
              -- live AGD metadata and remains advisory so new/manual values are never blocked.
              local result = {}
              if type(raw) == "table" then
                for k, v in pairs(raw) do
                  if type(k) == "number" then
                    -- list form: { "model-a", "model-b" }
                    result[v] = {}
                  else
                    -- already keyed form: { ["model-a"] = { opts = {} } }
                    result[k] = v
                  end
                end
              end
              for model_name, entry in pairs(result) do
                if thinking.resolve_capability(self, model_name).status == "supported" then
                  entry.opts = vim.tbl_extend("force", entry.opts or {}, { can_reason = true })
                end
              end
              return thinking.expand_model_choices(self, result)
            end,
          },
          -- temperature = {
          --   default = 0,
          -- },
          max_completion_tokens = {
            default = 4096,
          },
          -- Always present: unknown model capability stays permissive; exact
          -- route rules can still reject a known-invalid manual value.
          reasoning_effort = {
            order = 2,
            mapping = "parameters",
            type = "string",
            optional = true,
            enabled = true,
            choices = function(self)
              return thinking.levels_for(self)
            end,
            validate = function(value)
              return thinking.validate_effort(adapter, value)
            end,
            desc = "Optional proxy reasoning effort. Exact route rules reject known-invalid levels; unknown models show all common levels.",
          },
        },
      })
      -- `vim.tbl_deep_extend` cannot erase an inherited value with nil, so clear
      -- OpenAI's "medium" default after construction. This also makes /debug render
      -- the optional field as `nil` instead of silently enabling reasoning.
      adapter.schema.reasoning_effort.default = nil
      return adapter
    end,
  }

  return adapters
end

-- Get Agoda-specific adapter for codex/responses models (uses /v1/responses endpoint)
function M.get_agoda_responses_adapters()
  local adapters = {
    [myAiC.providers.openai_responses_agd.adapter_name] = function()
      local adapter
      adapter = require("codecompanion.adapters").extend("openai_responses", {
        name = myAiC.providers.openai_responses_agd.adapter_name,
        formatted_name = "OpenAI Responses AGD",
        env = {
          api_key = "OPENAI_API_KEY",
          url = myAiC.endpoints.agoda.OPENAI_PROXY_BASE,
        },
        handlers = {
          request = {
            build_parameters = function(self, params, messages)
              params = require("codecompanion.adapters.http.openai_responses").handlers.request.build_parameters(
                self,
                params,
                messages
              )
              return thinking.prepare_request(self, params)
            end,
          },
        },
        map_schema_to_params = function(self, settings)
          return thinking.map_settings(self, settings)
        end,
        -- Override the hardcoded upstream URL with the AGD proxy responses endpoint.
        -- model.choices is inherited from upstream (openai_responses.lua:586-661) which
        -- lists gpt-5-codex, 5.1-codex, 5.1-codex-max, 5.2-codex, 5.3-codex, etc. `extend()`
        -- deep-merges this table into the upstream choices rather than replacing it, so any
        -- model verified working at /v1/responses on the AGD proxy (see
        -- ai/agents/docs/agoda/proxy-models.md) but missing upstream must be added here too —
        -- upstream does not auto-track new proxy models.
        url = "${url}/v1/responses",
        schema = {
          model = {
            default = MODELS.gpt.GPT_5_3_CODEX,
            choices = thinking.expand_model_choices(myAiC.providers.openai_responses_agd.adapter_name, {
              -- gpt-5.6 tiers confirmed working at /v1/responses on AGD proxy (2026-07-14).
              -- The shared thinking module appends local low/high/xhigh/max
              -- selector aliases; only canonical names reach the proxy.
              [MODELS.gpt.GPT_5_6_SOL] = {
                formatted_name = "GPT 5.6 Sol",
                meta = { context_window = 1050000 },
                opts = { can_manage_context = true, has_function_calling = true, has_vision = true, can_reason = true },
              },
              [MODELS.gpt.GPT_5_6_TERRA] = {
                formatted_name = "GPT 5.6 Terra",
                meta = { context_window = 1050000 },
                opts = { can_manage_context = true, has_function_calling = true, has_vision = true, can_reason = true },
              },
              [MODELS.gpt.GPT_5_6_LUNA] = {
                formatted_name = "GPT 5.6 Luna",
                meta = { context_window = 1050000 },
                opts = { can_manage_context = true, has_function_calling = true, has_vision = true, can_reason = true },
              },
              -- gpt-5.5 kept as flagship -1 fallback reference — verified working at /v1/responses.
              [MODELS.gpt.GPT_5_5] = {
                formatted_name = "GPT 5.5",
                meta = { context_window = 1050000 },
                opts = { can_manage_context = true, has_function_calling = true, has_vision = true, can_reason = true },
              },
            }),
          },
          max_output_tokens = {
            default = 4096,
          },
          ["reasoning.effort"] = {
            order = 2,
            mapping = "parameters",
            type = "string",
            optional = true,
            enabled = true,
            choices = function(self)
              return thinking.levels_for(self)
            end,
            validate = function(value)
              return thinking.validate_effort(adapter, value)
            end,
            desc = "Optional Responses API reasoning effort. Exact route rules reject known-invalid levels; unknown models show all common levels.",
          },
          -- Codex models on AGD reject top_p — suppress it (same pattern upstream uses for gpt-5.4-nano)
          top_p = {
            enabled = function()
              return false
            end,
          },
        },
      })
      adapter.schema["reasoning.effort"].default = nil
      return adapter
    end,
  }

  return adapters
end

-- Merge Agoda responses adapters with existing adapters configuration
function M.merge_agoda_responses_adapters(base_adapters)
  base_adapters = base_adapters or {}
  local responses_adapters = M.get_agoda_responses_adapters()
  return vim.tbl_extend("force", base_adapters, responses_adapters)
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
  local agoda_adapters = M.get_agoda_adapters(true)
  local result = vim.tbl_extend("force", base_adapters, agoda_adapters)
  return result
  -- __AUTO_GENERATED_PRINT_VAR_START__
  -- __AUTO_GENERATED_PRINT_VAR_START__
end

-- Helper to filter git diff output by line range (for visual selection)
-- @param diff string: Git diff output
-- @param start_line number: Start line of selection (1-indexed)
-- @param end_line number: End line of selection (1-indexed)
-- @return string: Filtered diff showing only hunks overlapping with line range
local function filter_diff_by_range(diff, start_line, end_line)
  if not diff or diff == "" then
    return diff
  end

  local filtered_lines = {}
  local current_hunk = {}
  local in_relevant_hunk = false
  local diff_header = {}
  local past_header = false

  for line in diff:gmatch "[^\r\n]+" do
    -- Capture diff header lines (before first hunk)
    if
      not past_header
      and (line:match "^diff %-%-git" or line:match "^index" or line:match "^%%%-" or line:match "^%+%+%+")
    then
      table.insert(diff_header, line)
    -- Check for hunk header: @@ -old_start,old_count +new_start,new_count @@
    elseif line:match "^@@" then
      past_header = true

      -- Save previous hunk if it was relevant
      if in_relevant_hunk and #current_hunk > 0 then
        vim.list_extend(filtered_lines, current_hunk)
      end

      -- Parse hunk header
      local old_start, old_count, new_start, new_count = line:match "^@@%s*%-(%d+),?(%d*)%s*%+(%d+),?(%d*)%s*@@"

      if new_start then
        -- Handle missing count (means 1 line)
        new_count = new_count ~= "" and tonumber(new_count) or 1
        new_start = tonumber(new_start)

        -- Check if hunk overlaps with [start_line, end_line]
        local hunk_end = new_start + new_count - 1
        in_relevant_hunk = (new_start <= end_line and hunk_end >= start_line)

        current_hunk = { line } -- Start new hunk with header
      else
        in_relevant_hunk = false
        current_hunk = {}
      end
    elseif in_relevant_hunk then
      table.insert(current_hunk, line)
    end
  end

  -- Add last hunk if relevant
  if in_relevant_hunk and #current_hunk > 0 then
    vim.list_extend(filtered_lines, current_hunk)
  end

  -- If no relevant hunks found, return empty
  if #filtered_lines == 0 then
    return ""
  end

  -- Combine header + filtered hunks
  vim.list_extend(diff_header, filtered_lines)
  return table.concat(diff_header, "\n")
end

-- Get git diff for current buffer with optional visual selection filtering
-- @param diff_args string: Git diff arguments (e.g., "--staged", "", "main..")
-- @param context table|nil: Optional context with start_line, end_line for filtering
-- @return string: Git diff output or error/info message
function M.get_buffer_git_diff(diff_args, context)
  -- Get current buffer filepath
  local filepath = vim.api.nvim_buf_get_name(0)

  if filepath == "" or filepath == nil then
    return "Error: Buffer not saved. Save file before reviewing changes."
  end

  -- Check if file exists
  if vim.fn.filereadable(filepath) == 0 then
    return "Error: File does not exist on disk."
  end

  -- Get directory for git command
  local dir = vim.fn.fnamemodify(filepath, ":h")

  -- Validate git repo
  local git_check = vim.fn.system("git -C " .. vim.fn.shellescape(dir) .. " rev-parse --git-dir 2>&1")
  if vim.v.shell_error ~= 0 then
    return "Error: File not in a git repository."
  end

  -- Construct git diff command
  local cmd = string.format("git -C %s diff %s -- %s", vim.fn.shellescape(dir), diff_args, vim.fn.shellescape(filepath))
  _G.userdbg([==[M.get_buffer_git_diff cmd:]==], vim.inspect(cmd)) -- __AUTO_GENERATED_PRINT_VAR_END__

  -- Execute git diff
  local diff = vim.fn.system(cmd)

  if vim.v.shell_error ~= 0 then
    return "Error: Git diff failed:\n" .. diff
  end

  -- Check if empty (no changes)
  if diff == "" or diff:match "^%s*$" then
    local change_type = diff_args:match "staged" and "staged " or (diff_args == "" and "unstaged " or "")
    return "No " .. change_type .. "changes in current buffer"
  end

  -- Filter by visual selection if context provided
  -- start and end might be equal even not select why ?
  _G.userdbg([==[M.get_buffer_git_diff#if context:]==], vim.inspect(context)) -- __AUTO_GENERATED_PRINT_VAR_END__
  -- Check visual selection context is valid and spans multiple lines in visual or linewise visual mode
  if
    context
    and context.mode
    and (context.mode == "v" or context.mode == "V")
    and context.start_line
    and context.end_line
    and context.start_line ~= context.end_line
  then
    -- __AUTO_GENERATED_PRINT_VAR_START__
    local start_line = context.start_line
    local end_line = context.end_line

    -- Normalize range (ensure start <= end)
    if start_line > end_line then
      start_line, end_line = end_line, start_line
    end

    diff = filter_diff_by_range(diff, start_line, end_line)

    if diff == "" or diff:match "^%s*$" then
      return "No changes in selected line range (" .. start_line .. "-" .. end_line .. ")"
    end
  end

  return diff
end

-- Get staged changes for current buffer
-- @param context table|nil: Optional visual selection context
-- @return string: Staged diff or error/info message
function M.get_buffer_staged_diff(context)
  return M.get_buffer_git_diff("--staged", context)
end

-- Get unstaged changes for current buffer
-- @param context table|nil: Optional visual selection context
-- @return string: Unstaged diff or error/info message
function M.get_buffer_unstaged_diff(context)
  return M.get_buffer_git_diff("", context)
end

-- Get all changes (staged + unstaged) for current buffer
-- @param context table|nil: Optional visual selection context
-- @return string: Combined diff or error/info message
function M.get_buffer_all_diff(context)
  local staged = M.get_buffer_staged_diff(context)
  local unstaged = M.get_buffer_unstaged_diff(context)

  -- Check for errors first
  if staged:match "^Error:" then
    return staged
  end
  if unstaged:match "^Error:" then
    return unstaged
  end

  -- Check if both are empty
  local staged_empty = staged:match "^No"
  local unstaged_empty = unstaged:match "^No"

  if staged_empty and unstaged_empty then
    return "No changes in current buffer"
  end

  -- Build combined output
  local result = {}

  if not staged_empty then
    table.insert(result, "## Staged Changes\n")
    table.insert(result, staged)
  end

  if not unstaged_empty then
    if #result > 0 then
      table.insert(result, "\n\n")
    end
    table.insert(result, "## Unstaged Changes\n")
    table.insert(result, unstaged)
  end

  return table.concat(result)
end

return M
