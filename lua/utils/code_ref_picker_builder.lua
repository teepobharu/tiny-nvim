-- Shared picker builder for code reference / path format pickers.
-- Used by both the keymap code_ref_picker (<localleader>crp) and
-- the sub-picker copy_path_select (<M-y> inside files/grep picker).
-- Single source of truth for picker format, keybindings, toggle logic.

local M = {}

local clipboardUtil = require "utils.myinput"

--- Get file/directory statistics for preview pane
---@param path string
---@return table|nil
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

--- Copy path to clipboard and notify (stays in picker)
---@param path string
---@return boolean success
local function copy_to_clipboard(path)
  if not path or path == "" then
    vim.notify("Path is empty or invalid", vim.log.levels.WARN)
    return false
  end

  vim.fn.setreg("+", path)
  vim.fn.setreg('"', path)

  Snacks.debug(string.format("Copied %s", path))
  return true
end

--- Insert text at cursor, closing both pickers
---@param text string
---@param parent_picker? snacks.Picker
---@param format_picker snacks.Picker
local function insert_at_cursor(text, parent_picker, format_picker)
  format_picker:close()
  if parent_picker then
    parent_picker:close()
  end
  vim.api.nvim_put({ text }, "c", true, true)
  vim.notify("Inserted: " .. text, vim.log.levels.INFO)
end

--- Insert markdown link at cursor, closing both pickers
---@param path string
---@param parent_picker? snacks.Picker
---@param format_picker snacks.Picker
local function insert_markdown_link(path, parent_picker, format_picker)
  format_picker:close()
  if parent_picker then
    parent_picker:close()
  end

  local name = vim.fn.fnamemodify(path, ":t")
  if name == "" or name == "." then
    name = vim.fn.fnamemodify(path, ":h:t")
  end

  local markdown_link = string.format("[%s](%s)", name, path)
  vim.api.nvim_put({ markdown_link }, "c", true, true)
  vim.notify("Inserted markdown link: " .. markdown_link, vim.log.levels.INFO)
end

--- Build and open a shared code-ref / path-format picker.
---
--- Both the keymap picker and the sub-picker use this builder, which provides:
--- - Unified format function (label: path)
--- - Shared keybindings: <C-y> copy, <C-p> paste, <C-n> markdown, <A-c>/<A-l> toggle
--- - Configurable confirm behavior (copy vs paste)
--- - Optional preview pane with file stats
--- - Optional parent picker reference for sub-picker close chaining
--- - Optional footer string shown in the input window
---
---@param opts {
---  items: table[],
---  source: string,
---  title: string,
---  parent_picker?: snacks.Picker,
---  confirm_mode?: "copy"|"paste",
---  show_preview?: boolean,
---  use_visual?: boolean,
---  on_refresh: fun(),
---  footer?: string,
---}
function M.build(opts)
  local parent_picker = opts.parent_picker
  local confirm_mode = opts.confirm_mode or "copy"
  local show_preview = opts.show_preview ~= false -- default true

  -- Shared format function: { label: path }
  -- item.path holds the display value; item.text = label + path for Snacks fuzzy filtering
  local format_fn = function(item)
    return {
      { item.label, "SnacksPickerTitle" },
      { ": ", "Comment" },
      { item.path, "Normal" },
    }
  end

  -- Preview function (file stats)
  local preview_fn = nil
  if show_preview then
    preview_fn = function(ctx)
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
      table.insert(lines, "Press <CR> to " .. (confirm_mode == "copy" and "copy to clipboard" or "paste into buffer"))
      table.insert(lines, "Press <C-y> to copy to clipboard")
      table.insert(lines, "Press <C-p> to paste into buffer")
      table.insert(lines, "Press <C-n> to paste as markdown link")

      if ctx.buf and vim.api.nvim_buf_is_valid(ctx.buf) then
        vim.api.nvim_buf_set_option(ctx.buf, "modifiable", true)
        vim.api.nvim_buf_set_lines(ctx.buf, 0, -1, false, lines)
        vim.api.nvim_buf_set_option(ctx.buf, "modifiable", false)
        vim.bo[ctx.buf].filetype = "text"
        return true
      end

      return false
    end
  end

  -- Confirm handler based on mode
  local confirm_fn
  if confirm_mode == "copy" then
    confirm_fn = function(picker, item)
      if not item then
        vim.notify("No item selected", vim.log.levels.WARN)
        return
      end
      local ref = item.path
      clipboardUtil.copy_and_notify(ref, "plus", "copied: " .. ref)
      picker:close()
    end
  else
    confirm_fn = function(picker, item)
      if not item then
        vim.notify("No item selected", vim.log.levels.WARN)
        return
      end
      insert_at_cursor(item.path, parent_picker, picker)
    end
  end

  -- Layout: hide preview for standalone picker (no parent), show for sub-picker
  local layout = nil
  if not show_preview then
    layout = { preview = false }
  end

  -- Helper: close current picker and refresh via opts.on_refresh
  local function refresh_picker()
    local pickers = Snacks.picker.get { source = opts.source }
    local cur_picker = pickers and pickers[1]
    if cur_picker then
      cur_picker:close()
    end
    vim.schedule(function()
      if opts.on_refresh then
        opts.on_refresh()
      end
    end)
  end

  Snacks.picker.pick {
    source = opts.source,
    title = opts.title,
    layout = layout,
    items = opts.items,
    format = format_fn,
    preview = preview_fn,
    actions = {
      quit_all = function(format_picker)
        format_picker:close()
        if parent_picker then
          parent_picker:close()
        end
      end,
      copy_to_clipboard = function(_format_picker, selected_item)
        if selected_item then
          copy_to_clipboard(selected_item.path)
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
        footer = opts.footer,
        keys = {
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
              -- In visual/range mode: toggle char range; otherwise: toggle hide col
              local use_visual = opts.use_visual or false
              if use_visual then
                vim.g.code_ref_show_char_range = not (vim.g.code_ref_show_char_range or false)
                vim.notify(
                  "Char range: " .. (vim.g.code_ref_show_char_range and "enabled" or "disabled"),
                  vim.log.levels.INFO
                )
              else
                vim.g.code_ref_hide_col = not (vim.g.code_ref_hide_col or false)
                vim.notify("Column: " .. (vim.g.code_ref_hide_col and "hidden" or "shown"), vim.log.levels.INFO)
              end
              refresh_picker()
            end,
            mode = { "n", "i" },
            desc = "Toggle char/col in references",
          },
          ["<A-l>"] = {
            function()
              -- Toggle line visibility (path-only when hidden)
              vim.g.code_ref_hide_line = not (vim.g.code_ref_hide_line or false)
              vim.notify("Line: " .. (vim.g.code_ref_hide_line and "hidden" or "shown"), vim.log.levels.INFO)
              refresh_picker()
            end,
            mode = { "n", "i" },
            desc = "Toggle line visibility",
          },
        },
      },
    },
    confirm = confirm_fn,
  }
end

return M
