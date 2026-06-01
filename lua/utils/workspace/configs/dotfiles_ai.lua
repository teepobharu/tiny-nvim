require("utils.workspace.schema")

local function root()
  return vim.env.DOTFILES_DIR or "~/dotfiles"
end

---@type WorkspaceConfig
return {
  command = "WsDotfilesAiWorkspace",
  desc = "Open AI agent configs from user and dotfiles scopes",
  root = root,
  tabs = {
    {
      name = "ai~",
      specs = {
        -- User-level agent configs only. Keep keybindings, RTK, docs, and instruction files out.
        { abs = "~/.claude/settings.json" },
        { abs = "~/.claude/settings.local.json" },
        { abs = "~/.claude/.claude.json" },
        { abs = "~/Library/Application Support/ClaudeCode/managed-settings.json" },
        { abs = "/Library/Application Support/ClaudeCode/managed-settings.json" },
        { abs = "~/.codex/config.toml" },
        { abs = "~/.codex/hooks.json" },
        { abs = "~/.codex/computer-use/config.json" },
        { abs = "~/.opencode/opencode.json" },
        { abs = "~/.opencode/opencode.jsonc" },
      },
    },
    {
      name = "ailoc",
      specs = {
        -- Dotfiles/repo-local agent configs only. Keep docs and instruction files out.
        { file = "ai/mcp/mcphub.json" },
        { file = ".mcphub/servers.json" },
        { file = "ai/claude/settings.json" },
        { file = "ai/claude/settings2.json", quickfix_only = true },
        { file = "ai/claude/settings_bak.json", quickfix_only = true },
        { file = "ai/claude/.mcp.json" },
        { file = "ai/claude/cc-agd/settings.json" },
        { file = "ai/claude/cc-agd/litellm-config.yaml" },
        { file = "ai/claude/tweakcc/config.json", quickfix_only = true },
        { file = ".claude/settings.json" },
        { file = ".claude/settings.local.json" },
        { file = ".codex/config.toml" },
        { file = "ai/codex/config.toml" },
        { file = ".opencode/opencode.jsonc" },
        { file = "ai/opencode/opencode.jsonc" },
        { file = ".config/opencode/opencode.jsonc" },
        { file = ".config/nvim3_jelly_tinynvim/opencode.jsonc", quickfix_only = true },
      },
    },
  },
}

