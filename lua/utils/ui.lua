local M = {}

-- foldtext for Neovim < 0.10.0
function M.foldtext()
  return vim.api.nvim_buf_get_lines(0, vim.v.lnum - 1, vim.v.lnum, false)[1]
end

-- optimized treesitter foldexpr for Neovim >= 0.10.0
function M.foldexpr()
  local buf = vim.api.nvim_get_current_buf()
  if vim.b[buf].ts_folds == nil then
    -- as long as we don't have a filetype, don't bother
    -- checking if treesitter is available (it won't)
    if vim.bo[buf].filetype == "" then
      return "0"
    end
    vim.b[buf].ts_folds = pcall(vim.treesitter.get_parser, buf)
  end
  return vim.b[buf].ts_folds and vim.treesitter.foldexpr() or "0"
end

----- MY ADDED ------------

--- Run a noice command after ensuring any existing split view is in the current tab.
--- Noice caches view objects globally (View._views). A split window is bound to
--- the tab where it was first created, so calling cmd() from a different tab
--- silently does nothing. This helper destroys the stale cached view so noice
--- recreates it in the current tab.
---@param cmd string noice command name, e.g. "all", "history"
function M.noice_cmd_tab_aware(cmd)
  local ok, View = pcall(require, "noice.view")
  if ok and View._views then
    local cur_tab = vim.api.nvim_get_current_tabpage()
    for i = #View._views, 1, -1 do
      local v = View._views[i]
      local nui = v.view and v.view._nui
      if nui and nui.winid then
        if not vim.api.nvim_win_is_valid(nui.winid) then
          -- Stale entry with an invalid window — clean it up too.
          v.view:destroy()
          table.remove(View._views, i)
        elseif vim.api.nvim_win_get_tabpage(nui.winid) ~= cur_tab then
          -- Split lives in a different tab — destroy the cached view so it
          -- gets recreated fresh in the current tab on the next cmd() call.
          v.view:destroy()
          table.remove(View._views, i)
        end
      end
    end
  end
  require("noice").cmd(cmd)
end

---@return {fg?:string}?
function M.fg(name)
  local color = M.color(name)
  return color and { fg = color } or nil
end

---@param name string
---@param bg? boolean
---@return string?
function M.color(name, bg)
  ---@type {foreground?:number}?
  ---@diagnostic disable-next-line: deprecated
  local hl = vim.api.nvim_get_hl and vim.api.nvim_get_hl(0, { name = name, link = false })
    or vim.api.nvim_get_hl_by_name(name, true)
  ---@diagnostic disable-next-line: undefined-field
  ---@type string?
  local color = nil
  if hl then
    if bg then
      color = hl.bg or hl.background
    else
      color = hl.fg or hl.foreground
    end
  end
  return color and string.format("#%06x", color) or nil
end

return M
