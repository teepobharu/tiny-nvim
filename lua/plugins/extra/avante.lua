return {
  {
    "yetone/avante.nvim",
    event = "VeryLazy",
    build = "make",
    opts = {
      hints = { enabled = false }, -- Disable hints
      provider = "copilot", -- You can then change this provider here
      mappings = {
        ask = "<leader>ra",
        edit = "<leader>rA",
        refresh = "<leader>rr",
      },
      -- Disable Avante's built-in tools to prevent duplication with MCPHub's neovim server tools
      -- MCPHub provides file operations and bash terminal access via MCP
      disabled_tools = {
        -- File operations handled by MCPHub neovim server
        "list_files",
        "search_files",
        "read_file",
        "create_file",
        "rename_file",
        "delete_file",
        "create_dir",
        "rename_dir",
        "delete_dir",
        -- Terminal access handled by MCPHub neovim server
        "bash",
      },
    },
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      -- MCPHub integration for MCP tools access
      -- Usage: /mcp:* for prompts
      -- See: lua/plugins/extra/myAi.lua for configuration
      { "ravitemer/mcphub.nvim", optional = true },
    },
    config = function(_, options)
      require("avante").setup(options)

      local wk = require("which-key")
      wk.add({
        { "<leader>ra", desc = "Ask AI" },
        { "<leader>rA", desc = "Edit selected",   mode = { "v" } },
        { "<leader>rr", desc = "Refresh AI" },
        { "<leader>rM", desc = "Avante AI Models" },
      })
      vim.api.nvim_set_keymap("n", "<leader>rM", ":AvanteModel<CR>", { noremap = true, silent = true })
    end,
  },
  {
    "MeanderingProgrammer/render-markdown.nvim",
    optional = true,
    opts = {
      file_types = { "markdown", "Avante" },
    },
    ft = { "markdown", "Avante" },
  },
}
