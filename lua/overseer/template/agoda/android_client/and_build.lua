---@return overseer.TemplateFileDefinition
return {
  name = "Build android",
  description = "Build run android",
  builder = function(params)
    -- make sure to get the module path and the class package name to run in this command
    --
    local cmd = "sh /Users/tharutaipree/Personal/mynotes/work/AgodaCoding/agodaSnip.sh and"
    cmd = cmd .. " " .. params.input
    print([==[builder final cmd:]==], vim.inspect(cmd)) -- __AUTO_GENERATED_PRINT_VAR_END__
    -- __AUTO_GENERATED_PRINT_VAR_START__
    ---@type overseer.TaskDefinition
    return {
      cmd = cmd,
    }
  end,
  params = {
    input = {
      type = "string",
      -- Optional fields that are available on any type
      name = "command",
      desc = "sub commands",
      order = 1, -- determines order of parameters in the UI
      validate = function(value)
        return true
      end,
      optional = true,
      default = "and_build_app_presentation true",
      -- For component params only.
      -- When true, will default to the value in the task's default_component_params
      -- default_from_task = true,
    },
  },
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
  condition = {
    filetypes = { "kt" },
    -- dir = "$HOME",
    callback = function(task)
      -- current file path include tests and kotlin file
      -- get current dir
      local isInClientAndroidProject = vim.fn.expand("%:p:h"):match("client%-android")
      if isInClientAndroidProject then
        return true
      else
        return false
      end
    end,
  },
}
