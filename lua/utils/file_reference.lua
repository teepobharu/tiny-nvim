-- File reference parsing and resolution utilities
-- Extracted from lua/config/mykeymaps.lua:goto_file_line()
-- Handles multiple file reference formats for navigation

local M = {}
local myPathUtil = require("utils.mypath")

--- Parse file reference formats into path, line, and column components
---@param target string The file reference to parse (e.g., "file.lua:10:5", "file.md#L10", "file.md#anchor")
---@return {path: string, line: string, col: string, anchor: string|nil}
function M.parse_file_reference(target)
  local result = { path = "", line = "", col = "", anchor = nil }
  if not target or target == "" then
    return result
  end

  local path, line, col

  -- Handle file:// URI scheme first
  if target:match("^file://") then
    local without_prefix = target:match("^file://(.+)$")
    if without_prefix then
      -- Try path:line:col pattern
      local test_path, test_line, test_col = without_prefix:match("^(.+):(%d+):(%d+)$")
      if test_path then
        path, line, col = test_path, test_line, test_col
      else
        -- Try path:line pattern
        test_path, test_line = without_prefix:match("^(.+):(%d+)$")
        if test_path then
          path, line, col = test_path, test_line, ""
        else
          path, line, col = without_prefix, "", ""
        end
      end
    end
  else
    -- Regular file path with optional :line:col
    local test_path, test_line, test_col = target:match("^(.+):(%d+):(%d+)$")
    if test_path then
      path, line, col = test_path, test_line, test_col
    else
      test_path, test_line = target:match("^(.+):(%d+)$")
      if test_path then
        path, line, col = test_path, test_line, ""
      else
        path, line, col = target, "", ""
      end
    end
  end

  result.path = path

  -- Check for git-style line references (#L2, #L2-L3, #L2C3)
  if result.path and result.path:match("#") then
    local before, after = result.path:match("^(.-)#(.*)$")
    if before and after then
      -- Try git-style patterns
      local git_line, git_col
      local l1, c1 = after:match("^L(%d+)C(%d+)%-L(%d+)")
      if l1 then
        git_line, git_col = l1, c1
        -- Note: third capture group (git_end_line) available for future range selection
      else
        l1 = after:match("^L(%d+)%-L(%d+)")
        if l1 then
          git_line = l1
        else
          l1, c1 = after:match("^L(%d+)C(%d+)$")
          if l1 then
            git_line, git_col = l1, c1
          else
            l1 = after:match("^L(%d+)$")
            if l1 then
              git_line = l1
            end
          end
        end
      end

      if git_line then
        result.path = before
        line = git_line
        col = git_col or ""
      else
        -- Not a line reference, treat as README-style anchor
        result.path = before
        result.anchor = after
      end
    end
  end

  result.line = line or ""
  result.col = col or ""
  return result
end

--- Resolve relative file paths with smart priority logic
---@param path string The file path (relative or absolute)
---@return string Resolved absolute path
function M.resolve_file_path(path)
  if not path or path == "" then
    return path
  end

  -- Absolute paths or URIs: return as-is
  if path:match("^[/~]") or path:match("^%w+://") then
    return path
  end

  local base_dir = myPathUtil.get_buffer_cwd()
  local pathUtil = require("utils.path")
  local git_root = pathUtil.get_git_root()

  -- Check if path has explicit relative indicator (./ or ../)
  local has_relative_indicator = path:match("^%.%.?/")

  if has_relative_indicator then
    -- Explicit relative path: prioritize buffer cwd, fallback to git root
    local resolved_path = base_dir and vim.fn.fnamemodify(base_dir .. "/" .. path, ":p") or nil

    if (not resolved_path) or (vim.fn.filereadable(resolved_path) ~= 1 and vim.fn.isdirectory(resolved_path) ~= 1) then
      if git_root then
        local git_resolved = vim.fn.fnamemodify(git_root .. "/" .. path, ":p")
        if vim.fn.filereadable(git_resolved) == 1 or vim.fn.isdirectory(git_resolved) == 1 then
          return git_resolved
        end
      end
    end

    return resolved_path or path
  else
    -- No relative indicator: prioritize git root, fallback to buffer cwd
    if git_root then
      local git_resolved = vim.fn.fnamemodify(git_root .. "/" .. path, ":p")
      if vim.fn.filereadable(git_resolved) == 1 or vim.fn.isdirectory(git_resolved) == 1 then
        return git_resolved
      end
    end

    if base_dir then
      local cwd_resolved = vim.fn.fnamemodify(base_dir .. "/" .. path, ":p")
      return cwd_resolved
    end

    return vim.fn.fnamemodify(path, ":p")
  end
end

--- Jump to markdown heading by anchor text
---@param anchor string The anchor text to find (e.g., "done", "code section")
---@return boolean True if anchor found and jumped, false otherwise
function M.jump_to_anchor(anchor)
  if not anchor or anchor == "" then
    return false
  end

  -- Normalize anchor for loose matching
  local norm_anchor = anchor:gsub("[-_]+", " "):gsub("^#", ""):lower()

  -- Get all buffer lines and search for Markdown headings
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local found_line = nil

  -- First pass: match Markdown headings
  for i, l in ipairs(lines) do
    local heading = l:match("^%s*#+%s*(.+)$")
    if heading then
      local norm_heading = heading:gsub("%s+", " "):lower()
      if norm_heading:find(norm_anchor, 1, true) or norm_anchor:find(norm_heading, 1, true) then

        found_line = i
        break
      end
    end
  end

  -- Second pass: search file for anchor substring
  if not found_line then
    for i, l in ipairs(lines) do
      if l:lower():find(norm_anchor, 1, true) then
        found_line = i
        break
      end
    end
  end

  if found_line then
    vim.api.nvim_win_set_cursor(0, { found_line, 0 })
    return true
  end

  return false
end

return M
