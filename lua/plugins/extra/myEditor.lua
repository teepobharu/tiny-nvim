local pathUtil = require "utils.mypath"
local gitUtil = require "utils.git"
local keyutil = require "utils.keyutil"
local editor_keymaps = require "utils.editor_keymaps"
local avante_utils   = require "utils.my_avante_utils"

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
      -- log_level = "ERROR", -- TRACE|DEBUG|ERROR|INFO not work
      -- [WARN] above not help disable textmsg: CodeCompanion.nvim will experience breaking changes soon. Pin to version v17.33.0 or earlier to avoid this.
      -- https://codecompanion.olimorris.dev/configuration/chat-buffer
      strategies = {
        chat = {
          slash_commands = {
            ["buffer"] = {
              -- docs: initial snacks config wrong https://github.com/olimorris/codecompanion.nvim/blob/8ad65eef735b31bb47d76f59d878ee1bac4bdc85/lua/codecompanion/strategies/chat/slash_commands/init.lua#L100
              callback = "strategies.chat.slash_commands.catalog.buffer",
              -- description = "Insert open buffers",
              opts = {
                -- contains_code = true,
                provider = "snacks", -- default|telescope|mini_pick|fzf_lua
              },
            },
            ["file"] = {
              callback = "strategies.chat.slash_commands.catalog.file",
              description = "Insert a file",
              opts = {
                -- contains_code = true,
                -- max_lines = 1000,
                provider = "snacks", -- telescope|mini_pick|fzf_lua
              },
            },
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
        -- will work only when open new chat with the action cmd else not change model while there is prompt
        ["Model GPT mini 5 - G5"] = {
          strategy = "chat",
          opts = {
            adapter = {
              name = "copilot",
              model = "gpt-5-mini",
            },
            is_slash_cmd = true,
            short_name = "gpt5mini_g5m_gfree",
            stop_context_insertion = true,
          },
          prompts = {
            {
              role = "user",
              content = ""
            }
          },
        },
        ["Codecompanion Context"] = {
          strategy = "chat",
          description = "Write documentation for me",
          opts = {
            index = 11,
            adapter = {
              name = "copilot",
              model = "gpt-5-mini",
            },
            is_slash_cmd = true,
            auto_submit = false,
            short_name = "codecompanion_nvim_context",
            stop_context_insertion = true,
          },
          context = {
            {
              type = "file",
              path = {
                -- expand HOME
                vim.fn.expand("$HOME/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/extra/myEditor.lua")
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
          strategy = "chat",
          description = "Write documentation for me",
          opts = {
            index = 11,
            adapter = {
              name = "copilot",
              model = "gpt-5-mini",
            },
            is_slash_cmd = true,
            auto_submit = false,
            short_name = "snacks_nvim_context",
            stop_context_insertion = true,
          },
          context = {
            {
              type = "file",
              path = {
                -- expand HOME
                vim.fn.expand("$HOME/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/extra/myEditor.lua")
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
          strategy = "chat",
          description = "Write documentation for me",
          opts = {
            index = 11,
            adapter = {
              name = "copilot",
              model = "gpt-5-mini",
            },
            is_slash_cmd = true,
            auto_submit = false,
            short_name = "snacks_nvim_context",
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
          strategy = "chat",
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

                local attachref=""
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
          ]]
          }
          },
        },
        -- overrides the prompt frmo jellydn to
        ["Generate a Commit Message for Staged Short"] = {
          strategy = "chat",
          description = "Generate a commit message for staged change",
          opts = {
            short_name = "short-staged-commit",
            auto_submit = true,
            is_slash_cmd = true,
            adapter = {
              name = "copilot",
              model = "gpt-5-mini", -- slower but more complete than gpt-4.1 ?
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
                  ]] .. "\n\n```\n"
                  .. vim.fn.system("git diff --staged")
                  .. "\n```"
              end,
              opts = {
                contains_code = true,
              },
            },
          },
        },
        -- sample workflow: https://codecompanion.olimorris.dev/extending/workflows
        ["Setup Test Example"] = {
          strategy = "workflow",
          description = "My workflow",
          opts = {
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
      -- provider = "copilot", -- You can then change this provider here
      provider = "openai_agd", -- You can then change this provider here
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
      }, avante_utils.get_agoda_providers()),

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
        sources = {
          -- sample pickers: https://github.com/WizardStark/dotfiles/blob/main/home/.config/nvim/lua/workspaces/ui.lua#L417
          -- buffers and file to use tooggle key map when press c-space
          files = {
            hidden = true,
            win = {
              input = {
                keys = {
                  ["<C-space>"] = { "toggle_files_buffers", mode = { "n", "i" }, desc = "Toggle File/Buffer" },
                  ["<C-o>"] = { "open_file_remote", mode = { "n", "i" }, desc = "Open File Remote" },
                  ["<A-s>"] = { "toggle_cwd_files_grep", mode = { "n", "i" }, desc = "Cycle CWD Scope" },
                },
              },
            },
          },
          buffers = {
            win = {
              input = {
                keys = {
                  ["<C-space>"] = { "toggle_files_buffers", mode = { "n", "i" }, desc = "Toggle File/Buffer" },
                  ["<C-o>"] = { "open_file_remote", mode = { "n", "i" }, desc = "Open File Remote" },
                  ["<A-s>"] = { "toggle_cwd_files_grep", mode = { "n", "i" }, desc = "Cycle CWD Scope" },
                },
              },
            },
          },
          git_branches = {
            win = {
              input = {
                keys = {
                  ["<C-s>"] = { "my_diff_compare", mode = { "n", "i" }, desc = "Open Diff" },
                  ["<C-t>"] = { "test_picker", mode = { "n", "i" }, desc = "Test picker" },
                  ["<C-o>"] = { "open_file_remote", mode = { "n", "i" }, desc = "Open File Remote" },
                  ["f6"] = { "toggle_diffpreview_alt", mode = { "n", "i" }, desc = "Toggle Delta Mode" },
                  ["<C-g>"] = { "open_mr", mode = { "n", "i" }, desc = "Open Merge Request" },
                },
              },
            },
          },
          git_files = {
            win = {
              input = {
                keys = {
                  ["<C-o>"] = { "open_file_remote", mode = { "n", "i" }, desc = "Open File Remote" },
                },
              }
            },
          },
          git_log = {
            win = {
              input = {
                keys = {
                  ["<C-s>"] = { "my_diff_compare", mode = { "n", "i" }, desc = "Open Diff" },
                  ["f6"] = { "toggle_diffpreview_alt", mode = { "n", "i" }, desc = "Toggle Delta Mode" },
                  ["<C-t>"] = { "test_picker", mode = { "n", "i" }, desc = "Test picker" },
                },
              },
            },
          },
          qflist = {
            win = {
              input = {
                keys = {
                  ["<C-x>"] = { "remove_qf_item", mode = { "n", "i" }, desc = "Remove QF Item" },
                  ["<A-s>"] = { "toggle_cwd_files_grep", mode = { "n", "i" }, desc = "Cycle CWD Scope" },
                },
              },
            },
          },
          grep = {
            win = {
              input = {
                keys = {
                  ["<C-x>"] = { "remove_qf_item", mode = { "n", "i" }, desc = "Remove QF Item" },
                  ["<A-s>"] = { "toggle_cwd_files_grep", mode = { "n", "i" }, desc = "Cycle CWD Scope" },
                },
              },
            },
          },
          grep_word = {
            win = {
              input = {
                keys = {
                  ["<A-s>"] = { "toggle_cwd_files_grep", mode = { "n", "i" }, desc = "Cycle CWD Scope" },
                },
              },
            },
          },
        },
        actions = {
          open_file_remote = function(picker, item)
            local preview_source = picker.init_opts and picker.init_opts.source

            local current_buf_path = editor_keymaps.helpers.get_current_buffer_path()
            local last_bufferpath = vim.api.nvim_buf_get_name(vim.fn.bufnr("#"))

            local chosen_path = item._path
            if not chosen_path or chosen_path == "" then
              if current_buf_path and current_buf_path ~= "" then
                chosen_path = current_buf_path
              else
                chosen_path = last_bufferpath
              end
            end

            local filepath = pathUtil.get_git_real_filepath(chosen_path)

            local ref = item.branch or item.commit
            if not ref then
              if preview_source == "git_files" then
                ref = gitUtil.get_current_git_branch()
              elseif preview_source == "files" or preview_source == "buffers" then
                ref = nil
              else
                vim.notify("No reference found for this item", vim.log.levels.WARN)
              end
            end

            require('utils.git').open_remote(ref, "file", filepath)
          end,
          open_mr = function(picker, item)
            local branch = item.branch
            if not branch then
              vim.notify("No branch found for this item", vim.log.levels.WARN)
              return
            end
            gitUtil.open_mr(branch)
          end,

          remove_qf_item = function(picker, item)
            if not item then
              return
            end

            -- Get current quickfix list
            local qflist = vim.fn.getqflist()

            if #qflist == 0 then
              vim.notify("Quickfix list is empty. Send items to quickfix with <A-q> first.", vim.log.levels.WARN)
              return
            end

            -- For grep results, we need to match by file, line, and text
            -- For qflist items, we can use the index
            local idx = item.idx

            if idx and idx > 0 and idx <= #qflist then
              -- Direct index match (works for qflist picker)
              table.remove(qflist, idx)
              vim.fn.setqflist(qflist, "r")
              picker:refresh()
            else
              -- Try to find by matching file, line, and column (works for grep picker)
              local removed = false
              for i = #qflist, 1, -1 do
                local qf_item = qflist[i]
                local qf_file = qf_item.filename or (qf_item.bufnr and vim.api.nvim_buf_get_name(qf_item.bufnr))
                local item_file = item.file or item.filename

                if qf_file == item_file and qf_item.lnum == item.lnum then
                  -- Additional check for column if available
                  if not item.col or qf_item.col == item.col then
                    table.remove(qflist, i)
                    removed = true
                    break
                  end
                end
              end

              if removed then
                vim.fn.setqflist(qflist, "r")
                picker:refresh()
              else
                vim.notify("Could not find item in quickfix list", vim.log.levels.WARN)
              end
            end
          end,
          test_picker = function(picker, item)
            -- Debug action to inspect picker items
            vim.notify("Item: " .. vim.inspect(item), vim.log.levels.INFO)
            picker:close()
          end,
          toggle_diffpreview_alt = editor_keymaps.helpers.toggle_diffpreview_alt,
          my_diff_compare = function(picker, item, action)
            -- Get the selected reference from the picker
            local ref = item.branch or item.commit

            if not ref then
              local git_default = "master"
              ref = git_default
              vim.notify("No reference found, using default: " .. git_default, vim.log.levels.WARN)
            end

            picker:close() -- Close picker first

            -- Use the helper function to open current buffer with diff
            editor_keymaps.helpers.open_current_buffer_with_gitsigns_diff(ref)
          end,
          toggle_cwd_files_grep = function(picker, item)
            require("utils.snacks_terminal").toggle_cwd_files_grep(picker, item)
          end,
          toggle_files_buffers = function(picker, item)
            local preview_source = picker.init_opts and picker.init_opts.source
            if not preview_source then
              vim.notify("Error: picker.init_opts is nil", vim.log.levels.ERROR)
              return
            end

            local current_search = picker.input.filter and picker.input.filter.pattern
            ---@type snacks.picker.Config
            local picker_params = {
              pattern = current_search or "",
            }

            -- Helper to get toggle state (clean, no override logic)
            local function get_toggle_state(name)
              -- First check picker.opts (runtime state)
              if picker.opts[name] ~= nil then
                return picker.opts[name]
              end
              -- Fall back to init_opts (initial state)
              if picker.init_opts and picker.init_opts[name] ~= nil then
                return picker.init_opts[name]
              end
              return nil
            end

            if preview_source == "files" then
              picker_params.hidden = false
              Snacks.picker.buffers(picker_params)
              vim.defer_fn(function()
                if vim.api.nvim_get_mode().mode == "n" then
                  vim.cmd "startinsert"
                end
              end, 50)
            else
              -- Switching from buffers to files
              -- For files: persist both hidden and ignored states
              local hidden_state = get_toggle_state("hidden")
              local ignored_state = get_toggle_state("ignored")

              if hidden_state ~= nil then
                picker_params.hidden = hidden_state
              end
              if ignored_state ~= nil then
                picker_params.ignored = ignored_state
              end

              Snacks.picker.files(picker_params)
            end
            -- Snacks.picker.actions.insert(picker) -- nothing
            -- Snacks.picker.actions.toggle_focus(picker) -- not help sometimes still show
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
        },
        -- win : overrides here does not really work - not sure why
        win = {
          list = {
            keys = {
              ["<C-p>"] = { "focus_preview", desc = "Focus Preview" },
              ["0"] = { "focus_preview", desc = "Focus Preview" },
              -- make consistent as FZFlua
              ["<c-a>"] = { "sidekick_send", mode = { "n", "i" } },
              ["<a-a>"] = { "select_all", mode = { "n", "i" } },
              ["<a-q>"] = { "qflist", mode = { "n", "i" } },
              ["<c-q>"] = "cancel",
            },
          },
          input = {
            keys = {
              -- ["="] = "toggle_focus",
              -- ["<C-i>"] = "toggle_focus",
              ["<C-p>"] = { "focus_preview", desc = "Focus Preview" },
              ["0"] = { "focus_preview", mode = { "n" }, desc = "Focus Preview" },
              -- make consistent as FZFlua
              ["<c-a>"] = { "sidekick_send", mode = { "n", "i" } },
              ["<a-a>"] = { "select_all", mode = { "n", "i" } },
              ["<a-q>"] = { "qflist", mode = { "n", "i" } },
              ["<c-q>"] = "cancel",
              ["<M-=>"] = { "increase_picker_depth", mode = { "n", "i" }, desc = "Increase search depth" },
              ["<M-->"] = { "decrease_picker_depth", mode = { "n", "i" }, desc = "Decrease search depth" },
              ["<M-0>"] = { "reset_picker_depth", mode = { "n", "i" }, desc = "Reset search depth" },
            },
          },
          preview = {
            keys = {
              ["<c-q>"] = "cycle_win",
            },
          },
        },
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
  --#region AI Assistants
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
