---@return overseer.TemplateDefinition
return {
  name = "Run Android pick",
  description = "run android test on current file",
  builder = function(params)
    local andcmd = params.andcmd
    -- __AUTO_GENERATED_PRINT_VAR_START__
    local base_command = "sh " .. os.getenv("HOME") .. "/Personal/mynotes/work/AgodaCoding/agodaSnip.sh and "
    local finalcmd = base_command .. andcmd
    print([==[builderx finalcmd:]==], vim.inspect(finalcmd)) -- __AUTO_GENERATED_PRINT_VAR_END__
    ---@type overseer.TaskDefinition
    return {
      cmd = finalcmd,
    }
  end,
  --- @type overseer.Params|fun():overseer.Params
  params = function()
    local display_choices = {
      "Test mmb,legacy,home",
      "Detekt, Precheck Check",
      "Clean and fix zip error",
      "Build App Presentation",
      -- "Find Build Dir and Install APK",
    }

    local commands = {
      "and_test_mmb_screen_legacynav_home",
      "and_ci_ag_precheck_detekt",
      "and_zip_error",
      "and_build_app_presentation # build only",
      -- "and_find_build_dir_and_ls_apk # install apk",
    }

    local choice_input_list = { "Please select a command (default = Test mmb,legacy,home): " }

    for i, display_choice in ipairs(display_choices) do
      table.insert(choice_input_list, string.format("%d. %s", i, display_choice))
    end
    table.insert(choice_input_list, "") -- Exit input list construction

    local selected_index = vim.fn.inputlist(choice_input_list)
    local sel_command = commands[1] -- Default command

    if selected_index > 0 and selected_index <= #commands then
      sel_command = commands[selected_index]
      print([==[params#if selected_command:]==], vim.inspect(sel_command)) -- Debugging user choice
    end

    --- @type overseer.Params
    return {
      andcmd = {
        type = "enum",
        choices = commands,
        name = "finalcommand",
        desc = "The package name for the test",
        order = 1,
        default = sel_command,
        validate = function(value)
          return true
        end,
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
