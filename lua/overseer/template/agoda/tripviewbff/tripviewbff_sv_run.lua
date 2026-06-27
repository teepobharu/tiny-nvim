---@return overseer.TemplateDefinition
return {
  name = "Run Tripviewbff SV (nobuild)",
  tags = vim.tbl_extend("force", {
    require("overseer").TAG.BUILD,
    require("overseer").TAG.RUN,
    require("overseer").TAG.TEST,
    require("overseer").TAG.CLEAN,
  }, { "agoda", "custom" }),
  description = "Run TripView-BFF server via tw flow",
  builder = function(params)
    local current_path = vim.fn.expand "%:p:h"
    local is_in_proj = current_path:match "trip%-view%-bff"
      or current_path:match "trips%-web"
      or current_path:match "mmbweb"
    if not is_in_proj then
      error("This template only works in trip-view-bff, trips-web, or mmbweb projects. Current path: " .. current_path)
    end

    local sel_command = params.command
    local base_command = "sh " .. vim.fn.expand "$HOME" .. "/Personal/mynotes/work/AgodaCoding/agodaSnip.sh tw "
    local finalcmd = base_command .. sel_command

    ---@type overseer.TaskDefinition
    return {
      cmd = finalcmd,
      components = {
        { "open_output", direction = "float", on_start = "always" },
        "default",
      },
    }
  end,
  params = function()
    local choices = {
      ["Server run only"] = "tvbff_sv_run",
      ["Server run Development"] = "tvbff_sv_run Development",
    }

    return {
      command = {
        type = "namedEnum",
        name = "command",
        desc = "TripView-BFF server command",
        order = 1,
        choices = choices,
        default = choices["Server run only"],
        optional = false,
      },
    }
  end,
  components = {
    { "on_complete_notify", system = "always" },
    "default",
  },
  condition = {},
}
