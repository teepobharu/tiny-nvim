-- Only contains modifications to default configs
return {
  {
    "folke/sidekick.nvim",
    opts = {
      cli = {
        win = {
          keys = {
            -- Disable conflicting Ctrl keybindings
            files = false, -- disables <c-f>
            prompt = false, -- disables <c-p>
            buffers = false, -- disables <c-b>
            -- Disable all tmux navigation keys in sidekick terminal
            nav_left = false, -- disables <c-h>
            nav_down = false, -- disables <c-j>
            nav_up = false, -- disables <c-k>
            nav_right = false, -- disables <c-l>

            -- Remap to Alt/Meta keys (avoiding m-f, m-b for word navigation)
            files_alt = { "<a-e>", "files", mode = "nt", desc = "open file picker" },
            buffers_alt = { "<a-r>", "buffers", mode = "nt", desc = "open buffer picker (recent)" },
            prompt_alt = { "<a-p>", "prompt", mode = "t", desc = "insert prompt or context" },
          },
        },
      },
    },
    config = function(_, opts)
      require("sidekick").setup(opts)

      -- Remove tmux-navigator keybindings that conflict with sidekick
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "sidekick_terminal",
        callback = function(ev)
          local buf = ev.buf
          pcall(vim.keymap.del, "t", "<C-h>", { buffer = buf })
          pcall(vim.keymap.del, "t", "<C-j>", { buffer = buf })
          pcall(vim.keymap.del, "t", "<C-k>", { buffer = buf })
          pcall(vim.keymap.del, "t", "<C-l>", { buffer = buf })
        end,
        desc = "Remove tmux-navigator keys in sidekick terminal",
      })
    end,
  },
  -- MCPHub.nvim - MCP client and tool bridge for AI chat plugins
  {
    "folke/which-key.nvim",
    optional = true,
    opts = {
      spec = {
        { mapping_mcphub_key_prefix, group = "MCPHub", mode = { "n" } },
      },
    },
  },
  {
    "ravitemer/mcphub.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    cmd = "MCPHub",
    build = "bundled_build.lua",
    opts = {
      use_bundled_binary = true,
      config = vim.fn.expand "~/dotfiles/claude/mcp-proxy/mcphub.json",
      port = 37373,
      auto_approve = false,
      auto_toggle_mcp_servers = true,
      extensions = {
        codecompanion = {
          show_result_in_chat = true,
          make_vars = true,
          make_slash_commands = true,
        },
        avante = {
          make_slash_commands = true,
        },
      },
      ui = {
        window = {
          width = 0.8,
          height = 0.8,
        },
      },
      log = {
        level = vim.log.levels.WARN,
        to_file = false,
      },
    },
    keys = {
      { "<leader>ah", "<cmd>MCPHub<cr>", desc = "MCPHub" },
    },
  },
}
