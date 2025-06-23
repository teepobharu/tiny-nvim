---@return overseer.TemplateFileDefinition
return {
  name = "vimgrep_quicklist",
  description = "Run vimgrep and output to quickfix",
  builder = function(params)
    -- grepprg seems to be rg
    local cmd, num_subs = vim.o.grepprg:gsub("%$%*", params.input)
    local current_file_dir = vim.fn.expand("%:p:h")
    print([==[builder current_file_dir:]==], vim.inspect(current_file_dir)) -- __AUTO_GENERATED_PRINT_VAR_END__
    -- if eq dir do not apply dir filter
    if current_file_dir:gsub("/$", "") == params.dir:gsub("/$", "") then
      params.dir = ""
    end

    local dirpart, extra_args
    dirpart = (params.dir ~= "" and '"' .. params.dir .. '" ') or ""
    extra_args = params.extra_args ~= "" and params.extra_args or ""

    if num_subs == 0 then
      cmd = cmd .. ' "' .. params.input .. '" ' .. dirpart .. extra_args
    end

    ---@type overseer.TaskDefinition
    return {
      cmd = cmd,
      -- components = {
      --   {
      --     "on_output_quickfix", -- will output to quickfix
      --     errorformat = vim.o.grepformat,
      --     open = not params.bang,
      --     open_height = 8,
      --     items_only = true,
      --   },
      --   -- We don't care to keep this around as long as most tasks
      --   { "on_complete_dispose", timeout = 30 },
      --   { "on_complete_notify", system = "unfocused" },
      --   "default",
      -- },
      components = {
        {
          "on_output_quickfix", -- will output to quickfix
          errorformat = vim.o.grepformat,
          open = true,
          -- open = not params.bang,
          open_height = 8,
          items_only = true,
        },
        -- We don't care to keep this around as long as most tasks
        { "on_complete_dispose", timeout = 30 },
        { "on_complete_notify", system = "always" },
        "default",
      },
    }
  end,
  --- @type overseer.Params|fun():overseer.Params
  params = function()
    return {
      input = {
        type = "string",
        -- Optional fields that are available on any type
        name = "Search input",
        desc = "rg <pattern>",
        order = 1, -- determines order of parameters in the UI
        validate = function(value)
          return true
        end,
        optional = false,
      },
      dir = {
        type = "string",
        -- Optional fields that are available on any type
        name = "Directory",
        desc = "filepath to filter",
        order = 2, -- determines order of parameters in the UI
        validate = function(value)
          if vim.fn.isdirectory(value) == 0 then
            return false
          end
          return true
        end,
        optional = true,
        default = vim.fn.expand("%:p:h"),
      },
      extra_args = {
        type = "string",
        -- Optional fields that are available on any type
        name = "Directory",
        desc = "-t <filetype> -T <notfiletype> -F <filetype>",
        order = 3, -- determines order of parameters in the UI
        optional = true,
      },
    }
  end,
  -- components define here not working
  condition = {
    -- filetypes = { "lua" },
    -- dir = "",
    callback = function(task)
      return true
    end,
  },
}
