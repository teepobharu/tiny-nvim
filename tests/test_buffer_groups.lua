vim.notify = function() end

local groups = require "utils.buffer_groups"

local function eq(expected, actual, label)
  assert(vim.deep_equal(expected, actual), ("%s: expected %s, got %s"):format(
    label,
    vim.inspect(expected),
    vim.inspect(actual)
  ))
end

local function classification(buftype, name, filetype)
  local rank, group = groups.classify_values(buftype, name, filetype)
  return { rank, group }
end

eq({ 1, "ai" }, classification("terminal", "term://shell//claude", ""), "Claude terminal is AI")
eq({ 1, "ai" }, classification("", "CodeCompanion", "codecompanion"), "CodeCompanion chat is AI")
eq({ 1, "ai" }, classification("terminal", "term://shell//sidekick", ""), "Sidekick terminal is AI")
eq({ 2, "term" }, classification("terminal", "term://shell//zsh", ""), "generic terminal")
eq({ 2, "term" }, classification("terminal", "term://shell//ssh-agent", ""), "bare agent word is not AI")
eq({ 3, "lazygit" }, classification("terminal", "term://shell//lazygit", ""), "LazyGit terminal")
eq(
  { 2, "term" },
  classification("terminal", "term:///Users/me/Documents/Codex//123:zsh", ""),
  "AI word in terminal cwd does not promote shell"
)
eq(
  { 3, "lazygit" },
  classification("terminal", "term:///Users/me/Documents/Claude//123:lazygit", ""),
  "AI word in terminal cwd does not promote LazyGit"
)
eq({ 4, "file" }, classification("", "/tmp/.claude/settings.lua", "lua"), "AI-named path remains file")
eq({ 5, "util" }, classification("quickfix", "quickfix", "qf"), "utility buffer")
eq("LG", groups.group_labels.lazygit, "LazyGit row label")

eq(true, groups.is_focused_values("terminal", "term://shell//zsh", "", 1), "focus mode 1 includes terminals")
eq(false, groups.is_focused_values("terminal", "term://shell//zsh", "", 2), "focus mode 2 excludes terminals")
eq(
  false,
  groups.is_focused_values("terminal", "term:///Users/me/Documents/Codex//123:zsh", "", 2),
  "focus mode 2 ignores AI words in terminal cwd"
)
eq(true, groups.is_focused_values("terminal", "term://shell//claude", "", 2), "focus mode 2 keeps AI terminals")
eq(true, groups.is_focused_values("", "CodeCompanion", "codecompanion", 2), "focus mode 2 keeps chats")
eq(false, groups.is_focused_values("", "/tmp/.claude/settings.lua", "lua", 1), "focus excludes ordinary files")

local items = {
  { id = "file", buf = 5, _group_rank = 4, info = { lastused = 100 } },
  { id = "codecompanion", buf = 2, _group_rank = 1, info = { lastused = 10 } },
  { id = "utility", buf = 6, _group_rank = 5, info = { lastused = 100 } },
  { id = "terminal", buf = 3, _group_rank = 2, info = { lastused = 100 } },
  { id = "claude", buf = 1, _group_rank = 1, info = { lastused = 90 } },
  { id = "lazygit", buf = 4, _group_rank = 3, info = { lastused = 100 } },
}
groups.sort_items(items)
eq(
  { "claude", "codecompanion", "terminal", "lazygit", "file", "utility" },
  vim.tbl_map(function(item)
    return item.id
  end, items),
  "group order with last-used ordering inside AI"
)

local old_snacks = rawget(_G, "Snacks")
_G.Snacks = {
  picker = {
    util = {
      text = function()
        return "buffer"
      end,
    },
  },
}
local grouped_sort_called = false
local lastused_sort_called = false
local original_sort_items = groups.sort_items
local original_sort_lastused = groups.sort_lastused
groups.sort_items = function(found)
  grouped_sort_called = true
  return original_sort_items(found)
end
groups.sort_lastused = function(found)
  lastused_sort_called = true
  return original_sort_lastused(found)
end
groups.finder({ hidden = true, nofile = true }, {
  filter = {
    filter = function(_, found)
      return found
    end,
  },
})
eq(true, grouped_sort_called, "finder groups by default")
eq(false, lastused_sort_called, "finder does not fall back to flat last-used sort")
groups.sort_items = original_sort_items
groups.sort_lastused = original_sort_lastused
_G.Snacks = old_snacks

local editor_keymaps = require "utils.editor_keymaps"
local buffers = editor_keymaps.sources_n_keys.sources.buffers
eq(true, buffers.group_by_kind, "resolved source enables grouped ordering")

local old_snacks_actions = package.loaded["utils.snacks_actions"]
package.loaded["utils.snacks_actions"] = {
  _get_picker_traversal_state = function(picker)
    return { "/tmp/buffer-groups/lua", "/tmp/buffer-groups" }, picker.opts._scope_step_index or 1
  end,
}

local refresh_count = 0
local picker = {
  title = "Buffers",
  opts = {
    group_by_kind = true,
    focus_hidden_mode = 0,
  },
  refresh = function()
    refresh_count = refresh_count + 1
  end,
}

buffers.actions.toggle_buffer_scope(picker)
eq("Buffers [/tmp/buffer-groups] (2/2) • grouped", picker.title, "scoped title")
eq("/tmp/buffer-groups", picker.opts._buffer_scope_cwd, "scoped cwd")

buffers.actions.toggle_buffer_scope(picker)
eq("Buffers • grouped", picker.title, "all-buffers title")
eq(nil, picker.opts._buffer_scope_cwd, "all-buffers scope clears")

picker.opts.focus_hidden_mode = 2
buffers.actions.toggle_buffer_scope(picker)
eq(
  "Buffers [/tmp/buffer-groups] (2/2) • grouped • agent chats",
  picker.title,
  "scope title preserves focused mode"
)
eq(3, refresh_count, "scope action refreshes exactly once per toggle")

picker.opts.focus_hidden_mode = 0
picker.opts.focus_hidden = false
picker.title = "Buffers • grouped"
buffers.actions.toggle_focused_hidden_buffers(picker)
eq("Buffers • grouped • hidden focus", picker.title, "focus cycle mode 1 title")
buffers.actions.toggle_focused_hidden_buffers(picker)
eq("Buffers • grouped • agent chats", picker.title, "focus cycle mode 2 title")
buffers.actions.toggle_focused_hidden_buffers(picker)
eq("Buffers • grouped", picker.title, "focus cycle reset title")
eq(6, refresh_count, "focus cycle refreshes once without accumulating title suffixes")

package.loaded["utils.snacks_actions"] = old_snacks_actions

print "buffer group tests: ok"
