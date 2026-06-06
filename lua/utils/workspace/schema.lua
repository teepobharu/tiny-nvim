---@class WorkspaceFileSpec
---@field file? string Exact file path relative to workspace root.
---@field abs? string Exact absolute or expandable file path.
---@field first? string[] First existing workspace-root relative file from this ordered candidate list.
---@field quickfix_only? boolean Include only in quickfix-only runs (`:Command!` or `:Command qf`).
---@field glob? string Vim glob pattern resolved by `vim.fn.glob()` from workspace root.
---@field grep? string Ripgrep file glob resolved by `rg --files --glob` from workspace root; file discovery, not content search.
---@field max_depth? integer Maximum directory depth for `grep`; glob fallback also filters by relative path depth.
---@field max? integer Maximum number of files to add for `glob` or `grep`.
---@field include_dirs? boolean Allow directories for `glob`; files only by default.

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
