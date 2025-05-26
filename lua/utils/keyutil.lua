local M = {}

M.isSnackEnabled = vim.g.enable_extra_plugins and vim.tbl_contains(vim.g.enable_extra_plugins, "snacks") or true
M.isToggleTermEnabled = vim.g.enable_extra_plugins and vim.tbl_contains(vim.g.enable_extra_plugins, "myToggleterm")
print([==[ M.isSnackEnabled:]==], vim.inspect(M.isSnackEnabled)) -- __AUTO_GENERATED_PRINT_VAR_END__

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
