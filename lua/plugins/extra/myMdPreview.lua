local config_root = vim.fn.stdpath "config"

return {
  {
    "mdpreview",
    dir = config_root .. "/lua/plugins/local/mdpreview",
    cmd = { "MdPreview", "MdPreviewStop" },
    keys = {
      {
        "<leader>Mh",
        function()
          require("mdpreview").open {}
        end,
        desc = "MD Preview (browser)",
      },
    },
    config = function()
      require("mdpreview").setup()
    end,
  },
}
