---@class WorkspaceFileSpec
---@field file? string Project-root relative file path.
---@field abs? string Absolute or expandable file path.
---@field first? string[] First existing project-root relative file from this candidate list.
---@field quickfix_only? boolean Include only in quickfix-only runs (`:Command!` or `:Command qf`).
---@field max? integer Deprecated: only kept for old glob specs.
---@field glob? string Deprecated: avoid in workspace configs; prefer `file` or `first`.
---@field include_dirs? boolean Deprecated: only kept for old glob specs.

---@class WorkspaceTabConfig
---@field name string Short tab label shown by bufferline/custom tabline.
---@field cwd? string Optional tab-local cwd, project-root relative.
---@field specs WorkspaceFileSpec[] Files to open in this tab.

---@class WorkspaceConfig
---@field command string User command name.
---@field desc? string User command description.
---@field root string|fun():string Project root path or resolver.
---@field tabs WorkspaceTabConfig[] Tabs to open.

---@alias WorkspaceConfigList WorkspaceConfig[]

return {}
