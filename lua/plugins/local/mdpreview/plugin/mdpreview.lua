if vim.g.loaded_mdpreview then
  return
end
vim.g.loaded_mdpreview = true

vim.api.nvim_create_user_command("MdPreview", function(cmd)
  local args = {}
  if cmd.args ~= "" then
    for a in cmd.args:gmatch "%S+" do
      table.insert(args, a)
    end
  end
  require("mdpreview").open(args)
end, {
  nargs = "*",
  complete = "file",
  desc = "Open markdown preview in browser",
})

vim.api.nvim_create_user_command("MdPreviewStop", function()
  require("mdpreview").stop()
end, { desc = "Stop markdown preview server" })
