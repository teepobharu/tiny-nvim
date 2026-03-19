-- xxRunner.lua — Mute plugins/runner.lua
-- Add "xxRunner" to vim.g.enable_extra_plugins to disable task runner plugins.
-- Remove to re-enable. Shared plugins (which-key groups) are NOT affected.
--
-- Source: plugins/runner.lua
return {
  { "stevearc/overseer.nvim", enabled = false },
  { "jellydn/quick-code-runner.nvim", enabled = false },
  { "jellydn/hurl.nvim", enabled = false },
}
