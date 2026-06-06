local workspace = require("utils.workspace")
local configs = require("utils.workspace.configs")

local M = {}
local configs = require("utils.workspace.configs")

function M.setup()
  workspace.register(configs)
end

function M.pick_config()
  workspace.pick_config(configs)
end

return M
