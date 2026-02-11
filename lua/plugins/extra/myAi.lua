-- Only contains modifications to default configs
-- put all related ai agents additional plugins options and configs here

-- caveat : might not updated when something changed until restart nvim ?
local common_agent_env = {
  OPENAI_API_KEY = vim.env.GENAIAG,
  OPENAI_BASE_URL = vim.env.AG_OPENAIPROXY,
  ANTHROPIC_AUTH_TOKEN = vim.env.ANTHROPIC_AUTH_TOKEN,
  GLEAN_API_TOKEN = vim.env.GLEAN_API_TOKEN,
  GITLAB_TOKEN = vim.env.GITLAB_TOKEN,
  GEMINI_API_KEY = vim.env.GEMINI_API_KEY,
}
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
  },
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
    --
    opts = {
      use_bundled_binary = true,
      config = vim.fn.expand "~/dotfiles/claude/mcp-proxy/mcphub.json",
      port = 37373,
      -- Disable workspace mode for consistent port 37373 access by CLI agents
      -- Without this, workspace mode creates per-directory hubs on random ports (40000-41000)
      workspace = {
        -- enabled = false,
        enabled = true,
        look_for = { ".mcphub/servers.json" },
        port_range = { min = 40000, max = 41000 }, -- Port range for generating unique workspace ports
        get_port = function()
          return 47474
          -- return nil
          -- Optional function returning custom port number. Called when generating ports to allow custom port assignment logic
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
    -- version = "^17.33.0", -- pin to avoid breaking changes
    version = "^18.4.1",
    dependencies = {
      -- MCPHub integration for MCP tools/resources access
      { "ravitemer/mcphub.nvim", optional = true },
    },
    keys = require("utils.editor_keymaps").keymaps.codecompanion(),
    adapters = {
      llama3_2 = function()
        return require("codecompanion.adapters").extend("ollama", {
          name = "llama3", -- Give this adapter a different name to differentiate it from the default ollama adapter
          schema = {
            model = {
              default = "llama3.2:latest",
            },
            num_ctx = {
              default = 16384,
            },
            num_predict = {
              default = -1,
            },
          },
        })
      end,

      -- https://github.com/olimorris/codecompanion.nvim/blob/main/lua/codecompanion/adapters/ollama.lua
      llama3latest = function()
        return require("codecompanion.adapters").extend("ollama", {
          name = "llama3latest", -- Give this adapter a different name to differentiate it from the default ollama adapter
          schema = {
            model = {
              default = "llama3:latest",
            },
            num_ctx = {
              default = 16384,
            },
            num_predict = {
              default = -1,
            },
          },
        })
      end,
    },
    opts = {
      -- log_level = "DEBUG", -- TRACE|DEBUG|ERROR|INFO not work
      -- see logs in ~/.local/state/nvim/codecompanion.log -- not sure why not see
      --
      -- [WARN] above not help disable textmsg: CodeCompanion.nvim will experience breaking changes soon. Pin to version v17.33.0 or earlier to avoid this.
      -- https://codecompanion.olimorris.dev/configuration/chat-buffer
      interactions = {
        chat = {
          -- You can specify an adapter by name and model (both ACP and HTTP)
          adapter = {
            name = "copilot",
            model = require("utils.my_ai_constants").DEFAULT_COPILOT_MODEL or "gpt-5-mini",
          },
        },
        -- Or, just specify the adapter by name
        inline = {
          adapter = {
            name = "copilot",
            model = require("utils.my_ai_constants").DEFAULT_COPILOT_MODEL or "gpt-5-mini",
          },
        },
        cmd = {
          adapter = {
            name = "copilot",
            model = require("utils.my_ai_constants").DEFAULT_COPILOT_MODEL or "gpt-5-mini",
          },
        },
        background = {
          --          adapter = {
          --            name = "ollama",
          --            model = "qwen-7b-instruct",
          --            model = require("utils.my_ai_constants").DEFAULT_COPILOT_MODEL or "gpt-5-mini",
          --          },
        },
      },
      adapters = {
        http = require("utils.my_codecompanion_utils").merge_agoda_adapters {
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
      strategies = {
        chat = {
          adapter = "copilot",
          roles = { llm = "  Copilot Chat", user = "☀️ Brightza" },
          slash_commands = {
            ["buffer"] = { opts = { provider = "snacks" } },
            ["file"] = { opts = { provider = "snacks" } },
            ["fetch"] = { opts = { provider = "snacks" } },
            ["help"] = { opts = { provider = "snacks" } },
            ["image"] = { opts = { provider = "snacks" } },
            ["symbols"] = { opts = { provider = "snacks" } },
            ["quickfix"] = { opts = { provider = "snacks" } },
          },
        },
      },
      keymaps = {
        completion = {
          modes = {
            -- i = "<C-/>",
            -- i = "<C-Space>",
          },
        },
      },
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
      prompt_library = {
        -- https://deepwiki.com/search/check-the-settting-from-prompt_65b9cc4c-5ada-41a8-8b0d-49142cfdef65?mode=deep
        -- will work only when open new chat with the action cmd else not change model while there is prompt
        ["Model GPT mini 5 - G5"] = {
          interaction = "chat", -- ✅ Fixed: strategy → interaction
          opts = {
            adapter = "copilot", -- ✅ Fixed: simplified to string (model override via command params)
            is_slash_cmd = true,
            alias = "gpt5mini_g5m_gfree", -- ✅ Fixed: short_name → alias
            stop_context_insertion = true,
          },
          prompts = {
            {
              role = "user",
              content = "",
            },
          },
        },
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
              content = function()
                vim.g.codecompanion_auto_tool_mode = true
                -- Some clear instructions for the LLM to follow
                return [[### Instructions
Your instructions here

### Steps to Follow

      You are required to write code with correct usage of the lua settings provided by the documentation
      1. Update the code in #buffer{watch} using the @editor tool
      2. Make sure you trigger both tools in the same response Specification
      3. Follow the given documentation
      ]]
              end,
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
              content = function()
                -- Leverage auto_tool_mode which disables the requirement of approvals and automatically saves any edited buffer
                vim.g.codecompanion_auto_tool_mode = true
                -- Some clear instructions for the LLM to follow
                return [[### Instructions
Your instructions here

### Steps to Follow

      You are required to write code with correct usage of nvim lazy libraries and preferably in lua then fallback to vim if necessary
      1. Update the code in #buffer{watch} using the @editor tool
      2. Make sure you trigger both tools in the same response Specification
      3. Follow the given documentation
      ]]
              end,
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
              content = function()
                -- Leverage auto_tool_mode which disables the requirement of approvals and automatically saves any edited buffer
                vim.g.codecompanion_auto_tool_mode = true
                -- Some clear instructions for the LLM to follow
                return [[### Instructions
Your instructions here

### Steps to Follow

      You are required to write code with correct usage of nvim lazy libraries and preferably in lua then fallback to vim if necessary
      1. Update the code in #buffer{watch} using the @editor tool
      2. Make sure you trigger both tools in the same response Specification
      3. Follow the given documentation
      ]]
              end,
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
                local start_col = context.start_col or context.start_col
                local end_line = context.end_line or context.finish or (context.range and context.range.end_line)
                local end_col = context.end_col or context.end_col

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
          strategy = "chat",
          description = "Iteratively improve documentation",
          opts = {
            is_slash_cmd = true,
            auto_submit = false,
            short_name = "iterative_removal_doc",
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
        -- overrides the prompt from jellydn to
        ["Generate a Commit Message for Staged Short"] = {
          interaction = "chat",
          description = "Generate a commit message for staged change",
          opts = {
            alias = "short-staged-commit",
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
                return "Write commit message for the change with commitizen convention. Write concise and clear, informative commit messages that explain the 'what' and 'why' behind changes, not just the 'how'. Add bullet points of changes in description of commit message under the main commit message (use only 1 line break between title and body description). Important: keep the text clean no formatting (bad: **, '') keep plaintext with shortlist/dash prefix in body description. Only output the commit message. Do not output more than 5 bullet points. Do use acronym to save space and each point not too long. Don't include filepath, specific code changes or variables name"
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
        -- sample workflow: https://codecompanion.olimorris.dev/extending/workflows
        ["Setup Test Example"] = {
          description = "My workflow",
          opts = {
            is_workflow = true, -- v18+ syntax (was: strategy = "workflow")
            --   adapter = "openai", -- Always use the OpenAI adapter for this workflow
            adapter = "copilot",
          },
          prompts = {
            {
              name = "Setup Test", -- example edit <-> test in available
              role = "user",
              opts = { auto_submit = false },
              content = function()
                -- Leverage auto_tool_mode which disables the requirement of approvals and automatically saves any edited buffer
                vim.g.codecompanion_auto_tool_mode = true

                -- Some clear instructions for the LLM to follow
                return [[### Instructions
Your instructions here

### Steps to Follow

      You are required to write code following the instructions provided above and test the correctness by running the designated test suite. Follow these steps exactly:

      1. Update the code in #buffer{watch} using the @editor tool
      2. Then use the @cmd_runner tool to run the test suite with `<test_cmd>` (do this after you have updated the code)
      3. Make sure you trigger both tools in the same response

      We'll repeat this cycle until the tests pass. Ensure no deviations from these steps.]]
              end,
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
      },
    },
  },
}
