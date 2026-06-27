---@return overseer.TemplateDefinition
return {
  name = "Run TW/MMB entry pick",
  tags = vim.list_extend({ "agoda", "custom" }, require("overseer").TAG.values),
  description = "Run trips-web (tw) or legacy mmb entry commands",
  builder = function(params)
    -- v2: Validation moved from condition callback
    local current_path = vim.fn.expand "%:p:h"
    local is_in_proj = current_path:match "trip%-view%-bff"
      or current_path:match "trips%-web"
      or current_path:match "mmbweb"
    if not is_in_proj then
      error("This template only works in trip-view-bff, trips-web, or mmbweb projects. Current path: " .. current_path)
    end

    local selected_flow = params.flow or "tw"
    local sel_command = params.command
    local base_command = "sh " .. vim.fn.expand "$HOME" .. "/Personal/mynotes/work/AgodaCoding/agodaSnip.sh " .. selected_flow
    local finalcmd = base_command .. " " .. (sel_command or "")
    -- __AUTO_GENERATED_PRINT_VAR_START__
    print([==[builder finalcmd:]==], vim.inspect(finalcmd)) -- __AUTO_GENERATED_PRINT_VAR_END__

    ---@type overseer.TaskDefinition
    return {
      cmd = finalcmd,
      -- behavior: https://deepwiki.com/search/is-this-correct_41cc0f33-a7dd-48fb-92e4-05ecb8826107?mode=fast
      -- does not really open auto why
      components = {
        { "open_output", direction = "float", on_start = "always" },
      },
    }
  end,
  --- @type overseer.Params|fun():overseer.Params
  params = function()
    return {
      flow = {
        type = "namedEnum",
        name = "flow",
        desc = "Choose tw (TripsWeb) or mmba (legacy MMB)",
        order = 1,
        choices = {
          TripsWeb = "tw",
          ["MMB Legacy"] = "mmba",
        },
        default = "tw",
        optional = false,
      },
      command = {
        -- /Users/tharutaipree/Personal/mynotes/work/AgodaCoding/agodaSnip.sh
        optional = true, -- will not prompt
        description = "Additional command line arguments for tw or mmba entry flow",
        choices = {
          "tvbff_sv_run",
          "tvbff_cs_run",
          "tvbff_cs_run build",
          "tvbff_check_all",
          "tw_checkall_choose",
          "mmb_entry -s -n", -- legacy default sv no build
          "mmb_entry -s",
          "mmb_entry -dev",
          "mmb_entry -ci",
          "mmb_entry -o",
          "mmb_entry",
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
  condition = {
    -- filetype = { "kotlin", "typescript" },
    -- Note: v2 removed condition callbacks - validation moved to builder
  },
}
