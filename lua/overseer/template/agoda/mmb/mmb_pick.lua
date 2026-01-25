---@return overseer.TemplateDefinition
return {
  name = "Run Mmb pick",
  tags = vim.tbl_extend(
    "force",
    {
      require("overseer").TAG.BUILD,
      require("overseer").TAG.RUN,
      require("overseer").TAG.TEST,
      require("overseer").TAG.CLEAN,
    },
    { "agoda", "custom" }
  ),
  description = "run android test on current file",
  builder = function(params)
    -- v2: Validation moved from condition callback
    local current_path = vim.fn.expand "%:p:h"
    if not current_path:match "mmb" then
      Snacks.debug "Cmd Fail only works on path mmb"
      error("This template only works in mmb projects. Current path: " .. current_path)
    end

    local sel_command = params.command
    local base_command = "sh /Users/tharutaipree/Personal/mynotes/work/AgodaCoding/agodaSnip.sh mmb "
    local finalcmd = base_command .. sel_command
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
      components = {
        -- behavior: https://deepwiki.com/search/is-this-correct_41cc0f33-a7dd-48fb-92e4-05ecb8826107?mode=fast
        -- does not really open ??
        { "open_output", direction = "float", on_start = "always" },
        "default",
      },
    }
  end,
  --- @type overseer.Params|fun():overseer.Params
  params = function()
    -- TODO use same approach as and_pick for better completion selection index instead of key since keys  with inputlist fn will reorder from when remap with ipair loops
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

    -- Initialize html_choices (commented out in builder, keep for future use)
    local html_choices = {}
    -- local handle = io.popen('find test/playwright -type f -path "*/test-results-*/**/index.html"')
    -- if handle then
    --   for file in handle:lines() do
    --     table.insert(html_choices, file)
    --   end
    --   handle:close()
    -- end

    return {
      command = {
        type = "namedEnum", -- not in doc but usable why ? https://github.com/stevearc/overseer.nvim/blob/master/doc/reference.md
        name = "command",
        desc = "The package name for the test",
        order = 1,
        choices = choices,
        default = choices["Server run only"],
        optional = false,
      },
      playwright_report = {
        type = "choice",
        name = "Playwright HTML Report",
        desc = "Open Playwright HTML report",
        order = 2,
        choices = html_choices,
        optional = true,
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
  condition = {
    -- filetype = { "kotlin" },
    -- Note: v2 removed condition callbacks - validation moved to builder
  },
}
