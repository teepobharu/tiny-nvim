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
  -- When range exists, use its normalized start position instead of cursor position
  if range then
    start_line = range.start_line
    start_col = range.start_col
  end

  local end_line = range and range.end_line or nil
  local end_col = range and range.end_col or nil

  -- Default: don't show char range for multi-line selections (only show line range)
  if show_char_range == nil then
    show_char_range = vim.g.code_ref_show_char_range or false
  end

  -- Check if we should hide column entirely
  local hide_col = vim.g.code_ref_hide_col or false

  local has_range = end_line and end_line ~= start_line

  if format == "hash" then
    if has_range then
      if show_char_range then
        return ("%s#L%dC%d-L%dC%d"):format(path_part, start_line, start_col, end_line, end_col or start_col)
      end
      return ("%s#L%d-L%d"):format(path_part, start_line, end_line)
    end
    if hide_col then
      return ("%s#L%d"):format(path_part, start_line)
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

  -- Single line/position formatting
  if hide_col then
    -- Hide column entirely
    if format == "space" then
      return ("%s%s %d"):format(prefix, path_part, start_line)
    elseif format == "at_caps" then
      return ("%s%s L%d"):format(prefix, path_part, start_line)
    end
    return ("%s%s:%d"):format(prefix, path_part, start_line)
  else
    -- Show column
    if format == "space" then
      return ("%s%s %d:%d"):format(prefix, path_part, start_line, start_col)
    elseif format == "at_caps" then
      return ("%s%s L%d:C%d"):format(prefix, path_part, start_line, start_col)
    end
    return ("%s%s:%d:%d"):format(prefix, path_part, start_line, start_col)
  end
end

--- Get visual range from marks. Only returns a range when called with use_visual=true.
--- This prevents stale visual marks from leaking into normal mode calls.
--- Uses nvim_buf_get_mark (like sidekick.nvim) for reliable mark reading after mode exit.
---@param use_visual boolean whether the caller was invoked from visual mode
---@return table|nil range {start_line, start_col, end_line, end_col} or nil
local function get_visual_range(use_visual)
  if not use_visual then
    return nil
  end

  -- Exit visual mode first to flush current selection into '< '> marks
  -- Without this, marks still hold the PREVIOUS selection's values
  local mode = vim.fn.mode()
  if mode:match("[vV\x16]") then
    vim.cmd("normal! " .. vim.api.nvim_replace_termcodes("<Esc>", true, false, true))
  end

  local buf = vim.api.nvim_get_current_buf()
  -- nvim_buf_get_mark returns (1,0)-based: {row, col}
  local start_pos = vim.api.nvim_buf_get_mark(buf, "<")
  local end_pos = vim.api.nvim_buf_get_mark(buf, ">")

  if start_pos[1] == 0 or end_pos[1] == 0 then
    return nil
  end

  local start_line = start_pos[1]
  local start_col = start_pos[2] + 1 -- convert to 1-based
  local end_line = end_pos[1]
  local end_col = end_pos[2] + 1 -- convert to 1-based

  -- In line-visual (V) mode, '> col is max int (2147483647) meaning "entire line"
  -- Clamp to actual line length so char output is meaningful
  local max_col = 2147483647
  if end_pos[2] >= max_col then
    local end_line_text = vim.api.nvim_buf_get_lines(buf, end_line - 1, end_line, false)[1] or ""
    end_col = #end_line_text
  end
  if start_pos[2] >= max_col then
    local start_line_text = vim.api.nvim_buf_get_lines(buf, start_line - 1, start_line, false)[1] or ""
    start_col = #start_line_text
  end

  -- Normalize order (ensure start <= end)
  if start_line > end_line or (start_line == end_line and start_col > end_col) then
    start_line, end_line = end_line, start_line
    start_col, end_col = end_col, start_col
  end

  -- Single-line selection: not a range
  if start_line == end_line then
    return nil
  end

  return {
    start_line = start_line,
    start_col = start_col,
    end_line = end_line,
    end_col = end_col,
  }
end

---@param opts {format?: "colon"|"space"|"at"|"hash", absolute?: boolean, bufnr?: integer, copy?: boolean, copy_mode?: "plus"|"unnamed"|"both", show_char_range?: boolean, visual?: boolean}
---@return string|nil
function M.current(opts)
  opts = opts or {}
  local format = opts.format or "colon"
  local absolute = opts.absolute or false
  local bufnr = opts.bufnr or 0
  local copy = opts.copy ~= false
  local copy_mode = clipboardUtil.get_copy_mode(opts)
  local show_char_range = opts.show_char_range
  local use_visual = opts.visual or false

  local bufpath = vim.api.nvim_buf_get_name(bufnr)
  if not bufpath or bufpath == "" then
    return nil
  end

  local abs_path = vim.fn.fnamemodify(bufpath, ":p")
  local line, col = unpack(vim.api.nvim_win_get_cursor(0))
  col = col + 1 -- make 1-based
  local range = get_visual_range(use_visual)

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
---@param use_visual? boolean whether to include visual range
---@return table|nil
function M.current_options(show_char_range, use_visual)
  local parts = get_path_parts()
  if not parts then
    return nil
  end

  local line, col = unpack(vim.api.nvim_win_get_cursor(0))
  col = col + 1
  local range = get_visual_range(use_visual or false)

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

--- Toggle hiding column entirely (shows only line numbers)
function M.toggle_hide_col()
  vim.g.code_ref_hide_col = not vim.g.code_ref_hide_col
  local status = vim.g.code_ref_hide_col and "hidden" or "shown"
  vim.notify("Code ref column: " .. status, vim.log.levels.INFO)
  return vim.g.code_ref_hide_col
end

return M
