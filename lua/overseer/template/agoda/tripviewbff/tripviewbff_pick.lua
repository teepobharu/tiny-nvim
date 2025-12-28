---@return overseer.TemplateDefinition
return {
  name = "Run TW Tripviewbff pick",
  description = "run android test on current file",
  builder = function(params)
    local sel_command = params.command
    local base_command = "sh " .. vim.fn.expand("$HOME") .. "/Personal/mynotes/work/AgodaCoding/agodaSnip.sh mmba "
    local finalcmd = base_command .. " " .. (sel_command or "")
    -- __AUTO_GENERATED_PRINT_VAR_START__
    print([==[builder finalcmd:]==], vim.inspect(finalcmd)) -- __AUTO_GENERATED_PRINT_VAR_END__
    -- Playwright HTML report prompt
    -- local html_choices = {}
    -- local handle = io.popen('find test/playwright -type f -path "*/test-results-*/**/index.html"')
    -- if handle then
    --   for file in handle:lines() do
    --     table.insert(html_choices, file)
    --   end
    --   handle:close()
    -- end

    ---@type overseer.TaskDefinition
    return {
      cmd = finalcmd,
    }
  end,
  --- @type overseer.Params|fun():overseer.Params
  params = function()
    return {
      command = {
        -- /Users/tharutaipree/Personal/mynotes/work/AgodaCoding/agodaSnip.sh
        optional = true, -- will not prompt
        description = "Additional command line arguments for mmba",
        choices = {
          "mmb_entry -s -n", -- default sv no build
          "mmb_entry -s",
          "mmb_entry -dev",
          "mmb_entry -ci",
          "mmb_entry -o",
          "mmb_entry"
        },
        default = "",
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
      local isInProj = vim.fn.expand("%:p:h"):match("trip%-view%-bff") or vim.fn.expand("%:p:h"):match("trips%-web") or vim.fn.expand("%:p:h"):match("mmbweb")
      if isInProj then
        return true
      else
        return false
      end
    end,
  },
}
