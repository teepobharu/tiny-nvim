-- Active references to this command:
-- - ~/.bash_aliases: vC alias opens `nvim -c WsDotfilesWorkspace`
-- - ~/.config/leader-key/config.json: Interactive > Dotfiles Workspace opens `nvim -c WsDotfilesWorkspace`
-- Keep those references in sync if this command is renamed.

require("utils.workspace.schema")

local function root()
  return vim.env.DOTFILES_DIR or "~/dotfiles"
end

---@type WorkspaceConfig
return {
  command = "WsDotfilesWorkspace",
  desc = "Open dotfiles workspace layout",
  root = root,
  tabs = {
    {
      name = "start",
      specs = {
        -- DO NOT REMOVE: dotfiles shell startup workspace.
        -- Alias: start. Focus: shell bootstrap files and primary AI docs entrypoint.
        { file = ".bash_exports" },
        { abs = "~/.bash.local" },
        { file = ".bash_aliases" },
        { file = "ai/AI-docs.md" },
        { file = ".bash_profile" },
      },
    },
    {
      name = "ai",
      specs = {
        -- DO NOT REMOVE: dotfiles AI/MCP operational workspace.
        -- Alias: ai. Focus: task scratchpad, MCP config/docs, repository README.
        -- Keep generated/internal docs out of commits.
        { file = "tasks/open" },
        { file = "ai/mcp/mcphub.json" },
        { file = "ai/mcp/MCP.md" },
        { file = "README.md" },
      },
    },
  },
}
