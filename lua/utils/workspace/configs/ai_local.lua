require("utils.workspace.schema")

local function home()
  return vim.env.HOME or "~"
end

---@type WorkspaceConfig
return {
  command = "WsAiLocalWorkspace",
  desc = "Open user-level and local AI agent configs",
  root = home,
  tabs = {
    {
      name = "ai~",
      specs = {
        -- User-level agent configs only. Keep keybindings, RTK, docs, and instruction files out.
        { file = ".claude/settings.json" },
        { file = ".claude/settings.local.json" },
        { file = ".claude/.claude.json" },
        { file = "Library/Application Support/ClaudeCode/managed-settings.json" },
        { abs = "/Library/Application Support/ClaudeCode/managed-settings.json" },
        { file = ".codex/config.toml" },
        { file = ".codex/hooks.json" },
        { file = ".codex/computer-use/config.json" },
        { file = ".opencode/opencode.json" },
        { file = ".opencode/opencode.jsonc" },
      },
    },
    {
      name = "ailoc",
      specs = {
        -- Home-local nested agent configs only. Keep generated sessions/caches and docs out.
        { glob = ".claude/.claude*/settings*.json", max = 8 },
        { glob = ".claude/.claude*/.claude.json", max = 8 },
        { glob = ".codex/automations/*/automation.toml", max = 6, quickfix_only = true },
        { glob = ".opencode/*.{json,jsonc}", max = 8, quickfix_only = true },
      },
    },
  },
}
