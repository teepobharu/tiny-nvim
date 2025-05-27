-- Also add to tmux config
-- set -g @plugin 'christoomey/vim-tmux-navigator'
-- run '~/.tmux/plugins/tpm/tpm'
-- unbind -n C-\\
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
  keys = {
    { "<c-h>", "<cmd><C-U>TmuxNavigateLeft<cr>" },
    { "<c-j>", "<cmd><C-U>TmuxNavigateDown<cr>" },
    { "<c-k>", "<cmd><C-U>TmuxNavigateUp<cr>" },
    { "<c-l>", "<cmd><C-U>TmuxNavigateRight<cr>" },
    { "<c-\\>", "<cmd><C-U>TmuxNavigatePrevious<cr>" },
  },
  config = function()
    local map = vim.keymap.set
    vim.g.tmux_navigator_no_mappings = 1
    opts = { noremap = true, silent = true, desc = "Navigate tmux" }
    map("t", "<C-k>", "<cmd>TmuxNavigateUp<cr>", opts)
    map("t", "<C-j>", "<cmd>TmuxNavigateDown<cr>", opts)
    map("t", "<C-h>", "<cmd>TmuxNavigateLeft<cr>", opts)
    map("t", "<C-l>", "<cmd>TmuxNavigateRight<cr>", opts)
  end,
}
