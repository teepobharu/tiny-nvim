-- Wrap the existing Avante blink.compat source, changing only our MCP selections.
-- Upstream command execution schedules a whole-input gsub after 100ms; references
-- must bypass it so a second completion or newer typing cannot be overwritten.
local Source = {}
Source.__index = Source

function Source.new(opts, config)
  return setmetatable({ delegate = require("blink.compat.source").new(opts, config) }, Source)
end

function Source:enabled() return self.delegate:enabled() end
function Source:get_trigger_characters() return self.delegate:get_trigger_characters() end

local function find_command(name)
  for _, command in ipairs(require("avante.utils").get_commands()) do
    if command.name == name then return command end
  end
end

function Source:get_completions(ctx, callback)
  return self.delegate:get_completions(ctx, function(result)
    if not result then return callback() end
    local before = ctx.line:sub(1, ctx.cursor[2])
    local start = before:find("/[^%s/]*$")
    local suffix = ctx.line:sub(ctx.cursor[2] + 1):match("^[%w_.:-]*") or ""
    local commands = {}
    for _, command in ipairs(require("avante.utils").get_commands()) do commands[command.name] = command end
    -- A mention starts at a token boundary, never inside a URL or an ordinary word.
    if start and (start == 1 or before:sub(start - 1, start - 1):match("%s")) then
      for _, item in ipairs(result.items or {}) do
        local command = commands[item.data and item.data.name]
        if command and command._mcphub_tool_command then
          local selection = command._mcphub_selection
          local reference = "@{" .. selection.server_name .. (selection.tool_name and ":" .. selection.tool_name or "") .. "}"
          item.data = vim.tbl_extend("force", item.data or {}, {
            mcphub_selection = vim.deepcopy(selection), mcphub_picker = command._mcphub_picker,
          })
          item.insertText = nil
          item.textEdit = {
            newText = command._mcphub_picker and item.label or reference,
            range = {
              start = { line = ctx.cursor[1] - 1, character = start - 1 },
              ["end"] = { line = ctx.cursor[1] - 1, character = ctx.cursor[2] + #suffix },
            },
          }
        end
      end
    else
      -- Do not expose our commands outside a valid slash-token completion context.
      result.items = vim.tbl_filter(function(item)
        local command = commands[item.data and item.data.name]
        return not (command and command._mcphub_tool_command)
      end, result.items or {})
    end
    callback(result)
  end)
end

function Source:resolve(item, callback)
  if item.data and item.data.mcphub_selection then return callback(item) end
  return self.delegate:resolve(item, callback)
end

function Source:execute(ctx, item, callback, default_implementation)
  local selection = item.data and item.data.mcphub_selection
  if not selection then return self.delegate:execute(ctx, item, callback, default_implementation) end
  if not require("utils.avante_mcphub").selection_available(selection) then
    vim.notify("MCP selection is no longer available: " .. selection.server_name, vim.log.levels.WARN)
    return callback()
  end
  if item.data.mcphub_picker then
    local command = find_command(item.data.name)
    local avante = package.loaded.avante
    local sidebar = avante and avante.get and avante.get(false)
    if not command or not sidebar then return callback() end
    default_implementation()
    return command.callback(sidebar, nil, callback)
  end
  -- Blink applies just the supplied range and places the cursor after the reference.
  default_implementation()
  callback()
end

return Source
