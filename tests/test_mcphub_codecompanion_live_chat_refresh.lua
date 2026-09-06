local mcphub_root = vim.env.MCPHUB_PLUGIN_ROOT
local codecompanion_root = vim.env.CODECOMPANION_PLUGIN_ROOT

assert(mcphub_root and mcphub_root ~= "", "MCPHUB_PLUGIN_ROOT must point to a patched mcphub.nvim checkout")
assert(
  codecompanion_root and codecompanion_root ~= "",
  "CODECOMPANION_PLUGIN_ROOT must point to a patched codecompanion.nvim checkout"
)

vim.opt.runtimepath:prepend(mcphub_root)
vim.opt.runtimepath:prepend(codecompanion_root)
vim.notify = function() end

local adapter_utils = require("utils.my_codecompanion_utils")
local constants = require("utils.my_ai_constants")

local assertions = 0

local function check(condition, message)
  assertions = assertions + 1
  assert(condition, message)
end

local function has_label(items, label)
  for _, item in ipairs(items) do
    if item.label == label then
      return true
    end
  end
  return false
end

require("codecompanion").setup({
  adapters = { http = adapter_utils.get_agoda_adapters(false) },
  display = { chat = { show_settings = true } },
  interactions = { chat = { adapter = constants.providers.openai_agd.adapter_name } },
})

local chat = require("codecompanion").chat({
  params = { adapter = constants.providers.openai_agd.adapter_name, model = "gpt-5.4" },
})
check(chat and chat.editor_context, "real CodeCompanion chat should be created with editor context")

local completion = require("codecompanion.providers.completion")
local first_label = "#mcp:resource://one"
local second_label = "#mcp:resource://two"
check(not has_label(completion.editor_context("chat"), first_label), "completion cache starts without MCP resources")

chat.editor_context.editor_context.test_only = { description = "Preserve chat-local context" }

local resources = {
  {
    server_name = "fixture",
    uri = "resource://one",
    name = "One",
    description = "First fixture resource",
  },
}
local listeners = {}
local hub = {
  get_resources = function()
    return resources
  end,
  access_resource = function()
    return { text = "fixture resource" }
  end,
}
package.loaded["mcphub"] = {
  get_hub_instance = function()
    return hub
  end,
  on = function(events, callback)
    listeners[#listeners + 1] = { events = events, callback = callback }
  end,
}
package.loaded["mcphub.extensions.codecompanion.variables"] = nil

local variables = require("mcphub.extensions.codecompanion.variables")
variables.setup({ make_vars = true })
check(vim.wait(500, function() return #listeners == 1 end), "resource listeners should register")
check(
  vim.wait(500, function() return chat.editor_context.editor_context["mcp:resource://one"] ~= nil end),
  "initial MCP resource should reach the existing chat"
)
check(has_label(completion.editor_context("chat"), first_label), "completion should refresh after initial registration")
check(chat.editor_context.editor_context.test_only ~= nil, "existing non-MCP chat context should survive refresh")

resources = {
  {
    server_name = "fixture",
    uri = "resource://two",
    name = "Two",
    description = "Second fixture resource",
  },
}
listeners[1].callback()
check(
  vim.wait(500, function()
    return chat.editor_context.editor_context["mcp:resource://one"] == nil
      and chat.editor_context.editor_context["mcp:resource://two"] ~= nil
  end),
  "resource update should replace context in the already-open chat"
)
check(not has_label(completion.editor_context("chat"), first_label), "completion should drop removed MCP resource")
check(has_label(completion.editor_context("chat"), second_label), "completion should expose refreshed MCP resource")
check(chat.editor_context.editor_context.test_only ~= nil, "resource update should retain chat-local context")

vim.api.nvim_buf_delete(chat.bufnr, { force = true })
print(string.format("ok - mcphub CodeCompanion live chat refresh (%d assertions)", assertions))
