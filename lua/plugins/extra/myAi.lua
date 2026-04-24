-- Only contains modifications to default configs
-- put all related ai agents additional plugins options and configs here

local editor_keymaps = require "utils.editor_keymaps"
local AI_CONST = require "utils.my_ai_constants"

local CLAUDE_CODER_MAPPING_PREFIX = "<leader>C"
-- caveat : might not updated when something changed until restart nvim ?
local common_agent_env = {
  OPENAI_API_KEY = vim.env.GENAIAG,
  OPENAI_BASE_URL = vim.env.AG_OPENAIPROXY,
  ANTHROPIC_AUTH_TOKEN = vim.env.ANTHROPIC_AUTH_TOKEN,
  GLEAN_API_TOKEN = vim.env.GLEAN_API_TOKEN,
  GITLAB_TOKEN = vim.env.GITLAB_TOKEN,
  GEMINI_API_KEY = vim.env.GEMINI_API_KEY,
  CLAUDE_CODE_USE_BEDROCK = vim.env.CLAUDE_CODE_USE_BEDROCK or "0",
  CLAUDE_CODE_NO_FLICKER = "1", -- render only viz part save mem ? add fn search / and c-u/d , but sidekick terminal normal mode can scroll up easily not like term for vim / claude
}

-- Enable per-chat yolo mode (auto-approve all tool calls) via v19 approvals API
local function enable_yolo_on_created(chat)
  require("codecompanion.interactions.chat.tools.approvals"):toggle_yolo_mode(chat.bufnr)
end

-- Import AI prompts from centralized location
local ai_prompts = require "utils.my_ai_prompts"
local EMPTY_PROMPT_CCOMP = ai_prompts.EMPTY_PROMPT_CODECOMPANION
local CODE_REVIEW_INSTRUCTIONS = ai_prompts.CODE_REVIEW_INSTRUCTIONS

-- Generated prompt_library entries from top_choices (AGD + Copilot)
local prompt_lib_gen = require("utils.my_codecompanion_prompt_library").build(EMPTY_PROMPT_CCOMP)
-- Jellydn base prompts (migrated from codecompanion.lua with v19 fields)
local jellydn_prompts = require("utils.my_codecompanion_prompt_library").build_jellydn_prompts()

return {
  {
    -- https://deepwiki.com/search/explain-if-luarcjson-file-can_a16e3ee5-0d51-46cf-9c7d-6b6a96e5ad8c?mode=fast
    "folke/sidekick.nvim",
    -- https://deepwiki.com/search/what-does-dev-and-dir-field-is_dcd4b58d-b892-4dd9-b13c-88c7a1a0d367?mode=fast
    -- The dev path is configured by config.dev.path (default "~/projects"). The resolved directory becomes {config.dev.path}/{plugin.name} config.lua:69-76 .

    -- DEBUG way 1
    -- directly edit source code
    -- w/o exiting use :Lazy reload
    --
    -- if no change reflect / cache try below
    -- dir = "/Users/tharutaipree/.local/share/nvim3_jelly_tinynvim/lazy/sidekick.nvim/",
    -- dir = "sidekick.nvim/",
    -- dev = true,
    opts = {
      cli = {
        -- Moved from myEditor.lua — custom prompt context variables
        prompts = {
          fname = function()
            return vim.fn.expand "%:t"
          end,
          fpath = function()
            -- in this format file: <> \n name <> in newline separate
            -- try sending just the file name not the content
            return vim.fn.expand "%:p"
          end,
        },
        win = {
          keys = {
            -- Disable conflicting Ctrl keybindings
            -- files = false, -- disables <c-f>
            -- prompt = "<m-i>", -- disables <c-p>
            -- buffers = false, -- disables <c-b>
            -- Disable all tmux navigation keys in sidekick terminal
            nav_left = false, -- disables <c-h>
            nav_down = false, -- disables <c-j>
            nav_up = false, -- disables <c-k>
            nav_right = false, -- disables <c-l>
          },
        },
        -- work around for issues docs/memory/sidekick_env_propagation.md
        tools = {
          opencode = {
            -- Use <M-p> for the command palette instead of the default <C-p>
            keys = { prompt = { "<m-p>", "prompt" } },
            env = common_agent_env,
            -- env = {
            --   GLEAN_API_TOKEN = vim.env.GLEAN_API_TOKEN,
            -- },
          },
          -- crush = {
          --   env = {
          --     GLEAN_API_TOKEN = vim.env.GLEAN_API_TOKEN,
          --   },
          -- },
          codex = {
            env = common_agent_env,
          },
          claude = {
            cmd = { "claude", "--allow-dangerously-skip-permissions" },
            env = common_agent_env,
          },
          claudeF = {
            cmd = { "claude", "--allow-dangerously-skip-permissions" },
            env = vim.tbl_extend("force", common_agent_env, { CLAUDE_CODE_NO_FLICKER = "0" }),
          },
          claude_Agd = {
            cmd = { vim.env.DOTFILES_DIR .. "/ai/claude/cc-agd/cag.sh" },
            env = common_agent_env,
          },
          claude_AgdOm = {
            cmd = { vim.env.DOTFILES_DIR .. "/ai/claude/cc-agd/cag.sh", "--om" },
            env = common_agent_env,
          },
          claude_AgdOmD = {
            cmd = { vim.env.DOTFILES_DIR .. "/ai/claude/cc-agd/cag.sh", "--omd" },
            env = common_agent_env,
          },
          debug_me = { -- https://github.com/folke/sidekick.nvim/issues/62
            env = vim.tbl_extend("force", common_agent_env, {
              FOO = "bar",
            }),
            -- require to use absolute (no ~) else failed - try chmod +x also
            cmd = { "/Users/tharutaipree/dotfiles/.config/nvim3_jelly_tinynvim/tests/debug_me.sh" },
            -- cmd = { "bash", "-c", "~/dotfiles/.config/nvim3_jelly_tinynvim/tests/debug_me.sh", "&&", "read" },
            -- below also work ?
            -- below envs work fine ?
            -- cmd = { "bash", "-l" }, -- show all env correctly
            -- cmd = { "bash", "-lc", "claude" }, -- show env properly used
            -- env = {
            --   FOO = "111",
            -- },
            dummyFn = function()
              -- Test :LazyDev importability and completionQ
              -- Behavior
              -- - config optional = true on coding not enough lua/plugins/coding.lua, ft lua lazydev lua/langs/lua.lua needed else blink error
              -- - initial = all buffers scan require modules / text to import into workspace
              -- .luarc.json - should not have setting of workspace.library (else functionality will not work ie. Snacks global sidekick.cli.terminal full path not navable)
              -- seems like load all deps
              -- if not enable will not auto load these plujgins into lsp workspace var
              -- use :VimDev to check latest loaded lists
              -- print(vim.env.VIMRUNTIME) --/opt/homebrew/Cellar/neovim/0.11.3/share/nvim/runtime
              -- uncomment to test
              require "sidekick.cli.terminal"
              require "snacks"
              require "lazydev"
              print(Snacks.bigfile)
              print "Debug Me tool executed"
              vim.uv.sleep(1000)
            end,
          },
        },
      },
    },
    keys = require("utils.editor_keymaps").keymaps.sidekick,
  },
  --#region AI tools moved from myEditor.lua
  -- image support for code companion , requires pngpaste , brew install pngpaste https://github.com/jcsalterego/pngpaste
  {
    "HakonHarnes/img-clip.nvim",
    event = "VeryLazy",
    keys = editor_keymaps.keymaps.img_clip,
    opts = {
      default = {
        prompt_for_file_name = false,
        template = "[Image$CURSOR]($FILE_PATH)",
        use_absolute_path = false,
      },
      filetypes = {
        codecompanion = {
          prompt_for_file_name = false,
          use_absolute_path = true,
        },
        AvanteInput = {
          prompt_for_file_name = false,
          use_absolute_path = true,
        },
      },
    },
  },
  {
    "github/copilot.vim",
    -- v1.58.0 has issue errors 2026-01-26 02:58
    version = "1.57.0",
  },
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    dependencies = {
      { "github/copilot.vim" },
      { "nvim-lua/plenary.nvim" },
    },
    enabled = true,
    keys = editor_keymaps.keymaps.copilot_chat,
    opts = {
      model = require("utils.my_ai_constants").DEFAULT_COPILOT_MODEL,
    },
  },
  {
    "yetone/avante.nvim",
    -- https://github.com/yetone/avante.nvim?tab=readme-ov-file#default-setup-configuration
    opts = {
      provider = "copilot", -- You can then change this provider here
      -- provider = "openai_agd", -- You can then change this provider here
      web_search_engine = {
        -- provider = "tavily", -- tavily, serpapi, google, kagi, brave, or searxng
        provider = "google",
      },
      -- Providers: base providers merged with Agoda-specific providers from utils
      -- See lua/utils/my_avante_utils.lua for Agoda provider configurations
      providers = vim.tbl_extend("force", {
        copilot = {
          model = AI_CONST.DEFAULT_COPILOT_MODEL,
        },
      }, {}), -- default = no custom provider
      -- avante_utils.get_agoda_providers()),

      acp_follow_agent_locations = false,
      selection = {
        enabled = true,
        hint_display = "none",
      },
      behavior = {
        -- auto_set_keymaps = false,
        allow_access_to_git_ignored_files = true, -- still not allow outside repo / root how ?
      },
      mappings = { -- https://github.com/yetone/avante.nvim/blob/5df39b480d438a46afa1571db6480210bccea21b/lua/avante/config.lua#L641
        ---@class AvanteConflictMappings
        sidebar = {
          switch_windows = "<C-Tab>", -- not work
        },
        files = {
          add_current = "<leader>rc", -- wil get map after avante is show
          add_all_buffers = "<leader>rC",
        },
        toggle = {
          debug = "<leader>rd", -- discard to some random key
          selection = "<localleader>ax",
        },
        select_history = "<leader>rh",
        focus = "<localleader>ax", -- discard to some random key
      },
    },
    keys = editor_keymaps.keymaps.avante,
  },
  --#endregion AI tools moved from myEditor.lua
  {
    "folke/which-key.nvim",
    optional = true,
    opts = {
      spec = {
        { "<leader>ah", group = "MCPHub", mode = { "n" } },
        { "<leader>Am", group = "Commit Message", mode = { "n" } },
        { "<leader>Amm", desc = "Git staged commit msg", mode = { "n" } },
        { "<leader>AmM", desc = "Git staged commit msg (large files)", mode = { "n" } },
        { "<leader>Amf", desc = "Review staged commit (fast, gpt-4.1)", mode = { "n" } },
        { "<leader>C", group = "Claude Code", mode = { "n", "v" }, icon = "🤖" },
      },
    },
  },

  {
    "ravitemer/mcphub.nvim",
    version = "6.2.0",
    -- MCPHub.nvim - MCP client and tool bridge for AI chat plugins
    --     require("mcphub")
    --     Do more investigation on integration and amed the documentation of dependencies check to reflect the investigations on these sites:
    -- @{fetch_webpage}
    --
    -- @{full_stack_dev}
    --
    -- https://ravitemer.github.io/mcphub.nvim/extensions/avante.html
    -- https://ravitemer.github.io/mcphub.nvim/extensions/codecompanion
    -- https://ravitemer.github.io/mcphub.nvim/extensions/copilotchat.html
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    cmd = "MCPHub",
    build = "bundled_build.lua",
    -- MCPHub extension - enables MCP tools/resources in CodeCompanion
    -- Usage:
    --   @{mcp}           - All tools via use_mcp_tool
    --   @{server}        - All tools from a server
    --   @{server__tool}  - Specific tool
    --   #{mcp:resource}  - Resource as variable
    --   /mcp:prompt      - MCP prompt as slash command
    --
    config = function(_, opts)
      local auth = require "utils.mcphub_auth"
      -- MCPHubClearAuth user command
      -- Clears stale OAuth credentials from ~/.local/share/mcp-hub/oauth-storage.json.
      -- Use when an upstream MCP server resets its client registry (pod restart / DCR eviction)
      -- causing "client ID not found in server's client registry" on the consent page.
      -- After clearing, restart the server from :MCPHub UI (press R on the server row).
      -- See: lua/utils/mcphub_auth.lua, docs/memory/mcphub.md

      vim.api.nvim_create_user_command("MCPHubClearAuth", function(cmdopts)
        local url = vim.trim(cmdopts.args or "")
        if url == "" then
          auth.pick_and_clear()
        else
          auth.clear_notify(url)
        end
      end, {
        nargs = "?",
        desc = "Clear MCPHub OAuth credentials (no arg = picker, arg = server URL)",
        complete = function(_, _, _)
          return require("utils.mcphub_auth").list_all_urls()
        end,
      })
      require("mcphub").setup(opts)
    end,
    opts = {
      use_bundled_binary = true,
      config = vim.fn.expand "~/dotfiles/ai/mcp/mcphub.json",
      port = 37373,
      -- Disable workspace mode for consistent port 37373 access by CLI agents
      -- Without this, workspace mode creates per-directory hubs on random ports (40000-41000)
      workspace = {
        -- enabled = false,
        enabled = true,
        look_for = { ".mcphub/servers.json" },
        port_range = { min = 40000, max = 41000 }, -- Port range for generating unique workspace ports
        -- TODO: check if needed
        get_port = function()
          -- Derive unique port per profile to prevent multi-profile conflicts
          -- (see tasks/open/mcphub-multi-profile-port-conflict.md)
          -- local appname = vim.env.NVIM_APPNAME or "nvim"
          -- if appname:find("nvimwt") then
          --   return 47475 -- worktree profile
          -- end
          return 47474 -- main profile
        end,
        -- more tried notes + config ./mypoc.lua
        -- mcp-hub --port 47474 --config ~/dotfiles/ai/mcp/mcphub.json --config ./.mcphub/project.json
      },
      auto_approve = false,
      auto_toggle_mcp_servers = true,
      extensions = {
        copilotchat = {
          enabled = true,
          convert_tools_to_functions = true, -- Convert MCP tools to CopilotChat functions
          convert_resources_to_functions = true, -- Convert MCP resources to CopilotChat functions
          add_mcp_prefix = false, -- Add "mcp_" prefix to function names
        },
        avante = {
          make_slash_commands = true,
        },
      },
      ui = {
        window = {
          width = 0.8,
          height = 0.8,
        },
      },
      log = {
        level = vim.log.levels.WARN,
        to_file = false,
      },
    },
    keys = {
      { "<leader>ah", "<cmd>MCPHub<cr>", desc = "MCPHub" },
      {
        "<leader>aHx",
        function()
          require("utils.mcphub_auth").pick_and_clear()
        end,
        desc = "Clear MCPHub OAuth (picker)",
      },
    },
  },

  -- Blink.cmp integration for Avante completion
  -- Provides autocomplete for MCP prompts, tools, and resources in Avante chat
  -- does rank lower than custom settings in lua/plugins/extra/myEditor.lua:1275
  -- {
  --   "saghen/blink.cmp",
  --   dependencies = {
  --     "Kaiser-Yang/blink-cmp-avante", -- same as manual (need to configure order again)
  --   },
  --   opts = {
  --     sources = {
  --       default = { 'avante', 'lsp', 'path', 'snippets', 'buffer' },
  --       -- default = { 'avante' }, -- avante should be on top of the list (else get other merged)
  --       providers = {
  --         avante = {
  --           name = "Avante",
  --           module = "blink-cmp-avante",
  --           -- Show Avante completions alongside other sources
  --           -- Disabled by default in Avante chat context to avoid conflicts
  --           opts = {},
  --         },
  --       },
  --     },
  --   },
  -- },
  -- use for codecompanion
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "yaml", "markdown" } },
  },
  {
    "olimorris/codecompanion.nvim",
    version = "19.7.x", -- exact pin: v19.7.0 / f76cd2598e1d4a5fd78e27c29e2e5f53c9a99c21
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

      -- Show loading spinner when request is started (from jellydn/tiny-nvim)
      local ok, spinner = pcall(require, "spinner")
      if ok then
        local group = vim.api.nvim_create_augroup("CodeCompanionHooks", {})
        vim.api.nvim_create_autocmd({ "User" }, {
          pattern = "CodeCompanionRequest*",
          group = group,
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
        group = group,
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
            end
          end)
        end,
      })
    end,
    keys = require("utils.editor_keymaps").keymaps.codecompanion(),
    -- NOTE: llama3_2 and llama3latest ollama adapters were removed — they were
    -- at the plugin spec level (not inside opts) so Lazy.nvim ignored them.
    -- To re-enable, move into opts.adapters.http below.
    opts = {
      system_prompt = require("utils.my_ai_prompts").COPILOT_SYSTEM_PROMPT,
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
          -- adapter = "openai_agd",
          adapter = "copilot",
          -- adapter = {
          -- dont know why override model in interaction not work need replace in adpaters schema
          -- https://codecompanion.olimorris.dev/configuration/adapters-http#changing-the-default-model
          -- model default here not working ?
          -- name = "copilot",
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
          -- Chat buffer keymaps (from jellydn/tiny-nvim codecompanion.lua)
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
          },
        },
        -- Or, just specify the adapter by name
        inline = {
          adapter = "copilot",
        },
        cmd = {
          adapter = "copilot",
        },
        background = {
          --adapter = "copilot",
        },
      },
      adapters = {
        cache_models_for = 5000, -- local cached inside var - def 1800 (30m)
        http = require("utils.my_codecompanion_utils").merge_agoda_adapters {
          copilot = function()
            return require("codecompanion.adapters").extend("copilot", {
              schema = {
                model = {
                  default = require("utils.my_ai_constants").DEFAULT_COPILOT_MODEL or "gpt-5-mini",
                  -- choices -> currently no temperature opts check for 5mini
                  -- /Users/tharutaipree/.local/share/nvim3_jelly_tinynvim/lazy/codecompanion.nvim/lua/codecompanion/adapters/http/copilot/init.lua:334:27
                },
                -- temperature = { -- see tasks/open/investigate-codecompanion-adapter-switching.md:85:1
              },
            })
          end,
          --   copilot = {
          --    schema = {
          --     model = {
          -- if have show error formatted
          -- default = require("utils.my_ai_constants").DEFAULT_COPILOT_MODEL or "gpt-5-mini",
          --      },
          --    },
          --  },
        },
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
        action_palette = {
          provider = "snacks",
        },
      },
      -- NOTE: strategies block merged into interactions above (v19 migration)
      keymaps = {
        completion = {
          modes = {
            -- i = "<C-/>",
            -- i = "<C-Space>",
          },
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
              -- adapter = "copilot", -- nil to use current chat
              -- model = "gpt-4.1", -- nil to use current chat Error: {"error":{"message":"model gpt-4.1 is not supported via Responses API.","code":"unsupported_api_for_model"}}
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
        -- https://deepwiki.com/search/check-the-settting-from-prompt_65b9cc4c-5ada-41a8-8b0d-49142cfdef65?mode=deep
        -- will work only when open new chat with the action cmd else not change model while there is prompt
        -- NOTE: AGD + Copilot model entries are auto-generated by utils/my_codecompanion_prompt_library.lua
        -- from my_ai_constants.providers[*].top_choices (per-family tiered structure)
        --
        -- Known caveats:
        -- - Claude models: `temperature` and `top_p` cannot both be specified
        -- - opus 4.5 and 4.6 same error temp topp
        ["Codecompanion Context"] = {
          interaction = "chat", -- ✅ Fixed: strategy → interaction
          description = "Write documentation for me",
          opts = {
            index = 11,
            adapter = "copilot", -- ✅ Fixed: simplified to string
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
            adapter = "copilot", -- ✅ Fixed: simplified to string
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
            adapter = "copilot", -- ✅ Fixed: simplified to string
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
              name = "copilot",
              model = "claude-sonnet-4.5",
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
              name = "copilot",
              -- model = "gpt-4o",
              -- model = "grok-code-fast-1",
              model = "gpt-5-mini",
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
              name = "copilot",
              model = "gpt-5-mini",
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
              name = "copilot",
              model = "gpt-4.1",
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
            adapter = "copilot", -- ✅ Fixed: simplified to string
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
            adapter = "copilot",
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
              name = "copilot",
              model = "gpt-4.1", -- lower max token (16k vs 50k) 5-mini get some error while 4.1 perform pull correctly
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
            adapter = "copilot",
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
  {
    "greggh/claude-code.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    opts = {
      command = "claude --allow-dangerously-skip-permissions",
    },
  },
  {
    "coder/claudecode.nvim",
    opts = {
      -- terminal_cmd = "claude --allow-dangerously-skip-permissions",
      terminal_cmd = vim.env.HOME .. "/dotfiles/ai/claude/cc-agd/cag.sh --allow-dangerously-skip-permissions",
      -- terminal_cmd = "claude",
    },
    -- lua/plugins/extra/claude-code.lua:194
    keys = {
      {
        CLAUDE_CODER_MAPPING_PREFIX .. "C",
        "<cmd>ClaudeCode --continue <cr>",
        desc = "Toggle Claude Continue",
      },
      { CLAUDE_CODER_MAPPING_PREFIX .. "M", "<cmd>ClaudeCodeSelectModel<cr>", desc = "Select Claude model" },
      {
        "<leader>as",
        "<cmd>ClaudeCodeTreeAdd<cr>",
        desc = "Add file",
        ft = { "NvimTree", "neo-tree", "oil", "minifiles", "netrw" },
      },
    },
  },
}
