-- Snacks Picker Actions
-- All reusable picker actions extracted from editor_keymaps.lua and snacks_terminal.lua
-- This module contains action functions that can be used across different snacks pickers

---@class snacks.picker.actions
---@field [string] snacks.picker.Action.spec
local M = {}

--- Debug logger for picker persistence flow.
--- Enable with: vim.g.snacks_debug_picker_persist = true
--- @param event string
--- @param data table|nil
function M.log_picker_persist(event, data)
  if not vim.g.snacks_debug_picker_persist then
    return
  end
  local ok, payload = pcall(vim.inspect, data or {})
  local msg = string.format("[picker-persist] %s %s", event, ok and payload or "{}")
  vim.schedule(function()
    vim.notify(msg, vim.log.levels.INFO)
  end)
end

local pathUtil = require "utils.mypath"
local gitUtil = require "utils.git"

--#region Scope Traversal Sources
-- Shared helpers for subproject-based upward traversal used by:
--   B (a-s): toggle_cwd_files_grep — cycle scope up subproject chain
--   C (a-e): toggle_external — move cwd up one step + exclude initial cwd
--   D (buffers): same patterns with separate persistence

--- Sources that support cwd-based scope traversal and external toggling
local scope_traversal_sources = {
  files = true,
  grep = true,
  grep_word = true,
  todo_comments = true,
}

--#endregion Scope Traversal Sources

--#region Per-Source Opts Persistence
-- Persist toggle opts (hidden, ignored, follow, regex, case_args) per picker source type
-- across picker sessions within a single Neovim session using vim.g.
-- Key pattern: vim.g.picker_source_opts = { files = { hidden = false, ... }, grep = { ... } }

--- Sources that support per-source opts persistence
local persisted_opt_keys = { "hidden", "ignored", "follow", "regex" }

--- Get persisted opts for a source type
--- @param source string Picker source name (e.g. "files", "grep")
--- @return table|nil Persisted opts or nil if none
function M.get_persisted_source_opts(source)
  local all_opts = vim.g.picker_source_opts
  if not all_opts or not all_opts[source] then
    M.log_picker_persist("get_persisted_source_opts:miss", { source = source })
    return nil
  end
  local ret = vim.deepcopy(all_opts[source])
  M.log_picker_persist("get_persisted_source_opts:hit", { source = source, opts = ret })
  return ret
end

--- Save a single opt value for a source type
--- @param source string Picker source name
--- @param key string Opt key (e.g. "hidden", "ignored")
--- @param value any Opt value
function M.save_source_opt(source, key, value)
  local all_opts = vim.g.picker_source_opts and vim.deepcopy(vim.g.picker_source_opts) or {}
  local before = all_opts[source] and all_opts[source][key] or nil
  if not all_opts[source] then
    all_opts[source] = {}
  end
  all_opts[source][key] = value
  vim.g.picker_source_opts = all_opts
  M.log_picker_persist("save_source_opt", {
    source = source,
    key = key,
    before = before,
    after = value,
  })
end

--- Save all relevant toggle opts from a picker's current state
--- @param picker table Snacks picker instance
function M.save_picker_source_opts(picker)
  local source = picker.opts and picker.opts.source
  if not source then
    M.log_picker_persist("save_picker_source_opts:skip_no_source", {})
    return
  end
  -- Only persist for sources that support these toggles
  if not (source == "files" or source == "grep" or source == "grep_word") then
    M.log_picker_persist("save_picker_source_opts:skip_source", { source = source })
    return
  end
  for _, key in ipairs(persisted_opt_keys) do
    if picker.opts[key] ~= nil then
      M.save_source_opt(source, key, picker.opts[key])
    end
  end
  -- Persist case sensitivity args separately
  if picker.opts.args then
    local has_ignore_case = vim.tbl_contains(picker.opts.args, "-i")
      or vim.tbl_contains(picker.opts.args, "--ignore-case")
    local has_casesens = vim.tbl_contains(picker.opts.args, "-s")
      or vim.tbl_contains(picker.opts.args, "--case-sensitive")
    if has_ignore_case then
      M.save_source_opt(source, "case_mode", "ignore")
    elseif has_casesens then
      M.save_source_opt(source, "case_mode", "sensitive")
    else
      M.save_source_opt(source, "case_mode", "smart")
    end
  end
  M.log_picker_persist("save_picker_source_opts:done", {
    source = source,
    hidden = picker.opts.hidden,
    ignored = picker.opts.ignored,
    follow = picker.opts.follow,
    regex = picker.opts.regex,
    args = picker.opts.args,
  })
end

--#endregion Per-Source Opts Persistence

--#region Scope Traversal Chain Builder

--- Build ordered traversal chain from initial_cwd upward through subproject markers to git root
--- Returns: { initial_cwd, subproj_parent1, ..., git_root } (deduplicated, deepest first)
--- @param initial_cwd string Starting directory
--- @return string[] chain Ordered directories from initial_cwd to git root
local function build_scope_traversal_chain(initial_cwd)
  local path = require "utils.path"
  local git_root = path.get_root_directory() or Snacks.git.get_root()

  if not initial_cwd or initial_cwd == "" then
    initial_cwd = vim.fn.getcwd()
  end
  initial_cwd = vim.fn.fnamemodify(initial_cwd, ":p"):gsub("/$", "")

  -- Single-entry chain if no git root or cwd IS git root
  if not git_root or git_root == "" then
    return { initial_cwd }
  end
  git_root = vim.fn.fnamemodify(git_root, ":p"):gsub("/$", "")
  if initial_cwd == git_root then
    return { git_root }
  end

  -- Get all subprojects with metadata, sorted nearest-first
  local subprojects = pathUtil.get_sub_project_dirs_from_root(git_root, initial_cwd, true, true, "nearest") or {}

  -- Filter to in_cwd_traversal items (on the path from initial_cwd up to git_root)
  local traversal_dirs = {}
  local seen = {}

  -- Always start with initial_cwd
  seen[initial_cwd] = true
  table.insert(traversal_dirs, initial_cwd)

  for _, sp in ipairs(subprojects) do
    if sp.in_cwd_traversal and sp.dir then
      local normalized = vim.fn.fnamemodify(sp.dir, ":p"):gsub("/$", "")
      if not seen[normalized] and normalized ~= initial_cwd then
        seen[normalized] = true
        table.insert(traversal_dirs, normalized)
      end
    end
  end

  -- Ensure git root is always last
  if not seen[git_root] then
    table.insert(traversal_dirs, git_root)
  end

  -- Sort by depth (deepest first = initial_cwd, shallowest last = git_root)
  table.sort(traversal_dirs, function(a, b)
    local depth_a = select(2, a:gsub("/", ""))
    local depth_b = select(2, b:gsub("/", ""))
    return depth_a > depth_b
  end)

  return traversal_dirs
end

--- Get or initialize traversal chain for a picker
--- @param picker table Snacks picker instance
--- @param persist_key string|nil vim.g key for persisted initial cwd (nil = use vim.fn.getcwd())
--- @return string[] chain, number step_index
local function get_picker_traversal_state(picker, persist_key)
  if not picker.opts._scope_traversal_chain then
    -- Prefer the picker's active cwd over persisted state so traversal/external always
    -- follows the currently visible scope (important for non-persisted picker sessions).
    local initial_cwd = picker.opts.cwd or (persist_key and vim.g[persist_key]) or vim.fn.getcwd()
    picker.opts._scope_initial_cwd = initial_cwd
    picker.opts._scope_traversal_chain = build_scope_traversal_chain(initial_cwd)
    picker.opts._scope_step_index = 1 -- start at initial_cwd (index 1)
  end
  return picker.opts._scope_traversal_chain, picker.opts._scope_step_index
end

--- Reset traversal state on a picker (called when A-S selects new subproject or scope changes)
--- @param picker table Snacks picker instance
local function reset_picker_traversal_state(picker)
  picker.opts._scope_traversal_chain = nil
  picker.opts._scope_step_index = nil
  picker.opts._scope_initial_cwd = nil
  -- Also reset external state
  picker.opts._external_step_index = nil
  picker.opts._external_exclude_cwd = nil
  picker.opts._external_original_exclude = nil
  picker.opts.external = nil
end

--- Build a relative exclude pattern from exclude_cwd relative to search_cwd
--- @param exclude_cwd string The directory to exclude from search
--- @param search_cwd string The broader search cwd
--- @return string|nil The relative path to exclude, or nil if not applicable
local function build_cwd_exclude_pattern(exclude_cwd, search_cwd)
  if not exclude_cwd or not search_cwd then
    return nil
  end
  exclude_cwd = vim.fn.fnamemodify(exclude_cwd, ":p"):gsub("/$", "")
  search_cwd = vim.fn.fnamemodify(search_cwd, ":p"):gsub("/$", "")

  if exclude_cwd == search_cwd then
    return nil
  end
  if exclude_cwd == "/" or exclude_cwd == vim.env.HOME then
    return nil
  end

  local prefix = search_cwd .. "/"
  if exclude_cwd:sub(1, #prefix) == prefix then
    return exclude_cwd:sub(#prefix + 1)
  end
  return nil
end

-- Expose helpers for buffer actions in editor_keymaps
M._build_scope_traversal_chain = build_scope_traversal_chain
M._get_picker_traversal_state = get_picker_traversal_state
M._reset_picker_traversal_state = reset_picker_traversal_state
M._build_cwd_exclude_pattern = build_cwd_exclude_pattern

--#endregion Scope Traversal Chain Builder

--- Toggle picker external filter flag and re-run finder
--- For files/grep pickers: steps cwd up one subproject level + excludes initial scope cwd
--- For other pickers (buffers, git): toggles boolean flag checked in transform
--- @param picker table Snacks picker instance
function M.toggle_external(picker)
  if not picker then
    return
  end

  local source = picker.opts and picker.opts.source or ""

  -- For files/grep pickers: step-based external with exclude
  if scope_traversal_sources[source] then
    local chain, _ = get_picker_traversal_state(picker, "picker_cwd_cycle_state_value")

    if #chain <= 1 then
      vim.notify("No parent scope to expand to — already at top", vim.log.levels.INFO)
      return
    end

    -- Initialize external state if needed
    if not picker.opts._external_step_index then
      local current_scope_idx = picker.opts._scope_step_index or 1
      picker.opts._external_step_index = current_scope_idx
      -- The cwd to exclude = the scope cwd when external was first activated
      picker.opts._external_exclude_cwd = chain[current_scope_idx]
      -- Save original exclude for restoration
      picker.opts._external_original_exclude = picker.opts.exclude and vim.deepcopy(picker.opts.exclude) or nil
    end

    -- Advance external step (one up)
    local ext_idx = picker.opts._external_step_index + 1

    local title_source = type(source) == "string" and (source:sub(1, 1):upper() .. source:sub(2)) or "Picker"

    -- Preserve search state across refresh (same pattern as toggle_cwd_files_grep)
    local filter_pattern = picker.input.filter and (picker.input.filter.pattern ~= "" and picker.input.filter.pattern)
    local filter_search = picker.input.filter and (picker.input.filter.search ~= "" and picker.input.filter.search)

    if ext_idx > #chain then
      -- Reached top — disable external mode, restore original state
      vim.notify("External: reached top, disabling", vim.log.levels.INFO)
      picker.opts._external_step_index = nil
      picker.opts._external_exclude_cwd = nil
      picker.opts.external = false

      -- Restore to current scope position
      local scope_idx = picker.opts._scope_step_index or 1
      picker.opts.cwd = chain[scope_idx]
      picker.opts.args = nil
      picker.opts.show_empty = true

      -- Restore exclude
      if picker.opts._external_original_exclude ~= nil then
        picker.opts.exclude = picker.opts._external_original_exclude
      else
        picker.opts.exclude = nil
      end
      picker.opts._external_original_exclude = nil

      picker.title = title_source
    else
      -- Apply external: cwd = chain[ext_idx], exclude = initial scope cwd
      picker.opts._external_step_index = ext_idx
      picker.opts.external = true

      local new_cwd = chain[ext_idx]
      local exclude_cwd = picker.opts._external_exclude_cwd
      local exclude_pattern = build_cwd_exclude_pattern(exclude_cwd, new_cwd)

      picker.opts.cwd = new_cwd
      picker.opts.args = nil
      picker.opts.show_empty = true

      -- Build exclude list: restore original + add our exclude
      local base_exclude = picker.opts._external_original_exclude
          and vim.deepcopy(picker.opts._external_original_exclude)
        or {}
      if exclude_pattern then
        table.insert(base_exclude, exclude_pattern)
      end
      picker.opts.exclude = #base_exclude > 0 and base_exclude or nil

      local short_cwd = new_cwd
      local git_root = require("utils.path").get_root_directory() or Snacks.git.get_root()
      if git_root then
        local rel = new_cwd:gsub("^" .. vim.pesc(git_root) .. "/?", "")
        short_cwd = rel == "" and "." or rel
      end
      local short_excl = exclude_pattern or "none"
      picker.title = string.format("%s [ext: %s, excl: %s]", title_source, short_cwd, short_excl)

      if ext_idx == #chain then
        vim.notify(string.format("External: git root, excl: %s\nNext toggle disables", short_excl), vim.log.levels.INFO)
      else
        vim.notify(
          string.format("External: %s, excl: %s (%d/%d)", short_cwd, short_excl, ext_idx, #chain),
          vim.log.levels.INFO
        )
      end
    end

    -- Preserve search state
    if filter_pattern then
      picker.opts.pattern = filter_pattern
    end
    if filter_search then
      picker.opts.search = filter_search
    end

    picker:refresh()
  else
    -- For other pickers (buffers, git): simple boolean toggle
    picker.opts.external = not picker.opts.external
    picker:refresh()
  end
end

--#region Git Helper Functions for Pickers

--- Helper function to open file diff with gitsigns
--- @param file_path string File path (relative or absolute)
--- @param ref string Git reference to compare with
function M.open_file_with_gitsigns_diff(file_path, ref)
  if not pcall(require, "gitsigns") then
    vim.notify("Gitsigns is not available", vim.log.levels.ERROR)
    return
  end

  local git_root = Snacks.git.get_root()

  if vim.fn.filereadable(file_path) == 0 then
    file_path = git_root .. "/" .. file_path
  end

  vim.cmd("tabnew " .. vim.fn.fnameescape(file_path))

  require("gitsigns").diffthis(ref, {
    vertical = true,
  })
end

--- Helper function to open current buffer in new tab with gitsigns diff
--- @param ref string Git reference to compare with
function M.open_current_buffer_with_gitsigns_diff(ref)
  if not pcall(require, "gitsigns") then
    vim.notify("Gitsigns is not available", vim.log.levels.ERROR)
    return
  end

  local current_file = vim.api.nvim_buf_get_name(0)

  if current_file == "" then
    vim.notify("No file in current buffer", vim.log.levels.WARN)
    return
  end

  vim.cmd("tabnew " .. vim.fn.fnameescape(current_file))

  require("gitsigns").diffthis(ref, {
    vertical = true,
  })
end

--- Helper function to build remote URL for a file at a specific ref
--- @param file_path string File path (relative or absolute)
--- @param ref string Git reference (branch, tag, or commit)
--- @return string|nil Remote URL or nil if error
function M.build_remote_url(file_path, ref)
  local git_root = Snacks.git.get_root()
  if not git_root then
    return nil
  end

  if vim.fn.filereadable(file_path) == 0 then
    file_path = git_root .. "/" .. file_path
  end

  local rel_path = file_path:gsub("^" .. vim.pesc(git_root) .. "/?", "")
  local remote_path = gitUtil.get_remote_path "origin"

  if not remote_path or remote_path == "" then
    return nil
  end

  local url
  if remote_path:match "gitlab" then
    url = string.format("https://%s/-/blob/%s/%s", remote_path, ref, rel_path)
  else
    url = string.format("https://%s/blob/%s/%s", remote_path, ref, rel_path)
  end

  return url
end

--- Helper function to open file in remote at specific ref
--- @param file_path string File path (relative or absolute)
--- @param ref string Git reference to open at
function M.open_file_in_remote(file_path, ref)
  local url = M.build_remote_url(file_path, ref)

  if not url then
    vim.notify("Failed to build remote URL", vim.log.levels.ERROR)
    return
  end

  local filename = vim.fn.fnamemodify(file_path, ":t")

  vim.fn.jobstart({ "open", url }, { detach = true })
  vim.notify(string.format("Opening %s @ %s in browser", filename, ref), vim.log.levels.INFO)
end

--#endregion Git Helper Functions

--#region Path Copy Utilities

-- Get the selected file path from picker item
--- Extract file path and line/col info from picker item
--- @param item table Picker item
--- @return string|nil file_path
--- @return number|nil line (1-based)
--- @return number|nil col (1-based)
local function get_item_path(item)
  if not item then
    return nil, nil, nil
  end

  local file_path = item._path or item.file or item.path
  local line = nil
  local col = nil

  -- Extract line/col from grep items
  if item.pos and type(item.pos) == "table" then
    line = item.pos[1] -- already 1-based
    col = item.pos[2] + 1 -- convert from 0-based to 1-based
  end

  return file_path, line, col
end

-- Get relative path from source to target with ../ if outside
local function get_relative_path_with_parent(target_path, source_path)
  if not target_path or target_path == "" then
    return nil
  end

  target_path = vim.fn.fnamemodify(target_path, ":p")
  source_path = vim.fn.fnamemodify(source_path, ":p")

  local target_parts = vim.split(target_path, "/", { plain = true })
  local source_parts = vim.split(source_path, "/", { plain = true })

  local common_len = 0
  for i = 1, math.min(#target_parts, #source_parts) do
    if target_parts[i] == source_parts[i] then
      common_len = i
    else
      break
    end
  end

  local ups = #source_parts - common_len - 1
  local rel_parts = {}

  for _ = 1, ups do
    table.insert(rel_parts, "..")
  end

  for i = common_len + 1, #target_parts do
    table.insert(rel_parts, target_parts[i])
  end

  return table.concat(rel_parts, "/")
end

-- Generate different path formats
local function generate_path_formats(file_path)
  local git_root = Snacks.git.get_root()

  local prev_buf = vim.api.nvim_buf_get_name(vim.fn.bufnr "#")
  local current_buf = vim.api.nvim_buf_get_name(0)
  local ref_buf_path = (prev_buf ~= "" and prev_buf) or current_buf

  local dir_path = vim.fn.fnamemodify(file_path, ":h")
  local ref_buf_dir = vim.fn.fnamemodify(ref_buf_path, ":h")

  local formats = {
    {
      label = "Relative",
      path = get_relative_path_with_parent(file_path, ref_buf_path),
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
    {
      label = "Dir Relative",
      path = get_relative_path_with_parent(dir_path, ref_buf_dir),
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

-- Generate code-ref format variants from path formats + line/col
-- @param path_formats table[] Array of path format objects from generate_path_formats()
-- @param line number|nil Line number (1-based)
-- @param col number|nil Column number (1-based)
-- @return table[] Array of code-ref format objects
local function generate_coderef_formats(path_formats, line, col)
  if not line or not col then
    return {}
  end

  local coderef_formats = {}
  local hide_col = vim.g.code_ref_hide_col or false

  -- For each path variant, generate all 5 code-ref format variants
  for _, path_format in ipairs(path_formats) do
    local path = path_format.path
    if not path or path == "" then
      goto continue
    end

    -- Skip directory variants (only process file paths)
    if path_format.key:match "^dir_" then
      goto continue
    end

    -- Determine label prefix based on path type
    local path_type_label = path_format.label

    -- Generate 5 code-ref format variants for this path
    local ref_formats = {
      {
        format = "colon",
        label = path_type_label .. " (colon)",
        path = hide_col and string.format("%s:%d", path, line) or string.format("%s:%d:%d", path, line, col),
      },
      {
        format = "space",
        label = path_type_label .. " (space)",
        path = hide_col and string.format("%s %d", path, line) or string.format("%s %d:%d", path, line, col),
      },
      {
        format = "at",
        label = path_type_label .. " (@)",
        path = hide_col and string.format("@%s:%d", path, line) or string.format("@%s:%d:%d", path, line, col),
      },
      {
        format = "at_caps",
        label = path_type_label .. " (@caps)",
        path = hide_col and string.format("@%s L%d", path, line) or string.format("@%s L%d:C%d", path, line, col),
      },
      {
        format = "hash",
        label = path_type_label .. " (#)",
        path = hide_col and string.format("%s#L%d", path, line) or string.format("%s#L%dC%d", path, line, col),
      },
    }

    for _, ref_format in ipairs(ref_formats) do
      table.insert(coderef_formats, {
        label = ref_format.label,
        path = ref_format.path,
        key = path_format.key .. "_" .. ref_format.format,
        is_coderef = true,
        line = line,
        col = col,
      })
    end

    ::continue::
  end

  return coderef_formats
end

-- Get file/directory statistics
local function get_path_stats(path)
  if not path or path == "" then
    return nil
  end

  local abs_path = vim.fn.fnamemodify(path, ":p")
  local stat = vim.loop.fs_stat(abs_path)

  if not stat then
    return nil
  end

  local function format_size(bytes)
    if bytes < 1024 then
      return string.format("%d B", bytes)
    elseif bytes < 1024 * 1024 then
      return string.format("%.2f KB", bytes / 1024)
    elseif bytes < 1024 * 1024 * 1024 then
      return string.format("%.2f MB", bytes / (1024 * 1024))
    else
      return string.format("%.2f GB", bytes / (1024 * 1024 * 1024))
    end
  end

  local function format_time(sec)
    return os.date("%Y-%m-%d %H:%M:%S", sec)
  end

  local type_str = stat.type == "directory" and "Directory" or "File"

  local line_count = nil
  if stat.type == "file" then
    local ok, lines = pcall(vim.fn.readfile, abs_path)
    if ok then
      line_count = #lines
    end
  end

  return {
    type = type_str,
    size = format_size(stat.size),
    size_bytes = stat.size,
    modified = format_time(stat.mtime.sec),
    modified_sec = stat.mtime.sec,
    created = format_time(stat.birthtime.sec),
    created_sec = stat.birthtime.sec,
    permissions = string.format("%o", stat.mode):sub(-3),
    line_count = line_count,
  }
end

-- Copy path to clipboard and notify
local function copy_to_clipboard(path, _label)
  if not path or path == "" then
    vim.notify("Path is empty or invalid", vim.log.levels.WARN)
    return false
  end

  vim.fn.setreg("+", path)
  vim.fn.setreg('"', path)

  Snacks.debug(string.format("Copied %s", path))
  return true
end

--- Picker action: Copy relative path to previous/active buffer
function M.copy_path_relative_buffer(picker, item)
  local file_path, _, _ = get_item_path(item)
  if not file_path then
    vim.notify("No file path found", vim.log.levels.WARN)
    return
  end

  local prev_buf = vim.api.nvim_buf_get_name(vim.fn.bufnr "#")
  local current_buf = vim.api.nvim_buf_get_name(0)
  local ref_buf_path = (prev_buf ~= "" and prev_buf) or current_buf

  local rel_path = get_relative_path_with_parent(file_path, ref_buf_path)
  if copy_to_clipboard(rel_path, "relative path (to buffer)") then
    picker:close()
  end
end

--- Picker action: Copy relative path to git root
function M.copy_path_relative_git(picker, item)
  local file_path, _, _ = get_item_path(item)
  if not file_path then
    vim.notify("No file path found", vim.log.levels.WARN)
    return
  end

  local git_root = Snacks.git.get_root()
  if not git_root then
    vim.notify("Not in a git repository", vim.log.levels.WARN)
    return
  end

  local rel_path = file_path:gsub("^" .. vim.pesc(git_root) .. "/?", "")
  if copy_to_clipboard(rel_path, "relative path (to git root)") then
    picker:close()
  end
end

--- Picker action: Copy relative path to current CWD
function M.copy_path_relative_cwd(picker, item)
  local file_path, _, _ = get_item_path(item)
  if not file_path then
    vim.notify("No file path found", vim.log.levels.WARN)
    return
  end

  local rel_path = vim.fn.fnamemodify(file_path, ":.")
  if copy_to_clipboard(rel_path, "relative path (to cwd)") then
    picker:close()
  end
end

--- Picker action: Copy absolute path
function M.copy_path_absolute(picker, item)
  local file_path, _, _ = get_item_path(item)
  if not file_path then
    vim.notify("No file path found", vim.log.levels.WARN)
    return
  end

  local abs_path = vim.fn.fnamemodify(file_path, ":p")
  if copy_to_clipboard(abs_path, "absolute path") then
    picker:close()
  end
end

--- Helper function to insert text at cursor position
local function insert_at_cursor(text, parent_picker, format_picker)
  format_picker:close()
  parent_picker:close()
  vim.api.nvim_put({ text }, "c", true, true)
  vim.notify("Inserted: " .. text, vim.log.levels.INFO)
end

--- Helper function to insert markdown link format at cursor position
local function insert_markdown_link(path, parent_picker, format_picker)
  format_picker:close()
  parent_picker:close()

  local name = vim.fn.fnamemodify(path, ":t")
  if name == "" or name == "." then
    name = vim.fn.fnamemodify(path, ":h:t")
  end

  local markdown_link = string.format("[%s](%s)", name, path)
  vim.api.nvim_put({ markdown_link }, "c", true, true)
  vim.notify("Inserted markdown link: " .. markdown_link, vim.log.levels.INFO)
end

--- Picker action: Open Snacks picker to choose copy format with preview
function M.copy_path_select(picker, item)
  local file_path, line, col = get_item_path(item)
  if not file_path then
    vim.notify("No file path found", vim.log.levels.WARN)
    return
  end

  local path_formats = generate_path_formats(file_path)
  local coderef_formats = generate_coderef_formats(path_formats, line, col)

  -- Build picker items: path formats first, then code-ref formats
  local picker_items = {}

  -- Add path formats
  for _, format in ipairs(path_formats) do
    if format.path and format.path ~= "" then
      table.insert(picker_items, {
        text = format.label,
        path = format.path,
        label = format.label,
        key = format.key,
        is_coderef = false,
      })
    end
  end

  -- Add code-ref formats if available
  for _, format in ipairs(coderef_formats) do
    table.insert(picker_items, {
      text = format.label,
      path = format.path,
      label = format.label,
      key = format.key,
      is_coderef = true,
      line = format.line,
      col = format.col,
    })
  end

  if #picker_items == 0 then
    vim.notify("No valid path formats available", vim.log.levels.WARN)
    return
  end

  local parent_picker = picker

  -- Title shows if code-refs are available
  local title = "Select Path Format (C-y: copy, Enter: paste)"
  if #coderef_formats > 0 then
    title = title .. " [+" .. #coderef_formats .. " code-refs]"
  end

  Snacks.picker.pick {
    source = "path_formats",
    title = title,
    items = picker_items,
    format = function(picker_item)
      return {
        { picker_item.label, "SnacksPickerTitle" },
        { ": ", "Comment" },
        { picker_item.path, "Normal" },
      }
    end,
    preview = function(ctx)
      local picker_item = ctx.item
      if not picker_item then
        return false
      end

      local stats = get_path_stats(picker_item.path)

      local lines = {
        "Path Format: " .. picker_item.label,
        "Path:",
        picker_item.path,
        "",
      }

      if stats then
        table.insert(lines, "File Information:")
        table.insert(lines, "  Type: " .. stats.type)
        table.insert(lines, "  Size: " .. stats.size)
        if stats.line_count then
          table.insert(lines, "  Lines: " .. stats.line_count)
        end
        table.insert(lines, "  Modified: " .. stats.modified)
        table.insert(lines, "  Created: " .. stats.created)
        table.insert(lines, "  Permissions: " .. stats.permissions)
        table.insert(lines, "")
      end

      table.insert(lines, "---")
      table.insert(lines, "")
      table.insert(lines, "Press <CR> to paste into buffer")
      table.insert(lines, "Press <C-y> to copy to clipboard")
      table.insert(lines, "Press <C-m> to paste as markdown link")

      if ctx.buf and vim.api.nvim_buf_is_valid(ctx.buf) then
        vim.api.nvim_buf_set_option(ctx.buf, "modifiable", true)
        vim.api.nvim_buf_set_lines(ctx.buf, 0, -1, false, lines)
        vim.api.nvim_buf_set_option(ctx.buf, "modifiable", false)
        vim.bo[ctx.buf].filetype = "text"
        return true
      end

      return false
    end,
    actions = {
      quit_all = function(format_picker)
        format_picker:close()
        parent_picker:close()
      end,
      copy_to_clipboard = function(format_picker, selected_item)
        if selected_item and copy_to_clipboard(selected_item.path, selected_item.label) then
          -- Don't close the picker, allow multiple copies
        end
      end,
      paste_to_buffer = function(format_picker, selected_item)
        if selected_item then
          insert_at_cursor(selected_item.path, parent_picker, format_picker)
        end
      end,
      paste_to_buffer_markdown = function(format_picker, selected_item)
        if selected_item then
          insert_markdown_link(selected_item.path, parent_picker, format_picker)
        end
      end,
    },
    win = {
      input = {
        keys = {
          -- follow default keymap esc quit all
          -- ["<C-q>"] = {
          --   "quit_all",
          --   mode = { "n", "i" },
          --   desc = "Exit Quit all",
          -- },
          ["<C-p>"] = {
            "paste_to_buffer",
            mode = { "n", "i" },
            desc = "Paste path at cursor",
          },
          ["<C-y>"] = {
            "copy_to_clipboard",
            mode = { "n", "i" },
            desc = "Copy path to clipboard",
          },
          ["<C-n>"] = {
            "paste_to_buffer_markdown",
            mode = { "n", "i" },
            desc = "Paste as markdown link",
          },
          ["<A-c>"] = {
            function()
              -- Toggle column visibility for code-ref items
              vim.g.code_ref_hide_col = not (vim.g.code_ref_hide_col or false)
              local state = vim.g.code_ref_hide_col and "hidden" or "shown"
              vim.notify("Column: " .. state, vim.log.levels.INFO)

              -- Close and reopen with updated formats
              local pickers = Snacks.picker.get { source = "path_formats" }
              local cur_picker = pickers and pickers[1]
              if cur_picker then
                cur_picker:close()
              end

              vim.schedule(function()
                M.copy_path_select(parent_picker, item)
              end)
            end,
            mode = { "n", "i" },
            desc = "Toggle column visibility",
          },
        },
      },
    },
    confirm = function(format_picker, selected_item)
      if selected_item then
        insert_at_cursor(selected_item.path, parent_picker, format_picker)
      end
    end,
  }
end

--#endregion Path Copy Utilities

--#region CWD Cycling Actions

--- snacks.picker.actions: actions
function M.yank_sys(picker, item)
  local clipboardUtil = require "utils.myinput"
  picker:action "yank"
  clipboardUtil.copy_yank_to_system(true)
end

function M.select_subproject_cwd(picker, opts_or_item)
  -- Support opts table with persist_key for buffer-specific persistence
  local persist_key = "picker_cwd_cycle_state_value" -- default for files
  if type(opts_or_item) == "table" and opts_or_item.persist_key then
    persist_key = opts_or_item.persist_key
  end

  local pathUtil = require "utils.mypath"
  local path = require "utils.path"
  local picker_util = require "snacks.picker.util"

  local from_dir = pathUtil.get_previous_buffer_dir() or vim.fn.getcwd()
  local git_root = path.get_root_directory() or Snacks.git.get_root()
  local function fetch_subprojects(force_refresh)
    local subprojects = pathUtil.get_sub_project_dirs_from_root(git_root, from_dir, true, true, nil, {
      force_refresh = force_refresh,
    }) or {}
    if type(subprojects) ~= "table" then
      subprojects = { subprojects }
    end
    return subprojects
  end

  local items = {}
  local all_items = {}
  local cwd_items = {}
  local seen_dirs = {}

  local function build_item_meta(info, dir)
    local display_dir = dir and vim.fn.fnamemodify(dir, ":~") or ""
    local rel_path = ""
    if git_root and dir then
      local rel = dir:gsub("^" .. vim.pesc(git_root) .. "/?", "")
      rel_path = rel == "" and "." or rel
    end

    local sub_type = info and info.project_type or "subproj"
    local is_git_root = info and info.is_git_root
    local depth = info and info.depth_from_start or 0
    local full_path = dir or ""
    local trunc_full = full_path ~= "" and picker_util.truncpath(full_path, 50, { cwd = full_path }) or ""

    return {
      display_dir = display_dir,
      rel_path = rel_path,
      sub_type = is_git_root and "gitroot" or sub_type,
      is_git_root = is_git_root,
      depth = depth,
      full_path = full_path,
      trunc_full = trunc_full,
    }
  end

  local function build_preview_header(info, dir)
    local header = {}
    if info and info.depth_from_start ~= nil then
      table.insert(header, "depth:" .. tostring(info.depth_from_start))
    end
    if info and info.matched_file and info.matched_file ~= "" then
      local marker_label = info.matched_file
      -- Append scan source if not default tracked
      if info.scan_source and info.scan_source ~= "tracked" then
        marker_label = marker_label .. "(" .. info.scan_source .. ")"
      end
      table.insert(header, "marker:" .. marker_label)
    elseif info and info.project_type and info.project_type ~= "" then
      table.insert(header, "type:" .. info.project_type)
    end
    if info and info.in_submodule then
      table.insert(header, "submodule:" .. (info.submodule_root or "unknown"))
    end
    if git_root and dir then
      local rel = dir:gsub("^" .. vim.pesc(git_root) .. "/?", "")
      rel = rel == "" and "." or rel
      table.insert(header, "git:" .. rel)
    end
    return header
  end

  local function add_item(dir, label, info)
    if not dir or dir == "" then
      return
    end
    local key = vim.fn.fnamemodify(dir, ":p")
    if seen_dirs[key] then
      return
    end
    local meta = build_item_meta(info, dir)
    seen_dirs[key] = true

    -- Extract project type for searchable text
    local project_type = info and info.project_type or "subproj"
    local searchable_text = project_type .. " " .. dir

    table.insert(items, {
      text = searchable_text, -- Makes project type searchable (e.g., "yarn /path/to/frontend")
      data = dir, -- Preserves yank behavior to copy only clean directory path
      label = label,
      dir = dir,
      file = dir,
      info = info,
      meta = meta,
    })
  end

  local function rebuild_items(force_refresh)
    local subprojects = fetch_subprojects(force_refresh)
    items = {}
    seen_dirs = {}

    if git_root and vim.fn.isdirectory(git_root) == 1 then
      local root_info = { dir = git_root, project_type = "gitroot", is_git_root = true }
      add_item(git_root, "Git", root_info)
    end

    for _, sp_info in ipairs(subprojects) do
      add_item(sp_info.dir, "Sub-Project", sp_info)
    end

    all_items = items
    cwd_items = vim.tbl_filter(function(item)
      local info = item.info or {}
      return info.in_cwd_traversal or (item.meta and item.meta.is_git_root)
    end, items)

    return #items > 0
  end

  if not rebuild_items(false) then
    vim.notify("No subprojects found for current context", vim.log.levels.WARN)
    return
  end

  local show_all = true -- start in "root" (all) mode

  -- Compute short CWD context label for title (relative from git root)
  local from_dir_rel = "."
  if git_root and from_dir then
    local rel = from_dir:gsub("^" .. vim.pesc(git_root) .. "/?", "")
    from_dir_rel = rel == "" and "." or rel
  end

  local scope_modes = { "root", "cwd" }
  local function build_title()
    local scope_idx = show_all and 1 or 2
    local scope_label = scope_modes[scope_idx]
    return "Subproj [" .. from_dir_rel .. "] [" .. scope_label .. " " .. scope_idx .. "/" .. #scope_modes .. "]"
  end

  local function build_list_footer()
    return " cwd: " .. from_dir_rel .. " | git: " .. (git_root and vim.fn.fnamemodify(git_root, ":t") or "?")
  end

  -- Determine the current marker: persisted path, or cwd if none persisted
  local current_marker_dir = vim.g[persist_key]
  if not current_marker_dir or current_marker_dir == "" then
    current_marker_dir = vim.fn.getcwd()
  end
  current_marker_dir = vim.fn.fnamemodify(current_marker_dir, ":p"):gsub("/$", "")

  Snacks.picker.pick {
    source = "subproject_cwd",
    title = build_title(),
    items = items,
    format = function(item)
      local meta = item.meta or {}
      local info = item.info or {}

      -- CWD traversal indicator
      local cwd_prefix = info.in_cwd_traversal and "↑ " or "  "
      -- Active/persisted state marker
      local item_dir = vim.fn.fnamemodify(item.dir or "", ":p"):gsub("/$", "")
      local active_marker = item_dir == current_marker_dir and "* " or "  "

      -- Submodule indicator
      local submod_indicator = info.in_submodule and "[sub] " or ""

      if meta.is_git_root then
        local root_path = meta.display_dir ~= "" and meta.display_dir or (meta.full_path or "")
        return {
          { active_marker, "DiagnosticOk" },
          { cwd_prefix, "Comment" },
          { "Git ", "SnacksPickerLabel" },
          { root_path, "SnacksPickerFile" },
        }
      end

      return {
        { active_marker, "DiagnosticOk" },
        { cwd_prefix, "Comment" },
        { submod_indicator, "Special" },
        { meta.sub_type or "subproj", "SnacksPickerLabel" },
        { " d:" .. tostring(meta.depth or 0), "Comment" },
        { " ", "Comment" },
        { meta.rel_path or "", "SnacksPickerFile" },
        { " ", "Comment" },
        { meta.trunc_full or "", "Comment" },
      }
    end,
    preview = function(ctx)
      local item = ctx.item
      if not item then
        return false
      end

      local ok = Snacks.picker.preview.file(ctx)
      if ok == false then
        return ok
      end

      local info = item.info or {}
      local header = build_preview_header(info, item.dir)
      if #header > 0 and ctx.buf and vim.api.nvim_buf_is_valid(ctx.buf) then
        local lines = vim.api.nvim_buf_get_lines(ctx.buf, 0, -1, false)
        local header_line = table.concat(header, " | ")
        vim.api.nvim_buf_set_option(ctx.buf, "modifiable", true)
        vim.api.nvim_buf_set_lines(ctx.buf, 0, 0, false, { header_line, "" })
        -- vim.api.nvim_buf_set_lines(ctx.buf, 2, 2, false, lines)
        vim.api.nvim_buf_set_option(ctx.buf, "modifiable", false)
      end
      return ok
    end,
    actions = {
      apply_filter = function(subpicker, item)
        vim.print("Persist CWD: " .. tostring(item.dir))
        vim.g.picker_cwd_cycle_state = "subproject_picker"
        vim.g[persist_key] = item.dir
        -- close seems to also close the parent picker as well
        subpicker:action "cancel"
        -- Reset traversal state on parent picker for fresh chain from new initial cwd
        reset_picker_traversal_state(picker)
        local newOpts = require("utils.snacks_terminal").get_initial_picker_state {}
        picker.opts = vim.tbl_deep_extend("force", picker.opts, newOpts)
        -- Update parent picker title (skip git root — has its own toggle)
        local rel = item.dir:gsub("^" .. vim.pesc(git_root) .. "/?", "")
        if rel ~= "" then
          local source = picker.opts and picker.opts.source or "Picker"
          local title_source = type(source) == "string" and (source:sub(1, 1):upper() .. source:sub(2)) or "Picker"
          picker.title = string.format("%s [%s]", title_source, rel)
        end
        picker:find()
      end,
      apply_temp = function(subpicker, item)
        vim.print("Apply temp CWD: " .. tostring(item.dir))
        subpicker:action "cancel"
        reset_picker_traversal_state(picker)
        picker.opts.cwd = item.dir
        -- Update parent picker title (skip git root — has its own toggle)
        local rel = item.dir:gsub("^" .. vim.pesc(git_root) .. "/?", "")
        if rel ~= "" then
          local source = picker.opts and picker.opts.source or "Picker"
          local title_source = type(source) == "string" and (source:sub(1, 1):upper() .. source:sub(2)) or "Picker"
          picker.title = string.format("%s [%s]", title_source, rel)
        end
        picker:find()
      end,
      toggle_scope = function(subpicker)
        show_all = not show_all
        subpicker.opts.title = build_title()
        subpicker.opts.items = show_all and all_items or cwd_items
        subpicker:find()
      end,
      refresh_subprojects = function(subpicker)
        pathUtil.clear_subproject_cache { silent = true }
        if not rebuild_items(true) then
          vim.notify("No subprojects found for current context", vim.log.levels.WARN)
          return
        end
        subpicker.opts.title = build_title()
        subpicker.opts.items = show_all and all_items or cwd_items
        vim.notify("Subproject cache refreshed", vim.log.levels.INFO)
        subpicker:find()
      end,
    },
    win = {
      preview = {
        width = 0.25,
        min_width = 20,
      },
      list = {
        border = "bottom",
        footer = build_list_footer(),
        footer_pos = "left",
      },
      input = {
        footer = "CR:persist C-s:apply M-S:scope C-r:ref",
        keys = {
          ["<CR>"] = {
            "apply_filter",
            mode = { "n", "i" },
            desc = "Persist CWD",
          },
          ["<C-s>"] = {
            "apply_temp",
            mode = { "n", "i" },
            desc = "Apply CWD (temp)",
          },
          ["<M-S>"] = {
            "toggle_scope",
            mode = { "n", "i" },
            desc = "Toggle root/cwd scope",
          },
          ["<C-r>"] = {
            "refresh_subprojects",
            mode = { "n", "i" },
            desc = "Refresh subprojects",
          },
          -- default cancel with c-q
        },
      },
    },
  }
end

--- Toggle CWD scope for pickers (files/grep/etc)
--- Traverses upward through subproject markers from initial scope cwd to git root
--- Short-lived: does NOT persist across picker sessions (only A-S persists)
function M.toggle_cwd_files_grep(picker, item)
  local chain, step_idx = get_picker_traversal_state(picker, "picker_cwd_cycle_state_value")

  if #chain <= 1 then
    vim.notify("Only one scope available — no other levels to traverse", vim.log.levels.INFO)
    return
  end

  -- Advance to next step
  local next_idx = step_idx + 1

  if next_idx > #chain then
    -- Was at top (git root) — wrap to initial
    vim.notify("Returning to initial scope", vim.log.levels.INFO)
    next_idx = 1
  end

  picker.opts._scope_step_index = next_idx
  local new_cwd = chain[next_idx]

  -- Reset external state when scope changes
  picker.opts._external_step_index = nil
  picker.opts._external_exclude_cwd = nil
  picker.opts._external_original_exclude = nil
  picker.opts.external = nil
  picker.opts.exclude = nil

  -- Apply new cwd
  local source = picker.opts and picker.opts.source or "Picker"
  local title_source = type(source) == "string" and (source:sub(1, 1):upper() .. source:sub(2)) or "Picker"
  local git_root = require("utils.path").get_root_directory() or Snacks.git.get_root()
  local short_cwd = new_cwd
  if git_root then
    local rel = new_cwd:gsub("^" .. vim.pesc(git_root) .. "/?", "")
    short_cwd = rel == "" and "." or rel
  end

  picker.opts.cwd = new_cwd
  picker.opts.args = nil -- clear any max-depth from previous state
  picker.opts.show_empty = true
  picker.title = string.format("%s [%s] (%d/%d)", title_source, short_cwd, next_idx, #chain)

  -- Preserve search state
  local filter_pattern = picker.input.filter and (picker.input.filter.pattern ~= "" and picker.input.filter.pattern)
  local filter_search = picker.input.filter and (picker.input.filter.search ~= "" and picker.input.filter.search)
  if filter_pattern then
    picker.opts.pattern = filter_pattern
  end
  if filter_search then
    picker.opts.search = filter_search
  end

  if next_idx == #chain then
    vim.notify(string.format("Scope: git root\nNext toggle returns to initial", short_cwd), vim.log.levels.INFO)
  else
    vim.notify(string.format("Scope: %s (%d/%d)", short_cwd, next_idx, #chain), vim.log.levels.INFO)
  end

  picker:refresh()
end

--#endregion CWD Cycling Actions

--#region Depth Adjustment Actions

--- Adjust max-depth for files/grep pickers dynamically
--- @param picker table Snacks picker instance
--- @param item table Current item
--- @param direction number 1 to increase, -1 to decrease, 0 to reset
--- @param max_depth_limit number|nil Maximum depth limit
function M.adjust_picker_depth(picker, item, direction, max_depth_limit)
  local current_depth = picker.opts.max_depth
  local new_depth

  if direction == 0 then
    if current_depth == nil then
      return
    end
    new_depth = nil
  elseif direction > 0 then
    if current_depth == nil then
      new_depth = 10
    else
      new_depth = current_depth + 1
      if max_depth_limit and new_depth > max_depth_limit then
        new_depth = nil
      end
    end
  else
    if current_depth == nil then
      new_depth = 10
    elseif current_depth > 1 then
      new_depth = current_depth - 1
    else
      new_depth = 1
    end
  end

  picker.opts.max_depth = new_depth

  local depth_label = new_depth and tostring(new_depth) or "unlimited"

  if new_depth then
    picker.opts.args = { "--max-depth", tostring(new_depth) }
  else
    picker.opts.args = nil
  end

  if picker.title then
    local base_title = picker.title:gsub("%s*%-d=%d+", "")
    base_title = base_title:gsub("%s*%((Depth%s*%d+|Unlimited)%s*%)", "")

    if new_depth then
      picker.title = base_title .. " -d=" .. tostring(new_depth)
    else
      picker.title = base_title
    end
  end

  picker:refresh()
end

--#endregion Depth Adjustment Actions

--#region Buffer Filtering Actions

--- Filter buffers outside the current git root
--- @param picker table Snacks picker instance
--- @param item table Current item (unused)
function M.filter_buffers_outside_git_root(picker, item)
  local git_root = Snacks.git.get_root()

  if not git_root then
    vim.notify("Not in a git repository", vim.log.levels.WARN)
    return
  end

  local git_root_escaped = vim.pesc(git_root)

  -- Get all buffers and filter
  local filtered_items = {}
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      local buf_path = vim.api.nvim_buf_get_name(bufnr)
      if buf_path and buf_path ~= "" then
        local abs_path = vim.fn.fnamemodify(buf_path, ":p")
        -- Check if path does NOT start with git_root
        if not abs_path:match("^" .. git_root_escaped) then
          table.insert(filtered_items, {
            buf = bufnr,
            file = buf_path,
            path = buf_path,
            _path = buf_path,
          })
        end
      end
    end
  end

  if #filtered_items == 0 then
    vim.notify("No buffers outside git root found", vim.log.levels.INFO)
    return
  end

  local parent_picker = picker

  Snacks.picker.pick {
    source = "filtered_buffers",
    title = string.format("Buffers Outside Git Root (%d)", #filtered_items),
    items = filtered_items,
    format = function(buffer_item)
      local path = buffer_item.file or buffer_item.path or buffer_item._path
      local display_path = path and vim.fn.fnamemodify(path, ":~") or "?"
      local filename = path and vim.fn.fnamemodify(path, ":t") or "?"

      return {
        { filename, "SnacksPickerFile" },
        { " ", "Comment" },
        { display_path, "Comment" },
      }
    end,
    preview = function(ctx)
      local buffer_item = ctx.item
      if not buffer_item then
        return false
      end

      local buf_path = buffer_item.file or buffer_item.path or buffer_item._path
      if buf_path and vim.fn.filereadable(buf_path) == 1 then
        ctx:preview_file(buf_path)
        return true
      end

      return false
    end,
    actions = {
      delete_buffer = function(filtered_picker, selected_item)
        if selected_item and selected_item.buf then
          vim.api.nvim_buf_delete(selected_item.buf, { force = false })
          vim.notify("Buffer deleted: " .. (selected_item.file or "?"), vim.log.levels.INFO)
          filtered_picker:refresh()
          if parent_picker and parent_picker.refresh then
            parent_picker:refresh()
          end
        end
      end,
      force_delete_buffer = function(filtered_picker, selected_item)
        if selected_item and selected_item.buf then
          vim.api.nvim_buf_delete(selected_item.buf, { force = true })
          vim.notify("Buffer force deleted: " .. (selected_item.file or "?"), vim.log.levels.WARN)
          filtered_picker:refresh()
          if parent_picker and parent_picker.refresh then
            parent_picker:refresh()
          end
        end
      end,
    },
    win = {
      input = {
        keys = {
          ["<C-d>"] = {
            "delete_buffer",
            mode = { "n", "i" },
            desc = "Delete buffer",
          },
          ["<C-D>"] = {
            "force_delete_buffer",
            mode = { "n", "i" },
            desc = "Force delete buffer",
          },
        },
      },
    },
  }
end

--- Filter buffers with non-existent file paths
--- @param picker table Snacks picker instance
--- @param item table Current item (unused)
function M.filter_buffers_nonexistent(picker, item)
  -- Get all buffers and filter for non-existent files
  local filtered_items = {}
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      local buf_path = vim.api.nvim_buf_get_name(bufnr)
      if buf_path and buf_path ~= "" then
        local abs_path = vim.fn.fnamemodify(buf_path, ":p")
        -- Check if file does NOT exist
        if vim.fn.filereadable(abs_path) == 0 and vim.fn.isdirectory(abs_path) == 0 then
          table.insert(filtered_items, {
            buf = bufnr,
            file = buf_path,
            path = buf_path,
            _path = buf_path,
          })
        end
      end
    end
  end

  if #filtered_items == 0 then
    vim.notify("No buffers with non-existent paths found", vim.log.levels.INFO)
    return
  end

  local parent_picker = picker

  Snacks.picker.pick {
    source = "filtered_buffers",
    title = string.format("Buffers with Non-existent Paths (%d)", #filtered_items),
    items = filtered_items,
    format = function(buffer_item)
      local path = buffer_item.file or buffer_item.path or buffer_item._path
      local display_path = path and vim.fn.fnamemodify(path, ":~") or "?"
      local filename = path and vim.fn.fnamemodify(path, ":t") or "?"

      return {
        { "✗ ", "DiagnosticError" },
        { filename, "SnacksPickerFile" },
        { " ", "Comment" },
        { display_path, "Comment" },
      }
    end,
    preview = function(ctx)
      local buffer_item = ctx.item
      if not buffer_item then
        return false
      end

      local buf_path = buffer_item.file or buffer_item.path or buffer_item._path
      local lines = {
        "Non-existent Buffer",
        "",
        "Path: " .. (buf_path or "unknown"),
        "",
        "This buffer points to a file that no longer exists.",
        "",
        "Actions:",
        "  <CR>   - Close this picker",
        "  <C-d>  - Delete buffer (safe)",
        "  <C-D>  - Force delete buffer",
      }

      if ctx.buf and vim.api.nvim_buf_is_valid(ctx.buf) then
        vim.api.nvim_buf_set_option(ctx.buf, "modifiable", true)
        vim.api.nvim_buf_set_lines(ctx.buf, 0, -1, false, lines)
        vim.api.nvim_buf_set_option(ctx.buf, "modifiable", false)
        vim.bo[ctx.buf].filetype = "text"
        return true
      end

      return false
    end,
    actions = {
      delete_buffer = function(filtered_picker, selected_item)
        if selected_item and selected_item.buf then
          vim.api.nvim_buf_delete(selected_item.buf, { force = false })
          vim.notify("Buffer deleted: " .. (selected_item.file or "?"), vim.log.levels.INFO)
          filtered_picker:refresh()
          if parent_picker and parent_picker.refresh then
            parent_picker:refresh()
          end
        end
      end,
      force_delete_buffer = function(filtered_picker, selected_item)
        if selected_item and selected_item.buf then
          vim.api.nvim_buf_delete(selected_item.buf, { force = true })
          vim.notify("Buffer force deleted: " .. (selected_item.file or "?"), vim.log.levels.WARN)
          filtered_picker:refresh()
          if parent_picker and parent_picker.refresh then
            parent_picker:refresh()
          end
        end
      end,
    },
    win = {
      input = {
        keys = {
          ["<C-d>"] = {
            "delete_buffer",
            mode = { "n", "i" },
            desc = "Delete buffer",
          },
          ["<C-D>"] = {
            "force_delete_buffer",
            mode = { "n", "i" },
            desc = "Force delete buffer",
          },
        },
      },
    },
  }
end

--#endregion Buffer Filtering Actions

--#region Picker Switching Actions

--- 3-way cycle: files → buffers → grep → files
--- Preserves search pattern, saves current picker's toggle opts before switching,
--- and loads destination source's persisted opts.
--- Closes the current picker before opening the next to avoid orphan pickers
--- that cause double-press and focus issues.
--- @param picker table Snacks picker instance
--- @param item table Current item (unused)
function M.toggle_picker_source(picker, item)
  local current_source = picker.opts and picker.opts.source
  if not current_source then
    -- Fallback: try init_opts.source
    current_source = picker.init_opts and picker.init_opts.source
  end
  if not current_source then
    vim.notify("toggle_picker_source: cannot determine current source", vim.log.levels.ERROR)
    return
  end

  -- Save current picker's toggle opts before switching away
  M.save_picker_source_opts(picker)

  -- Read the correct search text based on current source:
  -- - For grep/grep_word: the user's query is in filter.search (pattern is the result filter)
  -- - For files/buffers: the user's input is in filter.pattern
  local current_search
  if current_source == "grep" or current_source == "grep_word" then
    current_search = picker.input.filter and picker.input.filter.search or ""
  else
    current_search = picker.input.filter and picker.input.filter.pattern or ""
  end

  -- Determine the next source in the cycle: files → buffers → grep → files
  -- grep_word is treated the same as grep in the cycle
  local next_source
  if current_source == "files" then
    next_source = "buffers"
  elseif current_source == "buffers" then
    next_source = "grep"
  elseif current_source == "grep" or current_source == "grep_word" then
    next_source = "files"
  else
    -- Unknown source (smart, etc.) — default: cycle to files
    next_source = "files"
  end

  -- Close the current picker before opening the next one.
  -- Without this, orphaned pickers stack up and intercept keypresses,
  -- causing the "double-press required after full cycle" bug.
  picker:close()

  -- Open the destination picker (deferred to let close complete cleanly)
  vim.schedule(function()
    if next_source == "buffers" then
      Snacks.picker.buffers {
        pattern = current_search ~= "" and current_search or nil,
        show_empty = true,
        hidden = false, -- buffers don't use hidden/ignored toggles
      }
      -- Ensure insert mode (buffers picker sometimes lands in normal)
      vim.defer_fn(function()
        if vim.api.nvim_get_mode().mode == "n" then
          vim.cmd "startinsert"
        end
      end, 50)
    elseif next_source == "grep" then
      local carry_search = current_search ~= "" and current_search or nil
      -- For grep: use get_initial_picker_state to load persisted per-source opts
      local snacks_util = require "utils.snacks_terminal"
      local picker_opts = snacks_util.get_initial_picker_state({
        show_empty = true,
        search = carry_search,
        live = true,
      }, { source = "grep" })
      Snacks.picker.grep(picker_opts)
    elseif next_source == "files" then
      -- Use get_initial_picker_state to load persisted per-source opts
      local snacks_util = require "utils.snacks_terminal"
      local picker_opts = snacks_util.get_initial_picker_state({
        pattern = current_search ~= "" and current_search or nil,
      }, { source = "files" })
      Snacks.picker.files(picker_opts)
    end
  end)
end

--- Legacy alias for backwards compatibility (if referenced elsewhere)
function M.toggle_files_buffers(picker, item)
  M.toggle_picker_source(picker, item)
end

--#endregion Picker Switching Actions

--#region Quickfix Actions

--- Remove an item from the quickfix list
--- Works for both qflist picker and grep picker
--- @param picker table Snacks picker instance
--- @param item table Item to remove from quickfix
function M.remove_qf_item(picker, item)
  if not item then
    return
  end

  -- Get current quickfix list
  local qflist = vim.fn.getqflist()

  if #qflist == 0 then
    vim.notify("Quickfix list is empty. Send items to quickfix with <A-q> first.", vim.log.levels.WARN)
    return
  end

  -- For grep results, we need to match by file, line, and text
  -- For qflist items, we can use the index
  local idx = item.idx

  if idx and idx > 0 and idx <= #qflist then
    -- Direct index match (works for qflist picker)
    table.remove(qflist, idx)
    vim.fn.setqflist(qflist, "r")
    picker:refresh()
  else
    -- Try to find by matching file, line, and column (works for grep picker)
    local removed = false
    for i = #qflist, 1, -1 do
      local qf_item = qflist[i]
      local qf_file = qf_item.filename or (qf_item.bufnr and vim.api.nvim_buf_get_name(qf_item.bufnr))
      local item_file = item.file or item.filename

      if qf_file == item_file and qf_item.lnum == item.lnum then
        -- Additional check for column if available
        if not item.col or qf_item.col == item.col then
          table.remove(qflist, i)
          removed = true
          break
        end
      end
    end

    if removed then
      vim.fn.setqflist(qflist, "r")
      picker:refresh()
    else
      vim.notify("Could not find item in quickfix list", vim.log.levels.WARN)
    end
  end
end

--#endregion Quickfix Actions

--#region Git Picker Actions

--- Toggle between git_diff group view and git_status picker
--- @param picker table Snacks picker instance
--- @param item table Current item (unused)
function M.gitdiff_toggle_group(picker, item)
  -- Toggle between git_diff and git_files sources
  if picker.opts.source == "git_diff" and not picker.opts.group then
    picker.opts.group = true
    Snacks.debug "Switched to git_diff group"
  elseif picker.opts.source == "git_diff" then
    picker.opts.group = false
    picker = Snacks.picker.git_status {}
    return
  elseif picker.opts.source == "git_status" then
    picker = Snacks.picker.git_diff {}
    return
  end
  picker:refresh()
end

--- Open file in remote repository at specific reference
--- Supports git_files, files, and buffers pickers
--- @param picker table Snacks picker instance
--- @param item table Item containing file path and optional branch/commit
function M.open_file_remote(picker, item)
  local pathUtil = require "utils.mypath"
  local gitUtil = require "utils.git"
  local editor_keymaps = require "utils.editor_keymaps"

  local preview_source = picker.init_opts and picker.init_opts.source

  local current_buf_path = editor_keymaps.helpers.get_current_buffer_path()
  local last_bufferpath = vim.api.nvim_buf_get_name(vim.fn.bufnr "#")

  local chosen_path = item._path
  if not chosen_path or chosen_path == "" then
    if current_buf_path and current_buf_path ~= "" then
      chosen_path = current_buf_path
    else
      chosen_path = last_bufferpath
    end
  end

  local filepath = pathUtil.get_git_real_filepath(chosen_path)

  local ref = item.branch or item.commit
  if not ref then
    if preview_source == "git_files" then
      ref = gitUtil.get_current_git_branch()
    elseif preview_source == "files" or preview_source == "buffers" then
      ref = nil
    else
      vim.notify("No reference found for this item", vim.log.levels.WARN)
    end
  end

  gitUtil.open_remote(ref, "file", filepath)
end

--- Open merge request for a branch
--- @param picker table Snacks picker instance
--- @param item table Item containing branch name
function M.open_mr(picker, item)
  local gitUtil = require "utils.git"
  local branch = item.branch
  if not branch then
    vim.notify("No branch found for this item", vim.log.levels.WARN)
    return
  end
  gitUtil.open_mr(branch)
end

--#endregion Git Picker Actions

--#region Case Sensitivity Actions

--- Toggle case sensitivity for files/grep pickers
--- Cycles through: case-sensitive -> ignore-case -> smart-case
--- Handles both fd (files) and rg (grep) arguments
--- @param picker table Snacks picker instance
--- @param item table Current item (unused)
function M.toggle_case_sensitivity(picker, item)
  local current_args = vim.deepcopy(picker.opts.args) or {}
  local before_args = vim.deepcopy(current_args)
  local has_ignore_case = vim.tbl_contains(current_args, "-i") or vim.tbl_contains(current_args, "--ignore-case")
  local has_casesens = vim.tbl_contains(current_args, "-s") or vim.tbl_contains(current_args, "--case-sensitive")
  local current_search = picker.input.filter and picker.input.filter.search
  local search_query_has_upper = current_search and current_search:match "%u"

  local source = picker.opts.source

  local function remove_exist_flags(args, flags)
    return vim.tbl_filter(function(arg)
      return not vim.tbl_contains(flags, arg)
    end, args)
  end

  local is_case_sensitive_perceived = has_casesens or (not has_ignore_case and search_query_has_upper)

  local is_next_sensitive = nil
  print([==[Toggle before args:]==], vim.inspect(picker.opts.args))

  if has_ignore_case then
    current_args = remove_exist_flags(current_args, { "-i", "--ignore-case" })
    current_args = remove_exist_flags(current_args, { "-s", "--case-sensitive" })
  elseif is_case_sensitive_perceived then
    -- Add ignore case flag
    current_args = remove_exist_flags(current_args, { "-i", "--ignore-case" })
    current_args = remove_exist_flags(current_args, { "-s", "--case-sensitive" })
    table.insert(current_args, "--ignore-case")
    is_next_sensitive = false
  else
    -- Add case sensitive flag
    current_args = remove_exist_flags(current_args, { "-i", "--ignore-case" })
    current_args = remove_exist_flags(current_args, { "-s", "--case-sensitive" })
    table.insert(current_args, "--case-sensitive")
    is_next_sensitive = true
  end

  picker.opts.args = current_args

  -- For file/buffer pickers, also update matcher settings
  if source == "files" or source == "buffers" or source == "smart" then
    local smartcase = picker.opts.matcher.smartcase
    local ignorecase = picker.opts.matcher.ignorecase
    local init_smartcase = picker.init_opts.matcher and picker.init_opts.matcher.smartcase
    local init_ignorecase = picker.init_opts.matcher and picker.init_opts.matcher.ignorecase

    print(
      [==[snacks_opt_tgg#picker.opts.matcher:]==],
      vim.inspect {
        smartcase = smartcase,
        ignorecase = ignorecase,
        init_smartcase = init_smartcase,
        init_ignorecase = init_ignorecase,
      }
    )

    if is_next_sensitive then
      picker.opts.matcher.ignorecase = false
      picker.opts.matcher.smartcase = false
    elseif is_next_sensitive == false then
      picker.opts.matcher.ignorecase = true
      picker.opts.matcher.smartcase = false
    else
      picker.opts.matcher.ignorecase = false
      picker.opts.matcher.smartcase = false
    end

    picker.matcher = require("snacks.picker.core.matcher").new(picker.opts.matcher)
  end

  picker.opts.case_sensitive_custom = is_next_sensitive
  picker.opts.case_nonsensitive_custom = is_next_sensitive == false

  M.log_picker_persist("toggle_case_sensitivity", {
    source = source,
    before_args = before_args,
    after_args = picker.opts.args,
    case_sensitive_custom = picker.opts.case_sensitive_custom,
    case_nonsensitive_custom = picker.opts.case_nonsensitive_custom,
  })

  -- Persist case mode per source
  M.save_picker_source_opts(picker)

  picker:find()
end

--#endregion Case Sensitivity Actions

--#region Undo Pickers action
M.undo_picker_split = function(picker, item)
  -- __AUTO_GENERATED_PRINT_VAR_START__
  if not item then
    return
  end
  -- Create a new tab
  -- picker:close()
  vim.cmd.tabnew()

  -- Get the current buffer (original file)
  local orig_buf = item.buf
  -- __AUTO_GENERATED_PRINT_VAR_START__
  local orig_file = vim.api.nvim_buf_get_name(orig_buf)

  -- Load the original file in the new tab (left window) - keep editable
  vim.cmd("edit " .. orig_file)
  local left_win = vim.api.nvim_get_current_win()
  local left_buf = vim.api.nvim_get_current_buf()

  -- Create a temporary buffer for the full undo state (right window)
  vim.cmd "vsplit"
  local right_win = vim.api.nvim_get_current_win()
  local right_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(right_win, right_buf)

  -- Get the full undo state content
  -- We need to replay the undo in a temporary buffer to get full content
  local tmp_file = vim.fn.stdpath "cache" .. "/snacks-undo-diff"
  local tmp_undo = tmp_file .. ".undo"
  local tmpbuf = vim.fn.bufadd(tmp_file)
  vim.bo[tmpbuf].swapfile = false
  vim.fn.writefile(vim.api.nvim_buf_get_lines(orig_buf, 0, -1, false), tmp_file)
  vim.fn.bufload(tmpbuf)

  -- Save and load undo history
  vim.api.nvim_buf_call(orig_buf, function()
    vim.cmd("silent wundo! " .. tmp_undo)
  end)
  vim.api.nvim_buf_call(tmpbuf, function()
    pcall(vim.cmd, "silent rundo " .. tmp_undo)
    -- Apply the specific undo
    vim.cmd("noautocmd silent undo " .. item.seq)
    -- Get the full content after undo
    local undo_content = vim.api.nvim_buf_get_lines(tmpbuf, 0, -1, false)
    -- Set the undo content in the right buffer
    vim.api.nvim_buf_set_lines(right_buf, 0, -1, false, undo_content)
  end)

  -- Clean up temporary buffer
  vim.api.nvim_buf_delete(tmpbuf, { force = true })
  vim.fn.delete(tmp_file)
  vim.fn.delete(tmp_undo)

  -- Make right buffer read-only (left stays editable)
  vim.bo[right_buf].readonly = true
  vim.bo[right_buf].modifiable = false

  -- Set up diff mode
  vim.cmd "diffthis"
  vim.api.nvim_set_current_win(left_win)
  vim.cmd "diffthis"

  -- Set buffer names
  vim.bo[right_buf].filetype = vim.bo[left_buf].filetype
  local undo_filename = "undo_" .. item.seq .. "//" .. orig_file
  vim.api.nvim_buf_set_name(right_buf, undo_filename)
  -- vim.api.nvim_buf_set_name(right_buf, "undo_" .. item.seq .. " (readonly)")
end
--#endregion

--#region Exported Action Tables

-- Path copy actions table
M.path_copy_actions = {
  copy_path_relative_buffer = M.copy_path_relative_buffer,
  copy_path_relative_git = M.copy_path_relative_git,
  copy_path_relative_cwd = M.copy_path_relative_cwd,
  copy_path_absolute = M.copy_path_absolute,
  copy_path_select = M.copy_path_select,
}

-- Buffer filtering actions table (only for buffer picker)
M.buffer_filter_actions = {
  filter_buffers_outside_git_root = M.filter_buffers_outside_git_root,
  filter_buffers_nonexistent = M.filter_buffers_nonexistent,
}

-- Action factories for creating git file actions with ref resolution
M.action_factories = {
  --- Create git file actions with ref resolution
  --- @param ref_provider string Git ref to use
  --- @param no_resolve boolean If true, skip ref resolution
  --- @return table actions Table containing action functions with metadata
  create_git_file_actions = function(ref_provider, no_resolve)
    local ref = ref_provider
    if not no_resolve and ref_provider then
      ref = ref_provider and gitUtil.get_ref_metadata(ref_provider).resolved_ref or ref_provider
    end
    return {
      open_file_diff = function(picker, item)
        if not item or not item.file then
          vim.notify("No file selected", vim.log.levels.WARN)
          return
        end
        picker:close()
        M.open_file_with_gitsigns_diff(item.file, ref)
      end,
      open_remote_at_ref = function(picker, item)
        if not item or not item.file then
          vim.notify("No file selected", vim.log.levels.WARN)
          return
        end
        M.open_file_in_remote(item.file, ref)
      end,
      open_remote_at_head = function(picker, item)
        if not item or not item.file then
          vim.notify("No file selected", vim.log.levels.WARN)
          return
        end
        M.open_file_in_remote(item.file, "HEAD")
      end,
    }
  end,
}

--#endregion Exported Action Tables

return M
