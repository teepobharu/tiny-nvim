-- goose.nvim - Open-Source AI Agent Integration
-- Uses Block's Goose AI (https://github.com/block/goose)
-- Fully open-source alternative to Cursor Agent
--
-- Install Goose CLI:
--   brew install block/tap/goose  # macOS
--   # or
--   curl -fsSL https://github.com/block/goose/releases/latest/download/goose-linux-amd64 -o goose
--   chmod +x goose && sudo mv goose /usr/local/bin/

return {
  "azorng/goose.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
  },
  cmd = { "Goose", "GooseToggle", "GooseChat", "GooseContext" },
  keys = {
    { "<leader>ag", "<cmd>GooseToggle<cr>", desc = "Goose: Toggle" },
    { "<leader>agc", "<cmd>GooseChat<cr>", desc = "Goose: Chat" },
    { "<leader>agx", "<cmd>GooseContext<cr>", desc = "Goose: Add context" },
    { "<leader>agn", "<cmd>GooseNewSession<cr>", desc = "Goose: New session" },
    { "<leader>ags", "<cmd>GooseSelectSession<cr>", desc = "Goose: Select session" },
    -- Visual mode: send selection
    { "<leader>ag", "<cmd>GooseSelection<cr>", mode = "v", desc = "Goose: Send selection" },
  },
  opts = {
    -- Goose CLI path (if not in PATH)
    goose_cmd = "goose",

    -- Provider configuration (can also use goose-config.yaml)
    provider = "anthropic", -- Options: anthropic, openai, ollama

    -- Model selection
    model = "claude-sonnet-4-20250514",

    -- UI settings
    ui = {
      position = "right",
      width = 0.4,
      border = "rounded",
      title = " Goose AI ",
    },

    -- Toolkits to enable
    toolkits = {
      "developer",
      "git",
      "github",
      "web_search",
    },

    -- Session settings
    session = {
      -- Auto-save sessions
      auto_save = true,
      -- Show session in statusline
      statusline = true,
    },

    -- Safety settings
    safety = {
      -- Require confirmation for shell commands
      confirm_shell = true,
      -- Require confirmation for file writes
      confirm_write = false,
    },
  },
  config = function(_, opts)
    require("goose").setup(opts)

    -- Register with which-key
    local ok, wk = pcall(require, "which-key")
    if ok then
      wk.add({
        { "<leader>ag", group = "Goose AI" },
      })
    end

    -- Optional: Add to lualine statusline
    -- Shows current Goose session status
    -- local goose_status = require("goose").statusline
  end,
}
