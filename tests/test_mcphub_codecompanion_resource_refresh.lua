local script_path = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p")
local repo_root = vim.fs.dirname(vim.fs.dirname(script_path))
local mcphub_root = vim.env.MCPHUB_PLUGIN_ROOT
local codecompanion_root = vim.env.CODECOMPANION_PLUGIN_ROOT

assert(mcphub_root and mcphub_root ~= "", "MCPHUB_PLUGIN_ROOT must point to a patched mcphub.nvim checkout")
assert(
  codecompanion_root and codecompanion_root ~= "",
  "CODECOMPANION_PLUGIN_ROOT must point to a patched codecompanion.nvim checkout"
)

vim.opt.runtimepath:prepend(mcphub_root)
vim.opt.runtimepath:prepend(codecompanion_root)

local assertions = 0

local function check(condition, message)
  assertions = assertions + 1
  assert(condition, message)
end

local function has_label(items, label)
  return vim.iter(items):any(function(item)
    return item.label == label
  end)
end

-- CodeCompanion caches editor-context completion entries independently from
-- the shared config table. Verify the local API exposes an explicit reset.
local completion_config = {
  interactions = {
    shared = {
      editor_context = {
        baseline = { description = "Existing context" },
      },
    },
  },
}
package.loaded["codecompanion.config"] = completion_config
package.loaded["codecompanion.triggers"] = {
  mappings = {
    editor_context = "#",
    slash_commands = "/",
    tools = "@",
    acp_slash_commands = ">",
  },
}
package.loaded["codecompanion.interactions.chat.slash_commands.filter"] = { refresh_cache = function() end }
package.loaded["codecompanion.interactions.chat.tools.filter"] = { refresh_cache = function() end }
package.loaded["codecompanion.utils.buffers"] = { get_open = function() return {} end }
package.loaded["codecompanion.providers.completion"] = nil

local completion = require("codecompanion.providers.completion")
check(has_label(completion.editor_context("chat"), "#baseline"), "initial completion should include shared context")

completion_config.interactions.shared.editor_context["mcp:stale"] = { description = "MCP context" }
check(
  not has_label(completion.editor_context("chat"), "#mcp:stale"),
  "completion should stay cached until explicitly refreshed"
)
completion.refresh_editor_context_cache()
check(
  has_label(completion.editor_context("chat"), "#mcp:stale"),
  "completion refresh should expose the newly registered MCP context"
)

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

local shared_context = {
  custom = { description = "Keep this chat-specific context" },
  ["mcp:old"] = { description = "Remove this stale resource" },
}
local open_chat = {
  editor_context = {
    editor_context = {
      custom = shared_context.custom,
      ["mcp:old"] = shared_context["mcp:old"],
    },
  },
}
local completion_refreshes = 0
package.loaded["codecompanion.config"] = {
  interactions = {
    shared = {
      editor_context = shared_context,
    },
  },
}
package.loaded["codecompanion"] = {
  buf_get_chat = function()
    return { { chat = open_chat } }
  end,
}
package.loaded["codecompanion.providers.completion"] = {
  refresh_editor_context_cache = function()
    completion_refreshes = completion_refreshes + 1
  end,
}
package.loaded["mcphub.extensions.codecompanion.variables"] = nil

local variables = require("mcphub.extensions.codecompanion.variables")
variables.setup({ make_vars = true })
check(vim.wait(250, function() return #listeners == 1 and completion_refreshes == 1 end), "setup should register resources")
check(shared_context["mcp:old"] == nil, "shared context should remove stale MCP resources")
check(shared_context["mcp:resource://one"] ~= nil, "shared context should include the first resource")
check(open_chat.editor_context.editor_context.custom ~= nil, "open chat should preserve non-MCP context")
check(open_chat.editor_context.editor_context["mcp:old"] == nil, "open chat should remove stale MCP context")
check(
  open_chat.editor_context.editor_context["mcp:resource://one"] ~= nil,
  "open chat should receive the first registered resource"
)

resources = {
  {
    server_name = "fixture",
    uri = "resource://two",
    name = "Two",
    description = "Second fixture resource",
  },
}
listeners[1].callback()
check(vim.wait(250, function() return completion_refreshes == 2 end), "resource event should refresh completion state")
check(shared_context["mcp:resource://one"] == nil, "shared context should drop removed resources")
check(shared_context["mcp:resource://two"] ~= nil, "shared context should include the updated resource")
check(
  open_chat.editor_context.editor_context["mcp:resource://one"] == nil,
  "open chat should drop removed resource context"
)
check(
  open_chat.editor_context.editor_context["mcp:resource://two"] ~= nil,
  "open chat should receive refreshed resource context"
)
check(completion_refreshes == 2, "completion cache should refresh once per registration")

print(string.format("ok - mcphub CodeCompanion resource refresh (%d assertions)", assertions))
