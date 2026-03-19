-- xxMini.lua — Mute ALL mini.nvim plugins (UI + coding)
-- Combines xxMiniUi and xxMiniCode into one switch.
-- Use this instead of enabling both individually.
--
-- If you only want to mute UI mini plugins, use "xxMiniUi" instead.
-- If you only want to mute coding mini plugins, use "xxMiniCode" instead.
local specs = {}
vim.list_extend(specs, require "plugins.extra.xxMiniUi")
vim.list_extend(specs, require "plugins.extra.xxMiniCode")
return specs
