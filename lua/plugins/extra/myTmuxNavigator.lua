-- myTmuxNavigator.lua — full override of plugins/tmux-navigator.lua
--
-- Kept out of lua/plugins/ so the base file stays untouched and rebases
-- cleanly against upstream (jellydn/tiny-nvim). This file is loaded via
-- vim.g.enable_extra_plugins (see lua/config/mydefault-nvim-config.lua)
-- and lazy.nvim spec-merges it over the base plugins/tmux-navigator.lua
-- spec by returning the same plugin name "christoomey/vim-tmux-navigator".
--
-- HERDR + TMUX AWARE PANE NAVIGATION
-- ====================================
-- C-h/j/k/l moves between nvim splits first. At a split edge (no more
-- splits that direction), it crosses into the surrounding multiplexer:
--   - Inside herdr:  calls `herdr pane focus --direction <dir>` directly.
--     (The companion herdr plugin "vim-herdr-navigation" handles the
--      reverse case: C-h/j/k/l pressed in a NON-vim herdr pane, e.g. a
--      shell or lazygit, forwards to `herdr pane focus` too. See
--      ~/.config/herdr/plugins/personal/vim-herdr-navigation and the
--      [[keys.command]] entries in ~/.config/herdr/config.toml.)
--   - Inside tmux (no herdr): falls back to vim-tmux-navigator's
--     TmuxNavigate* commands.
--   - Neither: does nothing extra, plain nvim wincmd already ran.
--
-- IMPORTANT: lazy = false is required.
-- This spec defines its own mappings in config() instead of using
-- vim-tmux-navigator's `keys` table, and its `cmd` entries are never
-- invoked directly by the user. With lazy.nvim's default lazy-loading, a
-- plugin with no active load trigger simply never loads -- so config()
-- never runs and C-h/j/k/l end up doing nothing. lazy = false forces it
-- to load on startup like an eager plugin, guaranteeing the mappings
-- exist immediately.
return {
  "christoomey/vim-tmux-navigator",
  enabled = not vim.g.vscode,
  cmd = {
    "TmuxNavigateLeft",
    "TmuxNavigateDown",
    "TmuxNavigateUp",
    "TmuxNavigateRight",
    "TmuxNavigatePrevious",
  },
  -- See "lazy = false" note above -- do not remove or re-add `keys = {}`
  -- without also fixing the load trigger, or the mappings silently break.
  lazy = false,
  -- Note: lazy.nvim MERGES (concatenates) list-valued fields like `keys`
  -- across specs for the same plugin name -- it does not replace them.
  -- Setting `keys = {}` here does not erase plugins/tmux-navigator.lua's
  -- `keys` table. What actually wins is load order: this file is
  -- registered after the base plugin in
  -- lua/config/mydefault-nvim-config.lua's enable_extra_plugins list, so
  -- its config() runs last and vim.keymap.set() below overwrites the
  -- base spec's C-h/j/k/l mappings for the same mode+lhs.
  keys = {},
  config = function()
    local map = vim.keymap.set
    vim.g.tmux_navigator_no_mappings = 1

    local opts = { noremap = true, silent = true }

    -- Terminal mode nav (always tmux, no herdr side needed)
    opts.desc = "Navigate tmux up"
    map("t", "<C-k>", "<cmd>TmuxNavigateUp<cr>", opts)
    opts.desc = "Navigate tmux down"
    map("t", "<C-j>", "<cmd>TmuxNavigateDown<cr>", opts)
    opts.desc = "Navigate tmux left"
    map("t", "<C-h>", "<cmd>TmuxNavigateLeft<cr>", opts)
    opts.desc = "Navigate tmux right"
    map("t", "<C-l>", "<cmd>TmuxNavigateRight<cr>", opts)

    -- Normal mode: try nvim's own window movement first (wincmd h/j/k/l).
    -- If the window doesn't change, we're at the outermost split edge in
    -- that direction -- hand off to herdr or tmux to cross the pane boundary.
    local function nav(wincmd, dir)
      local prev = vim.api.nvim_get_current_win()
      vim.cmd("wincmd " .. wincmd)
      if vim.api.nvim_get_current_win() ~= prev then
        return -- moved within nvim, nothing else to do
      end
      -- At edge: cross into surrounding multiplexer
      if vim.env.HERDR_PANE_ID and vim.env.HERDR_PANE_ID ~= "" then
        -- Running inside herdr: ask herdr to focus the neighboring pane.
        local herdr = vim.env.HERDR_BIN_PATH or "herdr"
        vim.fn.system({ herdr, "pane", "focus", "--direction", dir, "--current" })
      elseif vim.env.TMUX and vim.env.TMUX ~= "" then
        -- Running inside tmux (no herdr): use vim-tmux-navigator as before.
        local cmd = ({ left = "TmuxNavigateLeft", down = "TmuxNavigateDown", up = "TmuxNavigateUp", right = "TmuxNavigateRight" })[dir]
        if cmd then pcall(vim.cmd, cmd) end
      end
      -- Neither herdr nor tmux: plain nvim at an edge, nothing more to do.
    end

    opts.desc = "Navigate left (vim/herdr/tmux)"
    map("n", "<C-h>", function() nav("h", "left") end, opts)
    opts.desc = "Navigate down (vim/herdr/tmux)"
    map("n", "<C-j>", function() nav("j", "down") end, opts)
    opts.desc = "Navigate up (vim/herdr/tmux)"
    map("n", "<C-k>", function() nav("k", "up") end, opts)
    opts.desc = "Navigate right (vim/herdr/tmux)"
    map("n", "<C-l>", function() nav("l", "right") end, opts)
    opts.desc = "Navigate previous (tmux)"
    map("n", "<C-\\>", "<cmd>TmuxNavigatePrevious<cr>", opts)
  end,
}
