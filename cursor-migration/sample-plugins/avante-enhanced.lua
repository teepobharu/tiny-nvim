-- avante.nvim - Enhanced Configuration for Cursor-like Experience
-- This builds on your existing avante.lua with more Cursor-like features
--
-- Key additions:
-- - Zen Mode (CLI-like interface)
-- - Auto-apply diffs
-- - Multiple provider support
-- - MCP integration

return {
  {
    "yetone/avante.nvim",
    event = "VeryLazy",
    build = "make",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      "nvim-tree/nvim-web-devicons",
      -- Optional: MCP support
      { "ravitemer/mcphub.nvim", optional = true },
    },
    opts = {
      -- Disable default hints (cleaner UI)
      hints = { enabled = false },

      -- Primary provider (switch with :AvanteProvider)
      provider = "copilot",

      -- Auto-suggestions provider (for Tab completions)
      auto_suggestions_provider = "copilot",

      -- Behavior settings (Cursor-like)
      behaviour = {
        -- Auto-apply AI suggestions
        auto_apply_diff_after_generation = true,
        -- Support paste from clipboard
        support_paste_from_clipboard = true,
        -- Enable agentic mode
        agentic_mode = true,
      },

      -- Provider configurations
      providers = {
        copilot = {
          -- Uses GitHub Copilot subscription
          model = "claude-3.5-sonnet",
        },
        claude = {
          endpoint = "https://api.anthropic.com",
          model = "claude-sonnet-4-20250514",
          -- Uses ANTHROPIC_API_KEY
        },
        openai = {
          endpoint = "https://api.openai.com/v1",
          model = "gpt-4o",
          -- Uses OPENAI_API_KEY
        },
        ollama = {
          endpoint = "http://localhost:11434",
          model = "codellama:13b",
        },
      },

      -- Keymappings
      mappings = {
        ask = "<leader>ra",
        edit = "<leader>rA",
        refresh = "<leader>rr",
        -- Additional mappings for Cursor-like experience
        focus = "<leader>rf",
        toggle = "<leader>rt",
      },

      -- UI configuration
      ui = {
        sidebar = {
          width = 0.4,
          position = "right",
        },
      },

      -- Security: Don't access git-ignored files (.env, etc.)
      allow_access_to_git_ignored_files = false,

      -- File selector configuration
      file_selector = {
        provider = "snacks",
      },

      -- Web search integration
      web_search = {
        enabled = true,
        provider = "google",
      },
    },
    keys = {
      { "<leader>ra", desc = "Avante: Ask AI" },
      { "<leader>rA", desc = "Avante: Edit selected", mode = "v" },
      { "<leader>rr", desc = "Avante: Refresh" },
      { "<leader>rM", "<cmd>AvanteModel<cr>", desc = "Avante: Select model" },
      { "<leader>rP", "<cmd>AvanteProvider<cr>", desc = "Avante: Select provider" },
      -- Zen Mode (CLI-like experience)
      {
        "<leader>rz",
        function() require("avante.api").zen_mode() end,
        desc = "Avante: Zen Mode",
      },
      -- Focus toggle
      {
        "<leader>rf",
        function() require("avante.api").toggle_sidebar() end,
        desc = "Avante: Toggle sidebar",
      },
    },
    config = function(_, opts)
      require("avante").setup(opts)

      -- Register with which-key
      local ok, wk = pcall(require, "which-key")
      if ok then
        wk.add({
          { "<leader>r", group = "Avante/Refactor" },
          { "<leader>ra", desc = "Ask AI" },
          { "<leader>rA", desc = "Edit selected", mode = "v" },
          { "<leader>rr", desc = "Refresh AI" },
          { "<leader>rM", desc = "Select model" },
          { "<leader>rP", desc = "Select provider" },
          { "<leader>rz", desc = "Zen Mode (CLI)" },
          { "<leader>rf", desc = "Toggle sidebar" },
        })
      end

      -- Create shell alias for Zen Mode (add to .zshrc/.bashrc)
      -- alias avante='nvim -c "lua vim.defer_fn(function() require(\"avante.api\").zen_mode() end, 100)"'
    end,
  },

  -- Render markdown in Avante buffers
  {
    "MeanderingProgrammer/render-markdown.nvim",
    optional = true,
    opts = {
      file_types = { "markdown", "Avante" },
    },
    ft = { "markdown", "Avante" },
  },
}
