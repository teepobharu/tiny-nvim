-- xxMiniUi.lua — Mute mini.nvim UI/picker/starter plugins
-- Add "xxMiniUi" to vim.g.enable_extra_plugins to disable this group.
-- Remove "xxMiniUi" to re-enable the mini UI stack.
--
-- Sources: plugins/picker.lua, plugins/starter.lua, plugins/ui.lua
-- Note: myUi.lua also disables these redundantly for its own override context.
return {
  -- plugins/picker.lua
  { "echasnovski/mini.pick", enabled = false },
  { "echasnovski/mini.extra", enabled = false },
  -- plugins/starter.lua
  { "echasnovski/mini.starter", enabled = false },
  -- plugins/ui.lua
  { "echasnovski/mini.icons", enabled = false },
  { "echasnovski/mini.statusline", enabled = false },
  { "echasnovski/mini.tabline", enabled = false },
  { "echasnovski/mini.bufremove", enabled = false },
  { "echasnovski/mini.files", enabled = false },
  { "echasnovski/mini.diff", enabled = false },
}
