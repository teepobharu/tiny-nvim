local pathUtil = require "utils.mypath"
local gitUtil = require "utils.git"
local keyutil = require "utils.keyutil"

local isSnackEnabled = keyutil.isSnackEnabled
local key_f = keyutil.key_f
local key_s = keyutil.key_s
local key_g = keyutil.key_g
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

local mapping_key_prefix = vim.g.ai_prefix_key or "<leader>A" -- orginal from codecompanion.lua

local function fzfcompareref(selected)
  local ok, gitsigns = pcall(require, "gitsigns")
  if not ok then
    vim.notify("Gitsigns is not available", vim.log.levels.ERROR)
    return
  end
  -- Extract branch/commit reference from selected line
  -- Format examples:
  --   remotes/origin/TRIPWEB-2627       a9020d5785 refactor: ...
  --   main                              b1234567   feat: ...
  --   feature/my-branch                 c9876543   fix: ...
  local line = selected[1]
  local commit_hash

  -- Try to match remote branch: "remotes/origin/BRANCH_NAME"
  -- Strip "remotes/" prefix and use "origin/BRANCH_NAME"
  local remote_ref = line:match("^remotes/(.-)%s+")
  if remote_ref then
    commit_hash = remote_ref
  else
    -- Try to match local branch or commit hash (everything before first whitespace)
    commit_hash = line:match("^(%S+)")
  end

  print([==["ctrl-s" commit_hash:]==], vim.inspect(commit_hash)) -- __AUTO_GENERATED_PRINT_VAR_END__
  local file_path = vim.fn.expand "%:p"
  vim.cmd("tabnew " .. file_path)
  gitsigns.diffthis(commit_hash, { vertical = true })
end

local function toggle_diffpreview_alt()
  -- Toggle delta.side-by-side in ~/.gitconfig.local
  local gitconfig_file = os.getenv "HOME" .. "/.gitconfig.local"
  local handle = io.popen('git config -f "' .. gitconfig_file .. '" delta.side-by-side')
  local is_side_side_enabled = handle:read "*a"
  handle:close()
  is_side_side_enabled = is_side_side_enabled:gsub("%s+", "")

  if is_side_side_enabled == "true" then
    print "side-by-side disabled"
    os.execute('git config -f "' .. gitconfig_file .. '" delta.side-by-side false')
  else
    print "side-by-side enabled"
    os.execute('git config -f "' .. gitconfig_file .. '" delta.side-by-side true')
  end
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
    opts = {
      -- default_file_explorer = false,
    },
    keys = {
      -- disabled <leader-e> key
      {
        "<leader>e",
        false,
      },
      {
        "<leader>fO",
        function()
          require("oil").toggle_float()
        end,
        desc = "Open OIL explorer",
      },
    },
  },
  {
    "stevearc/overseer.nvim",
    -- tutorials : https://github.com/stevearc/overseer.nvim/blob/master/doc/tutorials.md#run-a-file-on-save
    -- support on vscode tasks ?
    -- template syntax: https://github.com/stevearc/overseer.nvim/blob/master/doc/reference.md
    --  form: https://github.com/stevearc/overseer.nvim/blob/fe7b2f9ba263e150ab36474dfc810217b8cf7400/lua/overseer/form/utils.lua#L49
    keys = {
      {
        "<leader>ow",
        function()
          local overseer = require "overseer"
          overseer.run_template({ name = "run script" }, function(task)
            if task then
              task:add_component { "restart_on_save", paths = { vim.fn.expand "%:p" } }
              local main_win = vim.api.nvim_get_current_win()
              overseer.run_action(task, "open vsplit")
              vim.api.nvim_set_current_win(main_win)
            else
              vim.notify("WatchRun not supported for filetype " .. vim.bo.filetype, vim.log.levels.ERROR)
            end
          end)
        end,
        desc = "WatchRun overseer",
      },
      {
        "<leader>oR",
        function()
          local overseer = require "overseer"
          local tasks = overseer.list_tasks { recent_first = true }
          if vim.tbl_isempty(tasks) then
            vim.notify("No tasks found", vim.log.levels.WARN)
          else
            -- Store tasks in a lookup table by index
            local task_lookup = {}
            local items = {}
            for i, task in ipairs(tasks) do
              task_lookup[i] = task
              table.insert(items, {
                text = task.name,
                task_idx = i,
              })
            end

            Snacks.picker.pick {
              source = "select",
              title = "Rerun Task",
              items = items,
              format = "text",
              actions = {
                confirm = function(picker, item)
                  if item and item.task_idx then
                    local task = task_lookup[item.task_idx]
                    picker:close()
                    overseer.run_action(task, "restart")
                  end
                end,
                ["<c-x>"] = function(picker, item)
                  if item and item.task_idx then
                    local task = task_lookup[item.task_idx]
                    overseer.run_action(task, "dispose")
                    picker:close()
                  end
                end,
              },
            }
          end
        end,
        desc = "Select Rerun Task overseer",
      },

      {
        "<leader>oT",
        ":OverseerTaskAction<CR>", -- Add the command you want to run here
        desc = "Run Task Action overseer",
      },
      {
        "<leader>oQ",
        ":OverseerDeleteBundle<CR>",
        desc = "Delete Bundle overseer",
      },
      {
        "<leader>oC",
        ":OverseerClearCache<CR>",
        desc = "Clear Cache overseer",
      },
      {
        "<leader>os",
        ":OverseerSaveBundle<CR>",
        desc = "Save Bundle overseer",
      },
      {
        "<leader>ol",
        ":OverseerLoadBundle<CR>",
        desc = "Load Bundle overseer",
      },
      {
        "<leader>on",
        ":OverseerBuild<CR>",
        desc = "New Task overseer",
      },
    },
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
    keys = {
      {
        "<C-q>",
        false,
      },
    },
  },

  -- [Image](/Users/tharutaipree/dotfiles/.config/nvim3_jelly_tinynvim/assets/2025-09-06-23-28-21.png)
  -- image support for code companion , requires pngpaste , brew install pngpaste https://github.com/jcsalterego/pngpaste
  {
    "HakonHarnes/img-clip.nvim",
    event = "VeryLazy",
    keys = {
      -- suggested keymap
      { "<leader>iv", "<cmd>PasteImage<cr>", desc = "Paste image from system clipboard" },
    },
    -- command = { "PasteImage" },
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
    "greggh/claude-code.nvim",
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
    keys = {
      {
        mapping_key_prefix .. "a",
        "<cmd>CodeCompanionAction<cr>",
        desc = "Code Companion - actions",
        mode = "v",
      },
      {
        mapping_key_prefix .. "A",
        "<cmd>CodeCompanionChat Add<cr>",
        desc = "Code Companion - Add selected",
        mode = "v",
      },
      {
        mapping_key_prefix .. "V",
        -- "<cmd>CodeCompanionChat Toggle<cr>",
        "<cmd>CodeCompanionChat<cr>", -- will add selected input and toggle
        desc = "Code Companion - Add and Toggle",
        mode = "v",
      },
      { mapping_key_prefix .. "v", "<cmd>CodeCompanionChat<cr>", mode = "v" }, -- not sure why not override

      {
        mapping_key_prefix .. "q",
        "<cmd>CodeCompanionChat<cr>",
        desc = "Code Companion - Chat",
        mode = "v",
      },
      {
        mapping_key_prefix .. "Q",
        function()
          vim.cmd "CodeCompanion"
        end,
        desc = "Code Companion - Quick chat",
        mode = "v",
      },
    },
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
        -- overrides the prompt frmo jellydn to
        ["Generate a Commit Message for Staged"] = {
          strategy = "chat",
          description = "Generate a commit message for staged change",
          opts = {
            short_name = "staged-commit",
            auto_submit = false,
            is_slash_cmd = true,
          },
          prompts = {
            {
              role = "user",
              content = function()
                return "Write commit message for the change with commitizen convention. Write concise and clear, informative commit messages that explain the 'what' and 'why' behind changes, not just the 'how'. Add bullet points of changes in description of commit message under the main commit message (with only 1 line break)"
                  .. [[
feat(release): add slack msg and create release after deploy
- Enhance GitLab CI release job:
- Update dependency job name to `buckbeak-deploy-prod-tripviewbff` for clarity.
- Add detailed release description with deploy time, package version, rollback pipeline, quick deploy link, and changelog.
- Include direct release link in Slack notifications for better traceability.
- Update README:
- Expand "Clone repo" section to "Clone and Overview" with folder structure, cloning instructions, and IDE setup steps.
- Provide clearer onboarding for new contributors.
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
  },
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    enabled = true,
    keys = {
      {
        "<localleader>aE",
        "<cmd>CopilotChatBuffEdit<cr>",
        desc = "~ Copilot Chat Buf Edit ",
      },
    },
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
      web_search_engine = {
        -- provider = "tavily", -- tavily, serpapi, google, kagi, brave, or searxng
        provider = "google", 
      },
      providers = {
        -- not sure why not work yet
        copilot = {
          model = "gpt-5-mini",
        },
        openai = {
          endpoint = "http://openai-proxy.agoda.is",
          model = "gpt-5-mini",
          timeout = 30000, -- Timeout in milliseconds
          extra_request_body = {
            temperature = 0,
            max_completion_tokens  = 4096,
          },
        },
        -- bedrock = {
        --   endpoint = "https://genai-gateway.agoda.is/claude",
        --   -- model = "claude-sonnet-4-20250514",
        --   model = "global.anthropic.claude-sonnet-4-5-20250929-v1:0",
        --   timeout = 30000, -- Timeout in milliseconds
        --   disable_tools = true, -- disable tools!
        --   extra_request_body = {
        --     temperature = 0,
        --     max_tokens = 4096,
        --   }
        -- },
      },
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
  },
  {
    "jellydn/quick-code-runner.nvim",
    keys = {
      {
        "<leader>cP",
        function()
          require("utils.cmd").quickCommandRunCurrentFile()
        end,
        --     -- "gg0vGg$:QuickCodeRunner<CR>",
        desc = "Code Run File",
        mode = "n",
        },
      },
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
    opts = {
      git = {
        branches = {
          -- add actions that open remote the the file at current line remotely
          actions = {
            ["ctrl-o"] = function(selected)
              local ref = selected[1]:match "[^%w_]+(.*)$" -- Extract only the 'ref' part after special characters and space prefixes
              ref = ref:match "^(%S+)" -- Get the first word which is the ref
              open_remote(ref, "file")
              open_remote(ref, "branch")
            end,
            ["ctrl-s"] = fzfcompareref,
            ["ctrl-g"] = function(selected)
              -- Open merge request for selected branch
              local ref = selected[1]:match "[^%w_]+(.*)$" -- Extract only the 'ref' part after special characters and space prefixes
              ref = ref:match "^(%S+)" -- Get the first word which is the ref
              -- __AUTO_GENERATED_PRINT_VAR_START__
              gitUtil.open_mr(ref)
            end,
          },
        },
        bcommits = {
          actions = {
            ["ctrl-o"] = function(selected)
              -- Custom action to open remote file
              local commit_hash = selected[1]:match "%w+"
              open_remote(commit_hash, "file")
              open_remote(commit_hash, "commit")
            end,
            ["ctrl-s"] = fzfcompareref,
            ["f6"] = toggle_diffpreview_alt,
          },
        },
        blame = {
          actions = {
            ["ctrl-o"] = function(selected)
              -- Custom action to open remote file
              local commit_hash = selected[1]:match "%w+"
              open_remote(commit_hash, "file")
              open_remote(commit_hash, "commit")
            end,
            ["ctrl-s"] = fzfcompareref,
            ["f6"] = toggle_diffpreview_alt,
          },
        },
        commits = {
          actions = {
            -- ["default"] = function(selected)
            --   -- Default action (e.g., open commit diff)
            -- end,
            ["ctrl-o"] = function(selected)
              -- Custom action to open remote file
              local commit_hash = selected[1]:match "%w+"
              open_remote(commit_hash, "file")
              open_remote(commit_hash, "commit")
              -- local file_path = vim.fn.expand("%:p")
              -- local line_number = vim.fn.line(".")
              --
              -- local gitroot = pathUtil.get_git_root()
              -- local remote_path = gitUtil.get_remote_path("origin")
              -- local git_file_path = file_path:gsub(gitroot .. "/?", "")
              -- local url_pattern = "https://%s/blob/%s/%s#L%d"
              -- local url = string.format(url_pattern, remote_path, commit_hash, git_file_path, line_number)
              -- vim.fn.jobstart({ "open", url }, { detach = true })
              --
              -- vim.cmd("e " .. file_path)
            end,
            ["ctrl-s"] = fzfcompareref,
            ["f6"] = toggle_diffpreview_alt,
          },
        },
      },
    },
    keys = {
      -- opts.desc = "Git branch FZF"
      -- keymap("n", "<localleader>gO", function()
      --   require("config.telescope_pickers").fzf.pickers.open_git_pickers_telescope()
      -- end, opts)
      {
        "<leader>" .. key_g .. "S",
        "<cmd> :FzfLua git_blame<CR>",
        desc = "FZF Git Blame",
        mode = "n",
      },
      {
        "<leader>" .. key_g .. "o",
        function()
          require("config.telescope_pickers").fzf.pickers.open_git_pickers()
        end,
        desc = "Git branch FZF",
        mode = "n",
      },
      -- session_pickers leader-fS
      {
        "<leader>" .. key_f .. "s",
        function()
          require("config.telescope_pickers").fzf.pickers.session_picker()
        end,
        desc = "Session FZF",
      },
      -- session_pickers leader-fS
      {
        "<leader>" .. "f" .. "s",
        function()
          require("config.telescope_pickers").fzf.pickers.session_picker()
        end,
        desc = "Session FZF",
      },
    },
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
    keys = {
      { "<S-l>", "<Cmd>BufferLineCycleNext<CR>", desc = "Next Buffer" },
      { "<S-h>", "<Cmd>BufferLineCyclePrev<CR>", desc = "Prev Buffer" },
      { "<leader>bp", "<Cmd>BufferLineTogglePin<CR>", desc = "Toggle Pin" },
      { "<leader><Tab>r", ":BufferLineTabRename ", desc = "Rename Tab" },
      { "<leader>bs", ":BufferLineSortBy", desc = "Buffer Sort By.." },
      { "<leader>bsd", ":BufferLineSortByDirectory<CR>", desc = "Buffer Sort By Directory" },
      { "<leader>bse", ":BufferLineSortByExtension<CR>", desc = "Buffer Sort By Extension" },
      { "<leader>bsr", ":BufferLineSortByRelativeDirectory<CR>", desc = "Buffer Sort By Relative Directory" },
      { "<leader>bst", ":BufferLineSortByTabs<CR>", desc = "Buffer Sort By Tabs" },
      { "<leader>bg", ":BufferLinePick<CR>", desc = "Buffer Group Toggle Pin" },
      { "<leader>bup", ":BufferLineGroupToggle ungrouped<CR>", desc = "Buffer Group Toggle ungroup" },
      { "<leader>bup", ":BufferLineGroupToggle pinned<CR>", desc = "Buffer Group Toggle ungroup" },
      { "<leader>bcP", ":BufferLineGroupClose pinned<CR>", desc = "Buffer Close pin" },
      { "<leader>bcp", ":BufferLineGroupClose ungrouped<CR>", desc = "Buffer Close ungroup" },
    }
  },
  {
    "folke/persistence.nvim",
    opts = {
      dir = vim.fn.stdpath "state" .. "/my-sessions/", -- directory where session files are saved
    },
    keys = {
      {
        "<leader>qs",
        function()
          require("persistence").save()
        end,
        desc = "Save session",
      },
      {
        "<leader>ql",
        function()
          require("persistence").load { last = true }
        end,
        desc = "Restore last session",
      },
      {
        "<leader>qS",
        function()
          require("persistence").select()
        end,
        desc = "Select session to restore",
      },
      {
        "<leader>qd",
        function()
          require("persistence").stop()
        end,
        desc = "Stop persistence",
      },
    },
  },
  {
    "folke/trouble.nvim",
    keys = {
      {
        "<leader>xf",
        "<cmd>Trouble snacks_files<cr>",
        desc = "Trouble Snacks",
      },
    },
  },
  --#endregion Session and windows
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
                },
              },
            },
          },
          buffers = {
            win = {
              input = {
                keys = {
                  ["<C-space>"] = { "toggle_files_buffers", mode = { "n", "i" }, desc = "Toggle File/Buffer" },
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
                  ["f6"] = { "toggle_diffpreview_alt", mode = { "n", "i" }, desc = "Toggle Delta Mode" },
                  ["<C-g>"] = { "open_mr", mode = { "n", "i" }, desc = "Open Merge Request" },
                },
              },
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
                },
              },
            },
          },
          grep = {
            win = {
              input = {
                keys = {
                  ["<C-x>"] = { "remove_qf_item", mode = { "n", "i" }, desc = "Remove QF Item" },
                },
              },
            },
          },
        },
        actions = {
          open_mr = function(picker, item)
            print([==[ item:]==], vim.inspect(item)) -- __AUTO_GENERATED_PRINT_VAR_END__
            local branch = item.branch
            -- __AUTO_GENERATED_PRINT_VAR_START__
            print([==[open_mr branch:]==], vim.inspect(branch)) -- __AUTO_GENERATED_PRINT_VAR_END__
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
                print([==[remove_qf_item#if#for item:]==], vim.inspect(item)) -- __AUTO_GENERATED_PRINT_VAR_END__
                print([==[remove_qf_item#if#for qf_item:]==], vim.inspect(qf_item)) -- __AUTO_GENERATED_PRINT_VAR_END__
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
            print([==[ item:]==], vim.inspect(item)) -- __AUTO_GENERATED_PRINT_VAR_END__
            picker:close()
          end,
          toggle_diffpreview_alt = toggle_diffpreview_alt,
          my_diff_compare = function(picker, item, action)
            -- print([==[ item:]==], vim.inspect(item)) -- __AUTO_GENERATED_PRINT_VAR_END__
            -- Check if Gitsigns is available
            if not pcall(require, "gitsigns") then
              vim.notify("Gitsigns is not available", vim.log.levels.ERROR)
              return
            end
            -- Get the selected reference from the picker
            local ref = item.branch or item.commit
            vim.notify("diff ref=" .. vim.inspect(ref))

            if not ref then
              local git_default = "master"
              ref = git_default
              vim.notify("No reference compare with default", vim.log.levels.WARN)
            end

            picker:close() -- require this else not work
            vim.cmd "tabnew"
            vim.cmd "b#" -- switch to the previous buffer
            vim.cmd "bd#" -- delete the previous buffer (empty buffer)
            print([==[run my_diff_compare ref:]==], vim.inspect(ref)) -- __AUTO_GENERATED_PRINT_VAR_END__
            require("gitsigns").diffthis(ref, {
              vertical = true,
            })
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
    keys = {
      {
        "<leader>e",
        false,
      },
      -- {
      --   "<c-_>",
      --   false,
      -- },
      -- {
      --   "<c-]>",
      --   function()
      --     print("🔄 SNACKS TERMINAL CALLED FROM myEditor.lua")
      --     Snacks.terminal()
      --   end,
      --   desc = "Snacks Terminal"
      -- },
      -- "<C-_>" is same code as C-/ try use cat -v and type the key sequences to check
      {
        "<C-_>",
        function()
          Snacks.terminal()
        end,
        desc = "Snacks Terminal",
        mode = { "n", "v" },
      },
      -- Send current line to Snacks terminal
      {
        -- This universal fn tested and work
        -- Fixed: Now properly reuses existing terminals and handles count-based selection
        "<localleader>s",
        function()
          local count = vim.v.count > 0 and vim.v.count or nil
          local text = require("utils.input").getSelectedLines()
          require("utils.snacks_terminal").send_to_snacks_terminal(text, count)
        end,
        desc = "Send to Snacks terminal",
        mode = { "n", "v" },
      },
      {
        "<localleader>Sa",
        function()
          local count = vim.v.count > 0 and vim.v.count or nil
          require("utils.snacks_terminal").send_all_lines(count)
        end,
        desc = "Send all to Snacks terminal",
      },
      {
        "<localleader>Sr",
        function()
          local count = vim.v.count > 0 and vim.v.count or nil
          require("utils.snacks_terminal").send_previous_selection(count)
        end,
        desc = "Send previous selected to Snacks terminal",
      },
      {
        "<localleader>Ss",
        function()
          require("utils.snacks_terminal").custom_terminal_show()
        end,
        desc = "Snacks Terminal Picker",
        mode = { "n" },
      },
      -- { "<c-_>", function() vim.cmd(":ToggleTerm") end, desc = "ToggleTerm" },
      -- default keys for toggle term
      -- {
      --   "<c-_>",
      --   false
      -- },
      {
        "<leader>sx",
        function()
          require("utils.snacks_terminal").pick_tmux_window()
        end,
        desc = "Pick Tmux Win",
      },
      {
        "<leader>fG",
        function()
          require("utils.snacks_terminal").custom_git_pickers.git_diff_upstream()
        end,
        desc = "Git File Upstream",
      },
      {
        "<leader>fL",
        function()
          require("utils.snacks_terminal").custom_git_pickers.git_show()
        end,
        desc = "Last commit files",
      },
      {
        "<leader>fZ",
        function()
          require("utils.snacks_terminal").custom_change_list_picker()
        end,
        desc = "Git files by custom ref",
      },
      {
        "<leader>gb",
        function()
          Snacks.picker.git_branches()
        end,
        desc = "Git Branches",
      },
      {
        "<leader>E",
        function()
          local defaultDir = vim.fn.expand "%:p:h"
          local curword = vim.fn.expand "<cfile>"
          local filepath = curword and pathUtil.getFullPathFromRelativePath(curword)
          local notcurdir = (
            curword == "" or (vim.fn.filereadable(filepath) == 0 and vim.fn.isdirectory(filepath) == 0)
          )
          local cwddir = notcurdir and defaultDir or filepath
          -- lua/plugins/extra/myEditor.lua
          --     /Users/tharutaipree/dotfiles/.config/nvim3_jelly_tinynvim/lua/plugins/extra/myEditor.lua
          if not notcurdir then
            local success, err = pcall(function()
              vim.cmd("Neotree " .. filepath)
            end)
            print([==[(anon) err:]==], vim.inspect(err)) -- __AUTO_GENERATED_PRINT_VAR_END__
            -- __AUTO_GENERATED_PRINT_VAR_START__
            print([==[(anon) success:]==], vim.inspect(success)) -- __AUTO_GENERATED_PRINT_VAR_END__
            if not success then
              vim.notify("Error opening Neotree: " .. err, vim.log.levels.ERROR)
            else
              -- print("success")
              return
            end
          end

          Snacks.picker.explorer {
            cwd = defaultDir,
            auto_close = true,
            layout = {
              preset = "vertical",
            },
            win = {
              list = {
                keys = {
                  ["-"] = "explorer_up",
                  ["g."] = "toggle_hidden",
                },
              },
            },
          }
        end,
      },
      {
        "<C-e>",
        function()
          Snacks.picker.smart {
            win = {
              input = {
                keys = {
                  ["<C-space>"] = { "toggle_files_buffers", mode = { "n", "i" }, desc = "Toggle File/Buffer" },
                },
              },
            },
          }
        end,
        desc = "Find Smart",
      },
      {
        "<leader><space>",
        -- find files and use ctrl_space toggle to find buffer with
        function()
          Snacks.picker.buffers {
            win = {
              input = {
                keys = {},
              },
            },
          }
        end,
      },
      {
        "<leader>fq",
        function()
          Snacks.picker.qflist()
        end,
        desc = "Quickfix List",
      },
      {
        "<leader>sq",
        function()
          -- Get the current quickfix list
          local items = vim.fn.getqflist({ items = 0 }).items

          if not items or #items == 0 then
            vim.notify("Quickfix list is empty", vim.log.levels.WARN)
            return
          end

          local files = {}
          local seen = {}
          for _, item in ipairs(items) do
            -- Check if filename exists and hasn't been added yet
            if item.filename and item.filename ~= "" and not seen[item.filename] then
              table.insert(files, item.filename)
              seen[item.filename] = true
            elseif item.bufnr and item.bufnr > 0 then
              local name = vim.api.nvim_buf_get_name(item.bufnr)
              if name ~= "" and not seen[name] then
                table.insert(files, name)
                seen[name] = true
              end
            end
          end

          if #files == 0 then
            vim.notify("No valid files found in quickfix list", vim.log.levels.WARN)
            return
          end
          -- Use Snacks.picker.grep with the file list as 'dirs'
          -- This works because rg accepts file paths as arguments to search in
          Snacks.picker.grep {
            dirs = files,
            title = "Grep Quickfix Files",
          }
        end,
        desc = "Grep Quickfix Files",
      },
      {
        "<leader>sG",
        function()
          Snacks.picker.grep {
            cwd = pathUtil.get_sub_project_dir(),
            title = "Grep Monorepo Files",
          }
        end,
        desc = "Grep Dir Monorepo",
      },
      {
        "<leader>fWg",
        function()
          Snacks.picker.grep {
            cwd = pathUtil.get_sub_project_dir(),
            title = "Grep Monorepo Files",
          }
        end,
        desc = "Grep Dir Monorepo",
      },
      {
        "<leader>ff",
        function()
          Snacks.picker.files {
            -- pattern = function(picker)
            --   return picker:word()
            -- end,
          }
        end,
        desc = "Find Files",
        -- desc = "Find Files (word)",
        mode = { "n", "v" },
      },
      {
        "<leader>fF",
        function()
          Snacks.picker.files {
            cwd = pathUtil.get_sub_project_dir(),
            -- use fn from mypath.get_sub_project_dirs
            -- only search in current scope of mono repo on buffer files propogating to the closest file in this order
            --   return picker:word()
            -- end,
          }
        end,
        desc = "Find Files monorepo",
        mode = { "n", "v" },
      },
      {
        "<leader>fz", -- https://github.com/folke/snacks.nvim/discussions/617
        function()
          Snacks.picker.zoxide {
            finder = "files_zoxide",
            format = "file",
            -- confirm = "load_session" -- Disable loading session by default.
            confirm = function(picker, item)
              picker:close()
              if item then
                Snacks.picker.files { cwd = item.text }
              end
              local dir = item.file
              vim.fn.chdir(dir) -- Change current working directory
              vim.cmd("tcd " .. dir) -- Change tab-local current working directory
            end,
            win = {
              preview = {
                minimal = true,
              },
            },
          }
        end,
        desc = "Zoxide",
      },
    },
  },
  {
    "ThePrimeagen/harpoon",
    keys = {
      {
        "<leader>fhl",
        function()
          local harpoon = require "harpoon"
          harpoon.ui:toggle_quick_menu(harpoon:list())
        end,
        desc = "Harpoon menu",
      },
    },
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
    keys = {
      {
        "<leader>aV",
        function()
          require("sidekick.cli").send { msg = "{selection}" }
        end,
        mode = { "x" },
        desc = "Send Visual Selection",
      },
      {
        "<leader>aNt",
        function()
          require("sidekick.nes").toggle()
        end,
        mode = { "n" },
        desc = "Sidekick Toggle CLI",
      },
      {
        "<leader>aNe",
        function()
          require("sidekick.nes").enable()
        end,
        mode = { "n" },
        desc = "Sidekick Enable CLI",
      },
      {
        "<leader>aNd",
        function()
          require("sidekick.nes").disable()
        end,
        mode = { "n" },
        desc = "Sidekick Disable Nes",
      },
      {
        "<leader>aNu",
        function()
          require("sidekick.nes").update()
        end,
        mode = { "n" },
        desc = "Sidekick Nes Update",
      },
    },
  },
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
          "<leader>" .. key_f,
          group = "Find(Fzf)",
          mode = { "n" },
          icon = { icon = "", color = "black" },
        },
        {
          "<leader>" .. key_g,
          group = "Git(Fzf)",
          mode = { "n", "v" },
          icon = { icon = "", color = "black" },
        },
        {
          "<leader>" .. key_s,
          group = "Search(Fzf)",
          mode = { "n", "v" },
          icon = { icon = "", color = "black" },
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
  -- handle conflict with surround
  {
    "folke/flash.nvim",
    -- enabled = false,
    keys = {
      -- prevent conflict with surround
      {
        "s",
        mode = { "x", "o" },
        false,
        -- function()
        --   require("flash").jump()
        -- end,
      },
    },
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
