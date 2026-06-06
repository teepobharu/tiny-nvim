local shebang = require "utils.shebang"

local function get_effective_filetype(file, ft)
  if file:match("%.applescript$") or file:match("%.scpt$") then
    return "applescript"
  end
  return ft
end

return {
  name = "run script",
  tags = { require("overseer").TAG.RUN, "run", "custom" },
  builder = function()
    local file = vim.fn.expand "%:p"
    local ft = get_effective_filetype(file, vim.bo.filetype)
    local cmd = { ft, file }
    local filetype_commands = {
      -- lua = { "luafile", file },
      lua = { "nvim", "--headless", "-c luafile " .. file, "+q" },
      go = { "go", "run", file },
      python = { "python", file },
      javascript = { "node", file },
      typescript = { "bun", file },
      perl = { "perl", file },
      sh = { "sh", file },
      applescript = { "osascript", file },
      -- Add more filetypes and commands as needed
    }

    if not filetype_commands[ft] then
      vim.notify(
        "No run command found for filetype '" .. ft .. "', using default: " .. vim.inspect(cmd),
        vim.log.levels.WARN
      )
    end
    cmd = filetype_commands[ft] or cmd
    if vim.fn.executable(cmd[1]) == 0 then
      local warning = vim.inspect(cmd) .. " is not executable"
      vim.notify(warning, vim.log.levels.WARN)
      cmd = shebang.build_exec_cmd(file) or { "sh", file }
    end

    return {
      cmd = cmd,
      components = {
        { "on_output_quickfix", set_diagnostics = true },
        { "open_output", on_start = "always", direction = "dock", focus = false },
        "default",
      },
    }
  end,
  condition = {
    -- filetype = { "sh", "python", "go", "lua" },
  },
}
