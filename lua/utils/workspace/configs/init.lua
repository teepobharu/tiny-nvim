require("utils.workspace.schema")

---@type WorkspaceConfigList
return {
  require("utils.workspace.configs.dotfiles"),
  require("utils.workspace.configs.dotfiles_ai"),
  require("utils.workspace.configs.ai_local"),
  require("utils.workspace.configs.trips_workspace"),
  require("utils.workspace.configs.trips_dependencies"),
}
