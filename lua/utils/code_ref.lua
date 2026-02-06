-- Build and copy code reference strings (path + line + col)
-- Supports relative (to git root or cwd) and absolute paths.
local M = {}

local pathUtil = require "utils.path"
local clipboardUtil = require "utils.myinput"

local function get_path_parts()
  local bufpath = vim.api.nvim_buf_get_name(0)
  if not bufpath or bufpath == "" then
    return nil
  end

  local abs_path = vim.fn.fnamemodify(bufpath, ":p")
  local rel_path = abs_path
  local git_root = pathUtil.get_git_root()
  if git_root and git_root ~= "" and abs_path:sub(1, #git_root) == git_root then
    rel_path = abs_path:sub(#git_root + 2)
  else
    rel_path = vim.fn.fnamemodify(abs_path, ":.")
  end

  return {
    abs = abs_path,
    rel = rel_path,
  }
end

local function format_ref(path_part, start_line, start_col, format, range, show_char_range)
  local end_line = range and range.end_line or nil
  local end_col = range and range.end_col or nil

  -- Default: don't show char range for multi-line selections (only show line range)
  if show_char_range == nil then
    show_char_range = vim.g.code_ref_show_char_range or false
  end

  local has_range = end_line and end_line ~= start_line

  if format == "hash" then
    if has_range then
      return ("%s#L%d-L%d"):format(path_part, start_line, end_line)
    end
    return ("%s#L%dC%d"):format(path_part, start_line, start_col)
  end

  local prefix = ""
  if format == "at" or format == "at_caps" then
    prefix = "@"
  end

  if has_range then
    -- For ranges, conditionally show char positions based on flag
    if show_char_range then
      if format == "space" then
        return ("%s%s %d:%d-%d:%d"):format(prefix, path_part, start_line, start_col, end_line, end_col or start_col)
      elseif format == "at_caps" then
        return ("%s%s L%d:C%d-L%d:C%d"):format(prefix, path_part, start_line, start_col, end_line, end_col or start_col)
      end
      return ("%s%s:%d:%d-%d:%d"):format(prefix, path_part, start_line, start_col, end_line, end_col or start_col)
    else
      -- Don't show char positions in ranges by default
      if format == "space" then
        return ("%s%s %d-%d"):format(prefix, path_part, start_line, end_line)
      elseif format == "at_caps" then
        return ("%s%s L%d-L%d"):format(prefix, path_part, start_line, end_line)
      end
      return ("%s%s:%d-%d"):format(prefix, path_part, start_line, end_line)
    end
  end

  if format == "space" then
    return ("%s%s %d:%d"):format(prefix, path_part, start_line, start_col)
  elseif format == "at_caps" then
    return ("%s%s L%d:C%d"):format(prefix, path_part, start_line, start_col)
  end
  return ("%s%s:%d:%d"):format(prefix, path_part, start_line, start_col)
end

local function get_visual_range()
  -- Try current visual mode first
  local mode = vim.fn.mode()
  local is_visual = mode == "v" or mode == "V" or mode == "\22"

  -- If not in visual mode, check if we have a recent visual selection
  if not is_visual then
    local start_pos = vim.fn.getpos "'<"
    local end_pos = vim.fn.getpos "'>"

    -- Check if visual marks are valid (not at buffer start)
    if start_pos[2] == 0 or end_pos[2] == 0 then
      return nil
    end

    local start_line = start_pos[2]
    local end_line = end_pos[2]

    -- Only treat as range if different lines
    if start_line == end_line then
      return nil
    end

    return {
      start_line = start_line,
      start_col = start_pos[3],
      end_line = end_line,
      end_col = end_pos[3],
    }
  end

  -- We're in visual mode, use input util
  local ok, inputUtil = pcall(require, "utils.input")
  if not ok or not inputUtil then
    return nil
  end

  local res = inputUtil.get_line_selection "visual"
  if not res or not res.start_pos or not res.end_pos then
    return nil
  end

  local start_line, start_col = unpack(res.start_pos)
  local end_line, end_col = unpack(res.end_pos)

  if start_line > end_line or (start_line == end_line and start_col > end_col) then
    start_line, end_line = end_line, start_line
    start_col, end_col = end_col, start_col
  end

  return {
    start_line = start_line,
    start_col = start_col,
    end_line = end_line,
    end_col = end_col,
  }
end

---@param opts {format?: "colon"|"space"|"at"|"hash", absolute?: boolean, bufnr?: integer, copy?: boolean, copy_mode?: "plus"|"unnamed"|"both", show_char_range?: boolean}
---@return string|nil
function M.current(opts)
  opts = opts or {}
  local format = opts.format or "colon"
  local absolute = opts.absolute or false
  local bufnr = opts.bufnr or 0
  local copy = opts.copy ~= false
  local copy_mode = clipboardUtil.get_copy_mode(opts)
  local show_char_range = opts.show_char_range

  local bufpath = vim.api.nvim_buf_get_name(bufnr)
  if not bufpath or bufpath == "" then
    return nil
  end

  local abs_path = vim.fn.fnamemodify(bufpath, ":p")
  local line, col = unpack(vim.api.nvim_win_get_cursor(0))
  col = col + 1 -- make 1-based
  local range = get_visual_range()

  local rel_path = abs_path
  local git_root = pathUtil.get_git_root()
  if git_root and git_root ~= "" and abs_path:sub(1, #git_root) == git_root then
    rel_path = abs_path:sub(#git_root + 2)
  else
    -- relative to cwd
    rel_path = vim.fn.fnamemodify(abs_path, ":.")
  end

  local path_part = absolute and abs_path or rel_path
  local ref = format_ref(path_part, line, col, format, range, show_char_range)

  if copy then
    clipboardUtil.copy_to_clipboard(ref, copy_mode)
  end

  return ref
end

--- Build current ref options for pickers
---@param show_char_range? boolean whether to show char positions in ranges
---@return table|nil
function M.current_options(show_char_range)
  local parts = get_path_parts()
  if not parts then
    return nil
  end

  local line, col = unpack(vim.api.nvim_win_get_cursor(0))
  col = col + 1
  local range = get_visual_range()

  local formats = {
    { key = "colon", label = "path:line:col" },
    { key = "space", label = "path line:col" },
    { key = "at", label = "@path line:col" },
    { key = "at_caps", label = "@path Lline:Ccol" },
    { key = "hash", label = "path#LlineCcol" },
  }

  local items = {}
  for _, fmt in ipairs(formats) do
    table.insert(items, {
      format = fmt.key,
      absolute = false,
      label = "rel " .. fmt.label,
      text = format_ref(parts.rel, line, col, fmt.key, range, show_char_range),
    })
    table.insert(items, {
      format = fmt.key,
      absolute = true,
      label = "abs " .. fmt.label,
      text = format_ref(parts.abs, line, col, fmt.key, range, show_char_range),
    })
  end

  return items
end

--- Copy current reference and echo a short message
---@param opts table see M.current
---@return string|nil
function M.copy_current(opts)
  opts = opts or {}
  local ref = M.current(opts)
  if ref then
    local copy_mode = clipboardUtil.get_copy_mode(opts)
    clipboardUtil.copy_and_notify(ref, copy_mode, "Copied code ref: " .. ref)
  end
  return ref
end

--- Toggle showing char positions in range references
function M.toggle_char_range()
  vim.g.code_ref_show_char_range = not vim.g.code_ref_show_char_range
  local status = vim.g.code_ref_show_char_range and "enabled" or "disabled"
  vim.notify("Code ref char range: " .. status, vim.log.levels.INFO)
  return vim.g.code_ref_show_char_range
end

return M
