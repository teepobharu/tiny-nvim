-- CodeCompanion plugin spec (extracted from myAi.lua)
-- Loaded as a separate extra plugin entry in enable_extra_plugins.
-- All upvalues re-declared here to keep this file self-contained.

local AI_CFG = require "utils.my_ai_default_config"
local AI_CONST = require "utils.my_ai_constants"

local DEFAULT_ADAPTER = AI_CFG.DEFAULT_ADAPTER
local DEFAULT_MODEL = AI_CFG.preferred_model()
local FAST_MODEL = AI_CFG.fast_model()
local ENABLE_COPILOT = AI_CFG.ENABLE_COPILOT

-- Enable per-chat yolo mode (auto-approve all tool calls) via v19 approvals API
local function enable_yolo_on_created(chat)
  require("codecompanion.interactions.chat.tools.approvals"):toggle_yolo_mode(chat.bufnr)
end

local function focus_codecompanion_chat()
  local codecompanion = require "codecompanion"
  local chat = codecompanion.last_chat()

  if chat and chat.bufnr then
    codecompanion.restore(chat.bufnr)
    return
  end

  codecompanion.chat()
end

local function run_codecompanion_slash_picker(name)
  local chat_api = require "codecompanion.interactions.chat"
  local codecompanion = require "codecompanion"
  local chat = chat_api.buf_get_chat(vim.api.nvim_get_current_buf()) or codecompanion.last_chat()
  if not chat then
    chat = codecompanion.chat()
  end
  if not chat then
    vim.notify("CodeCompanion: no chat buffer found", vim.log.levels.WARN)
    return
  end

  if chat.ui and not chat.ui:is_visible() then
    chat.ui:open()
  end

  local config = require "codecompanion.config"
  local slash_config = config.interactions.chat.slash_commands[name]
  if not slash_config then
    vim.notify(("CodeCompanion: slash command not found: %s"):format(name), vim.log.levels.WARN)
    return
  end

  local ok, slash_command = pcall(require, "codecompanion.interactions.chat.slash_commands.builtin." .. name)
  if not ok then
    vim.notify(("CodeCompanion: failed to load /%s picker"):format(name), vim.log.levels.ERROR)
    return
  end

  slash_command
    .new({
      Chat = chat,
      config = slash_config,
    })
    :execute(require("codecompanion.interactions.chat.slash_commands").new())
end

local function json_text(value)
  local ok, encoded = pcall(vim.json.encode, value)
  return ok and encoded or vim.inspect(value)
end

local function build_mcphub_lean_group()
  local function list_servers_handler(self, action, cmd_opts)
    local hub = require("mcphub").get_hub_instance()
    if not hub or not hub.is_ready or not hub:is_ready() then
      cmd_opts.output_cb({ status = "error", data = "MCP Hub is not ready yet" })
      return
    end

    local include_disabled = action and action.include_disabled == true
    local items = {}
    for _, server in ipairs(hub:get_servers(include_disabled)) do
      local tools = (server.capabilities and server.capabilities.tools) or {}
      local readonly = 0
      for _, tool in ipairs(tools) do
        if tool.annotations and tool.annotations.readOnlyHint == true then
          readonly = readonly + 1
        end
      end
      table.insert(items, {
        name = server.name,
        description = server.description or "",
        status = server.status,
        disabled = server.disabled == true,
        tool_count = #tools,
        readonly_count = readonly,
      })
    end

    cmd_opts.output_cb({
      status = "success",
      data = { text = json_text(items) },
    })
  end

  local function list_tools_handler(self, action, cmd_opts)
    local hub = require("mcphub").get_hub_instance()
    if not hub or not hub.is_ready or not hub:is_ready() then
      cmd_opts.output_cb({ status = "error", data = "MCP Hub is not ready yet" })
      return
    end

    local server_name = action and action.server
    if not server_name or server_name == "" then
      cmd_opts.output_cb({ status = "error", data = "Missing required argument: server" })
      return
    end

    local server = hub:get_server(server_name)
    if not server or server.status ~= "connected" or server.disabled then
      cmd_opts.output_cb({ status = "success", data = { text = "[]" } })
      return
    end

    local tools = (server.capabilities and server.capabilities.tools) or {}
    local name_filter = vim.trim((action and action.filter) or ""):lower()
    local desc_filter = vim.trim((action and action.filter_description) or ""):lower()
    local any_filter = vim.trim((action and action.filter_any) or ""):lower()
    local readonly_only = action and action.readonly_only == true
    local include_schema = action and action.include_schema == true
    local items = {}

    for _, tool in ipairs(tools) do
      local name = (tool.name or "")
      local desc = (tool.description or "")
      local lname = name:lower()
      local ldesc = desc:lower()
      local readonly = tool.annotations and tool.annotations.readOnlyHint == true

      if (name_filter == "" or lname:find(name_filter, 1, true))
        and (desc_filter == "" or ldesc:find(desc_filter, 1, true))
        and (any_filter == "" or lname:find(any_filter, 1, true) or ldesc:find(any_filter, 1, true))
        and (not readonly_only or readonly)
      then
        local item = {
          name = name,
          description = desc,
          readonly = readonly,
        }
        if include_schema then
          item.inputSchema = tool.inputSchema or { type = "object" }
        end
        table.insert(items, item)
      end
    end

    cmd_opts.output_cb({
      status = "success",
      data = { text = json_text(items) },
    })
  end

  local function call_tool_handler(self, action, cmd_opts)
    local core = require "mcphub.extensions.codecompanion.core"
    local params = {
      server_name = action and action.server,
      tool_name = action and action.tool,
      tool_input = (action and action.arguments) or {},
    }
    core.execute_mcp_tool(params, self, cmd_opts.output_cb, {
      tool_display_name = "mcphub_call_tool",
      is_individual_tool = false,
      action = "use_mcp_tool",
    })
  end

  return {
    groups = {
      mcp_lean = {
        description = " Context-light MCPHub lean proxy tools: list servers, inspect a server's tools, and call a selected tool.",
        hide_in_help_window = false,
        tools = {
          "mcphub_list_servers",
          "mcphub_list_tools",
          "mcphub_call_tool",
        },
        opts = {
          collapse_tools = true,
        },
      },
    },
    mcphub_list_servers = {
      description = "List MCPHub servers available through the lean proxy",
      hide_in_help_window = true,
      visible = false,
      callback = function()
        return {
          name = "mcphub_list_servers",
          cmds = { list_servers_handler },
          output = require("mcphub.extensions.codecompanion.core").create_output_handlers(
            "mcphub_list_servers",
            true,
            { show_result_in_chat = true }
          ),
          schema = {
            type = "function",
            ["function"] = {
              name = "mcphub_list_servers",
              description = "List connected MCP servers visible to the lean proxy.",
              parameters = {
                type = "object",
                properties = {
                  include_disabled = {
                    type = "boolean",
                    description = "Include disabled/disconnected servers.",
                  },
                },
              },
            },
          },
        }
      end,
    },
    mcphub_list_tools = {
      description = "List tools for one server through the lean proxy",
      hide_in_help_window = true,
      visible = false,
      callback = function()
        return {
          name = "mcphub_list_tools",
          cmds = { list_tools_handler },
          output = require("mcphub.extensions.codecompanion.core").create_output_handlers(
            "mcphub_list_tools",
            true,
            { show_result_in_chat = true }
          ),
          schema = {
            type = "function",
            ["function"] = {
              name = "mcphub_list_tools",
              description = "List tools for a specific MCP server, with optional filtering.",
              parameters = {
                type = "object",
                properties = {
                  server = { type = "string", description = "Server name." },
                  filter = { type = "string", description = "Match tool name." },
                  filter_description = { type = "string", description = "Match description only." },
                  filter_any = { type = "string", description = "Match name or description." },
                  readonly_only = { type = "boolean", description = "Only readonly tools." },
                  include_schema = { type = "boolean", description = "Include inputSchema in output." },
                },
                required = { "server" },
              },
            },
          },
        }
      end,
    },
    mcphub_call_tool = {
      description = "Call a selected MCP server tool through the lean proxy",
      hide_in_help_window = true,
      visible = false,
      callback = function()
        return {
          name = "mcphub_call_tool",
          cmds = { call_tool_handler },
          output = require("mcphub.extensions.codecompanion.core").create_output_handlers(
            "mcphub_call_tool",
            true,
            { show_result_in_chat = true }
          ),
          schema = {
            type = "function",
            ["function"] = {
              name = "mcphub_call_tool",
              description = "Execute one tool on a chosen MCP server.",
              parameters = {
                type = "object",
                properties = {
                  server = { type = "string", description = "Server name." },
                  tool = { type = "string", description = "Tool name from mcphub_list_tools." },
                  arguments = { type = "object", description = "Tool input arguments." },
                },
                required = { "server", "tool" },
              },
            },
          },
        }
      end,
    },
  }
end

-- Import AI prompts from centralized location
local ai_prompts = require "utils.my_ai_prompts"
local EMPTY_PROMPT_CCOMP = ai_prompts.EMPTY_PROMPT_CODECOMPANION
local CODE_REVIEW_INSTRUCTIONS = ai_prompts.CODE_REVIEW_INSTRUCTIONS

-- Generated prompt_library entries from top_choices (AGD + Copilot)
local prompt_lib_gen = require("utils.my_codecompanion_prompt_library").build(EMPTY_PROMPT_CCOMP, {
  enabled_providers = { openai_agd = true, copilot = ENABLE_COPILOT },
})
-- Jellydn base prompts (migrated from codecompanion.lua with v19 fields)
local jellydn_prompts = require("utils.my_codecompanion_prompt_library").build_jellydn_prompts()


return {
  -- use for codecompanion
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "yaml", "markdown" } },
  },
  {
    "olimorris/codecompanion.nvim",
    version = "19.17.x", -- exact pin: v19.13.0 / 9d985b1cc4e650a676a977ab1f9ed50dc6d0f4d8
    dependencies = {
      -- "ibhagwan/fzf-lua", -- For fzf provider, file or buffer picker
      -- "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      -- MCPHub integration for MCP tools/resources access
      { "ravitemer/mcphub.nvim", optional = true },
      "jellydn/spinner.nvim", -- Show loading spinner when request is started
      -- Chat history persistence — save/restore sessions to disk
      { "ravitemer/codecompanion-history.nvim" },
    },
    config = function(_, options)
      require("codecompanion").setup(options)
      require("utils.my_codecompanion_inline_debug_demo").setup()
      require("utils.my_codecompanion_thinking").setup()

      local hooks_group = vim.api.nvim_create_augroup("CodeCompanionHooks", {})

      -- Show loading spinner when request is started (from jellydn/tiny-nvim)
      local ok, spinner = pcall(require, "spinner")
      if ok then
        vim.api.nvim_create_autocmd({ "User" }, {
          pattern = "CodeCompanionRequest*",
          group = hooks_group,
          callback = function(request)
            if request.match == "CodeCompanionRequestStarted" then
              spinner.show()
            end
            if request.match == "CodeCompanionRequestFinished" then
              spinner.hide()
            end
          end,
        })
      end

      -- Filter out empty-content messages before submit to avoid
      -- litellm/Vertex AI BadRequestError: "text content blocks must be non-empty"
      -- Uses on_submitted (not on_before_submit) because the blank message is added
      -- AFTER on_before_submit fires (chat/init.lua:1185) but BEFORE _submit_http (line 1226).
      -- on_submitted fires at line 1223 with the payload table, and since payload is passed
      -- by reference to _submit_http, mutating payload.messages here takes effect.
      vim.api.nvim_create_autocmd("User", {
        pattern = "CodeCompanionChatCreated",
        group = hooks_group,
        callback = function(event)
          local chat = require("codecompanion.interactions.chat").buf_get_chat(event.data.bufnr)
          if not chat then
            return
          end
          chat:add_callback("on_submitted", function(_, args)
            if args and args.payload and args.payload.messages then
              -- Filter 1: Remove empty-content messages to avoid
              -- litellm BadRequestError: "text content blocks must be non-empty"
              args.payload.messages = vim.tbl_filter(function(m)
                return not (type(m.content) == "string" and vim.trim(m.content) == "")
              end, args.payload.messages)

              -- Filter 2: Remove orphaned tool_use messages.
              -- At on_submitted time, messages use the INTERNAL format (pre-form_messages):
              --   assistant tool call: { role = "assistant", tools = { calls = [{id, ...}, ...] } }
              --   tool result:         { role = "tool", tools = { call_id = "tooluse_xxx" } }
              -- NOT the OpenAI wire format (tool_calls / tool_call_id) — form_messages converts later.
              -- This prevents Vertex AI / Anthropic BadRequestError:
              -- "`tool_use` ids were found without `tool_result` blocks immediately after"
              -- which happens when the user sends a new message while tool calls are pending.
              local msgs = args.payload.messages
              local clean = {}
              local i = 1
              while i <= #msgs do
                local m = msgs[i]
                local calls = m.tools and m.tools.calls
                local has_tool_calls = calls and #calls > 0
                if has_tool_calls then
                  -- Collect the set of expected tool_call ids
                  local expected_ids = {}
                  for _, tc in ipairs(calls) do
                    if tc.id then
                      expected_ids[tc.id] = true
                    end
                  end
                  -- Look ahead: all following tool-result messages must cover each call_id.
                  -- Tool results are consecutive messages with role="tool" and tools.call_id set.
                  local j = i + 1
                  while msgs[j] and msgs[j].role == "tool" and msgs[j].tools and msgs[j].tools.call_id do
                    expected_ids[msgs[j].tools.call_id] = nil
                    j = j + 1
                  end
                  local all_resolved = vim.tbl_isempty(expected_ids)
                  if not all_resolved then
                    -- Orphaned tool_use: skip this assistant message AND any partial tool results
                    i = j
                  else
                    -- All tool calls are resolved: keep the assistant message and its results
                    for k = i, j - 1 do
                      table.insert(clean, msgs[k])
                    end
                    i = j
                  end
                else
                  table.insert(clean, m)
                  i = i + 1
                end
              end
              args.payload.messages = clean

              -- Filter 3: Some OpenAI-compatible/LiteLLM backends reject
              -- system messages unless they are at the beginning. Tool context
              -- such as <tool>memory</tool> can append hidden system prompts
              -- after prior user/assistant messages.
              local system_messages = {}
              local non_system_messages = {}

              for _, msg in ipairs(args.payload.messages) do
                if msg.role == "system" then
                  if type(msg.content) == "string" and vim.trim(msg.content) ~= "" then
                    table.insert(system_messages, msg.content)
                  end
                else
                  table.insert(non_system_messages, msg)
                end
              end

              if #system_messages > 0 then
                table.insert(non_system_messages, 1, {
                  role = "system",
                  content = table.concat(system_messages, "\n\n"),
                })
              end

              args.payload.messages = non_system_messages
            end
          end)
        end,
      })
    end,
    keys = vim.list_extend(require("utils.editor_keymaps").keymaps.codecompanion(), {
      -- Replaces former <leader>Av: focus existing chat or open a new one
      {
        (vim.g.ai_prefix_key or "<leader>A") .. "V",
        focus_codecompanion_chat,
        desc = "Code Companion - Focus Chat",
        mode = { "n" },
      },
    }),
    -- NOTE: llama3_2 and llama3latest ollama adapters were removed — they were
    -- at the plugin spec level (not inside opts) so Lazy.nvim ignored them.
    -- To re-enable, move into opts.adapters.http below.
    opts = {
      log_level = "DEBUG", -- TRACE|DEBUG|ERROR|INFO not work
      -- see logs in ~/.local/state/nvim/codecompanion.log -- not sure why not see
      --
      -- [WARN] above not help disable textmsg: CodeCompanion.nvim will experience breaking changes soon. Pin to version v17.33.0 or earlier to avoid this.
      -- https://codecompanion.olimorris.dev/configuration/chat-buffer
      -- require("codecompanion").setup({
      --       interactions = {
      --         chat = {
      --           adapter = "anthropic",
      --           model = "claude-sonnet-4-20250514"
      --         },
      --       },
      --       opts = {
      --         log_level = "DEBUG",
      --       },
      --- @type CodeCompanion.Interactions_NOTWORK
      --     }
      interactions = {
        chat = {
          -- Reasoning effort: use <leader>At / :CodeCompanionThinking, or edit /debug.
          -- openai_agd maps `reasoning_effort`; openai_responses_agd maps `reasoning.effort`.
          -- Both fields are optional/free-form and capability metadata is advisory only.
          -- For ACP (codex/claude_code) adapters: use /acp_session_options slash command instead.
          adapter = DEFAULT_ADAPTER,
          model = DEFAULT_MODEL,
          opts = {
            system_prompt = require("utils.my_ai_prompts").COPILOT_SYSTEM_PROMPT,
          },
          -- adapter = {
          -- dont know why override model in interaction not work need replace in adpaters schema
          -- https://codecompanion.olimorris.dev/configuration/adapters-http#changing-the-default-model
          -- model default here not working ?
          -- name = DEFAULT_ADAPTER,
          -- model = "grok-code-fast-1",
          -- model = "gpt-5-mini",
          -- model = require("utils.my_ai_constants").DEFAULT_COPILOT_MODEL or "gpt-5-mini",
          -- model = require("utils.my_ai_constants").DEFAULT_COPILOT_MODEL or "gpt-5-mini",
          -- },
          roles = { llm = "  Copilot Chat", user = "☀️ Brightza" },
          slash_commands = {
            ["buffer"] = { opts = { provider = "snacks" } },
            ["file"] = { opts = { provider = "snacks" } },
            ["fetch"] = { opts = { provider = "snacks" } },
            ["help"] = { opts = { provider = "snacks" } },
            ["image"] = { opts = { provider = "snacks" } },
            ["symbols"] = { opts = { provider = "snacks" } },
          },
          tools = build_mcphub_lean_group(),
          -- Chat buffer keymaps (from jellydn/tiny-nvim codecompanion.lua)
          -- Custom insert-mode pickers — <M-b>/<M-f> to avoid blink.cmp <C-b>/<C-f> scroll-docs conflict
          keymaps = {
            send = {
              modes = { n = "<CR>", i = "<C-CR>" },
              index = 1,
              callback = "keymaps.send",
              description = "Send",
            },
            close = {
              modes = { n = "q" },
              index = 3,
              callback = "keymaps.close",
              description = "Close Chat",
            },
            stop = {
              modes = { n = "<C-c>" },
              index = 4,
              callback = "keymaps.stop",
              description = "Stop Request",
            },
            clear = {
              modes = { n = "<C-x>" },
              index = 6,
              callback = "keymaps.clear",
              description = "[Chat] Clear",

            },
            thinking_picker = {
              modes = { n = (vim.g.ai_prefix_key or "<leader>A") .. "t" },
              index = 7,
              callback = function(chat)
                require("utils.my_codecompanion_thinking").pick(chat)
              end,
              description = "Thinking level",
            },
            buffer_picker = {
              modes = { i = "<C-b>" },
              index = 8,
              callback = function()
                pcall(vim.cmd, "stopinsert")
                run_codecompanion_slash_picker "buffer"
              end,
              description = "Attach buffer",
            },
            file_picker = {
              modes = { i = "<C-f>" },
              index = 9,
              callback = function()
                pcall(vim.cmd, "stopinsert")
                run_codecompanion_slash_picker "file"
              end,
              description = "Attach file",
            },
          },
        },
        -- Or, just specify the adapter by name
        inline = {
          adapter = DEFAULT_ADAPTER,
        },
        cmd = {
          adapter = DEFAULT_ADAPTER,
        },
        background = {
          adapter = DEFAULT_ADAPTER,
        },
      },
      adapters = {
        http = vim.tbl_deep_extend(
          "force",
          {
            opts = {
              cache_models_for = 5000, -- local cached inside var - def 1800 (30m)
              show_model_choices = true, -- show model picker in ga (change_adapter) flow
            },
          },
          require("utils.my_codecompanion_utils").merge_agoda_responses_adapters(
          require("utils.my_codecompanion_utils").merge_agoda_adapters(vim.tbl_extend(
            "force",
            ENABLE_COPILOT and {
              copilot = function()
                return require("codecompanion.adapters").extend("copilot", {
                  schema = {
                    model = {
                      default = AI_CONST.DEFAULT_COPILOT_MODEL,
                      -- choices -> currently no temperature opts check for 5mini
                      -- /Users/tharutaipree/.local/share/nvim3_jelly_tinynvim/lazy/codecompanion.nvim/lua/codecompanion/adapters/http/copilot/init.lua:334:27
                    },
                    -- temperature = { -- see tasks/open/investigate-codecompanion-adapter-switching.md:85:1
                  },
                })
              end,
            } or {},
            {}
          ))
        )
        ),
        acp = { -- codex and claude_code works without extra settings just make sure acp cli is installed
          -- claude_code = function()
          --   return require("codecompanion.adapters").extend("claude_code", {
          --     env = { -- seems like not required
          --       -- CLAUDE_CODE_USE_BEDROCK = "1",
          --       -- CLAUDE_CODE_SKIP_BEDROCK_AUTH = "1",
          --       -- ANTHROPIC_BEDROCK_BASE_URL = "https://genai-gateway.agoda.is/claude",
          --       -- CLAUDE_CODE_OAUTH_TOKEN = os.getenv("ANTHROPIC_AUTH_TOKEN"),
          --       -- ANTHROPIC_AUTH_TOKEN = os.getenv("ANTHROPIC_AUTH_TOKEN"),
          --     },
          --   })
          -- end,
        },
      },
      display = {
        chat = {
          -- show_settings = true, -- ! cant change model on the fly ! - Renders a YAML settings block at top of chat buffer (edit to change effort/params) instead of going through gd debug context
        },
        action_palette = {
          provider = "snacks",
        },
      },
      extensions = {
        history = {
          enabled = true,
          opts = {
            keymap = "gh",
            save_chat_keymap = "sc",
            auto_save = true,
            expiration_days = 30,
            picker = "snacks",
            auto_generate_title = true,
            continue_last_chat = false,
            delete_on_clearing_chat = false,
            title_generation_opts = {
              ---Adapter for generating titles (defaults to current chat adapter)
              adapter = DEFAULT_ADAPTER, -- nil to use current chat adapter
              model = AI_CONST.static_models.fast[1],
              -- model = AI_CONST.providers.openai_agd.top_choices.gpt.default.S
              -- "gpt-4.1", -- nil to use current chat Error: {"error":{"message":"model gpt-4.1 is not supported via Responses API.","code":"unsupported_api_for_model"}}
              ---Number of user prompts after which to refresh the title (0 to disable)
              refresh_every_n_prompts = 0, -- e.g., 3 to refresh after every 3rd user prompt
              max_refreshes = 1,
            },
            -- TODO: memory opts  require vector search
            dir_to_save = vim.fn.stdpath "data" .. "/codecompanion-history",
          },
        },
        mcphub = {
          callback = "mcphub.extensions.codecompanion",
          opts = {
            -- MCP Tools
            make_tools = true, -- Make individual tools (@server__tool) and server groups (@server) from MCP servers
            show_server_tools_in_chat = true, -- Show individual tools in chat completion (when make_tools=true)
            add_mcp_prefix_to_tool_names = false, -- Add mcp__ prefix (e.g `@mcp__github`, `@mcp__neovim__list_issues`)
            show_result_in_chat = true, -- Show tool results directly in chat buffer
            format_tool = nil, -- function(tool_name:string, tool: CodeCompanion.Agent.Tool) : string Function to format tool names to show in the chat buffer
            -- MCP Resources
            make_vars = true, -- Convert MCP resources to #variables for prompts
            -- MCP Prompts
            make_slash_commands = true, -- Add MCP prompts as /slash commands
          },
        },
      },
      prompt_library = vim.tbl_extend("keep", {
        markdown = {
          dirs = {
            vim.fn.expand("~/Personal/mynotes/Extras/Template/copilot-custom-prompts/codecompanion"),
          },
        },
        -- https://deepwiki.com/search/check-the-settting-from-prompt_65b9cc4c-5ada-41a8-8b0d-49142cfdef65?mode=deep
        -- will work only when open new chat with the action cmd else not change model while there is prompt
        -- NOTE: AGD + Copilot model entries are auto-generated by utils/my_codecompanion_prompt_library.lua
        -- from my_ai_constants.providers[*].top_choices (per-family tiered structure)
        --
        -- Known caveat: older Claude/Opus deployments may reject non-default
        -- temperature + top_p together. Current AGD Sonnet 5 accepts both.
        ["Codecompanion Context"] = {
          interaction = "chat", -- ✅ Fixed: strategy → interaction
          description = "Write documentation for me",
          opts = {
            index = 11,
            adapter = DEFAULT_ADAPTER,
            is_slash_cmd = true,
            auto_submit = false,
            alias = "codecompanion_nvim_context", -- ✅ Fixed: short_name → alias
            stop_context_insertion = true,
            callbacks = { on_created = enable_yolo_on_created },
          },
          context = {
            {
              type = "file",
              path = {
                -- expand HOME
                vim.fn.expand "$HOME/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/extra/myAi.lua",
              },
            },
            {
              type = "url",
              url = "https://codecompanion.olimorris.dev/configuration/prompt-library",
            },
          },
          prompts = {
            {
              role = "user",
              content = [[### Instructions
Your instructions here

### Steps to Follow

      You are required to write code with correct usage of the lua settings provided by the documentation
      1. Update the code in #buffer{watch} using the @editor tool
      2. Make sure you trigger both tools in the same response Specification
      3. Follow the given documentation
      ]],
            },
          },
        },
        ["Snacks Nvim Context"] = {
          interaction = "chat", -- ✅ Fixed: strategy → interaction
          description = "Write documentation for me",
          opts = {
            index = 11,
            adapter = DEFAULT_ADAPTER,
            is_slash_cmd = true,
            auto_submit = false,
            alias = "snacks_nvim_context", -- ✅ Fixed: short_name → alias
            stop_context_insertion = true,
            callbacks = { on_created = enable_yolo_on_created },
          },
          context = {
            {
              type = "file",
              path = {
                -- expand HOME
                vim.fn.expand "$HOME/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/extra/myAi.lua",
              },
            },
            {
              type = "url",
              url = "https://github.com/folke/snacks.nvim/blob/main/docs/picker.md",
            },
            {
              type = "url",
              url = "https://www.reddit.com/r/neovim/comments/1hhmoxm/comment/m2w1utu/?utm_source=share&utm_medium=web3x&utm_name=web3xcss&utm_term=1&utm_content=share_button",
            },
          },
          prompts = {
            {
              role = "user",
              content = [[### Instructions
Your instructions here

### Steps to Follow

      You are required to write code with correct usage of nvim lazy libraries and preferably in lua then fallback to vim if necessary
      1. Update the code in #buffer{watch} using the @editor tool
      2. Make sure you trigger both tools in the same response Specification
      3. Follow the given documentation
      ]],
            },
          },
        },
        ["FZF Context"] = {
          interaction = "chat", -- ✅ Fixed: strategy → interaction
          description = "Write documentation for me",
          opts = {
            index = 11,
            adapter = DEFAULT_ADAPTER,
            is_slash_cmd = true,
            auto_submit = false,
            alias = "fzf_context", -- ✅ Fixed: short_name → alias (also changed alias to match prompt name)
            stop_context_insertion = true,
            callbacks = { on_created = enable_yolo_on_created },
          },
          context = {
            -- {
            --   type = "file",
            --   path = {
            --     -- expand HOME
            --     vim.fn.expand("$HOME/dotfiles")
            --   },
            -- },
            {
              type = "url",
              url = "https://github.com/junegunn/fzf/blob/master/man/man1/fzf.1",
            },
            {
              type = "url",
              url = "https://junegunn.github.io/fzf/releases/0.66.0",
            },
          },
          prompts = {
            {
              role = "user",
              content = [[### Instructions
Your instructions here

### Steps to Follow

      You are required to write code with correct usage of nvim lazy libraries and preferably in lua then fallback to vim if necessary
      1. Update the code in #buffer{watch} using the @editor tool
      2. Make sure you trigger both tools in the same response Specification
      3. Follow the given documentation
      ]],
            },
          },
        },
        -- will still replace the chat !!
        ["📂 Attach File:Line Refs (t)"] = {
          interaction = "chat", -- ✅ Fixed: strategy → interaction
          opts = {
            is_slash_cmd = false,
            auto_submit = false,
            -- placement = "add", -- for inline or "replace"|"add"|"before"|"chat"
            stop_context_insertion = true,
          },
          description = "Attach references to the chat",
          -- # sample ref with selection
          -- > - file: @lua/plugins/extra/myEditor.lua :L26:C1-L26:C999
          -- # sample ref with no selection
          -- > - file: @lua/plugins/extra/myEditor.lua :L26:C1
          prompts = {
            {
              role = "user",
              content = function(context)
                context = context or {}
                local bufnr = context.bufnr or vim.api.nvim_get_current_buf()
                local start_line = context.start_line or context.start or (context.range and context.range.start_line)
                local start_col = context.start_col or (context.range and context.range.start_col)
                local end_line = context.end_line or context.finish or (context.range and context.range.end_line)
                local end_col = context.end_col or (context.range and context.range.end_col)

                -- Fallback to cursor if no range provided
                if not start_line then
                  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
                  start_line = row
                  start_col = col
                  end_line = row
                  end_col = col
                end

                local bufname = context.filepath or vim.api.nvim_buf_get_name(bufnr)
                local relpath = vim.fn.fnamemodify(bufname == "" and vim.api.nvim_buf_get_name(0) or bufname, ":.")

                -- Normalize columns
                start_col = start_col or 1
                end_col = end_col or 999

                local attachref = ""
                if start_line and end_line and (start_line ~= end_line or start_col ~= end_col) then
                  attachref =
                    string.format("> - file: @%s :L%d:C%d-L%d:C%d", relpath, start_line, start_col, end_line, end_col)
                else
                  attachref = string.format("> - file: @%s :L%d:C%d", relpath, start_line, start_col)
                end

                return attachref .. "\n"
              end,
            },
          },
        },
        ["Iterative Workflow with Documentation"] = {
          interaction = "chat",
          description = "Iteratively improve documentation",
          opts = {
            is_slash_cmd = true,
            auto_submit = false,
            alias = "iterative_removal_doc",
            stop_context_insertion = true,
            adapter = {
              name = DEFAULT_ADAPTER,
              model = DEFAULT_MODEL,
            },
          },
          prompts = {
            {
              role = "user",
              content = [[Create a plan to remove related code from other entries

Do an in-depth analysis and develop comprehensive commands and scripts to ensure the task is fully achieved and verified.

For a large and complex task:
- Break it down into smaller, actionable steps along the achievement path.
- Validate each step with appropriate commands like:
  - `yarn test`: to validate functionality.
  - `yarn lint-fix`: to ensure code consistency.

Proposed Workflow:
1. Systematically remove unnecessary files and unreachable references in the `<path>src/Clientside</path>` directory.
2. Execute verification commands to ensure proper cleanup.
3. If issues arise, log and analyze problematic files, directories, or approaches:
   - Determine root causes preventing successful execution.
   - Explore alternate strategies to address failures.
4. Group changes into logical, coherent commits with clear descriptions.
5. Repeat this cycle iteratively, refining the approach until the task is completed or instructed to halt.

Documentation and Tracking:
- Keep detailed records of the process in markdown files:
  - Logs of commands executed, errors, and changes made with references.
  - Summarized reports linking daily actions and changes for better traceability.
- Maintain an overarching summary file (`DATE-actions.md`), consolidating all changes and providing a single reference point for handover purposes.
          ]],
            },
          },
        },
        ["Generate a Commit Message for Short Staged"] = {
          interaction = "chat",
          description = "Generate a commit message for staged change",
          opts = {
            alias = "short-staged-commit-msg",
            auto_submit = true,
            is_slash_cmd = true,
            adapter = {
              name = DEFAULT_ADAPTER,
              -- model = "gpt-4o",
              -- model = "grok-code-fast-1",
              model = FAST_MODEL,
            },
          },
          prompts = {
            {
              role = "user",
              content = function()
                local last_commits = vim.fn.system [[git log -n 10 --pretty=format:%s]]

                return "Write commit message for the change with commitizen convention. Write concise and clear, informative commit messages that explain the 'what' and 'why' behind changes, not just the 'how'. Add bullet points of changes in description of commit message under the main commit message (use only 1 line break between title and body description). Important: keep the text clean no formatting (bad: **, '') keep plaintext with shortlist/dash prefix in body description. Only output the commit message. Do not output more than 5 bullet points. Do use acronym to save space and each point not too long. Don't include filepath, specific code changes or variables name. Use the sample commit subjects below to match the existing style and format (scope, tense, abbreviations)."
                  .. "\n\nSample recent commit subjects (last 10):\n"
                  .. last_commits
                  .. [[

Example commit message:
feat(release): add slack msg and create release after deploy
- enhance GL CI release job
- update dependency job name to have common prefix
- add release desc with deploy dt, ver, pipeline, quick link, and changelog
- include direct release link in Slack notifications for better traceability
- expand clone repo section to include overview with folder structure, instructions, and IDE setup
- provide clearer onboarding for new contributors
                  ]]
                  .. "\n\n```\n"
                  .. vim.fn.system "git diff --staged"
                  .. "\n```"
              end,
              opts = {
                contains_code = true,
              },
            },
          },
        },
        ["Generate a Commit Message for Large Files Summary"] = {
          interaction = "chat",
          description = "Generate commit message with large file summaries (>50 lines)",
          opts = {
            alias = "staged-commit",
            auto_submit = true,
            is_slash_cmd = true,
            adapter = {
              name = DEFAULT_ADAPTER,
              model = FAST_MODEL,
            },
          },
          prompts = {
            {
              role = "user",
              content = function()
                local filtered_diff = require("utils.git").get_filtered_staged_diff(50, {
                  total_threshold = 700,
                  file_treatments = {
                    { pattern = "%.md$" }, -- skip md diffs entirely
                    { pattern = ".*", skip_diff_threshold = 100, trim_diff = true }, -- default: trim if >100 lines
                  },
                })
                local last_commits = vim.fn.system [[git log -n 10 --pretty=format:%s]]

                return "Write commit message for the change with commitizen convention. Write concise and clear, informative commit messages that explain the 'what' and 'why' behind changes, not just the 'how'. Add bullet points of changes in description of commit message under the main commit message (use only 1 line break between title and body description). Important: keep the text clean no formatting (bad: **, '') keep plaintext with shortlist/dash prefix in body description. Only output the commit message. Do not output more than 5 bullet points. Do use acronym to save space and each point not too long. Don't include filepath, specific code changes or variables name. Use the sample commit subjects below to match the existing style and format (scope, tense, abbreviations).\n\nNote: If total changes ≤700 lines, full diff shown. Otherwise: FILES CHANGED lists all files; LARGE FILES (>50 lines) shows summary only; SMALL FILES shows diff (trimmed to 100 lines if exceeded). Markdown files excluded from diff sections. Binary files marked with (binary)."
                  .. "\n\nSample recent commit subjects (last 10):\n"
                  .. last_commits
                  .. [[

Example commit message:
feat(release): add slack msg and create release after deploy
- enhance GL CI release job
- update dependency job name to have common prefix
- add release desc with deploy dt, ver, pipeline, quick link, and changelog
- include direct release link in Slack notifications for better traceability
- expand clone repo section to include overview with folder structure, instructions, and IDE setup
- provide clearer onboarding for new contributors
                  ]]
                  .. "\n\n```\n"
                  .. filtered_diff
                  .. "\n```"
              end,
              opts = {
                contains_code = true,
              },
            },
          },
        },
        ["Review a Staged Commit Message (Fast)"] = {
          interaction = "chat",
          description = "Review a staged commit message — fast via gpt-4.1",
          opts = {
            alias = "review-staged-commit-fast",
            auto_submit = true,
            is_slash_cmd = true,
            adapter = {
              name = DEFAULT_ADAPTER,
              model = FAST_MODEL,
            },
          },
          prompts = {
            {
              role = "user",
              content = function()
                return [[Help me review the following staged commit message for clarity, conciseness, and adherence to best practices.
Part 1: Review & Feedback
Analyze the commit message and organize feedback into the following sections, ordered by severity:

Bugs
Identify any inaccurate, incorrect, or misleading statements.
Call out contradictions between the message and the implied change.
Provide concrete examples or corrected wording.
Potential Improvements

Suggest ways to improve clarity, completeness, or intent.
Recommend additional context when helpful (especially why the change exists).
Propose improved phrasing where applicable.
Style Suggestions

Recommend improvements based on commit message conventions (e.g., imperative mood, tense, length).
Fix grammar, structure, or readability issues.
Flag deviations from common standards (e.g., Conventional Commits).
For each section, provide:

A short, concise numbered list of findings
Specific examples or reworded alternatives
A reference to the relevant file path when applicable
                ]] .. [[Part 2: Final Commit Message (Strict Output Rules)
After the review, compose a final commit message following Commitizen / Conventional Commits conventions.

Rules for the final output:

✅ Explain both what and why (not just how)
✅ Use imperative, present tense
✅ Keep text plain text only
Do NOT use markdown, bold, quotes, or special formatting
✅ Structure:
Title line
Exactly 1 blank line
Body with bullet points using -
✅ Maximum 5 bullet points
✅ Keep bullet points short and concise
✅ Use common acronyms to save space where appropriate
❌ Do NOT mention file paths
❌ Do NOT mention specific variable names or code details
❌ Do NOT exceed one blank line between title and body
---
staged-commits
---

                  ]] .. "\n\n```\n" .. vim.fn.system "git diff --staged" .. "\n```"
              end,
              opts = {
                contains_code = true,
              },
            },
          },
        },
        ["Review a Staged Commit Message"] = {
          interaction = "chat", -- ✅ Fixed: strategy → interaction
          description = "Review a staged commit message",
          opts = {
            alias = "review-staged-commit", -- ✅ Fixed: short_name → alias
            auto_submit = true,
            is_slash_cmd = true,
            adapter = DEFAULT_ADAPTER,
          },
          prompts = {
            {
              role = "user",
              content = function()
                return [[Help me review the following staged commit message for clarity, conciseness, and adherence to best practices.
Part 1: Review & Feedback
Analyze the commit message and organize feedback into the following sections, ordered by severity:

Bugs
Identify any inaccurate, incorrect, or misleading statements.
Call out contradictions between the message and the implied change.
Provide concrete examples or corrected wording.
Potential Improvements

Suggest ways to improve clarity, completeness, or intent.
Recommend additional context when helpful (especially why the change exists).
Propose improved phrasing where applicable.
Style Suggestions

Recommend improvements based on commit message conventions (e.g., imperative mood, tense, length).
Fix grammar, structure, or readability issues.
Flag deviations from common standards (e.g., Conventional Commits).
For each section, provide:

A short, concise numbered list of findings
Specific examples or reworded alternatives
A reference to the relevant file path when applicable
                ]] .. [[Part 2: Final Commit Message (Strict Output Rules)
After the review, compose a final commit message following Commitizen / Conventional Commits conventions.

Rules for the final output:

✅ Explain both what and why (not just how)
✅ Use imperative, present tense
✅ Keep text plain text only
Do NOT use markdown, bold, quotes, or special formatting
✅ Structure:
Title line
Exactly 1 blank line
Body with bullet points using -
✅ Maximum 5 bullet points
✅ Keep bullet points short and concise
✅ Use common acronyms to save space where appropriate
❌ Do NOT mention file paths
❌ Do NOT mention specific variable names or code details
❌ Do NOT exceed one blank line between title and body
---
staged-commits
---

                  ]] .. "\n\n```\n" .. vim.fn.system "git diff --staged" .. "\n```"
              end,
              opts = {
                contains_code = true,
              },
            },
          },
        },
        -- Code review actions for current buffer changes
        ["Review Staged Changes (Current Buffer)"] = {
          interaction = "chat",
          description = "AI code review of staged changes in the current buffer",
          opts = {
            is_slash_cmd = false, -- Available in actions picker, not slash command
            auto_submit = false, -- Manual review before sending
            stop_context_insertion = false, -- Allow visual selection context
          },
          context = {
            {
              type = "file",
              path = function()
                return vim.api.nvim_buf_get_name(0)
              end,
            },
          },
          prompts = {
            {
              role = "user",
              content = function(context)
                local diff = require("utils.my_codecompanion_utils").get_buffer_staged_diff(context)

                -- Check if error or no changes
                if diff:match "^Error:" or diff:match "^No" then
                  return diff
                end

                local scope = (context and context.start_line) and "selected lines" or "entire file"
                local filepath = vim.api.nvim_buf_get_name(0)
                local relpath = vim.fn.fnamemodify(filepath, ":.")

                return CODE_REVIEW_INSTRUCTIONS("staged", scope, relpath, diff)
              end,
              opts = {
                contains_code = true,
              },
            },
          },
        },
        ["Review Unstaged Changes (Current Buffer)"] = {
          interaction = "chat",
          description = "AI code review of unstaged changes in the current buffer",
          opts = {
            is_slash_cmd = false,
            auto_submit = false,
            stop_context_insertion = false,
          },
          context = {
            {
              type = "file",
              path = function()
                return vim.api.nvim_buf_get_name(0)
              end,
            },
          },
          prompts = {
            {
              role = "user",
              content = function(context)
                local diff = require("utils.my_codecompanion_utils").get_buffer_unstaged_diff(context)

                if diff:match "^Error:" or diff:match "^No" then
                  return diff
                end

                local scope = (context and context.start_line) and "selected lines" or "entire file"
                local filepath = vim.api.nvim_buf_get_name(0)
                local relpath = vim.fn.fnamemodify(filepath, ":.")

                return CODE_REVIEW_INSTRUCTIONS("unstaged", scope, relpath, diff)
              end,
              opts = {
                contains_code = true,
              },
            },
          },
        },
        ["Review All Changes (Current Buffer)"] = {
          interaction = "chat",
          description = "AI code review of all changes (staged + unstaged) in current buffer",
          opts = {
            is_slash_cmd = false,
            auto_submit = false,
            stop_context_insertion = false,
          },
          context = {
            {
              type = "file",
              path = function()
                return vim.api.nvim_buf_get_name(0)
              end,
            },
          },
          prompts = {
            {
              role = "user",
              content = function(context)
                local diff = require("utils.my_codecompanion_utils").get_buffer_all_diff(context)

                if diff:match "^Error:" or diff:match "^No changes" then
                  return diff
                end

                local scope = (context and context.start_line) and "selected lines" or "entire file"
                local filepath = vim.api.nvim_buf_get_name(0)
                local relpath = vim.fn.fnamemodify(filepath, ":.")

                return CODE_REVIEW_INSTRUCTIONS("all (staged + unstaged)", scope, relpath, diff)
              end,
              opts = {
                contains_code = true,
              },
            },
          },
        },
        -- sample workflow: https://codecompanion.olimorris.dev/extending/workflows
        ["Setup Test Example"] = {
          description = "My workflow",
          opts = {
            is_workflow = true, -- v18+ syntax (was: strategy = "workflow")
            --   adapter = "openai", -- Always use the OpenAI adapter for this workflow
            adapter = DEFAULT_ADAPTER,
            callbacks = { on_created = enable_yolo_on_created },
          },
          prompts = {
            {
              name = "Setup Test", -- example edit <-> test in available
              role = "user",
              opts = { auto_submit = false },
              content = [[### Instructions
Your instructions here

### Steps to Follow

      You are required to write code following the instructions provided above and test the correctness by running the designated test suite. Follow these steps exactly:

      1. Update the code in #buffer{watch} using the @editor tool
      2. Then use the @cmd_runner tool to run the test suite with `<test_cmd>` (do this after you have updated the code)
      3. Make sure you trigger both tools in the same response

      We'll repeat this cycle until the tests pass. Ensure no deviations from these steps.]],
            },
            {
              name = "Repeat On Failure",
              role = "user",
              opts = { auto_submit = true },
              -- Scope this prompt to only run when the cmd_runner tool is active
              condition = function()
                return _G.codecompanion_current_tool == "cmd_runner"
              end,
              -- Repeat until the tests pass, as indicated by the testing flag
              repeat_until = function(chat)
                return chat.tools.flags.testing == true
              end,
              content = "The tests have failed. Can you edit the buffer and run the test suite again?",
            },
          },
        },
        -- Agentic prompt: pull latest on all GKG-indexed projects (skip nvim lazy) then reindex successes
        -- Tools: @{agent} = autonomous agent (cmd_runner), @{mcp} = static MCPHub tool group (always registered)
        -- IMPORTANT: @{gkg} is a *dynamic* group — only registered when GKG SSE server is connected at load time.
        -- Use @{mcp} (static, always available) instead; it provides use_mcp_tool to call GKG tools on demand.
        ["GKG Update & Reindex Projects"] = {
          interaction = "chat",
          description = "Pull latest changes for all GKG-indexed projects and reindex them (skip nvim lazy plugin dirs)",
          opts = {
            alias = "gkg-update-proj-reindex",
            is_slash_cmd = true,
            auto_submit = true,
            adapter = {
              name = DEFAULT_ADAPTER,
              model = FAST_MODEL,
            },
            callbacks = { on_created = enable_yolo_on_created },
          },
          prompts = {
            {
              role = "user",
              content = [[@{agent} @{mcp} @{gkg}

Tool-call contract (MUST follow exactly every time):
- Always call `use_mcp_tool` with exactly these top-level keys:
  `{ "server_name": "...", "tool_name": "...", "tool_input": { ... } }`
- Never use `arguments`; use `tool_input`.
- For `toggle_mcp_server`, `tool_input` MUST include BOTH:
  `{ "server_name": "gkg", "action": "start" }`
- If a tool error says missing params, retry immediately with corrected payload.
- Make one tool call at a time and wait for result before next call.

Step 0: Call use_mcp_tool with:
{ "server_name": "mcphub", "tool_name": "get_current_servers", "tool_input": { "include_disabled": true, "format": "summary" } }

Step 1: If `gkg` is disabled/not connected, call use_mcp_tool with:
{ "server_name": "mcphub", "tool_name": "toggle_mcp_server", "tool_input": { "server_name": "gkg", "action": "start" } }
Wait for success before proceeding.

Step 2: Directly use gkg tool if available or call use_mcp_tool with:
{ "server_name": "gkg", "tool_name": "list_projects", "tool_input": {} }

For each project path listed:
3. Skip any project whose path contains "lazy" (nvim lazy plugin cache dirs, e.g. ~/.local/share/*/lazy/*)
4. For remaining projects, run `git -C <project_path> pull` using cmd_runner
5. Record each project as success (exit 0) or failure (non-zero / error)

After all git pulls:
6. For each successfully updated project, call use_mcp_tool with:
{ "server_name": "gkg", "tool_name": "index_project", "tool_input": { "path": "<project_path>" } }
7. Present a final summary with two sections:
   - Successfully updated & reindexed (list paths)
   - Failed — needs manual update (list paths + reason)

Proceed autonomously without asking for confirmation between steps.]],
            },
          },
        },
        -- Sourcegraph search link generator for Agoda internal codebase
        -- Syntax: context:no-fork repo:^<regex> <term> file:<regex> (-content:<x> and -file:<x>)
        -- URL-encoding: ^ → %5E, \ → %5C, ( → %28, ) → %29, | → %7C, space → +
        -- MMB web fullstack template covers: devops/ci-templates, cart/, agoda-e2e/, full-stack/(mmb|a|tooling|host|mono)
        ["Sourcegraph Search Link"] = {
          interaction = "chat",
          description = "Generate Sourcegraph search URL for Agoda codebase (MMB/fullstack and devops context)",
          opts = {
            alias = "sg-search",
            is_slash_cmd = true,
            auto_submit = false,
            stop_context_insertion = true,
            adapter = DEFAULT_ADAPTER,
          },
          prompts = {
            {
              role = "user",
              content = [=[You are a Sourcegraph query builder for Agoda's internal codebase at https://agoda.sourcegraphcloud.com.

## Sourcegraph Syntax Reference

**Filters:**
- `context:no-fork` — exclude forked repos (always include this)
- `repo:^<regex>` — filter repos by URL-anchored regex
- `file:<regex>` — filter by filepath regex
- `content:<pattern>` — match inside file content
- `-content:<p>` / `-file:<p>` — exclusions (also written as `not content:p`)
- `lang:<name>` — filter by language (e.g. `lang:typescript`)
- Boolean: `and`, `or`, `not`; group with `()`

**Pattern types (URL param):**
- `patternType=keyword` — space-separated keyword (most flexible, default)
- `patternType=regexp` — regex search term
- `patternType=literal` — exact literal

**Base URL:** `https://agoda.sourcegraphcloud.com/search?q=<encoded>&patternType=keyword&sm=0`

**URL-encoding key chars:** `^`→`%5E`, `\`→`%5C`, `(`→`%28`, `)`→`%29`, `|`→`%7C`, space→`+`

## Repo Regex Cheatsheet

| Scope | Pattern |
|-------|---------|
| MMB Web (fullstack + devops + cart + e2e) | `^gitlab\.agodadev\.io\/(devops\/ci-templates)\|(cart\/)\|(agoda-e2e\/)\|((full-stack\/)(mmb\|a\|tooling\|host\|mono)).*` |
| Full-stack only | `^gitlab\.agodadev\.io\/full-stack\/.*` |
| DevOps only | `^gitlab\.agodadev\.io\/devops\/.*` |
| Specific repo | `^gitlab\.agodadev\.io\/full-stack\/mmb\/mmbweb$` |

## Pre-built: MMB Web Fullstack (broad context)
Matches any MMB web content; filepath must contain `mmb` or `test`; excludes mock content/files.

**Raw query:**
```
context:no-fork repo:^gitlab\.agodadev\.io\/(devops\/ci-templates)|(cart\/)|(agoda-e2e\/)|((full-stack\/)(mmb|a|tooling|host|mono)).* /mmbweb/ file:/mmb|test/ (-content:mock and -file:mock)
```

**URL:** https://agoda.sourcegraphcloud.com/search?q=context:no-fork++repo:%5Egitlab%5C.agodadev%5C.io%5C/%28devops%5C/ci-templates%29%7C%28cart%5C/%29%7C%28agoda-e2e%5C/%29%7C%28%28full-stack%5C/%29%28mmb%7Ca%7Ctooling%7Chost%7Cmono%29%29.*+/mmbweb/++file:/mmb%7Ctest/+%28-content:mock+and+-file:mock%29&patternType=keyword&sm=0

---
Given the search intent below, output:
1. The raw Sourcegraph query (human-readable)
2. The full URL-encoded search link

Search intent: <!-- replace with what you want to search for, e.g. "find all usages of BookingService in MMB BFF code, exclude test files" -->
]=],
            },
          },
        },
      }, jellydn_prompts, prompt_lib_gen),
    },
  },
}
