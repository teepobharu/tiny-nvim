return {
  name = "run script",
  builder = function()
    local file = vim.fn.expand("%:p")
    local ft = vim.bo.filetype
    local cmd = { ft, file }
    local filetype_commands = {
      -- lua = { "luafile", file },
      lua = { "nvim" , "--headless", "-c luafile " .. file, "+q" },
      go = { "go", "run", file },
      python = { "python", file },
      javascript = { "node", file },
      typescript = { "bun", file },
      perl = { "perl", file },
      sh = { "sh", file },
      -- Add more filetypes and commands as needed
    }

    if not filetype_commands[ft] then
      vim.notify("No run command found for filetype '" .. ft .. "', using default: " .. vim.inspect(cmd), vim.log.levels.WARN)
    end
    cmd = filetype_commands[ft] or cmd
    if vim.fn.executable(cmd[1]) == 0 then
      local warning = tostring(cmd) .. "is not executable"
      Snacks.notify.warning(warning)
      cmd = cmd .. " " .. "|| echo 'Warning: cmd not working"
    end

    return {
      cmd = cmd,
      components = {
        { "on_output_quickfix", set_diagnostics = true },
        "default",
      },
    }
  end,
  condition = {
    -- filetype = { "sh", "python", "go", "lua" },
  },
}
