return {
  name = "run script",
  builder = function()
    local file = vim.fn.expand("%:p")
    local ft = vim.bo.filetype
    local cmd = { ft, file }
    local filetype_commands = {
      lua = { "luafile", file },
      go = { "go", "run", file },
      python = { "python", file },
      javascript = { "node", file },
      typescript = { "bun", file },
      perl = { "perl", file },
      sh = { "sh", file },
      -- Add more filetypes and commands as needed
    }

    if not filetype_commands[ft] then
      vim.notify("No run command found for " .. ft .. "using default command: " .. cmd)
    end

    cmd = filetype_commands[ft] or cmd

    return {
      cmd = cmd,
      components = {
        { "on_output_quickfix", set_diagnostics = true },
        "on_result_diagnostics",
        "default",
      },
    }
  end,
  condition = {
    -- filetype = { "sh", "python", "go", "lua" },
  },
}
