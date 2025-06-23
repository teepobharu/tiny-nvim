---@return overseer.TemplateDefinition
return {
  name = "Run Android pick",
  description = "run android test on current file",
  builder = function(params)
    local sel_command = params.command
    local base_command = "sh /Users/tharutaipree/Personal/mynotes/work/AgodaCoding/agodaSnip.sh and "
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
      ["Build App Presentation"] = "and_build_app_presentation # build only",
      ["Find Build Dir and Install APK"] = "and_find_build_dir_and_ls_apk # install apk",
      ["Detekt Check"] = "and_detekt_check # check detekt",
    }
    --- @type overseer.Params
    return {
      command = {
        type = "namedEnum",
        name = "command",
        desc = "The package name for the test",
        order = 1,
        choices = choices,
        default = choices["Build App Presentation"],
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
      local isInClientAndroidProject = vim.fn.expand("%:p:h"):match("client%-android")
      if isInClientAndroidProject then
        return true
      else
        return false
      end
    end,
  },
}
