local workspace = require("utils.workspace")
local configs = require("utils.workspace.configs")

local M = {}

function M.setup()
  workspace.register(configs)
end

return M
