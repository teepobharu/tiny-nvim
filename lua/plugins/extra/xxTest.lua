-- xxTest.lua — Mute plugins/test.lua
-- Add "xxTest" to vim.g.enable_extra_plugins to disable test runner plugins.
-- Remove to re-enable. Shared plugins (which-key groups) are NOT affected.
--
-- Source: plugins/test.lua
return {
  { "vim-test/vim-test", enabled = false },
  { "nvim-neotest/neotest", enabled = false },
}
