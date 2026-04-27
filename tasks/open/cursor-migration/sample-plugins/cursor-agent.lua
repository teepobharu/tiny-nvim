-- cursor-agent.nvim - Direct Cursor CLI Integration
-- Requires: Cursor Pro subscription + cursor-agent CLI in PATH
-- Install CLI: https://docs.cursor.com/cli
--
-- Usage:
--   :CursorAgent           - Open interactive terminal
--   :CursorAgentSelection  - Send visual selection
--   :CursorAgentBuffer     - Send entire buffer

return {
  "xTacobaco/cursor-agent.nvim",
  cmd = { "CursorAgent", "CursorAgentSelection", "CursorAgentBuffer" },
  keys = {
    { "<leader>aC", "<cmd>CursorAgent<cr>", desc = "Cursor Agent" },
    { "<leader>aCs", "<cmd>CursorAgentSelection<cr>", mode = "v", desc = "Cursor: Send selection" },
    { "<leader>aCb", "<cmd>CursorAgentBuffer<cr>", desc = "Cursor: Send buffer" },
  },
  config = function()
    require("cursor-agent").setup({
      -- Path to cursor-agent CLI (must be in PATH or specify full path)
      cmd = "cursor-agent",

      -- Terminal window configuration
      window = {
        position = "float",
        width = 0.8,
        height = 0.8,
        border = "rounded",
      },
    })
  end,
}
