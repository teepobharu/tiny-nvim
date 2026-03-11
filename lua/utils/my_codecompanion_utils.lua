-- CodeCompanion utility functions for Agoda-specific adapter configurations
-- Similar pattern to my_avante_utils.lua for consistency
-- TODO: extract common model name, url, env keys to be in common place to be reused in both avante, codecomponion, others
local M = {}

-- `CodeCompanionChat adapter=<adapter> model=<model>` - Open a chat buffer with a specific http adapter and model
local MODELS = require("utils.my_ai_constants").models

-- Get Agoda-specific adapter configurations
-- These adapters use internal Agoda endpoints and are separated from the main config
-- for easier maintenance and to optionally exclude them from adapter selection
--- @param use_dynamic_fetch boolean? whether to use dynamic model fetching for the OpenAI Agoda adapter (default: false)
function M.get_agoda_adapters(use_dynamic_fetch)
  return {
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
    -- Uses env-based URL templating: AG_OPENAIPROXY provides base URL (e.g. http://openai-proxy.agoda.is)
    -- Uses dynamic model fetching via fetch_model_helper from my_codecompanion_actions
    openai_agd = function()
      return require("codecompanion.adapters").extend("openai", {
        env = {
          api_key = "OPENAI_API_KEY",
          url = "AG_OPENAIPROXY", -- Base URL from env var
          chat_url = "/v1/chat/completions", -- Chat endpoint path
          models_endpoint = "/v1/models", -- Models listing endpoint
        },
        url = "${url}${chat_url}",
        schema = {
          model = {
            default = MODELS.gpt.GPT_5_2,
            choices = function(self, opts)
              local finalOpt = vim.tbl_deep_extend("force", {}, opts or {})
              finalOpt.use_dynamic_fetch = use_dynamic_fetch
              return require("utils.my_codecompanion_actions").fetch_model_helper(self, finalOpt)
            end,
          },
          -- temperature = {
          --   default = 0,
          -- },
          max_completion_tokens = {
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
  if context and context.start_line and context.end_line then
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
