return {
  {
    "folke/which-key.nvim",
    optional = true,
    opts = {
      spec = {
        { "<leader>m", group = "markdown", icon = "" },
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    optional = true,
    opts = { ensure_installed = { "markdown", "markdown_inline" } },
  },
  -- Markdown preview
  {
    "MeanderingProgrammer/render-markdown.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    opts = {
      latex = { enabled = false },
    },
    ft = { "markdown" },
    keys = {
      {
        "<leader>tm",
        "<cmd>RenderMarkdown toggle<cr>",
        desc = "Toggle Markdown preview",
      },
    },
  },
  {
    "previm/previm",
    config = function()
      -- define global for open markdown preview, let g:previm_open_cmd = 'open -a Safari'
      -- vim.g.previm_open_cmd = "/Applications/Brave\\ Browser.app/Contents/MacOS/Brave\\ Browser"
      -- vim.g.previm_open_cmd = "open -a Microsoft\\ Edge"
      vim.g.previm_open_cmd = "open -a Safari"
    end,
    ft = { "markdown" },
    keys = {
      {
        "<leader>m",
        "<cmd>PrevimOpen<cr>",
        desc = "Markdown preview on browser",
      },
    },
  },
}
