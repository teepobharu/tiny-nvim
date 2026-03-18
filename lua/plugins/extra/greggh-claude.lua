-- Claude Code Plugin for Neovim
--
-- Usage:
--   • Toggle Claude: <C-,> (Control + comma) in normal or terminal mode
--   • Continue conversation: <leader>Cc
--   • Verbose mode: <leader>Cv
--
-- The plugin opens in a floating window covering 90% of the screen.
-- You can interact with Claude directly from within Neovim for coding assistance.

local mapping_key_prefix = "<localleader>C"

return {
  {
    "folke/which-key.nvim",
    optional = true,
    opts = {
      spec = {
        { mapping_key_prefix, group = "G-ClaudeCode", mode = { "n", "v" }, icon = "🤖" },
      },
    },
  },
  {
    "greggh/claude-code.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    opts = {
      keymaps = {
        toggle = {
          normal = "<C-,>",
          terminal = "<C-,>",
          variants = {
            continue = mapping_key_prefix .. "c",
            verbose = mapping_key_prefix .. "v",
            sudo = mapping_key_prefix .. "s",
          },
        },
      },
      window = {
        position = "float",
        float = {
          width = "90%",
          height = "90%",
          row = "center",
          col = "center",
          relative = "editor",
          border = "double",
        },
      },
      command_variants = {
        -- Output options
        sudo = "--dangerously-skip-permissions", -- Enable verbose logging with full turn-by-turn output
      },
    },
  },
}
