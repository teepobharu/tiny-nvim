local picker = require "utils.instruction_picker"

local function eq(expected, actual, label)
  assert(vim.deep_equal(expected, actual), ("%s: expected %s, got %s"):format(
    label,
    vim.inspect(expected),
    vim.inspect(actual)
  ))
end

local function write(path, lines)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  assert(vim.fn.writefile(lines, path) == 0, "failed to write " .. path)
end

local function by_suffix(entries, suffix)
  for _, entry in ipairs(entries) do
    if entry.path:sub(-#suffix) == suffix then
      return entry
    end
  end
end

local test_root = vim.fn.tempname()
local home = vim.fs.joinpath(test_root, "home")
local project = vim.fs.joinpath(test_root, "project")
vim.fn.mkdir(vim.fs.joinpath(project, ".git"), "p")

local global_agents = vim.fs.joinpath(home, ".codex", "AGENTS.md")
local global_skills = vim.fs.joinpath(home, ".agents", "skills")
local missing = vim.fs.joinpath(home, ".cursor", "rules")

local ok, err = pcall(function()
  write(global_agents, { "# Global Codex", "global body" })
  write(vim.fs.joinpath(global_skills, "demo", "SKILL.md"), { "---", "description: Demo skill", "---" })
  write(vim.fs.joinpath(global_skills, "demo", "notes.md"), { "not an instruction" })
  write(vim.fs.joinpath(project, "AGENTS.md"), { "# Project agents", "body" })
  write(vim.fs.joinpath(project, "tasks", "AGENTS.md"), { "# Task agents" })
  write(vim.fs.joinpath(project, "CLAUDE.md"), { "# Claude project" })
  write(vim.fs.joinpath(project, ".cursor", "rules", "shared.mdc"), { "# Cursor rule" })
  write(vim.fs.joinpath(project, ".agents", "skills", "local", "SKILL.md"), { "# Local skill" })
  write(vim.fs.joinpath(project, "node_modules", "pkg", "AGENTS.md"), { "# Must be skipped" })
  write(vim.fs.joinpath(project, "docs", "ordinary.md"), { "# Ordinary markdown" })

  local entries, report = picker.discover {
    home = home,
    project_root = project,
    include_vim_sources = false,
    sources = {
      {
        path = global_agents,
        agent = "codex",
        scope = "global",
        category = "instruction",
        label = "Codex global",
      },
      {
        path = global_agents,
        agent = "codex",
        scope = "global",
        category = "instruction",
      },
      { path = global_skills, agent = "all", scope = "global", category = "skill" },
      { path = missing, agent = "cursor", scope = "global", category = "rule" },
    },
  }

  eq(7, #entries, "catalog contains global and project instructions")
  eq(1, #report.missing, "missing configured path is reported")
  eq(false, report.truncated, "fixture scan is not truncated")

  local global = by_suffix(entries, "/.codex/AGENTS.md")
  eq("codex", global.agent, "configured agent column")
  eq("global", global.scope, "configured scope column")
  eq("instruction", global.category, "instruction category")
  eq("Global Codex", global.heading, "heading summary")
  eq(2, global.line_count, "line count")
  assert(global.text:find("Codex global", 1, true), "search text includes configured label")
  assert(global.text:find("~/.codex/AGENTS.md", 1, true), "search text includes display path")

  local skill = by_suffix(entries, "/.agents/skills/demo/SKILL.md")
  eq("skill", skill.category, "global skill category")
  eq("Demo skill", skill.heading, "skill description fallback")
  assert(not by_suffix(entries, "/.agents/skills/demo/notes.md"), "non-SKILL markdown is excluded")

  local project_agents = by_suffix(entries, "/tasks/AGENTS.md")
  eq("project", project_agents.scope, "project scope")
  eq("./tasks/AGENTS.md", project_agents.display_path, "project-relative display path")
  local cursor_rule = by_suffix(entries, "/.cursor/rules/shared.mdc")
  eq("cursor", cursor_rule.agent, "project rule agent inference")
  eq("rule", cursor_rule.category, "project rule category")
  assert(not by_suffix(entries, "/node_modules/pkg/AGENTS.md"), "dependency directory is skipped")
  assert(not by_suffix(entries, "/docs/ordinary.md"), "ordinary markdown is excluded")

  local content, read_err = picker.read_content(global_agents)
  assert(not read_err, "read content should not error")
  eq("# Global Codex\nglobal body", content, "copy-content source")
  local rejected, size_error = picker.read_content(global_agents, 1)
  eq(nil, rejected, "read limit rejects oversized content")
  assert(size_error:find("byte limit", 1, true), "read limit error explains rejection")

  local columns = picker.format_item(cursor_rule)
  eq(5, #columns, "row renderer column count")
  eq("[cursor] ", columns[1][1], "agent label has no fixed-width padding")
  eq("[p] ", columns[2][1], "project scope uses compact label")
  eq("[r] ", columns[3][1], "rule category uses compact label")
  assert(columns[4][1]:find("shared.mdc", 1, true), "path column is rendered")
  local global_columns = picker.format_item(global)
  eq("[g] ", global_columns[2][1], "global scope uses compact label")
  eq("[md] ", global_columns[3][1], "instruction category uses compact label")
  local skill_columns = picker.format_item(skill)
  eq("[sk] ", skill_columns[3][1], "skill category uses compact label")

  eq({ "all", "claude", "codex", "cursor" }, picker.agent_filters(entries), "agent filters are deterministic")
  eq("claude", picker.next_agent_filter(entries, "all"), "agent cycle leaves unfiltered view first")
  eq("codex", picker.next_agent_filter(entries, "claude"), "agent cycle advances alphabetically")
  local global_entries = picker.filter_entries(entries, "all", true)
  eq(2, #global_entries, "global filter excludes project rows")
  eq("global", global_entries[1].scope, "global filter only returns global rows")
  local codex_entries = picker.filter_entries(entries, "codex", false)
  assert(#codex_entries > 1, "agent filter retains shared all-agent rows")
  assert(picker.picker_title(entries, report, "all", true):find("global", 1, true), "title exposes global filter")

  eq("global", entries[1].scope, "global rows sort first")

  local original_snacks = _G.Snacks
  local original_read_content = picker.read_content
  local original_notify = vim.notify
  local original_setreg = vim.fn.setreg
  local observed_limit
  local action_ok, action_err = pcall(function()
    _G.Snacks = {
      picker = {
        pick = function(config)
          return config
        end,
        preview = { file = function() end },
      },
    }
    picker.read_content = function(_, limit)
      observed_limit = limit
      return "mock content"
    end
    vim.notify = function() end
    vim.fn.setreg = function() end

    local config = picker.open {
      home = home,
      project_root = false,
      include_vim_sources = false,
      max_file_bytes = 4096,
      sources = {
        { path = global_agents, agent = "codex", scope = "global", category = "instruction" },
      },
    }
    eq(1, #config.finder(config), "picker finder starts with all entries")
    assert(config.win.input.keys["<M-s>"], "agent-cycle key is registered")
    assert(config.win.input.keys["<M-g>"], "global-filter key is registered")
    local fake_picker = {
      opts = config,
      refresh = function(self)
        self.refreshed = (self.refreshed or 0) + 1
      end,
    }
    config.actions.instruction_cycle_agent(fake_picker)
    eq("codex", config.instruction_agent, "agent action cycles the picker state")
    config.actions.instruction_toggle_global(fake_picker)
    eq(true, config.instruction_global_only, "global action toggles the picker state")
    eq(2, fake_picker.refreshed, "filter actions refresh the open picker")
    config.actions.instruction_copy_content(nil, config.finder(config)[1])
    eq(4096, observed_limit, "copy action preserves configured read limit")
  end)
  _G.Snacks = original_snacks
  picker.read_content = original_read_content
  vim.notify = original_notify
  vim.fn.setreg = original_setreg
  assert(action_ok, action_err)
end)

vim.fn.delete(test_root, "rf")
assert(ok, err)
print "instruction picker tests: ok"
