-- agentic.nvim - Multi-Provider AI Agent
-- Supports: Claude, Gemini, Cursor, Codex, OpenCode, Goose
-- Uses Agent Client Protocol (ACP) for unified interface
--
-- For Cursor support, install:
--   npm install -g @blowmage/cursor-agent-acp

return {
  "carlos-algms/agentic.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
  },
  keys = {
    -- Quick toggle (similar to Cursor's Cmd+K)
    {
      "<C-\\>",
      function() require("agentic").toggle() end,
      mode = { "n", "v", "i" },
      desc = "Toggle Agentic",
    },
    -- Leader key alternatives
    { "<leader>aG", function() require("agentic").toggle() end, desc = "Agentic: Toggle" },
    { "<leader>aGn", function() require("agentic").new_session() end, desc = "Agentic: New session" },
    { "<leader>aGs", function() require("agentic").select_session() end, desc = "Agentic: Select session" },
    { "<leader>aGp", function() require("agentic").select_provider() end, desc = "Agentic: Select provider" },
  },
  opts = {
    -- Default provider (change based on subscription)
    -- Options: "claude", "gemini", "cursor-acp", "codex", "goose"
    provider = "claude",

    -- Provider-specific configurations
    providers = {
      claude = {
        -- Uses ANTHROPIC_API_KEY env var
        model = "claude-sonnet-4-20250514",
      },
      ["cursor-acp"] = {
        -- Requires cursor-agent-acp installed globally
        -- npm install -g @blowmage/cursor-agent-acp
        endpoint = "http://localhost:3001", -- or Docker: cursor-acp service
      },
      goose = {
        -- Uses Goose CLI
        cmd = "goose",
      },
      gemini = {
        -- Uses GOOGLE_API_KEY env var
        model = "gemini-2.0-flash",
      },
    },

    -- UI configuration
    ui = {
      position = "right",
      width = 0.4,
      border = "rounded",
    },

    -- Context settings
    context = {
      -- Include current file automatically
      include_current_file = true,
      -- Enable @ file completion
      file_completion = true,
      -- Enable image/screenshot support
      image_support = true,
    },

    -- Behavior
    behavior = {
      -- Auto-accept mode (skip permission prompts)
      auto_accept = false,
      -- Plan mode (think before acting)
      plan_mode = true,
    },
  },
  config = function(_, opts)
    require("agentic").setup(opts)

    -- Register with which-key
    local ok, wk = pcall(require, "which-key")
    if ok then
      wk.add({
        { "<leader>aG", group = "Agentic AI" },
      })
    end
  end,
}
