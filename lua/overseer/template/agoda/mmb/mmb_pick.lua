---@return overseer.TemplateDefinition
return {
  name = "Run Mmb pick",
  description = "run android test on current file",
  builder = function(params)
    local sel_command = params.command
    local base_command = "sh /Users/tharutaipree/Personal/mynotes/work/AgodaCoding/agodaSnip.sh mmb "
    local finalcmd = base_command .. sel_command
    -- __AUTO_GENERATED_PRINT_VAR_START__
    print([==[builder finalcmd:]==], vim.inspect(finalcmd)) -- __AUTO_GENERATED_PRINT_VAR_END__
    ---@type overseer.TaskDefinition
    return {
      cmd = finalcmd,
    }
  end,
  --- @type overseer.Params|fun():overseer.Params
  params = function()
    local choices = {
      ["Client install only"] = "--client-installonly",
      ["Dev BLP"] = "--dev-blp --client-noinstall",
      ["Dev BLP +install"] = "--dev-blp",
      ["Dev BLP + run Server"] = "--dev-blp -s",
      --- if client build then no run sv if -s not specified
      ["Server and parallel def build"] = "-s",
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
    filetypes = { "kt" },
    callback = function(task)
      local isInProj = vim.fn.expand("%:p:h"):match("mmb")
      if isInProj then
        return true
      else
        return false
      end
    end,
  },
}
