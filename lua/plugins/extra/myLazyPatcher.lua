-- lazy-local-patcher.nvim — auto-apply git patches to Lazy-managed plugins
-- Used to patch mcphub.nvim for CodeCompanion v19 compatibility (PR #279)
-- Patches live in: ~/.config/nvim3_jelly_tinynvim/patches/<plugin-name>/
-- See: tasks/open/patch-mcphub-codecompanion-v19.md
-- Remove when PR #279 is merged upstream: tasks/open/monitor-mcphub-pr279-merge.md
--
-- How it works:
--   1. After first `:Lazy sync`, patches are applied to plugin git repos and persist
--   2. On subsequent `:Lazy sync/update`, patches are reverted before git ops, then re-applied after
--   3. Between syncs, the patched files remain in the plugin directory
--   4. First-time setup: run `:lua require("lazy-local-patcher").apply_all()` or `:Lazy sync`
return {
  {
    "polirritmico/lazy-local-patcher.nvim",
    -- cmd = "LazyLocalPatcher", -- not work / show
    config = true,
    -- Load early so the Lazy autocmds (LazySyncPre/LazySync) are registered
    -- before any manual :Lazy operations
    -- patch changelog: docs/memory/lazy-local-patching.md
    lazy = false,
    keys = {
      { "<leader>lz", ':lua require("lazy-local-patcher").apply_all()', desc = "Lazy apply patch" },
      { "<leader>lZ", ':lua require("lazy-local-patcher").restore_all()', desc = "Lazy restore patch" },
    },
  },
}
