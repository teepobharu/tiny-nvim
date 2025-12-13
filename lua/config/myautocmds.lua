-- MY AUTO COMMANDS -----
local M = {}

--#region: use case switch open selected link in previous buffer: 
--vim.api.nvim_create_autocmd("WinEnter", {
vim.api.nvim_create_autocmd("WinEnter", {
  callback = function()
    vim.g.prev_win = vim.g.current_win
    vim.g.current_win = vim.api.nvim_get_current_win()
  end,
})

--

return M
