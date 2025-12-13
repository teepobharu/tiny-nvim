local M = {}

-- Truncate path to show beginning and end when too long
local function truncate_path(path, max_len)
  if #path <= max_len then
    return path
  end

  -- Extract filename from path
  local filename = path:match("([^/]+)$") or path
  local dir = path:sub(1, #path - #filename)

  -- If directory is too long, truncate it
  local available = max_len - #filename - 3 -- 3 for "..."
  if #dir > available and available > 10 then
    dir = dir:sub(1, available) .. "..."
  elseif #dir > available then
    -- If directory is still too long, show end of path
    local start_len = math.floor(max_len * 0.3)
    local end_len = max_len - start_len - 3
    return path:sub(1, start_len) .. "..." .. path:sub(-end_len)
  end

  return dir .. filename
end

function M.get_terminal_buffers()
  local bufs = vim.api.nvim_list_bufs()
  local terminals = {}
  for _, buf in ipairs(bufs) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == "terminal" then
      local name = vim.api.nvim_buf_get_name(buf)
      local ft = vim.bo[buf].filetype or ""

      local term_type = "others"
      if ft:match("toggleterm") then
        term_type = "toggleterm"
      elseif ft:match("snacks") then
        term_type = "snacks"
      elseif name:match("lazygit") then
        term_type = "lazygit"
      elseif ft:match("sidekick") then
        term_type = "sidekick"
      elseif name:match("term") then
        term_type = "terminal"
      else
        term_type = "unknown"
      end
      local is_tmux = name:match("bin/tmux")
      -- id from 1 ++
      table.insert(terminals, {
        idx = #terminals + 1,
        score = #terminals + 1,
        buf = buf,
        name = name,
        term_type = term_type,
        filetype = ft,
        is_tmux = is_tmux and true or false,
      })
    end
  end
  -- Sort by term_type priority
  local priority = {toggleterm=1, snacks=2, lazygit=3, sidekick=4, terminal=5, others=6, unknown=7}
  table.sort(terminals, function(a, b)
    local a_priority = priority[a.term_type] or 999
    local b_priority = priority[b.term_type] or 999
    return a_priority < b_priority
  end)

  return terminals
end

-- Format terminal item for display in picker
function M.format_terminal(item, opts)
  local Snacks = require("snacks")
  local width = opts.width or 80

  -- Type badge with color
  local type_colors = {
    toggleterm = "DiagnosticInfo",
    snacks = "DiagnosticHint",
    lazygit = "DiagnosticWarn",
    sidekick = "Special",
    terminal = "Comment",
    others = "Comment",
    unknown = "Comment",
  }

  local type_badge = string.format("[%s]", item.term_type)
  local type_width = #type_badge + 1
  local type_hl = type_colors[item.term_type] or "Comment"

  -- Buffer number
  local buf_str = string.format("#%d", item.buf)
  local buf_width = #buf_str + 1

  -- Available width for path
  local available_width = width - type_width - buf_width - 2 - 10 -- my extra padding
  local display_name = truncate_path(item.name, available_width)

  return {
    { type_badge, type_hl },
    { " " },
    { buf_str, "Number" },
    { " " },
    { display_name, "Normal" },
  }
end

return M
