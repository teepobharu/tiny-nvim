local pathUtil = require "utils.mypath"
local gitUtil = require "utils.git"
local keyutil = require "utils.keyutil"
local editor_keymaps = require "utils.editor_keymaps"
local avante_utils = require "utils.my_avante_utils"

local isSnackEnabled = keyutil.isSnackEnabled
local open_remote = gitUtil.open_remote

---Run the first available formatter followed by more formatters
---@param bufnr integer
---@param ... string
---@return string
local function first(bufnr, ...)
  local conform = require "conform"
  for i = 1, select("#", ...) do
    local formatter = select(i, ...)
    if conform.get_formatter_info(formatter, bufnr).available then
      return formatter
    end
  end
  return select(1, ...)
end

return {
  -- Disabled list
  {
    "nvim-treesitter/nvim-treesitter",
    -- version = false, -- last release is way too old and doesn't work on Windows
    dependencies = {
      "nvim-treesitter/nvim-treesitter-textobjects", -- nv2 has this : add selecting around (vaf : function) or sentence [], {} block
    },
  },
  { "nvimdev/dashboard-nvim", lazy = true, enabled = false },
  { "Wansmer/treesj", enabled = false },
  -- folke/edgy.nvim:  https://github.com/LazyVim/LazyVim/blob/1f8469a53c9c878d52932818533ce51c27ded5b6/lua/lazyvim/plugins/extras/ui/edgy.lua#L97
  {
    "jellydn/hurl.nvim",
    keys = {},
    -- opts = {
    --   env_file = { 'vars.env' }, -- current->gitroot by default, abs file not work traverse https://deepwiki.com/search/is-this-opt-set-in-opts-correc_3aa3eb0a-7ff7-427f-a1b1-c446116091c9?mode=fast
    -- }
  },
  {
    "stevearc/oil.nvim",
    enabled = true,
    opts = {},
    keys = editor_keymaps.keymaps.oil,
  },
  {
    "stevearc/overseer.nvim",
    keys = editor_keymaps.keymaps.overseer,
    opts = {
      -- default config: https://github.com/stevearc/overseer.nvim/blob/a2734d90c514eea27c4759c9f502adbcdfbce485/lua/overseer/config.lua#L4
      templates = {
        "builtin",
        "user.run_script",
        "vscode_global.vscode_global",
        "common_shell.grep_async",
        "agoda.android_client.and_build",
        "agoda.mmb.mmb_pick",
        "agoda.mmb.mmb_tests",
        "agoda.tripviewbff.tripviewbff_pick",
        "agoda.dotnet.dotnet_test",
        "agoda.android_client.and_test",
        "agoda.android_client.and_pick",
      },
      strategy = {
        "terminal",
        -- "toggleterm", -- https://github.com/stevearc/overseer.nvim/blob/master/doc/third_party.md#toggleterm
        use_shell = true,
      },
      task_list = {
        bindings = {
          ["<C-q>"] = ":q<CR>",
          ["<C-s>"] = ":OverseerQuickAction<CR>",
          ["S"] = ":OverseerSaveBundle<CR>",
          ["T"] = ":OverseerTaskAction<CR>",
          ["Q"] = ":OverseerDeleteBundle<CR>",
          ["C"] = ":OverseerClearCache<CR>",
          ["I"] = ":OverseerInfo<CR>",
          ["B"] = ":OverseerLoadBundle<CR>",

          ["<S-Up>"] = "ScrollOutputUp",
          ["<S-Down>"] = "ScrollOutputDown",
          ["<A-q>"] = "OpenQuickFix",
          -- ["<C-l>"] = "",
          -- ["<C-h>"] = "",
          ["<C-l>"] = false,
          ["<C-h>"] = false,
          -- c-j and c-k remove bind
          ["<C-j>"] = false,
          ["<C-k>"] = false,
          ["J"] = "DecreaseDetail",
          ["L"] = "IncreaseDetail",
          -- ["K"] = "IncreaseAllDetail",
          -- ["L"] = "",
          -- ["H"] = "",
          -- ["zk"] = "DecreaseDetail",
          -- ["zj"] = "IncreaseDetail",
          -- ["zl"] = "IncreaseAllDetail",
          -- ["zh"] = "DecreaseAllDetail",
        },
      },
    },
  },
  {
    "echasnovski/mini.bufremove",
    keys = editor_keymaps.keymaps.bufremove,
  },
  -- [Image](/Users/tharutaipree/dotfiles/.config/nvim3_jelly_tinynvim/assets/2025-09-06-23-28-21.png)
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
    -- config = function(_, opt)
    --   -- __AUTO_GENERATED_PRINT_VAR_START__
    --   print([==[ opt:]==], vim.inspect(opt)) -- __AUTO_GENERATED_PRINT_VAR_END__
    -- end,
  },
  --
  --#region AI Assistants
  {
    "greggh/claude-code.nvim", -- will soon be replaced with another claude code libs   - [claudecode.nvim](https://github.com/coder/claudecode.nvim
    opts = {
      keymaps = {
        toggle = {
          normal = "<localleader>C",
          terminal = "<localleader>C",
          variants = {
            continue = "<leader>Cc",
            verbose = "<leader>Cv",
            sudo = "<leader>Cs",
          },
        },
      },
      command_variants = {
        -- Output options
        sudo = "--dangerously-skip-permissions", -- Enable verbose logging with full turn-by-turn output
      },
    },
  },
  {
    "olimorris/codecompanion.nvim",
    -- version = "^17.33.0", -- pin to avoid breaking changes
    version = "^18.4.1",
    keys = editor_keymaps.keymaps.codecompanion(),
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
      adapters = {
        -- TODO FIX AUTH ERRORS
        http = {
          openai_agd = function()
            return require("codecompanion.adapters").extend("openai", {
              -- url = "http://openai-proxy.agoda.is/v1/completions",
              env = {
                api_key = "OPENAI_API_KEY",
                url = "AG_OPENAIPROXY", -- Your base URL
                chat_url = "/v1/chat/completions", -- For chat requests
                models_endpoint = "/v1/models", -- For model listing in requrie("codecompanion.adapters.http.openai_compatible") logic
              },
              url = "${url}${chat_url}", -- endpoint will be /v1/chat/completions or /v1/completions based on chat or completion
              schema = {
                model = {
                  default = "gpt-5.2",
                  -- minimal
                  choices = {
                    "gpt-4.1",
                    "gpt-4.1-mini",
                    "gpt-5-mini",
                    "gpt-5.1",
                    "gpt-5.2-pro",
                    "gpt-5.2-codex",
                    --work in chat --
                    "gpt-5.2",
                    "deepseek-r1-0528-maas",
                    --to test --
                    "gemini-3-pro-preview",
                    --not work below
                    -- "deepseek"
                    -- "qwq-32b", -- fallback haiku ??
                    -- "claude-haiku-4-5",
                    -- "claude-sonnet-4-5",
                    -- "claude-opus-4-5",
                  },
                  -- choices = function(self, opts)
                  --   -- This will call get_models() and return all 588 models
                  --   return require("codecompanion.adapters.http.openai_compatible").schema.model.choices(self, opts)
                  -- end,
                },
              },
            })
          end,
        },
        acp = { -- codex and claude_code works without extra settings jsut make sure acp cli is installed
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
                vim.fn.expand "$HOME/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/extra/myEditor.lua",
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
                vim.fn.expand "$HOME/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/extra/myEditor.lua",
              },
            },
            {
              type = "url",
              url = "https://github.com/folke/snacks.nvim/blob/main/docs/picker.md",
            },
            {
              type = "url",
              url = "https://www.reddit.com/r/neovim/comments/1j4e7fq/share_your_custom_snackspicker_sources",
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
        -- overrides the prompt frmo jellydn to
        ["Generate a Commit Message for Staged Short"] = {
          interaction = "chat",
          description = "Generate a commit message for staged change",
          opts = {
            alias = "short-staged-commit",
            auto_submit = true,
            is_slash_cmd = true,
            adapter = "copilot", -- ✅ Fixed: simplified to string
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

✅ Output ONLY the final commit message
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
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    enabled = true,
    keys = editor_keymaps.keymaps.copilot_chat,
    opts = {
      -- model = "", -- override claude-sonnet model since not support on my copilot (get ereror)
      -- debug = true, -- add to debug message by calling l-a-d and  see in file using <gf> or check :messages in the logfile name else see only error (not prompt and embedding used)
      -- mappings = {
      -- complete = { -- no difference copilot autocompl not see in chat anyway - 20250327
      --   detail = "Use @<C-Tab> or /<C-Tab> to complete the suggestion.",
      --   insert = "<C-t>",
      -- },
      -- },
    },
  },
  {
    "yetone/avante.nvim",
    -- dependencies = {
    --   "HakonHarnes/img-clip.nvim"
    -- },
    -- {
    --   -- support for image pasting :
    --   -- when use cmd + shift + v in insert save in .local/..
    --   -- if used map config will create asset in current dir
    --   "HakonHarnes/img-clip.nvim",
    --   event = "VeryLazy",
    --   opts = {
    --     -- recommended settings
    --     default = {
    --       embed_image_as_base64 = false,
    --       prompt_for_file_name = false,
    --       drag_and_drop = {
    --         insert_mode = true,
    --       },
    --       -- required for Windows users
    --       use_absolute_path = true,
    --     },
    --   },
    -- },
    -- },
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
          model = "gpt-5-mini",
        },
        ---@type AvanteSupportedProvider
        -- vclaude = {
        --   __inherited_from ="openai_agd",
        --   model = "claude-3-7-sonnet",
        -- },
        -- lua print(require('avante.config').provider)
        -- lua print(vim.inspect(require('avante.config').get_last_used_model(require('avante.config').providers)))
      }, {}), -- default = no custom provider
      -- avante_utils.get_agoda_providers()),

      -- Removed inline Agoda provider definitions (claude_agd, vertex_vclaude_2, vertex_claude_agd, openai_agd)
      -- These are now imported from lua/utils/my_avante_utils.lua
      -- To get a lean provider list without Agoda providers, use:
      -- providers = vim.tbl_extend("force", { copilot = { model = "gpt-5-mini" } }, {})

      acp_follow_agent_locations = false,
      selection = {
        enabled = true,
        hint_display = "none",
      },
      behavior = {
        -- auto_set_keymaps = false,
      },
      mappings = { -- https://github.com/yetone/avante.nvim/blob/5df39b480d438a46afa1571db6480210bccea21b/lua/avante/config.lua#L641
        -- edit = "<leader>rE", -- does not overwrite why ?
        --- @class AvanteConflictMappings
        sidebar = {
          switch_windows = "<C-Tab>", -- not work
          -- apply_all = "A" -- conflict with c-wf focus command confimration popup
          -- reverse_switch_windows = "<s-tab>",
        },
        files = {
          add_current = "<leader>aC",
        },
        toggle = {
          debug = "<leader>rd", -- discard to some random key
          selection = "<localleader>ax",
        },
        focus = "<localleader>ax", -- discard to some random key
      },
    },
    keys = editor_keymaps.keymaps.avante,
  },
  {
    "folke/sidekick.nvim",
    -- https://github.com/folke/sidekick.nvim?tab=readme-ov-file
    opts = {
      -- enabled = false, -- or default is fn and use vim.g.sidekick_nes
      cli = {
        prompts = {
          fname = function()
            return vim.fn.expand "%:t"
          end,
          fpath = function(ctx)
            -- in this format file: <> \n name <> in newline separate
            -- try sending just the file name not the content
            return vim.fn.expand "%:p"
            -- \nname: " .. vim.fn.expand("%:t")
            -- this sends the current file content
            -- return "Current file: " .. ctx.buf .. " at line " .. ctx.row
          end,
        },
      },
    },
    keys = editor_keymaps.keymaps.sidekick,
  },
  --#endregion AI Assistants
  --
  {
    "jellydn/quick-code-runner.nvim",
    keys = editor_keymaps.keymaps.quick_code_runner,
    opts = {
      -- debug = true, -- add to debug and see what happens when codepad is called
      file_types = {
        -- @ Troubleshoot when pip install does not work globally
        -- The code will create in ~/.cache/dir_/tofile.py
        -- Workaround create pipenv inside the ~/.cache/
        -- cd ~/.cache && pipenv --python 3
        -- pipenv install pandas
        python = {
          pathUtil.get_pythonpath(false) .. " -u",
          -- first check if therre is virt env in the git rroot dir or .venv or not if not python3 -u else pipenv run python -u
          -- purre cli handle not work with handling https://github.com/jellydn/quick-code-runner.nvim/blob/main/lua/quick-code-runner/utils.lua#L248
          -- "[[ -d .venv ]] && echo 'pipenv run python -u' || echo 'python3 -u'", -- not work
          -- "pipenv run python -u", -- Have some lag
          -- "python3 -u", -- Original
        },
        -- from common  -------------------
        -- https://github.com/jellydn/quick-code-runner.nvim/blob/main/lua/quick-code-runner/init.lua#L17
        -- do not know why ned to override else not work
        javascript = {
          "bun run",
        },
        go = {
          "go run",
        },
        lua = {
          "lua",
        },
        typescript = {
          -- "bun run",
          -- check out myTest.ts -- after downloaded next run no downloadede require
          -- uses esm.sh else upkg load long and stuck / use deno install (will save in cache - use deno info to check path)
          -- import { format } from "https://esm.sh/date-fns@3.6.0/format";
          -- const formattedDate = format(new Date(), "yyyy-MM-dd");
          -- console.log(formattedDate);

          "deno run --allow-import --allow-env --allow-sys --allow-read",
        },
        --  end common -------------------
        sh = {
          "bash",
        },
      },
      global_files = {
        javascript = pathUtil.get_global_file_by_type "js",
        typescript = pathUtil.get_global_file_by_type "ts",
        python = pathUtil.get_global_file_by_type "py",
        go = pathUtil.get_global_file_by_type "go",
        lua = pathUtil.get_global_file_by_type "lua",
        --  end common -------------------
        sh = pathUtil.get_global_file_by_type "sh",
      },
    },
  },
  {
    "ibhagwan/fzf-lua",
    enabled = true,
    opts = editor_keymaps.fzf_opts,
    keys = editor_keymaps.keymaps.fzf_lua,
  },
  --#region Session and windows
  {
    "akinsho/bufferline.nvim",
    opts = {
      -- check on health groups
      -- options = {
      -- groups = {
      -- items = {
      --   require('bufferline.groups').builtin.ungrouped,
      -- }
      -- }
      -- }
    },
    keys = editor_keymaps.keymaps.bufferline,
  },
  {
    "folke/persistence.nvim",
    opts = {
      dir = vim.fn.stdpath "state" .. "/my-sessions/", -- directory where session files are saved
    },
    keys = editor_keymaps.keymaps.persistence,
  },
  {
    "folke/trouble.nvim",
    keys = editor_keymaps.keymaps.trouble,
  },
  --#endregion Session and windows
  --
  --#region Files / Search
  {
    "folke/snacks.nvim",
    enabled = isSnackEnabled,
    opts = {
      dashboard = {
        enabled = false,
      },
      explorer = {
        replace_netrw = false,
      },
      -- https://github.com/folke/snacks.nvim/blob/main/docs/picker.md
      picker = {
        formatters = {
          file = {
            truncate = 200,
          },
        },
        ui_select = true, -- boolean set `vim.ui.select` to a snacks picker, might conflict with fzf
        -- Import pre-configured picker sources from editor_keymaps
        sources = vim.tbl_deep_extend("force", editor_keymaps.sources_n_keys.sources, {
          -- Source-specific overrides (if needed)
          files = {
            hidden = true, -- files picker specific setting
          },
          -- https://deepwiki.com/search/how-can-i-customize-explorer-k_06a6e33a-6125-418e-bd05-d979f1420178?mode=fast
          -- TODO: check does not realy work why ?
        }),
        toggles = {
          -- Existing toggles...
          git_cwd = {
            icon = "",
            value = true, -- Show when case_sensitive is true
          },
          case_sensitive_custom = {
            icon = "C", -- Icon to show in title
            value = true, -- Show when case_sensitive is true
          },
          case_nonsensitive_custom = {
            icon = "~", -- Icon to show in title
            value = true, -- Show when case_sensitive is true
          },
          custom_cwd = {
            icon = ".", -- Icon to show in title
            value = true, -- Show when case_sensitive is true
          },
        },
        -- Merge path copy actions from editor_keymaps with local actions
        actions = vim.tbl_extend("force", editor_keymaps.snacks_actions, {
          gitdiff_toggle_group = function(picker, item)
            require("utils.snacks_actions").gitdiff_toggle_group(picker, item)
          end,
          toggle_case_sensitivity = function(picker, item)
            require("utils.snacks_actions").toggle_case_sensitivity(picker, item)
          end,
          open_file_remote = function(picker, item)
            require("utils.snacks_actions").open_file_remote(picker, item)
          end,
          open_mr = function(picker, item)
            require("utils.snacks_actions").open_mr(picker, item)
          end,
          remove_qf_item = function(picker, item)
            require("utils.snacks_actions").remove_qf_item(picker, item)
          end,
          test_picker = function(picker, item)
            -- Debug action to inspect picker items
            vim.notify("Item: " .. vim.inspect(item), vim.log.levels.INFO)
            picker:close()
          end,
          toggle_diffpreview_alt = editor_keymaps.helpers.toggle_diffpreview_alt,
          my_diff_compare = function(picker, item, action)
            require("utils.snacks_actions_wip").my_diff_compare(picker, item, action)
          end,
          toggle_cwd_files_grep = function(picker, item)
            require("utils.snacks_terminal").toggle_cwd_files_grep(picker, item)
          end,
          toggle_files_buffers = function(picker, item)
            require("utils.snacks_actions").toggle_files_buffers(picker, item)
          end,
          increase_picker_depth = function(picker, item)
            require("utils.snacks_terminal").adjust_picker_depth(picker, item, 1)
          end,
          decrease_picker_depth = function(picker, item)
            require("utils.snacks_terminal").adjust_picker_depth(picker, item, -1)
          end,
          reset_picker_depth = function(picker, item)
            require("utils.snacks_terminal").adjust_picker_depth(picker, item, 0)
          end,
        }), -- Close vim.tbl_extend for actions
        -- Import common win settings from editor_keymaps
        win = editor_keymaps.sources_n_keys.common,
      },
      -- https://github.com/folke/snacks.nvim/blob/main/docs/gitbrowse.md
      gitbrowse = {
        url_patterns = {
          ["gitlab%..*"] = {
            branch = "/-/tree/{branch}",
            file = "/-/blob/{branch}/{file}#L{line_start}-L{line_end}",
            permalink = "/-/blob/{commit}/{file}#L{line_start}-L{line_end}",
            commit = "/-/commit/{commit}",
          },
        },
      },
    },
    keys = editor_keymaps.keymaps.snacks,
  },
  {
    "ThePrimeagen/harpoon",
    keys = editor_keymaps.keymaps.harpoon,
  },
  --#endregion Files / Search
  --
  {
    "folke/which-key.nvim",
    optional = true,
    opts = {
      icons = {
        -- ref: https://github.com/folke/which-key.nvim/blob/3aab2147e74890957785941f0c1ad87d0a44c15a/lua/which-key/icons.lua#L55
        -- search glxyphs: https://nerdfonts.ytyng.com/
        rules = {
          { pattern = "avante", icon = " ", color = "green" },
          { pattern = "sidekick", icon = " ", color = "blue" },
          { pattern = "overseer", icon = "󰙵 ", color = "cyan" },
          { pattern = "lsp", icon = "", color = "blue" },
          -- { pattern = "%f[%a]ai", icon = " ", color = "green" },
        },
      },
      ---@type wk.Spec
      spec = vim.list_extend({
        -- overides key desc
        {
          "<leader>as",
          desc = "Select sidekick CLI",
          -- icon = { icon = " ", color = "orange" }
        },
        {
          "<leader>ad",
          desc = "Detach sidekick",
        },
        {
          "<leader>at",
          mode = { "x", "n" },
          desc = "Add ref to sidekick",
        },
        {
          "<leader>af",
          desc = "Add file sidekick",
        },
        {
          "<leader>aV",
          mode = { "x" },
          desc = "Add text sidekick",
        },
        -- end overides key desc
        { "<localleader>a", group = "ai" },
        {
          "gG",
          group = "web",
          mode = { "n", "v" },
          icon = { icon = "🌐", color = "blue" },
        },
        {
          "<localleader>g",
          group = "Git",
          mode = { "n" },
          icon = { icon = "", color = "black" },
        },
        {
          "<localleader>c",
          group = "file/dir",
          mode = { "n" },
          icon = { icon = "📂", color = "black" },
        },
        {
          "<localleader>f",
          group = "file/find",
          mode = { "n" },
          icon = { icon = "📂", color = "black" },
        },
        {
          "<localleader>r",
          group = "code/lsp/lua",
          mode = { "n" },
          icon = { icon = "💻", color = "black" },
        },
        -- Avante model selection groups
        {
          "<leader>rs",
          -- group = "avante",
          desc = "pick Avante models",
          mode = { "n", "x", "v" },
          -- icon = { icon = " ", color = "green" },
        },
        {
          "<leader>rS",
          desc = "pick Avante custom models",
          mode = { "n", "x", "v" },
        },
      }, isSnackEnabled and {
        {
          "<leader>L",
          group = "linter/lsp",
          mode = { "n" },
          icon = { color = "black" },
        },
        {
          "<leader>" .. keyutil.key_f,
          group = "Find(Fzf)",
          mode = { "n" },
          icon = { icon = "", color = "black" },
        },
        {
          "<leader>" .. keyutil.key_g,
          group = "Git(Fzf)",
          mode = { "n", "v" },
          icon = { icon = "", color = "black" },
        },
        {
          "<leader>" .. keyutil.key_s,
          group = "Search(Fzf)",
          mode = { "n", "v" },
          icon = { icon = "", color = "black" },
        },
      } or {}),
    },
  },
  -- {
  --   "glepnir/lspsaga.nvim",
  --   keys = {
  --     -- Scroll hover definition while insert - use C-f,b use normal mode the <leader> lh + lh instead
  --     -- below mapping also works but open new preview window for saga and can't continue with the auto cmp
  --     -- { "<C-p>", "<cmd>Lspsaga hover_doc<CR>", desc = "Hover Doc", mode = "i" },
  --   },
  -- },
  --#region LSP and Formatting
  {
    "stevearc/conform.nvim",
    -- ../conform.lua | https://github.com/stevearc/conform.nvim/blob/master/doc/recipes.md#format-command
    -- npm i -g eslint_d # duplicated when used with eslint and cant seems format or use codfe actions like eslint ?
    opts = {
      -- log_level = vim.log.levels.DEBUG -- TRACE will see each line but still not see more LSP format info
      formatters_by_ft = {
        sh = { "shfmt" },
        ["javascript"] = { "biome", "deno_fmt", "prettier", "prettierd", "dprint", stop_after_first = true },
        ["javascriptreact"] = function(bufnr)
          return {
            "rustywind",
            first(bufnr, "biome", "deno_fmt", "prettier", "prettierd", "dprint"),
          }
        end,
        ["typescript"] = { "biome", "deno_fmt", "prettier", "prettierd", "dprint", stop_after_first = true },
        -- ["typescript"] = { lsp_format = "prefer", "biome", "deno_fmt", "prettier", "prettierd", "dprint", stop_after_first = true },
        ["typescriptreact"] = function(bufnr)
          return {
            "rustywind",
            first(bufnr, "biome", "deno_fmt", "prettier", "prettierd", "dprint"),
          }
        end,
      },
      default_format_opts = {
        lsp_format = vim.g.lsp_format_mode or "fallback",
      },
      format_on_save = function(bufnr)
        -- Disable with a global or buffer-local variable
        if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
          return
        end
        return { timeout_ms = 500, lsp_format = vim.g.lsp_format_mode or "fallback" }
      end,
    },
  },
  -- required to add avante cmp sources
  {
    "saghen/blink.compat",
    -- use v2.* for blink.cmp v1.*
    version = "2.*",
    -- lazy.nvim will automatically load the plugin when it's required by blink.cmp
    lazy = true,
    -- make sure to set opts so that lazy.nvim calls blink.compat's setup
    opts = {},
  },
  -- codecompanion https://www.reddit.com/r/neovim/comments/1hhmoxm/comment/m2w1utu/?utm_source=share&utm_medium=web3x&utm_name=web3xcss&utm_term=1&utm_content=share_button
  {
    "saghen/blink.cmp",
    opts = {
      signature = {
        -- key works but now get duplicate overlay another ui conflict
        -- when disalbe noice no issue
        enabled = false,
        window = {
          show_documentation = false, -- https://cmp.saghen.dev/configuration/signature
        },
      },
      keymap = {
        -- https://cmp.saghen.dev/configuration/keymap.html
        -- 'c-e' by default remove autocomplete
        -- disable from main coding.ai then trigger only when change from normal mode
        -- does not allow to have K + K to jump to preview like noice but has preview scroll c-f,b
        -- but why get map by inital vim.lsp.buf ??
        -- ["K"] = { "show_documentation"}
        ["<C-c>"] = {
          function(cmp)
            if cmp.is_visible() then
              return cmp.show { providers = { "copilot" } }
            else
              return
            end
          end,
          "fallback",
        },
      },
      sources = {
        -- default = {
        --     "avante_commands", "avante_mentions", "avante_files"
        --     -- ,"codecompanion"
        --   },
        providers = {
          -- codecompanion = {
          --   name = "codecompanion",
          --   module = "blink.compat.source",
          --   score_offset = 1000, -- show at a higher priority than lsp
          -- },
          avante_commands = {
            name = "avante_commands",
            module = "blink.compat.source",
            score_offset = 1000, -- highest priority - show commands first
            opts = {},
          },
          avante_mentions = {
            name = "avante_mentions",
            module = "blink.compat.source",
            score_offset = 900, -- high priority - show mentions second
            opts = {},
          },
          avante_files = {
            name = "avante_files", -- FIXED: was incorrectly set to "avante_commands"
            module = "blink.compat.source",
            score_offset = 800, -- medium-high priority - show files third
            opts = {},
          },
        },
        per_filetype = {
          -- check ft with set filetype
          -- AvantePromptInput = { inherit_defaults = true },
          -- AvanteInput = { inherit_defaults = true, "avante_commands", "avante_mentions", "avante_files" },
          AvanteInput = { inherit_defaults = true, "avante_commands", "avante_mentions", "avante_files" },
          -- lua = { inherit_defaults = true, 'lazydev' } } -- defaults https://github.com/Saghen/blink.cmp/blob/e7cdf1ac0be3acfce2a718bc921768ac747db5d9/doc/configuration/sources.md?plain=1#L23
        },
      },
    },
  },
  --#endregion LSP and Formatting
  --#region Code edition
  -- handle conflict with surround
  {
    "folke/flash.nvim",
    keys = editor_keymaps.keymaps.flash,
  },
  {
    "kylechui/nvim-surround",
    vscode = true,
    version = "^3.0.0", -- Use for stability; omit to use `main` branch for the latest features
    event = "VeryLazy",
    config = function()
      require("nvim-surround").setup {
        -- https://github.com/kylechui/nvim-surround/blob/main/lua/nvim-surround/config.lua
        keymaps = {
          visual = "s",
          -- visual_line = "gS",
          -- visual_line = "gs",
        },
        -- Configuration here, or leave empty to use defaults
      }
    end,
  },
  -- #endregion Code edition
  -- { import = "plugins.extra.copilot-chat-v2" },
  -- {
  --   "neovim/nvim-lspconfig",
  --   opts = {
  --     servers = {
  --       vtsls = {
  --         root_dir = require("lspconfig.util").root_pattern(".git"),
  --         --   local bufPath = vim.api.nvim_buf_get_name(0)
  --         -- local cwd = require("lspconfig").util.root_pattern(".git")(bufPath)
  --       },
  --       biome = {
  --         -- root_dir = require("lspconfig.util").root_pattern(".git"),
  --         root_dir = function()
  --           if Lsp.biome_config_exists() then
  --             print("biome_config_exists")
  --             return Lsp.biome_config_path()
  --           end
  --           print("biome not exist in dir")
  --           -- add option to copy biome config v
  --           require("utils.lsp_setup")
  --           -- else copied content from the config to the current gitdir
  --           -- vim.fn.mkdir(pathUtil.biome_config_path(), "p")
  --           -- vim.fn.writefile({ "biome.json" }, pathUtil.biome_config_path() .. "/biome_config")
  --           -- return vim.fn.stdpath("config")
  --         end,
  --       },
  --     },
  --   },
  -- },
  -- { import = "plugins.extra.myImage" }, -- create too many sticky image render without removing
  { import = "plugins.extra.myNoice" },
}
