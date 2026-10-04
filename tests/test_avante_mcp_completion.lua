-- Real installed Avante completion + blink.compat, in a clean worktree namespace.
-- Catalog/sidebar are synthetic; no model requests, MCP execution or UI control.
local root = vim.env.NVIM_MCP_TEST_PLUGIN_ROOT or vim.fn.stdpath("data") .. "/lazy"
for _, name in ipairs({ "avante.nvim", "blink.compat", "blink.cmp" }) do vim.opt.rtp:append(root .. "/" .. name) end
local assertions = 0
local function check(value, message) assertions = assertions + 1; assert(value, message) end
local function eq(expected, actual, message) check(vim.deep_equal(expected, actual), message .. ": " .. vim.inspect(actual)) end
local catalog = {
  { server_name = "slack", name = "read_tool" }, { server_name = "slack", name = "search" },
  { server_name = "tavily", name = "search" }, { server_name = "version.1", name = "tool.name" },
}
package.loaded.mcphub = { get_hub_instance = function() return { get_tools = function() return catalog end } end }
local bridge = require "utils.avante_mcphub"
local builtin_calls = 0
local commands = bridge.build_commands(package.loaded.mcphub.get_hub_instance(), { { name = "custom" } }, {})
commands[#commands + 1] = { name = "custom", callback = function(_, _, done) builtin_calls = builtin_calls + 1; done() end }
package.loaded["avante.utils"] = { get_commands = function() return commands end }
package.loaded.cmp = { lsp = { CompletionItemKind = vim.lsp.protocol.CompletionItemKind } }
local buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_set_current_buf(buf)
vim.cmd "noautocmd setlocal filetype=AvanteInput"
vim.o.virtualedit = "onemore"
local sidebar = {
  containers = { input = { bufnr = buf, winid = vim.api.nvim_get_current_win() } },
  set_input_value = function() error("completion must never replace the whole input") end,
  submit_input = function() error("completion must never submit") end,
}
package.loaded.avante = { get = function() return sidebar end }
local upstream = require("cmp_avante.commands"):new()
require("blink.compat.registry").register_source("avante_commands", upstream)
local source = require("utils.avante_mcp_completion").new({}, { name = "avante_commands" })
local text_edits = require "blink.cmp.lib.text_edits"
require("blink.cmp.config").completion.accept.dot_repeat = false -- Headless test, no insert-mode key replay.
eq(true, source:enabled(), "existing source enabled in Avante input")
eq({ "/" }, source:get_trigger_characters(), "existing slash trigger retained")
local function content() return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n") end
local function set(lines, row, col)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_win_set_cursor(0, { row or #lines, col or #lines[#lines] })
end
local function context()
  local cursor = vim.api.nvim_win_get_cursor(0)
  return { id = 1, bufnr = buf, cursor = cursor,
    line = vim.api.nvim_buf_get_lines(buf, cursor[1] - 1, cursor[1], false)[1], trigger = { kind = "manual" } }
end
local function item_for(name)
  local result
  source:get_completions(context(), function(value) result = value end)
  check(result ~= nil, "completion returned a result")
  for _, item in ipairs(result.items) do
    if item.label == "/" .. name then item.cursor_column = context().cursor[2]; return item end
  end
end
local default_calls, callbacks, upstream_calls = 0, 0, 0
local execute = upstream.execute
upstream.execute = function(self, item, callback) upstream_calls = upstream_calls + 1; return execute(self, item, callback) end
local function accept(item)
  check(item ~= nil, "expected completion exists")
  source:execute(context(), item, function() callbacks = callbacks + 1 end, function()
    default_calls = default_calls + 1
    local edit = text_edits.get_from_item(item)
    local new_cursor = text_edits.get_apply_end_position(edit, {})
    text_edits.apply(edit, {})
    vim.api.nvim_win_set_cursor(0, new_cursor)
  end)
end

set({ "Find news with /ta and summarize it", "Keep this second line" }, 1, #"Find news with /ta")
accept(item_for("tavily"))
eq("Find news with @{tavily} and summarize it\nKeep this second line", content(), "middle-of-prompt insertion preserves both sides and other lines")
eq({ 1, #"Find news with @{tavily}" }, vim.api.nvim_win_get_cursor(0), "cursor follows the inserted reference")
local cursor = vim.api.nvim_win_get_cursor(0)
vim.api.nvim_buf_set_text(buf, 0, cursor[2], 0, cursor[2], { " /sl" })
vim.api.nvim_win_set_cursor(0, { 1, cursor[2] + #" /sl" })
accept(item_for("slack:read_tool"))
eq("Find news with @{tavily} @{slack:read_tool} and summarize it\nKeep this second line", content(), "second completion keeps the first selection")
eq(2, #bridge.selected_tools(package.loaded.mcphub.get_hub_instance(), content()), "mixed server/tool mentions select the union of schemas")
-- Typing immediately after completion must survive beyond upstream's 100ms cleanup delay.
cursor = vim.api.nvim_win_get_cursor(0)
vim.api.nvim_buf_set_text(buf, 0, cursor[2], 0, cursor[2], { " NOW" })
local expected = content()
vim.wait(150, function() return false end, 10)
eq(expected, content(), "new typing survives without a delayed buffer rewrite")
eq(0, upstream_calls, "MCP acceptance bypasses upstream command execution")
eq(2, callbacks, "each inline completion finalized once")

set({ "ค้นหา 🔎 /sl แล้วตอบ", "@{tavily} must remain" }, 1, #"ค้นหา 🔎 /sl")
accept(item_for("slack:search"))
eq("ค้นหา 🔎 @{slack:search} แล้วตอบ\n@{tavily} must remain", content(), "UTF-8 text and prior references are preserved")
set({ "/version.1:tool.name appears literally here", "Now use /ve" })
accept(item_for("version.1:tool.name"))
eq("/version.1:tool.name appears literally here\nNow use @{version.1:tool.name}", content(), "matching labels elsewhere are never globally removed")
set({ "/sl" })
accept(item_for("slack"))
eq("@{slack}", content(), "empty request gets only a reference, no placeholder")
set({ "Compare /slack:search, then continue" }, 1, #"Compare /slack:sea")
accept(item_for("slack:search"))
eq("Compare @{slack:search}, then continue", content(), "completion in the middle of a command replaces only that token")
set({ "Use @{slack:read_tool} again /sl" })
accept(item_for("slack:read_tool"))
eq("Use @{slack:read_tool} again @{slack:read_tool}", content(), "repeated references preserve original input")
eq(1, #bridge.selected_tools(package.loaded.mcphub.get_hub_instance(), content()), "repeated references attach only one schema")
set({ "Use /s" })
local prefetched = item_for("slack")
vim.api.nvim_buf_set_text(buf, 0, #"Use /s", 0, #"Use /s", { "l" })
vim.api.nvim_win_set_cursor(0, { 1, #"Use /sl" })
accept(prefetched)
eq("Use @{slack}", content(), "Blink compensates for typing after the completion list was fetched")

local warnings, old_notify = 0, vim.notify
vim.notify = function() warnings = warnings + 1 end
set({ "Keep /ta" })
local stale = item_for("tavily")
local saved_catalog, defaults_before = catalog, default_calls
catalog = {}
accept(stale)
eq("Keep /ta", content(), "stale selection leaves prompt intact")
eq(defaults_before, default_calls, "stale selection does not apply an edit")
eq(1, warnings, "stale selection warns")
catalog = saved_catalog
vim.notify = old_notify

-- The optional picker uses its own anchored edit, never the upstream delayed cleanup.
local old_select, pending = vim.ui.select, nil
vim.ui.select = function(_, _, callback) pending = callback end
set({ "Use @{tavily} /tools:pick:sl and keep this" }, 1, #"Use @{tavily} /tools:pick:sl")
accept(item_for("tools:pick:slack"))
check(pending ~= nil, "picker opens only on explicit picker selection")
vim.api.nvim_buf_set_text(buf, 0, 0, 0, 0, { "Prefix: " })
pending(catalog[1])
eq("Prefix: Use @{tavily} @{slack:read_tool} and keep this", content(), "picker anchor follows unrelated edits and preserves other mentions")
eq(0, upstream_calls, "picker bypasses upstream delayed cleanup too")
set({ "Cancel /tools:pick:sl and keep" }, 1, #"Cancel /tools:pick:sl")
accept(item_for("tools:pick:slack"))
expected = content()
pending(nil)
eq(expected, content(), "picker cancellation does not overwrite input")
eq({}, vim.api.nvim_buf_get_extmarks(buf, vim.api.nvim_create_namespace("AvanteMCPInlineInput"), 0, -1, {}), "picker anchors cleaned up")
set({ "Edit /tools:pick:sl and keep" }, 1, #"Edit /tools:pick:sl")
accept(item_for("tools:pick:slack"))
vim.api.nvim_buf_set_text(buf, 0, #"Edit /tools:pick:", 0, #"Edit /tools:pick:slack", { "CHANGED" })
expected = content()
pending(catalog[1])
eq(expected, content(), "picker does not overwrite a token edited while selecting")
vim.ui.select = old_select

-- Manually submitted commands restore arguments to Avante's already-cleared input.
set({ "" })
for _, command in ipairs(commands) do
  if command.name == "slack" then command.callback(sidebar, "Keep @{tavily} and the request"); break end
end
eq("@{slack} Keep @{tavily} and the request", content(), "manual slash arguments preserved without a placeholder")
set({ "https://example.test/sl" })
eq(nil, item_for("slack"), "no MCP completion inside a URL")
set({ "/custom" })
accept(item_for("custom"))
eq(1, builtin_calls, "non-MCP command retains its callback")
eq(1, upstream_calls, "non-MCP command delegates to original source")
vim.wait(150, function() return false end, 10)
print(("Avante inline MCP completion passed (%d assertions; real Avante + blink.compat + blink text edits)"):format(assertions))
