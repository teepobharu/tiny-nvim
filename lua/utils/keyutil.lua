local M = {}

M.isSnackEnabled = vim.g.enable_plugins and vim.g.enable_plugins.snacks == "yes"
M.isToggleTermEnabled = vim.g.enable_plugins and vim.g.enable_plugins.myToggleterm == "yes"

local function get_prefix_key(key)
  if M.isSnackEnabled then
    return key:upper()
  else
    return key:lower()
  end
end

M.key_f = get_prefix_key("f")
M.key_s = get_prefix_key("s")
M.key_g = get_prefix_key("g")
M.key_l = get_prefix_key("l")
M.key_e = get_prefix_key("e")

return M
