--  =========================
-- MY SETTINGS -----------------
--  =========================
vim.g.maplocalleader = ","
vim.g.lazygit_config = true
vim.g.lazygit_passthrough_ctrl_hjkl = false
vim.g.ai_prefix_key = "<leader>A" -- see: lua/plugins/extra/codecompanion.lua
vim.opt.foldexpr = "v:lua.require'utils.ui'.foldexpr()"

-- debugging
-- vim.g.snacks_debug_external_filter = true
vim.g.subproject_scan_ignored = true -- only check for false but can change if needed / freeze
-- vim.g.userdebug = true
-- will use if not explcitly set to false
-- vim.g.lazydev_enabled = false
