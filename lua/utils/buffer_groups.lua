-- buffer_groups.lua — Classify and sort buffers by group for the buffer picker
-- Groups (ranked 1-5):
--   1: AI tool buffers (codecompanion, claude/cag, sidekick, avante, copilot, etc.)
--   2: Terminal buffers (buftype == "terminal")
--   3: LazyGit terminals
--   4: File buffers (buftype == "")
--   5: Utility/internal (quickfix, help, nofile, snacks internal, etc.)

local M = {}

--- Patterns that identify AI tool buffers (checked against buffer name, case-insensitive)
M.ai_patterns = {
  "claude",
  "claudecode",
  "claude-code",
  "claude_code",
  "cag",
  "cc-agd",
  "agent",
  "pi-agent",
  "pi_session",
  "sidekick",
  "sidekick_terminal",
  "avante",
  "codecompanion",
  "copilot",
  "crush",
  "codex",
  "gemini",
}

M.terminal_patterns = {
  "term://",
  "terminal",
  "toggleterm",
  "snacks_terminal",
  "sidekick_terminal",
  "tiny_term",
}

M.lazygit_patterns = {
  "lazygit",
}

M.ai_chat_filetypes = {
  "codecompanion",
  "avante",
  "copilot-chat",
  "copilotchat",
}

M.group_labels = {
  ai = "AI",
  term = "T",
  lazygit = "LZ",
  file = "F",
  util = "U",
}

local function lastused(item)
  return (item.info and item.info.lastused or 0)
end

local function matches_any(value, patterns)
  value = (value or ""):lower()
  for _, pat in ipairs(patterns) do
    if value:find(pat, 1, true) then
      return true
    end
  end
  return false
end

local function has_value(values, value)
  value = (value or ""):lower()
  for _, candidate in ipairs(values) do
    if value == candidate then
      return true
    end
  end
  return false
end

local function classify_ai_priority(name, filetype)
  if has_value(M.ai_chat_filetypes, filetype) or matches_any(name, { "codecompanion" }) then
    return 1
  end
  if matches_any(name, { "claude", "claudecode", "claude-code", "claude_code", "cag", "cc-agd" })
    or matches_any(filetype, { "claude", "claudecode", "claude-code", "claude_code" })
  then
    return 2
  end
  if matches_any(name, { "sidekick", "pi-agent", "pi_session", " pi " }) or matches_any(filetype, { "sidekick" }) then
    return 3
  end
  return 9
end

--- Classify a buffer into a group rank.
--- @param buf number Buffer number
--- @return number group_rank (1=ai, 2=terminal, 3=lazygit, 4=file, 5=utility)
--- @return string group_name
--- @return number group_subrank
function M.classify(buf)
  local buftype = vim.bo[buf].buftype
  local name = vim.api.nvim_buf_get_name(buf) or ""
  local filetype = vim.bo[buf].filetype or ""

  -- Normal files must stay files even when their path contains ".claude" or similar.
  if buftype == "" and not has_value(M.ai_chat_filetypes, filetype) then
    return 4, "file", 1
  end

  -- AI tools outrank generic terminals, so sidekick/claude/cag terminals group as AI.
  if matches_any(name, M.ai_patterns) or matches_any(filetype, M.ai_patterns) or has_value(M.ai_chat_filetypes, filetype) then
    return 1, "ai", classify_ai_priority(name, filetype)
  end

  if matches_any(name, M.lazygit_patterns) or matches_any(filetype, M.lazygit_patterns) then
    return 3, "lazygit", 1
  end

  if buftype == "terminal" then
    return 2, "term", 1
  end

  -- Group 5: Everything else (quickfix, help, nofile, etc.)
  return 5, "util", 1
end

--- True for buffers worth surfacing in the focused hidden/agent cycle.
--- This intentionally targets terminal and AI/agent buffers instead of every
--- file buffer, which keeps <A-r> useful for picking agent terminals.
--- @param buf number
--- @param info table|nil
--- @param mode? integer 1=terminal/agent buffers, 2=agent/chat buffers only
--- @return boolean
function M.is_focused_hidden(buf, info, mode)
  info = info or vim.fn.getbufinfo(buf)[1] or {}
  mode = mode or 1

  local buftype = vim.bo[buf].buftype
  local filetype = vim.bo[buf].filetype or ""
  local name = vim.api.nvim_buf_get_name(buf) or ""
  local is_chat_filetype = has_value(M.ai_chat_filetypes, filetype)
  local is_ai = matches_any(name, M.ai_patterns)
    or matches_any(filetype, M.ai_patterns)
    or is_chat_filetype

  if buftype == "terminal" then
    return mode == 1 or is_ai
  end

  if buftype == "" then
    return is_chat_filetype
  end

  if mode == 2 then
    return is_ai
  end

  return is_ai or matches_any(name, M.terminal_patterns) or matches_any(filetype, M.terminal_patterns)
end

--- Sort picker items by lastused (most recent first)
--- @param items snacks.picker.finder.Item[]
--- @return snacks.picker.finder.Item[]
function M.sort_lastused(items)
  table.sort(items, function(a, b)
    return lastused(a) > lastused(b)
  end)
  return items
end

--- Sort picker items by group rank, then by lastused within each group
--- @param items snacks.picker.finder.Item[]
--- @return snacks.picker.finder.Item[]
function M.sort_items(items)
  -- Pre-compute group rank for each item
  for _, item in ipairs(items) do
    if item.buf and not item._group_rank then
      item._group_rank, item._group_name, item._group_subrank = M.classify(item.buf)
    end
  end

  table.sort(items, function(a, b)
    local a_rank = a._group_rank or math.huge
    local b_rank = b._group_rank or math.huge
    if a_rank ~= b_rank then
      return a_rank < b_rank
    end
    local a_subrank = a._group_subrank or math.huge
    local b_subrank = b._group_subrank or math.huge
    if a_subrank ~= b_subrank then
      return a_subrank < b_subrank
    end
    -- Within same group, sort by lastused (most recent first)
    return lastused(a) > lastused(b)
  end)

  return items
end

--- Finder wrapper for Snacks buffers source.
--- Keeps the built-in item shape, but optionally sorts by grouped buffer type
--- before handing results to Snacks filtering/matching.
--- @param opts snacks.picker.buffers.Config|{group_by_kind?: boolean}
--- @param ctx snacks.picker.finder.ctx
--- @return snacks.picker.finder.Item[]
function M.finder(opts, ctx)
  opts = vim.tbl_extend("force", {
    hidden = false,
    unloaded = true,
    current = true,
    nofile = false,
    sort_lastused = true,
    focus_hidden = false,
    focus_hidden_mode = 0,
  }, opts)

  local items = {} ---@type snacks.picker.finder.Item[]
  local current_buf = vim.api.nvim_get_current_buf()
  local alternate_buf = vim.fn.bufnr "#"

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local info = vim.fn.getbufinfo(buf)[1]
    local keep = (opts.hidden or vim.bo[buf].buflisted)
      and (opts.unloaded or vim.api.nvim_buf_is_loaded(buf))
      and (opts.current or buf ~= current_buf)
      and (opts.nofile or vim.bo[buf].buftype ~= "nofile")
      and (not opts.modified or vim.bo[buf].modified)

    if opts.focus_hidden or (opts.focus_hidden_mode or 0) > 0 then
      keep = M.is_focused_hidden(buf, info, opts.focus_hidden_mode)
        and (opts.unloaded or vim.api.nvim_buf_is_loaded(buf))
        and (opts.current or buf ~= current_buf)
        and (opts.nofile or vim.bo[buf].buftype ~= "nofile")
        and (not opts.modified or vim.bo[buf].modified)
    end

    if keep then
      local name = vim.api.nvim_buf_get_name(buf)
      if name == "" then
        name = "[Scratch]"
      end
      local mark = vim.api.nvim_buf_get_mark(buf, '"')
      local flags = {
        buf == current_buf and "%" or (buf == alternate_buf and "#" or ""),
        info.hidden == 1 and "h" or (#(info.windows or {}) > 0) and "a" or "",
        vim.bo[buf].readonly and "=" or "",
        info.changed == 1 and "+" or "",
      }

      table.insert(items, {
        flags = table.concat(flags),
        buf = buf,
        name = vim.api.nvim_buf_get_name(buf),
        buftype = vim.bo[buf].buftype,
        filetype = vim.bo[buf].filetype,
        file = name,
        info = info,
        pos = mark[1] ~= 0 and mark or { info.lnum, 0 },
      })
      local item = items[#items]
      item._group_rank, item._group_name, item._group_subrank = M.classify(buf)
      item.text = Snacks.picker.util.text(item, { "buf", "name", "filetype", "buftype" })
    end
  end

  if opts.group_by_kind or (opts.focus_hidden_mode or 0) > 0 or opts.focus_hidden then
    M.sort_items(items)
  elseif opts.sort_lastused then
    M.sort_lastused(items)
  end

  return ctx.filter:filter(items)
end

--- Buffer formatter with visible group tag.
--- Keeps Snacks default buffer layout, but appends a short group badge.
--- @param item snacks.picker.finder.Item
--- @param picker snacks.Picker
--- @return snacks.picker.Highlight[]
function M.format(item, picker)
  local ret = require("snacks.picker.format").buffer(item, picker)
  if not (picker and picker.opts) then
    return ret
  end

  local group = item._group_name
  if group and group ~= "" then
    local label = M.group_labels[group] or group
    local prefix = {
      { "[", "SnacksPickerDelim" },
      { label, "SnacksPickerComment" },
      { "]", "SnacksPickerDelim" },
      { " " },
    }
    vim.list_extend(prefix, ret)
    return prefix
  end
  return ret
end

return M
