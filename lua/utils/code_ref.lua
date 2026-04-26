-- Build and copy code reference strings (path + line + col)
-- Supports relative (to git root or cwd) and absolute paths.
local M = {}

local pathUtil = require "utils.path"
local clipboardUtil = require "utils.myinput"

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

  -- Check if we should hide line entirely (path-only mode; implies hide_col)
  local hide_line = vim.g.code_ref_hide_line or false

  -- Path-only shortcut: ignore line/col and range formatting
  if hide_line then
    if format == "at" or format == "at_caps" then
      return "@" .. path_part
    end
    return path_part
  end

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
function M.get_visual_range(use_visual)
  if not use_visual then
    return nil
  end

  -- Exit visual mode first to flush current selection into '< '> marks
  -- Without this, marks still hold the PREVIOUS selection's values
  local mode = vim.fn.mode()
  if mode:match "[vV\x16]" then
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
  local range = M.get_visual_range(use_visual)

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

--- Generate unified path variants for a given file path.
--- Single source of truth for path variant generation used by both
--- the keymap code_ref_picker and the sub-picker copy_path_select.
---@param file_path string absolute file path to generate variants for
---@param opts? { ref_buf_path?: string, include_dirs?: boolean }
---@return table[] path_variants array of { label, path, key } (deduplicated)
function M.generate_path_variants(file_path, opts)
  opts = opts or {}
  local include_dirs = opts.include_dirs ~= false -- default true

  -- Determine reference buffer for relative path calculation
  local ref_buf_path = opts.ref_buf_path
  if not ref_buf_path then
    local prev_buf = vim.api.nvim_buf_get_name(vim.fn.bufnr "#")
    local current_buf = vim.api.nvim_buf_get_name(0)
    ref_buf_path = (prev_buf ~= "" and prev_buf) or current_buf
  end

  -- Use Snacks.git.get_root() if available, fallback to pathUtil
  local git_root
  local snacks_ok, snacks_git = pcall(function()
    return Snacks.git.get_root()
  end)
  if snacks_ok and snacks_git then
    git_root = snacks_git
  else
    git_root = pathUtil.get_git_root()
  end

  local dir_path = vim.fn.fnamemodify(file_path, ":h")
  local ref_buf_dir = vim.fn.fnamemodify(ref_buf_path, ":h")

  local formats = {
    {
      label = "Relative",
      path = pathUtil.get_relative_path_with_parent(file_path, ref_buf_path),
      key = "buffer",
    },
    {
      label = "Git",
      path = git_root and file_path:gsub("^" .. vim.pesc(git_root) .. "/?", "") or nil,
      key = "git",
    },
    {
      label = "Relative CWD",
      path = vim.fn.fnamemodify(file_path, ":."),
      key = "cwd",
    },
    {
      label = "Absolute",
      path = vim.fn.fnamemodify(file_path, ":p"),
      key = "absolute",
    },
  }

  if include_dirs then
    local dir_formats = {
      {
        label = "Dir Relative",
        path = pathUtil.get_relative_path_with_parent(dir_path, ref_buf_dir),
        key = "dir_buffer",
      },
      {
        label = "Dir Git",
        path = git_root and dir_path:gsub("^" .. vim.pesc(git_root) .. "/?", "") or nil,
        key = "dir_git",
      },
      {
        label = "Dir Relative CWD",
        path = vim.fn.fnamemodify(dir_path, ":."),
        key = "dir_cwd",
      },
      {
        label = "Dir Absolute",
        path = vim.fn.fnamemodify(dir_path, ":p"),
        key = "dir_absolute",
      },
    }
    for _, f in ipairs(dir_formats) do
      table.insert(formats, f)
    end
  end

  -- Deduplicate by path value, merging labels when paths are identical
  local seen_paths = {}
  local deduplicated = {}

  for _, format in ipairs(formats) do
    if format.path and format.path ~= "" then
      local existing = seen_paths[format.path]
      if existing then
        existing.label = existing.label .. "/" .. format.label
        existing.key = existing.key .. "," .. format.key
      else
        seen_paths[format.path] = format
        table.insert(deduplicated, format)
      end
    end
  end

  return deduplicated
end

--- Generate picker-ready code-ref items from path variants.
--- Uses format_ref() as the single source of truth for all formatting.
---@param path_variants table[] from generate_path_variants()
---@param line number|nil line number (1-based)
---@param col number|nil column number (1-based)
---@param range? table visual range { start_line, start_col, end_line, end_col }
---@param show_char_range? boolean whether to show char positions in ranges
---@return table[] items array of { label, text, path, key, is_coderef, line, col }
function M.generate_coderef_items(path_variants, line, col, range, show_char_range)
  if not line or not col then
    return {}
  end

  local format_keys = {
    { key = "colon", label = "colon" },
    { key = "space", label = "space" },
    { key = "at", label = "@" },
    { key = "at_caps", label = "@caps" },
    { key = "hash", label = "#" },
  }

  local items = {}

  for _, path_variant in ipairs(path_variants) do
    local path = path_variant.path
    if not path or path == "" then
      goto continue
    end

    -- Skip directory variants (only process file paths)
    if path_variant.key:match "^dir_" then
      goto continue
    end

    for _, fmt in ipairs(format_keys) do
      local ref_text = format_ref(path, line, col, fmt.key, range, show_char_range)
      local item_label = path_variant.label .. " (" .. fmt.label .. ")"
      table.insert(items, {
        label = item_label,
        -- Prefix label into text so Snacks fuzzy-filter matches on label words (e.g. "abs" → "Absolute")
        text = item_label .. " " .. ref_text,
        path = ref_text,
        key = path_variant.key .. "_" .. fmt.key,
        is_coderef = true,
        line = line,
        col = col,
      })
    end

    ::continue::
  end

  return items
end

--- Build current ref options for pickers with unified path variants
---@param show_char_range? boolean whether to show char positions in ranges
---@param use_visual? boolean whether to include visual range
---@return table|nil
function M.current_options(show_char_range, use_visual)
  local bufpath = vim.api.nvim_buf_get_name(0)
  if not bufpath or bufpath == "" then
    return nil
  end

  local line, col = unpack(vim.api.nvim_win_get_cursor(0))
  col = col + 1
  local range = M.get_visual_range(use_visual or false)

  local path_variants = M.generate_path_variants(bufpath)
  local items = M.generate_coderef_items(path_variants, line, col, range, show_char_range)

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

--- Toggle hiding line entirely (path-only mode)
function M.toggle_hide_line()
  vim.g.code_ref_hide_line = not vim.g.code_ref_hide_line
  local status = vim.g.code_ref_hide_line and "hidden" or "shown"
  vim.notify("Code ref line: " .. status, vim.log.levels.INFO)
  return vim.g.code_ref_hide_line
end

return M
