local M = {}

-- Default configuration
M.config = {
  prompt_dir = vim.fn.expand("$HOME/Personal/mynotes/Extras/Template/copilot-custom-prompts/"),
  patterns = { "*.prompt.md", "*.instructions.md" },
  timeout_ms = 60000,
}

-- Read file content and return as string
---@param path string File path to read
---@return string Content of the file
local function readfile(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok or not lines then
    return ""
  end
  return table.concat(lines, "\n")
end

-- Strip YAML frontmatter from content
---@param s string Content with potential frontmatter
---@return string Content without frontmatter
local function strip_frontmatter(s)
  if not s then return "" end
  -- If starts with YAML frontmatter '---', remove until the closing '---'
  if s:match("^%s*%-%-%-") then
    local s_idx, e_idx = s:find("%-%-%-", 1)
    if e_idx then
      local s2, e2 = s:find("%-%-%-", e_idx + 1)
      if e2 then
        return s:sub(e2 + 1):gsub("^%s+", "")
      end
    end
  end
  return s
end

-- Get list of prompt files from configured directory
---@param opts? table Optional config override { prompt_dir, patterns }
---@return table List of prompt file paths
function M.get_prompt_files(opts)
  opts = opts or {}
  local prompt_dir = opts.prompt_dir or M.config.prompt_dir
  local patterns = opts.patterns or M.config.patterns

  local files = {}
  for _, pat in ipairs(patterns) do
    local ok = vim.fn.globpath(prompt_dir, pat, false, true)
    if ok and #ok > 0 then
      vim.list_extend(files, ok)
    end
  end

  return files
end

-- Select a prompt using Snacks picker and call callback with content
---@param opts? table Optional config { prompt_dir, patterns, timeout_ms, callback }
---@param callback? function Function to call with selected content
function M.select_prompt(opts, callback)
  opts = opts or {}
  local files = M.get_prompt_files(opts)

  if vim.tbl_isempty(files) then
    local prompt_dir = opts.prompt_dir or M.config.prompt_dir
    vim.notify("No prompt files found in " .. prompt_dir, vim.log.levels.WARN)
    if callback then callback(nil) end
    return
  end

  local items = {}
  for _, f in ipairs(files) do
    table.insert(items, { text = vim.fn.fnamemodify(f, ":t"), file = f })
  end

  Snacks.picker.pick {
    source = "select",
    title = "Select Prompt File",
    items = items,
    format = "text",
    preview = "file",
    actions = {
      confirm = function(picker, item)
        if not item or not item.file then
          picker:close()
          if callback then callback(nil) end
          return
        end
        local c = readfile(item.file)
        c = strip_frontmatter(c)
        picker:close()
        if callback then callback(c) end
      end,
    },
  }
end

-- Select and paste prompt at cursor position
---@param opts? table Optional config { prompt_dir, patterns, paste_mode }
function M.select_and_paste_prompt(opts)
  opts = opts or {}
  
  M.select_prompt(opts, function(content)
    if not content or content == "" then
      return
    end

    -- Determine paste mode: 'cursor' (default), 'newline', 'append'
    local paste_mode = opts.paste_mode or 'cursor'

    if paste_mode == 'newline' then
      -- Paste on new line below cursor
      vim.cmd('normal! o')
      vim.api.nvim_put(vim.split(content, "\n"), 'l', true, true)
    elseif paste_mode == 'append' then
      -- Append to current line
      vim.api.nvim_put(vim.split(content, "\n"), 'c', true, true)
    else
      -- Default: paste at cursor position
      vim.api.nvim_put(vim.split(content, "\n"), 'c', true, true)
    end
  end)
end

-- Helper function to create CodeCompanion prompt content function
---@param opts? table Optional config { prompt_dir, patterns }
---@return function Function that returns selected prompt content
function M.create_codecompanion_content_fn(opts)
  return function()
    -- Enable auto tool mode for CodeCompanion
    vim.g.codecompanion_auto_tool_mode = true
    
    -- Create a promise-like mechanism to wait for selection
    local co = coroutine.running()
    local result = nil
    
    M.select_prompt(opts, function(content)
      result = content or ""
      if co then
        coroutine.resume(co)
      end
    end)
    
    -- If we're in a coroutine, yield and wait for result
    if co then
      coroutine.yield()
    end
    
    return result or ""
  end
end

return M
