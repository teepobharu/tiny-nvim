-- Only contains modifications to default configs
-- put all related ai agents additional plugins options and configs here
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
            -- env = {
            --   GLEAN_API_TOKEN = vim.env.GLEAN_API_TOKEN,
            -- },
          },
          -- crush = {
          --   env = {
          --     GLEAN_API_TOKEN = vim.env.GLEAN_API_TOKEN,
          --   },
          -- },
          -- codex = {
          --   env = {
          --     OPENAI_BASE_URL = vim.env.AG_OPENAIPROXY,
          --     OPENAI_API_KEY = vim.env.GENAIAG,
          --     GLEAN_API_TOKEN = vim.env.GLEAN_API_TOKEN,
          --     GITLAB_TOKEN = vim.env.GITLAB_TOKEN,
          --   },
          -- },
          -- claude = {
          --   env = {
          --     GLEAN_API_TOKEN = vim.env.GLEAN_API_TOKEN,
          --     ANTHROPIC_AUTH_TOKEN = vim.env.ANTHROPIC_AUTH_TOKEN,
          --   },
          -- },
          debug_me = { -- https://github.com/folke/sidekick.nvim/issues/62
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
  },
  -- MCPHub.nvim - MCP client and tool bridge for AI chat plugins
  {
    "folke/which-key.nvim",
    optional = true,
    opts = {
      spec = {
        { "<leader>ah", group = "MCPHub", mode = { "n" } },
      },
    },
  },

  {
    "ravitemer/mcphub.nvim",
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
    opts = {
      use_bundled_binary = true,
      config = vim.fn.expand "~/dotfiles/claude/mcp-proxy/mcphub.json",
      port = 37373,
      -- Disable workspace mode for consistent port 37373 access by CLI agents
      -- Without this, workspace mode creates per-directory hubs on random ports (40000-41000)
      workspace = { enabled = false },
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
  {
    "olimorris/codecompanion.nvim",
    dependencies = {
      -- MCPHub integration for MCP tools/resources access
      { "ravitemer/mcphub.nvim", optional = true },
    },
    opts = {
      extensions = {
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
    },
  },
}
