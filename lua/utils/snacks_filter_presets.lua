--- snacks_filter_presets.lua — Insert exclude patterns & path parts into picker input
---
--- Features:
--- 1. `<M-/>` — toggle project preset excludes (`!test !snap !mock !md !blob`)
--- 2. `<C-r>` prefix in insert mode — insert current buffer's path component
---    - `<C-r>f` — filename base (no extension, e.g. `index`)
---    - `<C-r>d` — directory relative to git root (e.g. `src/components`)
---    - `<C-r>e` — file extension  (e.g. `tsx`)
---    - `<C-r>p` — full path relative to git root
---
--- These mirror snacks' built-in `<C-r><c-w>`, `<C-r><c-f>`, `<C-r>%`, etc.
--- using the same `vim.api.nvim_put("c")` pattern so TextChangedI fires naturally.
---
--- The `!word` tokens are processed by the snacks matcher's native `inverse` logic.

local M = {}

-- =====================================================================
-- Project presets: map of project name → { tokens, description }
-- =====================================================================
M.presets = {
  ["trips-web"] = { "!test !.spec !snap !mock !.md !.png !blob", "trips-web: exclude tests, snapshots, mock, docs, blobs" },
  ["agoda"]     = { "!test !.spec !snap !mock !.md !.png",       "agoda: exclude tests, snapshots, mock, docs" },
  ["default"]   = { "!test !snap !.md",                 "default: exclude tests, snapshots" },
}

-- =====================================================================
-- Detect current project name from cwd
-- =====================================================================
function M.get_project_name()
  local cwd = vim.fn.getcwd()
  for name, _ in pairs(M.presets) do
    if name ~= "default" and cwd:find(name, 1, true) then
      return name
    end
  end
  return nil
end

-- =====================================================================
-- Get the preset tokens for the current project
-- =====================================================================
function M.get_preset_tokens()
  local project = M.get_project_name()
  if project and M.presets[project] then
    return M.presets[project][1]
  end
  return M.presets["default"][1]
end

-- =====================================================================
-- Get preset description for notifications
-- =====================================================================
function M.get_preset_desc()
  local project = M.get_project_name()
  if project and M.presets[project] then
    return M.presets[project][2]
  end
  return M.presets["default"][2]
end

-- =====================================================================
-- Remove all `!word` tokens from input
-- =====================================================================
function M.strip_exclude_tokens(input)
  return vim.trim(input:gsub("%s*!%S+", ""))
end

-- =====================================================================
-- Insert text into picker input using the same pattern as snacks' insert actions
-- (vim.api.nvim_buf_call to read source · vim.api.nvim_put to insert)
-- =====================================================================
local function insert_into_input(picker, value)
  vim.api.nvim_win_call(picker.input.win.win, function()
    vim.api.nvim_put({ value }, "c", true, true)
  end)
end

-- =====================================================================
-- Get current buffer's file path (same scope as snacks' <C-r><c-f>)
-- =====================================================================
local function get_buffer_path(picker)
  return vim.api.nvim_buf_get_name(picker.input.filter.current_buf)
end

-- =====================================================================
-- Resolve path relative to git root
-- =====================================================================
local function relative_to_git_root(filepath)
  local git_root = Snacks.git.get_root(filepath)
  if not git_root then return filepath end
  if filepath:sub(1, #git_root) == git_root then
    return filepath:sub(#git_root + 2) -- strip trailing /
  end
  return filepath
end

-- =====================================================================
-- Actions: `<C-r>` + key — same pattern as snacks' built-in insert actions
-- =====================================================================

--- `<C-r>f` — filename base without extension (e.g. `index`)
function M.insert_item_filename(picker)
  local filepath = get_buffer_path(picker)
  if not filepath or filepath == "" then return end
  -- Expand from the source buffer (same as snacks' insert action)
  local filename = ""
  vim.api.nvim_buf_call(picker.input.filter.current_buf, function()
    filename = vim.fn.expand("%:t:r") -- :t = tail (filename), :r = remove extension
  end)
  insert_into_input(picker, filename)
end

--- `<C-r>d` — directory relative to git root (e.g. `src/components`)
function M.insert_item_dirname(picker)
  local filepath = get_buffer_path(picker)
  if not filepath or filepath == "" then return end
  local dir = ""
  vim.api.nvim_buf_call(picker.input.filter.current_buf, function()
    local buf_dir = vim.fn.expand("%:p:h") -- absolute dir
    dir = relative_to_git_root(buf_dir)
  end)
  if dir == "" then return end
  insert_into_input(picker, dir)
end

--- `<C-r>e` — file extension (e.g. `tsx`)
function M.insert_item_extension(picker)
  local filepath = get_buffer_path(picker)
  if not filepath or filepath == "" then return end
  local ext = ""
  vim.api.nvim_buf_call(picker.input.filter.current_buf, function()
    ext = vim.fn.expand("%:e")
  end)
  if ext == "" then return end
  insert_into_input(picker, ext)
end

--- `<C-r>p` — full path relative to git root
function M.insert_item_relpath(picker)
  local filepath = get_buffer_path(picker)
  if not filepath or filepath == "" then return end
  local relpath = ""
  vim.api.nvim_buf_call(picker.input.filter.current_buf, function()
    relpath = relative_to_git_root(vim.fn.expand("%:p"))
  end)
  insert_into_input(picker, relpath)
end

-- =====================================================================
-- Action: toggle preset excludes in picker input
-- Cycle: insert preset → strip preset → insert preset ...
-- =====================================================================
function M.toggle_filter_preset(picker, _item)
  local buf = picker.input.win.buf
  local current_text = vim.api.nvim_buf_get_lines(buf, 0, -1, false)[1] or ""

  local preset = M.get_preset_tokens()
  local stripped = M.strip_exclude_tokens(current_text)
  local has_excludes = current_text ~= stripped

  local new_text
  if has_excludes then
    new_text = stripped
    vim.notify("Filter excludes: REMOVED", vim.log.levels.INFO)
  else
    new_text = stripped ~= "" and (stripped .. " " .. preset) or preset
    vim.notify(
      ("Filter excludes: %s"):format(M.get_preset_desc()),
      vim.log.levels.INFO
    )
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { new_text })
  vim.bo[buf].modified = false
  vim.api.nvim_win_set_cursor(picker.input.win.win, { 1, #new_text + 1 })

  -- Let TextChangedI autocommand handle filter updates naturally
  vim.schedule(function()
    picker:find({ refresh = false })
  end)
end

return M
