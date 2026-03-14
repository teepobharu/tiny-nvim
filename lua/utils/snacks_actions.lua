-- Snacks Picker Actions
-- All reusable picker actions extracted from editor_keymaps.lua and snacks_terminal.lua
-- This module contains action functions that can be used across different snacks pickers

---@class snacks.picker.actions
---@field [string] snacks.picker.Action.spec
local M = {}

local pathUtil = require "utils.mypath"
local gitUtil = require "utils.git"

--- Toggle picker external filter flag and re-run finder
--- @param picker table Snacks picker instance
function M.toggle_external(picker)
  if not picker then
    return
  end
  if vim.g.snacks_debug_external_filter then
    print(
      string.format(
        "toggle_external: source=%s -> %s",
        picker.opts and picker.opts.source or "unknown",
        tostring(not picker.opts.external)
      )
    )
  end
  picker.opts.external = not picker.opts.external
  picker:find()
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
        path = hide_col and string.format("@%s %d", path, line) or string.format("@%s %d:%d", path, line, col),
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

function M.select_subproject_cwd(picker)
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

  Snacks.picker.pick {
    source = "subproject_cwd",
    title = "Subprojects [root]",
    items = items,
    format = function(item)
      local meta = item.meta or {}
      local info = item.info or {}

      -- CWD traversal indicator
      local cwd_prefix = info.in_cwd_traversal and "↑ " or "  "

      -- Submodule indicator
      local submod_indicator = info.in_submodule and "[sub] " or ""

      if meta.is_git_root then
        local root_path = meta.display_dir ~= "" and meta.display_dir or (meta.full_path or "")
        return {
          { cwd_prefix, "Comment" },
          { "Git ", "SnacksPickerLabel" },
          { root_path, "SnacksPickerFile" },
        }
      end

      return {
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
        vim.print("Applying CWD: " .. tostring(item.dir))
        vim.g.picker_cwd_cycle_state = "subproject_picker"
        vim.g.picker_cwd_cycle_state_value = item.dir
        -- close seems to also close the parent picker as well
        subpicker:action "cancel"
        -- vim.print(vim.inspect {
        --   picker_cwd_cycle_state = vim.g.picker_cwd_cycle_state,
        --   picker_cwd_cycle_state_value = vim.g.picker_cwd_cycle_state_value,
        -- })
        local newOpts = require("utils.snacks_terminal").get_initial_picker_state {}
        picker.opts = vim.tbl_deep_extend("force", picker.opts, newOpts)
        -- vim.print(picker.opts.cwd)
        picker:find()
      end,
      toggle_scope = function(subpicker)
        show_all = not show_all
        local mode_label = show_all and "[root]" or "[cwd]"
        subpicker.opts.title = "Subprojects " .. mode_label
        subpicker.opts.items = show_all and all_items or cwd_items
        subpicker:find()
      end,
      refresh_subprojects = function(subpicker)
        pathUtil.clear_subproject_cache { silent = true }
        if not rebuild_items(true) then
          vim.notify("No subprojects found for current context", vim.log.levels.WARN)
          return
        end
        local mode_label = show_all and "[root]" or "[cwd]"
        subpicker.opts.title = "Subprojects " .. mode_label
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
      input = {
        footer = "<CR/C-s> apply, <M-S> toggle scope, <C-r> refresh, <C-q> cancel",
        keys = {
          ["<CR>"] = {
            "apply_filter",
            mode = { "n", "i" },
            desc = "Apply subproject CWD",
          },
          ["<C-s>"] = {
            "apply_filter",
            mode = { "n", "i" },
            desc = "Apply subproject CWD",
          },
          ["<M-S>"] = {
            "toggle_scope",
            mode = { "n", "i" },
            desc = "Toggle root/cwd scope",
          },
          ["<C-r>"] = {
            "refresh_subprojects",
            mode = { "n", "i" },
            desc = "Force refresh subprojects",
          },
          -- default cancel with c-q
        },
      },
    },
  }
end

--- Toggle CWD scope for pickers (files/grep/etc)
--- Cycles through: current dir -> git root -> sub-project dir -> previous buffer dir
function M.toggle_cwd_files_grep(picker, item)
  local path = require "utils.path"

  local current_dir = vim.fn.getcwd()
  local git_root = path.get_root_directory()
  local prev_buffer_dir = pathUtil.get_previous_buffer_dir()

  local function calculate_relative_depth(from_dir, to_dir)
    if not from_dir or not to_dir then
      return nil
    end
    local depth = 0
    local temp_dir = from_dir
    while temp_dir and temp_dir ~= "/" and temp_dir ~= to_dir do
      depth = depth + 1
      local parent = vim.fn.fnamemodify(temp_dir, ":h")
      if parent == temp_dir then
        return nil
      end
      temp_dir = parent
    end
    return temp_dir == to_dir and depth or nil
  end

  local sub_projects = pathUtil.get_sub_project_dirs_from_root(nil, prev_buffer_dir, true, true, "nearest") or {}
  local sub_project_results = {}
  for i, sp in ipairs(sub_projects) do
    if not sp.is_git_root then
      sp.relative_depth = calculate_relative_depth(prev_buffer_dir, sp.dir)
      table.insert(sub_project_results, sp)
      if #sub_project_results >= 3 then
        break
      end
    end
  end

  if not vim.g.picker_cwd_cycle_state then
    vim.g.picker_cwd_cycle_state = "current"
  end

  local cycle_order = { "current", "gitroot" }

  for i, _ in ipairs(sub_project_results) do
    table.insert(cycle_order, "subproject" .. i)
  end

  table.insert(cycle_order, "prevbuffer")
  table.insert(cycle_order, "current_d1")

  local cwd_map = {
    gitroot = git_root,
    current = current_dir,
    current_d1 = current_dir,
    prevbuffer = prev_buffer_dir,
  }

  local subproject_metadata = {}

  for i, sp_info in ipairs(sub_project_results) do
    local state_key = "subproject" .. i
    cwd_map[state_key] = sp_info.dir
    subproject_metadata[state_key] = sp_info
  end

  local seen_dirs = {}
  local unique_cycle_order = {}

  for _, state in ipairs(cycle_order) do
    local dir = cwd_map[state]
    if dir and dir ~= "" and vim.fn.isdirectory(dir) == 1 then
      local dir_key = (state == "current_d1") and "current_d1" or dir

      if not seen_dirs[dir_key] then
        seen_dirs[dir_key] = { state }
        table.insert(unique_cycle_order, state)
      else
        table.insert(seen_dirs[dir_key], state)
        cwd_map[state] = nil
      end
    else
      cwd_map[state] = nil
    end
  end

  cycle_order = unique_cycle_order

  if #cycle_order == 0 then
    cycle_order = { "current" }
    cwd_map = { current = current_dir }
  end

  if #cycle_order == 1 then
    vim.notify("Only one unique directory available - no other scopes to cycle to", vim.log.levels.INFO)
    return
  end

  local current_state_idx = nil
  for i, state in ipairs(cycle_order) do
    if state == vim.g.picker_cwd_cycle_state then
      current_state_idx = i
      break
    end
  end

  if not current_state_idx then
    current_state_idx = 0
  end

  local next_idx = (current_state_idx % #cycle_order) + 1
  vim.g.picker_cwd_cycle_state = cycle_order[next_idx]
  vim.g.picker_cwd_cycle_state_value = cwd_map[vim.g.picker_cwd_cycle_state]
  Snacks.notify.info("CWD Cycle State changed to: " .. vim.g.picker_cwd_cycle_state)
  local new_cwd = cwd_map[vim.g.picker_cwd_cycle_state]

  local source = picker.init_opts and picker.init_opts.source
  local filter_pattern = picker.input.filter and (picker.input.filter.pattern ~= "" and picker.input.filter.pattern)
  local filter_search = picker.input.filter and (picker.input.filter.search ~= "" and picker.input.filter.search)

  local state_labels = {
    current = cwd_map.current == cwd_map.gitroot and "Default/Git" or "Default/current",
    current_d1 = (cwd_map.current == cwd_map.gitroot and "Default/Git" or "Default/current") .. "(D=1)",
    gitroot = "Git Root",
    prevbuffer = "Previous Buf Dir",
  }

  local project_types = {}
  local has_duplicate_types = false
  for _, sp_info in pairs(subproject_metadata) do
    local ptype = sp_info.project_type or "unknown"
    if project_types[ptype] then
      has_duplicate_types = true
      break
    end
    project_types[ptype] = true
  end

  for state_key, sp_info in pairs(subproject_metadata) do
    local label = "Sub-Project"

    if sp_info.project_type and sp_info.project_type ~= "gitroot" then
      label = label .. " (" .. sp_info.project_type .. ")"
    end

    if has_duplicate_types then
      local depth_parts = {}
      if sp_info.depth then
        table.insert(depth_parts, "d:" .. sp_info.depth)
      end
      if sp_info.relative_depth then
        table.insert(depth_parts, "r:" .. sp_info.relative_depth)
      end
      if #depth_parts > 0 then
        label = label .. " [" .. table.concat(depth_parts, ",") .. "]"
      end
    end

    state_labels[state_key] = label
  end

  local state_aliases = {
    prevbuffer = "pbuf",
    current = "cur",
  }

  for i, sp_info in ipairs(sub_project_results) do
    state_aliases["subproject" .. i] = "s:" .. sp_info.project_type
  end

  local excluded_label_text = {
    gitroot = true,
    current_d1 = true,
  }

  vim.notify(string.format("CWD: %s\n%s", state_labels[vim.g.picker_cwd_cycle_state], new_cwd), vim.log.levels.INFO)

  local scope_label = state_labels[vim.g.picker_cwd_cycle_state]

  local current_state = vim.g.picker_cwd_cycle_state
  local dir_key = (current_state == "current_d1") and "current_d1" or new_cwd

  if seen_dirs[dir_key] and #seen_dirs[dir_key] > 1 then
    local dup_states = {}
    for _, state in ipairs(seen_dirs[dir_key]) do
      if state ~= current_state and not excluded_label_text[state] then
        local display_name = state_aliases[state] or state
        table.insert(dup_states, display_name)
      end
    end

    if #dup_states > 0 then
      scope_label = scope_label .. " (=" .. table.concat(dup_states, ",") .. ")"
    end
  end

  local picker_params = {
    cwd = new_cwd,
    pattern = filter_pattern or "",
    search = filter_search or "",
    live = picker.opts.supports_live and picker.opts.live,
    show_empty = true,
    title = string.format("%s [%s]", source or "Picker", scope_label),
  }

  local hidden_state = picker.opts.hidden
  local ignored_state = picker.opts.ignored

  if hidden_state == nil and picker.init_opts then
    hidden_state = picker.init_opts.hidden
  end
  if ignored_state == nil and picker.init_opts then
    ignored_state = picker.init_opts.ignored
  end

  if hidden_state ~= nil then
    picker_params.hidden = hidden_state
  end
  if ignored_state ~= nil then
    picker_params.ignored = ignored_state
  end

  if new_cwd == git_root and git_root and git_root ~= "" then
    picker_params.git_cwd = true
  end

  if
    vim.g.picker_cwd_cycle_state == "current_d1"
    and type(source) == "string"
    and (source:match "grep" or source:match "files")
    and not source:match "^git"
  then
    picker_params.args = { "--max-depth", "1" }
  end

  picker.opts.cwd = picker_params.cwd
  picker.opts.args = picker_params.args
  picker.opts.pattern = picker_params.pattern
  picker.opts.search = picker_params.search
  picker.opts.live = picker_params.live
  picker.opts.show_empty = true
  picker.title = picker_params.title
  picker.opts.git_cwd = picker_params.git_cwd
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

--- Toggle between files and buffers picker
--- Preserves search state and toggle states (hidden, ignored)
--- @param picker table Snacks picker instance
--- @param item table Current item (unused)
function M.toggle_files_buffers(picker, item)
  local preview_source = picker.init_opts and picker.init_opts.source
  if not preview_source then
    vim.notify("Error: picker.init_opts is nil", vim.log.levels.ERROR)
    return
  end

  local current_search = picker.input.filter and picker.input.filter.pattern
  ---@type snacks.picker.Config
  local picker_params = {
    pattern = current_search or "",
  }

  -- Helper to get toggle state (clean, no override logic)
  local function get_toggle_state(name)
    -- First check picker.opts (runtime state)
    if picker.opts[name] ~= nil then
      return picker.opts[name]
    end
    -- Fall back to init_opts (initial state)
    if picker.init_opts and picker.init_opts[name] ~= nil then
      return picker.init_opts[name]
    end
    return nil
  end

  if preview_source == "files" then
    picker_params.hidden = false
    Snacks.picker.buffers(picker_params)
    vim.defer_fn(function()
      if vim.api.nvim_get_mode().mode == "n" then
        vim.cmd "startinsert"
      end
    end, 50)
  else
    -- Switching from buffers to files
    -- For files: persist both hidden and ignored states
    local hidden_state = get_toggle_state "hidden"
    local ignored_state = get_toggle_state "ignored"

    if hidden_state ~= nil then
      picker_params.hidden = hidden_state
    end
    if ignored_state ~= nil then
      picker_params.ignored = ignored_state
    end

    Snacks.picker.files(picker_params)
  end
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
