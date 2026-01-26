-- Utilities for controlled debug printing
-- Usage: require('utils.user_debug').dbg(...) will print when vim.g.userdebug is truthy

local M = {}

--- Set debug enabled flag (updates global so other modules can see it)
function M.on(val)
  -- __AUTO_GENERATED_PRINT_VAR_START__
  print([==[M.on val:]==], vim.inspect(val)) -- __AUTO_GENERATED_PRINT_VAR_END__
  vim.g.userdebug = val == nil and true or val or false
end
function M.toggle(val)
  vim.g.userdebug = not vim.g.userdebug or false
end
_G.userdebugtoggle = M.toggle_debug -- global function for easy toggling from command line

--- Return whether debug printing is enabled
function M.is_enabled()
  return vim.g.userdebug ~= nil and vim.g.userdebug ~= false
end

--- Debug print helper that accepts any number of arguments of any type.
--- - Prints nothing when debug is disabled.
--- - For nil values prints the literal string "nil".
--- - Uses vim.inspect for non-nil values to produce readable representation.
--- @param ... any
function M.dbg(...)
  if not M.is_enabled() then
    return
  end

  local n = select("#", ...)
  if n == 0 then
    print "dbg: (no args)"
    return
  end

  local parts = {}
  for i = 1, n do
    local v = select(i, ...)
    if v == nil then
      table.insert(parts, "nil")
    else
      local ok, s = pcall(vim.inspect, v)
      if ok and s ~= nil then
        table.insert(parts, s)
      else
        table.insert(parts, tostring(v))
      end
    end
  end

  for _, part_str in ipairs(parts) do
    print(part_str)
  end
end

return M
