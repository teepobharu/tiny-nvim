@return overseer.TemplateDefinition
return {
  name = "Test jest curr no Cov watch snap",
  description = "Run Jest tests on the current file with specified options",
  builder = function(params)
    local file_name = vim.fn.expand("%")
    local base_command = "yarn test " .. file_name .. " --watch -u --silence=false --coverage=false"
    ---@type overseer.TaskDefinition
    return {
      cmd = base_command,
    }
  end,
  --- @type overseer.Params|fun():overseer.Params
  params = function()
    local choices = {
      ["Server + Build and parallel def build"] = "-s",
      ["Server run only"] = "-s --nobuild",
    }
    --- @type overseer.Params
    return {
      command = {
        type = "namedEnum",
        name = "command",
        desc = "The package name for the test",
        order = 1,
        choices = choices,
        default = choices["Sever"],
        optional = false,
      },
    }
  end,
  components = {
    -- {
    -- "on_output_quickfix", -- will output to quickfix
    -- errorformat = vim.o.grepformat,
    -- open = true,
    -- open = not params.bang,
    -- open_height = 8,
    -- items_only = true,
    -- },
    -- We don't care to keep this around as long as most tasks
    -- { "on_complete_dispose", timeout = 30 },
    { "on_complete_notify", system = "always" },
    "default",
  },
  priority = 5,
  condition = {
    filetypes = { "kt", "test" }, -- Include test filetypes
    callback = function(task)
      local isTestFile = vim.fn.expand("%:t"):match("_test.kt$") -- Match test files
      if isTestFile then
        return true
      else
        return false
      end
    end,
  },
}
