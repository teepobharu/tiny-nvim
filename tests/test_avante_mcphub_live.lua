-- Read-only attached-hub check. No model requests, tool execution, hub restart or config writes.
local url = assert(vim.env.MCP_HUB_SERVER_URL, "Set MCP_HUB_SERVER_URL to an already-running hub")
local plugin_root = vim.env.NVIM_MCP_TEST_PLUGIN_ROOT or vim.fn.stdpath("data") .. "/lazy"
for name, kind in vim.fs.dir(plugin_root) do
  if kind == "directory" then vim.opt.rtp:append(plugin_root .. "/" .. name) end
end

local api = require "mcphub"
api.setup({
  server_url = url, port = tonumber(url:match(":(%d+)$")) or 37373,
  use_bundled_binary = true, config = vim.fn.expand "~/dotfiles/ai/mcp/mcphub.json",
  workspace = { enabled = false }, auto_approve = false, auto_toggle_mcp_servers = false,
  extensions = {},
})
assert(vim.wait(10000, function()
  local hub = api.get_hub_instance()
  return hub and hub:is_ready()
end, 25), "attached hub did not become ready")
local hub = api.get_hub_instance()
hub.call_tool = function() error("this check must not execute tools") end
-- Hub readiness precedes the asynchronous server capability snapshot.
assert(vim.wait(10000, function()
  for _, tool in ipairs(hub:get_tools()) do if tool.server_name == "tavily" then return true end end
  return false
end, 25), "Tavily capabilities unavailable; check connection/policy filters")

local bridge = require "utils.avante_mcphub"
local opts = {}
bridge.extend_opts(opts)
local tools = opts.custom_tools()
local named = {}
for _, tool in ipairs(tools) do named[tool.name] = tool end
assert(#tools == 4 and named.use_mcp_tool and named.access_mcp_resource)
assert(named.mcphub_list_servers and named.mcphub_list_tools)

-- Validate the parameter conversion used by the installed OpenAI/Claude providers.
local convert = require("avante.utils").llm_tool_param_fields_to_json_schema
local properties, required = convert(named.mcphub_list_tools.param.fields)
assert(vim.deep_equal(required, { "server" }))
assert(properties.include_schema.type == "boolean" and properties.limit.type == "number")

local catalog = hub:get_tools()
assert(#catalog > 0, "no filtered connected tools")
local plain = bridge.catalog_prompt(hub, "use tavily search openai news")
assert(not plain:find('"inputSchema"', 1, true))
local server_text = named.mcphub_list_servers.func({ query = "tavily" })
local servers = vim.json.decode(server_text)
assert(#servers.items > 0, "Tavily is not connected; choose another metadata-only test server")
local server = servers.items[1].name
local concise_text = named.mcphub_list_tools.func({ server = server })
local concise = vim.json.decode(concise_text)
assert(#concise.items > 0 and concise.items[1].inputSchema == nil)
local tool_name = concise.items[1].name
local schema_text = named.mcphub_list_tools.func({ server = server, tool_name = tool_name, include_schema = true })
local one = vim.json.decode(schema_text)
assert(one.total == 1 and one.items[1].inputSchema)
assert(#bridge.selected_tools(hub, "@{" .. server .. ":" .. tool_name .. "}") == 1)
assert(#bridge.selected_tools(hub, "@{" .. server .. "}") == servers.items[1].tool_count)

local commands = bridge.build_commands(hub)
local sidebar = { set_input_value = function(self, input) self.input = input end }
for _, command in ipairs(commands) do
  if command.name == server then command.callback(sidebar, "Search OpenAI news"); break end
end
assert(sidebar.input == "@{" .. server .. "} Search OpenAI news")
local full = hub:get_active_servers_prompt(false, false)
print(vim.json.encode({
  check = "Avante MCP lean metadata passed", filteredToolCount = #catalog, dispatchAndDiscoveryCount = #tools,
  oldCatalogBytes = #full, initialMCPPromptBytes = #plain,
  selectedToolPromptBytes = #bridge.catalog_prompt(hub, "@{" .. server .. ":" .. tool_name .. "}"),
  selectedServerTools = one.total == 1 and servers.items[1].tool_count,
  modelRequestSent = false, mcpToolExecuted = false,
}))
-- Stops only this attached Neovim client's SSE connection; never stop_server().
hub:stop()
