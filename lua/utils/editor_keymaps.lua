-- Utility module for editor keymaps
-- Extracts keymap configurations from myEditor.lua to keep it clean

local M = {}

local pathUtil = require "utils.mypath"
local gitUtil = require "utils.git"
local keyutil = require "utils.keyutil"
local inputUtils = require "utils.input"

local key_f = keyutil.key_f
local key_s = keyutil.key_s
local key_g = keyutil.key_g
local open_remote = gitUtil.open_remote

-- Helper: return the full path of the current buffer if available
local function get_current_buffer_path()
  local bufname = vim.api.nvim_buf_get_name(0)
  if bufname and bufname ~= "" then
    return vim.fn.fnamemodify(bufname, ":p")
  end
  return nil
end

-- FZF compare ref helper
local function fzfcompareref(selected)
  local ok, gitsigns = pcall(require, "gitsigns")
  if not ok then
    vim.notify("Gitsigns is not available", vim.log.levels.ERROR)
    return
  end

  local line = selected[1]
  local commit_hash = line

  -- handle branch selectors
  line = line:match "[^%w_]+(.*)$"

  -- handle commits selectors
  local remote_ref = line:match "^remotes/(.-)%s+"
  if remote_ref then
    commit_hash = remote_ref
    -- __AUTO_GENERATED_PRINT_VAR_START__
  else
    commit_hash = line:match "^(%S+)"
  end
  vim.print([==[fzfcompareref ref]==], vim.inspect(commit_hash)) -- __AUTO_GENERATED_PRINT_VAR_END__

  -- DO NOT CARE gitsigns will handle it all
  -- Gitsigns diffthis refs/remotes/origin/main
  -- all of below works
  -- require("gitsigns").diffthis("refs/remotes/origin/main")
  -- require("gitsigns").diffthis("remotes/origin/main")
  -- require("gitsigns").diffthis("main")
  -- local remote_ref = line:match "^remotes/(.-)%s+"
  local file_path = vim.fn.expand "%:p"
  local original_tab = vim.api.nvim_get_current_tabpage()
  vim.cmd("tabnew " .. file_path)
  -- require("gitsigns").diffthis("upstream/HEAD", { vertical = true })
  gitsigns.diffthis(commit_hash, { vertical = true }, function(err)
    if err then
      vim.cmd "tabclose"
      vim.api.nvim_set_current_tabpage(original_tab)
    end
  end)
end

-- Toggle delta side-by-side preview
local function toggle_diffpreview_alt()
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

-- Git helper functions are now in utils/git.lua
-- Delegate to the centralized implementations
local function open_file_with_gitsigns_diff(file_path, ref)
  gitUtil.open_file_with_gitsigns_diff(file_path, ref)
end

local function open_current_buffer_with_gitsigns_diff(ref)
  gitUtil.open_current_buffer_with_gitsigns_diff(ref)
end

local function open_file_in_remote(file_path, ref)
  gitUtil.open_file_in_remote(file_path, ref)
end

-- Export helper functions that are used in opts
M.helpers = {
  get_current_buffer_path = get_current_buffer_path,
  toggle_diffpreview_alt = toggle_diffpreview_alt,
  open_current_buffer_with_gitsigns_diff = open_current_buffer_with_gitsigns_diff,
  open_file_with_gitsigns_diff = open_file_with_gitsigns_diff,
  open_file_in_remote = open_file_in_remote,
}

--#region Keymap configurations by plugin
M.keymaps = {
  -- Oil file explorer
  oil = {
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

  -- Overseer task runner
  overseer = {
    {
      "<leader>op",
      function()
        require("overseer").run_task { name = "run script" }
      end,
      desc = "Overseer Run script",
    },
    {
      "<leader>ox",
      ":OverseerRun run\\ script<CR>",
      desc = "Overseer Run script",
    },
    {
      "<leader>oP",
      function()
        require("overseer").run_task { name = "run script - deterministic" }
      end,
      desc = "Overseer Run Deterministic",
    },
    {
      "<leader>oi",
      function()
        vim.cmd "checkhealth overseer"
      end,
      desc = "Overseer check health",
    },
    {
      "<leader>ow",
      function()
        local overseer = require "overseer"
        overseer.run_task({ name = "run script" }, function(task)
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
      desc = "Overseer Run +Watch",
    },
    {
      "<leader>ot",
      function()
        require("overseer").run_task {}
      end,
      desc = "Overseer run tasks",
      -- TODO: create custom Snacks picker to filter by available tags custom and builtins
      -- vim.print(require("overseer").list_tasks())
    },
    {
      "<leader>oT",
      function()
        require("overseer").run_task {
          first = false, -- required else it run the first match without show picker
          tags = { "custom" }, -- Only show templates with "hybrid" tag
          -- tags = { require("overseer").TAG.BUILD }, -- Only show templates with "hybrid" tag
          -- local overseer = require "overseer"
          -- BUILD / RUN / TEST / CLEAN ... can work with popuplated vscode tasks
          -- require("overseer").run_task({tags = {require("overseer").TAG.CLEAN} , first=false})
          -- require("overseer").run_task({tags = {require("overseer").TAG.RUN} , first=false})
          -- require("overseer").run_task({tags = {require("overseer").TAG.TEST} , first=false})
          -- require("overseer").run_task({tags = {require("overseer").TAG.RUN} , first=false})
          -- require("overseer").run_task({tags = {require("overseer").TAG.BUILD} , first=false})

          -- overseer.run_task({tags = {"custom"} , first=false})
          -- vim.print(require("overseer").TAG)
        }
      end,
      desc = "Overseer Run VS Code~,custom tasks",
    },
    {
      "<leader>oR",
      function()
        local overseer = require "overseer"
        local tasks = overseer.list_tasks { recent_first = true }
        if vim.tbl_isempty(tasks) then
          vim.notify("No tasks found", vim.log.levels.WARN)
        else
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
      "<leader>on",
      ":OverseerShell<CR>",
      desc = "New Task overseer",
    },
  },

  -- Buffer management
  bufremove = {
    {
      "<C-q>",
      false,
    },
  },

  -- Image clipboard
  img_clip = {
    {
      "<leader>iv",
      "<cmd>PasteImage<cr>",
      desc = "Paste image from system clipboard",
    },
  },

  -- Code Companion AI
  -- Base keymaps + model selection keymaps from my_codecompanion_actions
  codecompanion = function()
    local companion_prefix = vim.g.ai_prefix_key or "<leader>A"
    local base_keymaps = {
      -- Actions (normal + visual)
      {
        companion_prefix .. "a",
        "<cmd>CodeCompanionActions<cr>",
        desc = "Code Companion - Actions",
        mode = { "n", "v" },
      },
      {
        companion_prefix .. "A",
        "<cmd>CodeCompanionChat Add<cr>",
        desc = "Code Companion - Add selected",
        mode = "v",
      },
      -- Toggle chat (normal + visual)
      {
        companion_prefix .. "v",
        "<cmd>CodeCompanionChat Toggle<cr>",
        desc = "Code Companion - Toggle Chat",
        mode = { "n", "v" },
      },
      {
        companion_prefix .. "V",
        "<cmd>CodeCompanionChat<cr>",
        desc = "Code Companion - Add and Toggle",
        mode = "v",
      },
      -- Quick chat (visual: add selected, normal: input prompt)
      {
        companion_prefix .. "q",
        "<cmd>CodeCompanionChat<cr>",
        desc = "Code Companion - Ask New Add selected",
        mode = "v",
      },
      {
        companion_prefix .. "q",
        function()
          local input = vim.fn.input "Quick Chat: "
          if input ~= "" then
            vim.cmd("CodeCompanion " .. input)
          end
        end,
        desc = "Code Companion - Quick chat",
        mode = "n",
      },
      {
        companion_prefix .. "Q",
        ":CodeCompanion ",
        desc = "Code Companion - Type chat",
        mode = "v",
      },
      {
        companion_prefix .. "i",
        "<cmd>'<,'>CodeCompanion<cr>",
        ":CodeCompanion",
        desc = "Code Companion - Quick inline ui",
        mode = "v",
      },
      -- Slash command keymaps (from jellydn/tiny-nvim codecompanion.lua)
      {
        companion_prefix .. "e",
        "<cmd>CodeCompanion /explain<cr>",
        desc = "Code Companion - Explain code",
        mode = "v",
      },
      {
        companion_prefix .. "f",
        "<cmd>CodeCompanion /fix<cr>",
        desc = "Code Companion - Fix code",
        mode = "v",
      },
      {
        companion_prefix .. "l",
        "<cmd>CodeCompanion /lsp<cr>",
        desc = "Code Companion - Explain LSP diagnostic",
        mode = { "n", "v" },
      },
      {
        companion_prefix .. "t",
        "<cmd>CodeCompanion /tests<cr>",
        desc = "Code Companion - Generate unit test",
        mode = "v",
      },
      {
        companion_prefix .. "m",
        "<cmd>CodeCompanion /commit<cr>",
        desc = "Code Companion - Git commit message",
      },
      {
        companion_prefix .. "M",
        "<cmd>CodeCompanion /staged-commit<cr>",
        desc = "Code Companion - Git commit message (staged)",
      },
      {
        companion_prefix .. "mm",
        "<cmd>CodeCompanion /staged-commit<cr>",
        desc = "Code Companion Jelly - Git staged commit message",
      },
      {
        companion_prefix .. "mM",
        "<cmd>CodeCompanion /large-staged-files-commit-msg<cr>",
        desc = "Code Companion - Git commit (large files summary)",
      },
      {
        companion_prefix .. "mf",
        "<cmd>CodeCompanion /review-staged-commit-fast<cr>",
        desc = "Code Companion - Git Review staged commit (fast, gpt-4.1)",
      },
      {
        companion_prefix .. "d",
        "<cmd>CodeCompanion /inline-doc<cr>",
        desc = "Code Companion - Inline document code",
        mode = "v",
      },
      {
        companion_prefix .. "D",
        "<cmd>CodeCompanion /doc<cr>",
        desc = "Code Companion - Document code",
        mode = "v",
      },
      {
        companion_prefix .. "r",
        "<cmd>CodeCompanion /refactor<cr>",
        desc = "Code Companion - Refactor code",
        mode = "v",
      },
      {
        companion_prefix .. "R",
        "<cmd>CodeCompanion /review<cr>",
        desc = "Code Companion - Review code",
        mode = "v",
      },
      {
        companion_prefix .. "n",
        "<cmd>CodeCompanion /naming<cr>",
        desc = "Code Companion - Better naming",
        mode = "v",
      },
      -- History: browse and restore past chat sessions
      {
        companion_prefix .. "H",
        "<cmd>CodeCompanionHistory<cr>",
        desc = "Code Companion - Chat History",
        mode = { "n" },
      },
    }
    -- Merge model selection keymaps (inline picker, chat picker, adapter/model shortcuts)
    return require("utils.my_codecompanion_actions").generate_codecompanion_keymaps(base_keymaps)
  end,

  -- Copilot Chat
  copilot_chat = {
    {
      "<localleader>am",
      "<cmd>CopilotChatModels<cr>",
      desc = "Copilot Chat Model",
    },
  },

  -- Avante AI
  -- Keymaps are generated from my_avante_utils.lua using generate_avante_keymaps()
  -- This provides a clear mapping structure and reduces duplication
  --
  -- Structure:
  --   <leader>rsm - Select Copilot/default model picker
  --   <leader>rSM - Select AGD model picker
  --   <leader>rs[f|F|g|G|h|H|c|C|x|X] - Copilot models (visual=ask, normal=switch)
  --   <leader>rS[f|F|g|G|h|H|c|C|x|X] - AGD models (visual=ask, normal=switch)
  avante = require("utils.my_avante_utils").generate_avante_keymaps {
    {
      "<leader>rsm",
      function()
        require("utils.my_avante_utils").select_model_lean()
      end,
      desc = "Avante Models (default)",
      mode = "n",
    },
    {
      "<leader>rSm",
      function()
        require("utils.my_avante_utils").select_model_agd { source = "top_choices" }
      end,
      desc = "Avante Models (AGD top_choice)",
      mode = "n",
    },
    {
      "<leader>rSM",
      function()
        require("utils.my_avante_utils").select_model_agd()
      end,
      desc = "Avante Models (AGD All)",
      mode = "n",
    },
    {
      "<leader>rc", -- if not map not show not sure why unsafe key ?
      function()
        require("avante.api").add_selected_file(vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":p"))
      end,
      desc = "Avante - Add current to chat",
    },
  },

  -- Quick code runner
  quick_code_runner = {
    {
      "<leader>cP",
      function()
        require("utils.cmd").quickCommandRunCurrentFile()
      end,
      desc = "Code Run File",
      mode = "n",
    },
  },

  -- FZF Lua
  fzf_lua = {
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
      desc = "Git custom branch open,diff, FZF",
      mode = "n",
    },
    {
      "<leader>" .. key_f .. "s",
      function()
        require("config.telescope_pickers").fzf.pickers.session_picker()
      end,
      desc = "Session FZF",
    },
  },

  -- Bufferline
  bufferline = {
    { "<S-l>", "<Cmd>BufferLineCycleNext<CR>", desc = "Next Buffer" },
    { "<S-h>", "<Cmd>BufferLineCyclePrev<CR>", desc = "Prev Buffer" },
    { "<leader>bp", "<Cmd>BufferLineTogglePin<CR>", desc = "Toggle Pin" },
    { "<leader><Tab>r", ":BufferLineTabRename ", desc = "Rename Tab" },
    { "<leader>bs", ":BufferLineSortBy", desc = "Buffer Sort By.." },
    { "<leader>bsd", ":BufferLineSortByDirectory<CR>", desc = "Buffer Sort By Directory" },
    { "<leader>bse", ":BufferLineSortByExtension<CR>", desc = "Buffer Sort By Extension" },
    { "<leader>bsr", ":BufferLineSortByRelativeDirectory<CR>", desc = "Buffer Sort By Relative Directory" },
    { "<leader>bst", ":BufferLineSortByTabs<CR>", desc = "Buffer Sort By Tabs" },
    { "<leader>bg", ":BufferLinePick<CR>", desc = "Buffer Go Pick" },
    { "<leader>bcp", ":BufferLineGroupClose ungrouped<CR>", desc = "Buffer Close Ungroup" },
    { "<leader>bup", ":BufferLineGroupToggle pinned<CR>", desc = "Buffer Group Pin" },
    { "<leader>bu", ":BufferLineGroupToggle ", desc = "Buffer Toggle.." },
    { "<leader>buP", ":BufferLineGroupToggle ungrouped<CR>", desc = "Buffer Group Ungroup" },
    { "<leader>bcP", ":BufferLineGroupClose pinned<CR>", desc = "Buffer Close Pin" },
  },

  -- Persistence (session management)
  persistence = {
    {
      "<leader>qs",
      function()
        require("persistence").save()
      end,
      desc = "Save session",
    },
    {
      "<leader>qr",
      function()
        -- run vim SessionCurrentDir commandTables
        vim.cmd "SessionCurrentDir"
      end,
      desc = "Restore session (cwd)",
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

  -- Trouble
  trouble = {
    {
      "<leader>xf",
      "<cmd>Trouble snacks_files<cr>",
      desc = "Trouble Snacks",
    },
  },

  -- Snacks.nvim
  snacks = {
    {
      "<leader>e",
      false,
    },
    {
      "<C-_>",
      function()
        Snacks.terminal()
      end,
      desc = "Snacks Terminal",
      mode = { "n", "v" },
    },
    {
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
    {
      "<leader>sx",
      function()
        require("utils.snacks_terminal").pick_tmux_window()
      end,
      desc = "Pick Tmux Win",
    },
    {
      "<leader>fD",
      function()
        require("utils.snacks_pickers").dotfiles_picker()
      end,
      desc = "Dotfiles Config",
    },
    {
      "<leader>fG",
      function()
        require("utils.snacks_pickers").custom_git_pickers.git_diff_upstream()
      end,
      desc = "Git File Upstream",
    },

    {
      "<leader>fL",
      function()
        require("utils.snacks_pickers").custom_git_pickers.git_last_commit_show()
      end,
      desc = "Last commit files",
    },
    {
      "<leader>fZ",
      function()
        require("utils.snacks_pickers").custom_change_list_picker()
      end,
      desc = "Git files by custom ref",
    },
    {
      "<leader>gB",
      function()
        Snacks.picker.git_log { current_file = true } -- BCommits equivalent
      end,
      desc = "Git BCommits Snacks",
    },
    {
      "<leader>gb",
      function()
        Snacks.picker.git_branches()
      end,
      desc = "Git Branches",
    },
    {
      "<leader>gd",
      function()
        Snacks.picker.git_diff {
          -- base = "main"
          -- group = true
        }
      end,
      desc = "Git Branches",
    },
    {
      "<leader>gO",
      function()
        Snacks.gitbrowse {
          branch = require("utils.git").git_main_branch(),
          what = "file",
        }
      end,
      desc = "Git open remote main",
      mode = { "n", "x" },
    },
    {
      "<leader>/",
      function()
        local search = inputUtils.is_visual_mode() and inputUtils.getSelectedLines "visual_selection" or nil
        local snacks_util = require "utils.snacks_terminal"
        local picker_opts = snacks_util.get_initial_picker_state({
          show_empty = true,
          search = search,
          live = not (search and search:match "%S" ~= nil), -- force in live mode only when search has non-whitespace content
        }, { source = "grep" })

        Snacks.picker.grep(picker_opts)
      end,
      desc = "Grep",
      mode = { "n", "x" },
    },
    {
      "<leader>fw",
      function()
        local snacks_util = require "utils.snacks_terminal"
        local picker_opts = snacks_util.get_initial_picker_state({
          show_empty = true,
          live = true, -- force in live mode (normally it switch to non live mode)
        }, { source = "grep_word" })

        Snacks.picker.grep_word(picker_opts)
      end,
      desc = "Grep cwd:Git Ignorecase",
      mode = { "n", "x" },
    },
    {
      "<leader>fW",
      function()
        local snacks_util = require "utils.snacks_terminal"
        local picker_opts = snacks_util.get_initial_picker_state({
          show_empty = true,
          need_search = false,
          live = true,
        }, { source = "grep_word" })

        Snacks.picker.grep_word(picker_opts)
      end,
      desc = "Grep Visual selection or word",
      mode = { "n", "x" },
    },
    {
      "<leader>E",
      function()
        local defaultDir = vim.fn.expand "%:p:h"
        local curword = vim.fn.expand "<cfile>"
        local filepath = curword and pathUtil.getFullPathFromRelativePath(curword)
        local notcurdir = (curword == "" or (vim.fn.filereadable(filepath) == 0 and vim.fn.isdirectory(filepath) == 0))
        local cwddir = notcurdir and defaultDir or filepath

        if not notcurdir then
          local success, err = pcall(function()
            vim.cmd("Neotree " .. filepath)
          end)
          if not success then
            vim.notify("Error opening Neotree: " .. err, vim.log.levels.ERROR)
          else
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
      desc = "Neotree cursor/Snacks",
    },
    {
      "<leader>fs",
      function()
        require("utils.snacks_pickers").session_picker()
      end,
      desc = "Session Snacks",
    },
    {
      "<C-e>",
      function()
        local snacks_util = require "utils.snacks_terminal"
        local picker_opts = snacks_util.get_initial_picker_state {
          win = {
            input = {
              keys = {
                ["<C-space>"] = { "toggle_picker_source", mode = { "n", "i" }, desc = "Cycle File/Buffer/Grep" },
              },
            },
          },
        }
        Snacks.picker.smart(picker_opts)
      end,
      desc = "Find Smart",
    },
    {
      "<leader><space>",
      function()
        local snacks_actions = require "utils.snacks_actions"
        -- fabllack to files when empty

        local picker = Snacks.picker.buffers {

          -- win = {
          --   input = {
          --     keys = {
          --       -- Buffer filtering actions (only for buffer picker)
          --       ["<C-p><C-g>"] = {
          --         snacks_actions.filter_buffers_outside_git_root,
          --         mode = { "n", "i" },
          --         desc = "Filter: buffers outside git root",
          --       },
          --       ["<C-b>"] = {
          --         snacks_actions.filter_buffers_outside_git_root,
          --         mode = { "n", "i" },
          --         desc = "Filter: buffers outside git root",
          --       },
          --       ["<C-p><C-x>"] = {
          --         snacks_actions.filter_buffers_nonexistent,
          --         mode = { "n", "i" },
          --         desc = "Filter: non-existent buffers",
          --       },
          --     },
          --   },
          -- },
        }

        -- fallback to files when no buffer (make sure below is same as <leader><ff> mapping)
        if not picker or picker.closed then
          Snacks.picker.files(require("utils.snacks_terminal").get_initial_picker_state({
            search = inputUtils.is_visual_mode() and inputUtils.getSelectedLines "visual_selection",
          }, { source = "files" }))
        end
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
        local items = vim.fn.getqflist({ items = 0 }).items

        if not items or #items == 0 then
          vim.notify("Quickfix list is empty", vim.log.levels.WARN)
          return
        end

        local files = {}
        local seen = {}
        for _, item in ipairs(items) do
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
        Snacks.picker.grep(require("utils.snacks_terminal").get_initial_picker_state({
          title = "Grep Subproject",
          search = inputUtils.is_visual_mode() and inputUtils.getSelectedLines "visual_selection",
        }, { cwd_default = "subproject", use_previous_cwd_state = false }))
      end,
      mode = { "n", "x" },
      desc = "Grep Dir Monorepo Selected",
    },
    {
      "<leader>fWg",
      function()
        Snacks.picker.grep(require("utils.snacks_terminal").get_initial_picker_state({
          title = "Grep Monorepo Files",
        }, { cwd_default = "subproject", use_previous_cwd_state = false, source = "grep" }))
      end,
      desc = "Grep Dir Monorepo",
    },
    {
      "<leader>ff",
      function()
        Snacks.picker.files(require("utils.snacks_terminal").get_initial_picker_state({
          search = inputUtils.is_visual_mode() and inputUtils.getSelectedLines "visual_selection",
        }, { source = "files" }))
      end,
      desc = "Find Files",
      mode = { "n", "v" },
    },
    {
      "<leader>sh",
      function()
        Snacks.picker.help {
          pattern = inputUtils.is_visual_mode() and inputUtils.getSelectedLines "visual_selection",
        }
      end,
      desc = "Help Pages",
      mode = { "n", "x" },
    },
    {
      "<leader>st",
      function()
        Snacks.picker.todo_comments(require("utils.snacks_terminal").get_initial_picker_state {
          show_empty = true,
        })
      end,
      desc = "Todo (scoped)",
    },
    {
      "<leader>sT",
      function()
        Snacks.picker.todo_comments(require("utils.snacks_terminal").get_initial_picker_state {
          -- TODO check why scope not persist
          show_empty = true,
          keywords = { "TODO", "FIX", "FIXME" },
        })
      end,
      desc = "Todo/Fix/Fixme (scoped)",
    },
    {
      "<leader>sb",
      function()
        Snacks.picker.lines {
          supports_live = true,
          -- live = true, -- didnot rellay filter (add hl)
        }
      end,
      mode = "n",
      desc = "Buffer Lines",
    },
    {
      "<leader>sb",
      -- normal mode set in default snacks
      function()
        Snacks.picker.lines {
          -- this will prefill in pattern and let user type extra match
          supports_live = true, -- Enable toggle support
          -- live = true,
          --   search is using live mode if not set to true
          pattern = inputUtils.is_visual_mode() and inputUtils.getSelectedLines "visual_selection",
          -- even though search (non grep) does not really filter out result it did highlight
          -- search = inputUtils.is_visual_mode() and inputUtils.getSelectedLines('visual_selection'),
        }
      end,
      desc = "Buffer Lines Selected",
      mode = "x",
    },
    {
      "<leader>sB",
      -- normal mode set in default snacks
      function()
        Snacks.picker.grep_buffers(require("utils.snacks_terminal").get_initial_picker_state {
          search = inputUtils.is_visual_mode() and inputUtils.getSelectedLines "visual_selection",
        })
      end,
      desc = "Grep Open Buffers Selected",
      mode = "x",
    },
    {
      "<leader>fF",
      function()
        Snacks.picker.files(require("utils.snacks_terminal").get_initial_picker_state({
          search = inputUtils.is_visual_mode() and inputUtils.getSelectedLines "visual_selection",
          title = "Find Files Monorepo/Subproject",
        }, { cwd_default = "subproject", use_previous_cwd_state = false, source = "files" }))
      end,
      desc = "Find Files monorepo",
      mode = { "n", "x" },
    },
    {
      "<leader>fz",
      function()
        Snacks.picker.zoxide {
          finder = "files_zoxide",
          format = "file",
          confirm = function(picker, item)
            picker:close()
            if item then
              Snacks.picker.files { cwd = item.text }
            end
            local dir = item.file
            vim.fn.chdir(dir)
            vim.cmd("tcd " .. dir)
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
    {
      "<leader>fS",
      function()
        Snacks.picker.snippets()
      end,
      desc = "Snippets (LuaSnip)",
    },
  },

  -- Harpoon
  harpoon = {
    {
      "<leader>fhl",
      function()
        local harpoon = require "harpoon"
        harpoon.ui:toggle_quick_menu(harpoon:list())
      end,
      desc = "Harpoon menu",
    },
  },

  -- Sidekick
  sidekick = {
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

  -- Flash (disable conflicting keys)
  flash = {
    {
      "s",
      mode = { "x", "o" },
      false,
    },
  },
}
--#endregion

-- FZF-lua actions that need to be returned as opts
M.fzf_opts = {
  git = {
    branches = {
      actions = {
        ["ctrl-o"] = function(selected)
          local ref = selected[1]:match "[^%w_]+(.*)$"
          ref = ref:match "^(%S+)"
          open_remote(ref, "file")
          open_remote(ref, "branch")
        end,
        ["ctrl-s"] = fzfcompareref, -- <c-s>
        ["ctrl-g"] = function(selected)
          local ref = selected[1]:match "[^%w_]+(.*)$"
          ref = ref:match "^(%S+)"
          gitUtil.open_mr(ref)
        end,
      },
    },
    bcommits = {
      actions = {
        ["ctrl-o"] = function(selected)
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
        ["ctrl-o"] = function(selected)
          local commit_hash = selected[1]:match "%w+"
          open_remote(commit_hash, "file")
          open_remote(commit_hash, "commit")
        end,
        ["ctrl-s"] = fzfcompareref,
        ["f6"] = toggle_diffpreview_alt,
      },
    },
  },
}

--#region Snacks other maps
-- Snacks picker action factories
-- Delegates to utils/snacks_actions.lua (canonical source)
M.snacks_action_factories = {
  --- Create git file actions with ref resolution
  --- @param ref_provider string
  --- @param no_resolve boolean
  --- @return table actions Table containing action functions with metadata fields:
  ---   - open_file_diff: function(picker, item) - Open file with diff against ref
  ---   - open_remote_at_ref: function(picker, item) - Open file in remote at ref
  ---   - open_remote_at_head: function(picker, item) - Open file in remote at HEAD
  create_git_file_actions = function(ref_provider, no_resolve)
    return require("utils.snacks_actions").action_factories.create_git_file_actions(ref_provider, no_resolve)
  end,
}

-- Snacks picker actions (stateless functions)
-- Delegates to utils/snacks_actions.lua
M.snacks_common_actions = {
  copy_path_relative_buffer = function(picker, item)
    require("utils.snacks_actions").copy_path_relative_buffer(picker, item)
  end,
  copy_path_relative_git = function(picker, item)
    require("utils.snacks_actions").copy_path_relative_git(picker, item)
  end,
  copy_path_relative_cwd = function(picker, item)
    require("utils.snacks_actions").copy_path_relative_cwd(picker, item)
  end,
  copy_path_absolute = function(picker, item)
    require("utils.snacks_actions").copy_path_absolute(picker, item)
  end,
  copy_path_abs_multi = function(picker, item)
    require("utils.snacks_actions").copy_path_abs_multi(picker, item)
  end,
  copy_path_select = function(picker, item)
    require("utils.snacks_actions").copy_path_select(picker, item)
  end,
  toggle_external_scope = function(picker)
    require("utils.snacks_actions").toggle_external(picker)
  end,
  yank_sys = function(picker, item)
    require("utils.snacks_actions").yank_sys(picker, item)
  end,
  -- https://deepwiki.com/search/trigger-yank-action-in-another_8bb3e790-7ce9-4165-b316-978a705364c3?mode=fast
  -- use opts.field else item.data / item.text
  -- yank_sys_og = { action = "yank", reg = "+" }, -- field = "<item field to use to copy>"
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
  toggle_diffpreview_alt = toggle_diffpreview_alt,
  my_diff_compare = function(picker, item, action)
    require("utils.snacks_actions_wip").my_diff_compare(picker, item, action)
  end,
  toggle_cwd_files_grep = function(picker, item)
    require("utils.snacks_actions").toggle_cwd_files_grep(picker, item)
  end,
  select_subproject_cwd = function(picker, item)
    require("utils.snacks_actions").select_subproject_cwd(picker, item)
  end,
  toggle_files_buffers = function(picker, item)
    require("utils.snacks_actions").toggle_picker_source(picker, item)
  end,
  toggle_picker_source = function(picker, item)
    require("utils.snacks_actions").toggle_picker_source(picker, item)
  end,
  toggle_grep_picker = function(picker, item)
    require("utils.snacks_actions").toggle_grep_picker(picker, item)
  end,
  increase_picker_depth = function(picker, item)
    require("utils.snacks_actions").adjust_picker_depth(picker, item, 1)
  end,
  decrease_picker_depth = function(picker, item)
    require("utils.snacks_actions").adjust_picker_depth(picker, item, -1)
  end,
  reset_picker_depth = function(picker, item)
    require("utils.snacks_actions").adjust_picker_depth(picker, item, 0)
  end,
}

-- Common keymap groups for snacks pickers
-- These can be merged into picker configurations using vim.tbl_extend("force", ...)
--
-- KEY ORGANIZATION:
-- - common_keys: Universal keys used across all/most pickers (e.g., <C-o> for open_file_remote)
-- - copy_path_keys: Path copy actions (Yy, Yg, YP, Yp, YY) for file/grep pickers
-- - files_keys: File-specific actions (toggle, cycle cwd) for files/buffers
-- - grep_keys: Grep-specific actions (<C-x>, <A-s>) for grep/qflist pickers
-- - git_file_keys*: Git-specific actions for git pickers (not used in declarative sources)
--
-- MERGE ORDER (custom keys last to override):
-- Example: vim.tbl_extend("force", common_keys, copy_path_keys, files_keys, {custom overrides})
--          └─ base (applied first)                                           └─ overrides (applied last)
local snacks_picker_shared_keys = {
  files_and_grep = {
    input = {
      ["<M-c>"] = { "toggle_case_sensitivity", mode = { "n", "i" }, desc = "Toggle case sensitivity" },
      ["<M-=>"] = { "increase_picker_depth", mode = { "n", "i" }, desc = "Increase search depth" },
      ["<M-->"] = { "decrease_picker_depth", mode = { "n", "i" }, desc = "Decrease search depth" },
      ["<M-0>"] = { "reset_picker_depth", mode = { "n", "i" }, desc = "Reset search depth" },
      ["<M-g>"] = { "toggle_grep_picker", mode = { "n", "i" }, desc = "Toggle Grep <-> Source" },
    },
  },
  -- Common keys used across multiple pickers
  common_keys = {
    input = {
      ["<C-o>"] = { "open_file_remote", mode = { "n", "i" }, desc = "Open File Remote" },
      ["<M-e>"] = { "toggle_external_scope", mode = { "n", "i" }, desc = "Toggle external filter" },
      ["<M-b>"] = { "toggle_external_scope", mode = { "n", "i" }, desc = "Toggle external filter" },
    },
  },
  -- Copy path actions - applies to file/grep/explorer pickers
  copy_path_keys = {
    input = {
      ["<C-y>"] = { "copy_path_abs_multi", mode = { "n", "i" }, desc = "Copy Absolute Path(s)" },
      ["Yy"] = { "copy_path_relative_buffer", mode = { "n" }, desc = "Copy Relative Path (Buffer)" },
      ["Yg"] = { "copy_path_relative_git", mode = { "n" }, desc = "Copy Relative Path (Git)" },
      ["Yp"] = { "copy_path_relative_cwd", mode = { "n" }, desc = "Copy Relative Path (CWD)" },
      ["YP"] = { "copy_path_absolute", mode = { "n" }, desc = "Copy Absolute Path" },
      ["YY"] = { "copy_path_select", mode = { "n" }, desc = "Copy Path Select" },
      ["<M-y>"] = { "copy_path_select", mode = { "n", "i" }, desc = "Copy Path Select" },
    },
  },
}

-- local test = vim.tbl_extend("force",{ t= 123})
-- -- __AUTO_GENERATED_PRINT_VAR_START__
-- print([==[ test:]==], vim.inspect(test)) -- __AUTO_GENERATED_PRINT_VAR_END__

local snacks_picker_group_keys = {

  -- File-specific keys (toggle, cycle cwd)
  files_keys = {
    input = vim.tbl_extend(
      "force",
      snacks_picker_shared_keys.common_keys.input,
      snacks_picker_shared_keys.copy_path_keys.input,
      snacks_picker_shared_keys.files_and_grep.input,
      {
        ["<C-space>"] = { "toggle_picker_source", mode = { "n", "i" }, desc = "Cycle File/Buffer/Grep" },
        ["<A-s>"] = { "toggle_cwd_files_grep", mode = { "n", "i" }, desc = "Cycle CWD Scope" },
        ["<M-S>"] = { "select_subproject_cwd", mode = { "n", "i" }, desc = "Pick Subproject CWD" },
      }
    ),
  },
  -- Grep-specific keys (common across grep/qflist pickers)
  grep_keys = {
    input = vim.tbl_extend(
      "force",
      snacks_picker_shared_keys.common_keys.input,
      snacks_picker_shared_keys.copy_path_keys.input,
      snacks_picker_shared_keys.files_and_grep.input,
      {
        ["<C-space>"] = { "toggle_picker_source", mode = { "n", "i" }, desc = "Cycle File/Buffer/Grep" },
        ["<C-x>"] = { "remove_qf_item", mode = { "n", "i" }, desc = "Remove QF Item" },
        ["<A-s>"] = { "toggle_cwd_files_grep", mode = { "n", "i" }, desc = "Cycle CWD Scope" },
        ["<M-S>"] = { "select_subproject_cwd", mode = { "n", "i" }, desc = "Pick Subproject CWD" },
      }
    ),
  },

  -- Git diff & remote actions - for git file pickers
  git_file_keys = {
    input = {
      ["<C-y>"] = { "copy_path_abs_multi", mode = { "n", "i" }, desc = "Copy Absolute Path(s)" },
      ["<C-s>"] = { "open_file_diff", mode = { "n", "i" }, desc = "Open Gitsigns diff in new tab" },
      ["<C-g>"] = { "open_file_diff", mode = { "n", "i" }, desc = "Open Gitsigns diff in new tab" },
      ["<C-o>"] = { "open_remote_at_ref", mode = { "n", "i" }, desc = "Open file in remote at ref" },
      ["<C-O>"] = { "open_remote_at_head", mode = { "n", "i" }, desc = "Open file in remote at HEAD" },
      ["<M-e>"] = { "toggle_external_scope", mode = { "n", "i" }, desc = "Toggle missing files" },
      ["<M-b>"] = { "toggle_external_scope", mode = { "n", "i" }, desc = "Toggle missing files" },
      -- TODO: support git operations
      -- ["<M-S>"] = { "select_subproject_cwd", mode = { "n", "i" }, desc = "Pick Subproject CWD" },
    },
    list = {
      ["<C-y>"] = { "copy_path_abs_multi", mode = { "n", "i" }, desc = "Copy Absolute Path(s)" },
      ["<C-s>"] = { "open_file_diff", mode = { "n", "i" }, desc = "Open Gitsigns diff in new tab" },
      ["<C-g>"] = { "open_file_diff", mode = { "n", "i" }, desc = "Open Gitsigns diff in new tab" },
      ["<C-o>"] = { "open_remote_at_ref", mode = { "n", "i" }, desc = "Open file in remote at ref" },
      ["<C-O>"] = { "open_remote_at_head", mode = { "n", "i" }, desc = "Open file in remote at HEAD" },
      ["<M-e>"] = { "toggle_external_scope", mode = { "n", "i" }, desc = "Toggle missing files" },
      ["<M-b>"] = { "toggle_external_scope", mode = { "n", "i" }, desc = "Toggle missing files" },
    },
  },

  -- Alternate git keys for upstream picker (using different keybinds)
  git_file_keys_upstream = {
    input = {
      ["<C-s>"] = { "open_file_diff", mode = { "n", "i" }, desc = "Open Gitsigns diff in new tab" },
      ["<C-g>"] = { "open_file_diff", mode = { "n", "i" }, desc = "Open Gitsigns diff in new tab" },
      ["<C-o>"] = { "open_remote_at_ref", mode = { "n", "i" }, desc = "Open file in remote at upstream ref" },
      ["<C-2>"] = { "open_remote_at_head", mode = { "n", "i" }, desc = "Open file in remote at HEAD" },
      ["<M-e>"] = { "toggle_external_scope", mode = { "n", "i" }, desc = "Toggle missing files" },
      ["<M-b>"] = { "toggle_external_scope", mode = { "n", "i" }, desc = "Toggle missing files" },
    },
    list = {
      ["<C-s>"] = { "open_file_diff", mode = { "n", "i" }, desc = "Open Gitsigns diff in new tab" },
      ["<C-g>"] = { "open_file_diff", mode = { "n", "i" }, desc = "Open Gitsigns diff in new tab" },
      ["<C-o>"] = { "open_remote_at_ref", mode = { "n", "i" }, desc = "Open remote compared ref" },
      ["<C-1>"] = { "open_remote_at_head", mode = { "n", "i" }, desc = "Open remote at HEAD" },
      ["<M-e>"] = { "toggle_external_scope", mode = { "n", "i" }, desc = "Toggle missing files" },
      ["<M-b>"] = { "toggle_external_scope", mode = { "n", "i" }, desc = "Toggle missing files" },
    },
  },

  -- Git keys with back navigation (for custom change list picker)
  git_file_keys_with_back = function(on_back)
    return {
      input = {
        ["<C-h>"] = {
          function(picker)
            if on_back then
              picker:close()
              on_back()
            end
          end,
          mode = { "n", "i" },
          desc = "Back to ref selection",
        },
        ["<C-s>"] = { "open_file_diff", mode = { "n", "i" }, desc = "Open Gitsigns diff in new tab" },
        ["<C-g>"] = { "open_file_diff", mode = { "n", "i" }, desc = "Open Gitsigns diff in new tab" },
        ["<C-o>"] = { "open_remote_at_ref", mode = { "n", "i" }, desc = "Open file in remote at selected ref" },
        ["<M-o>"] = { "open_remote_at_head", mode = { "n", "i" }, desc = "Open file in remote at HEAD" },
        ["<M-e>"] = { "toggle_external_scope", mode = { "n", "i" }, desc = "Toggle missing files" },
        ["<M-b>"] = { "toggle_external_scope", mode = { "n", "i" }, desc = "Toggle missing files" },
      },
      list = {
        ["<C-s>"] = { "open_file_diff", mode = { "n", "i" }, desc = "Open Gitsigns diff in new tab" },
        ["<C-g>"] = { "open_file_diff", mode = { "n", "i" }, desc = "Open Gitsigns diff in new tab" },
        ["<M-o>"] = { "open_remote_at_ref", mode = { "n", "i" }, desc = "Open file in remote at selected ref" },
        ["<C-h>"] = {
          function(picker)
            if on_back then
              picker:close()
              on_back()
            end
          end,
          mode = { "n", "i" },
          desc = "Back to ref selection",
        },
        ["<M-e>"] = { "toggle_external_scope", mode = { "n", "i" }, desc = "Toggle missing files" },
        ["<M-b>"] = { "toggle_external_scope", mode = { "n", "i" }, desc = "Toggle missing files" },
      },
    }
  end,
}

-- Declarative snacks picker key settings
-- These are pre-merged configurations ready to use in myEditor.lua
--
-- USAGE IN myEditor.lua:
--   sources = vim.tbl_deep_extend("force",
--     editor_keymaps.snacks_picker_keys_setting.sources,
--     { files = { hidden = true } }  -- Custom overrides per picker
--   )
--
-- MERGE PATTERN:
--   Each picker merges keys in order: common_keys → copy_path_keys/files_keys/grep_keys → custom
--   Later keys override earlier ones (vim.tbl_extend("force", ...))
--- Factory for inline key functions that persist toggle opts per source.
--- These MUST be inline functions (not named action strings) because Snacks
--- unconditionally overwrites toggle_* actions after all config merging
--- (snacks/picker/config/init.lua:93-105).
---
--- IMPORTANT: Inline key functions in win.input.keys receive the snacks.win
--- object as their first argument, NOT the picker (snacks/win.lua:994-996).
--- We retrieve the real picker via Snacks.picker.get({ source = source }).
---
--- Toggle keys: <a-h> hidden, <a-i> ignored, <a-f> follow, <a-r> regex (grep only)
--- @param source string  picker source name ("files" | "grep" | "grep_word")
--- @param has_regex boolean  whether to include the regex toggle key
local function make_persist_toggle_keys(source, has_regex)
  local sa = require "utils.snacks_actions"

  local function wrap(opt_name, desc)
    return {
      function(_win) -- _win is snacks.win (input window), NOT the picker
        -- Retrieve the real picker instance for this source
        local pickers = Snacks.picker.get { source = source }
        local picker = pickers and pickers[1]
        if not picker then
          sa.log_picker_persist("toggle_" .. opt_name .. ":ERROR_no_picker", {
            source = source,
            win_type = type(_win),
            win_has_buf = _win and _win.buf ~= nil,
            active_pickers = vim.tbl_map(function(p)
              return p.opts and p.opts.source or "?"
            end, Snacks.picker.get {} or {}),
          })
          vim.notify(
            ("[picker-persist] toggle_%s: no active picker for source=%s"):format(opt_name, source),
            vim.log.levels.WARN
          )
          return
        end
        local before = picker.opts[opt_name]
        picker.opts[opt_name] = not picker.opts[opt_name]
        if picker.list then
          picker.list:set_target()
        end
        sa.log_picker_persist("toggle_" .. opt_name, {
          source = source,
          before = before,
          after = picker.opts[opt_name],
          picker_id = picker.id,
          pattern = picker.input and picker.input.filter and picker.input.filter.pattern,
        })
        sa.save_source_opt(source, opt_name, picker.opts[opt_name])
        picker:find()
      end,
      mode = { "i", "n" },
      desc = desc,
    }
  end

  local keys = {
    ["<a-h>"] = wrap("hidden", "Toggle Hidden"),
    ["<a-i>"] = wrap("ignored", "Toggle Ignored"),
    ["<a-f>"] = wrap("follow", "Toggle Follow"),
  }
  if has_regex then
    keys["<a-r>"] = wrap("regex", "Toggle Regex")
  end
  return keys
end

local source_n_snacks = {}
M.sources_n_keys = {
  sources = {
    -- Files picker: common + copy path + file-specific actions
    git_diff = {
      win = {
        input = {
          keys = vim.tbl_extend("force", {}, {
            ["<M-g>"] = { "gitdiff_toggle_group", mode = { "n", "i" }, desc = "Toggle group diff" },
          }),
        },
      },
    },
    git_status = {
      win = {
        input = {
          keys = vim.tbl_extend("force", {}, {
            ["<M-g>"] = { "gitdiff_toggle_group", mode = { "n", "i" }, desc = "Toggle git diff" },
          }),
        },
      },
    },
    files = {
      win = {
        input = {
          -- Inline persist wrappers override <a-h>/<a-i>/<a-f> after Snacks auto-generates
          -- toggle_* actions (which run last in config merge and cannot be overridden via actions table).
          keys = vim.tbl_extend(
            "force",
            snacks_picker_group_keys.files_keys.input,
            make_persist_toggle_keys("files", false)
          ),
        },
      },
    },
    -- Buffers picker: common + copy path + file-specific actions
    buffers = {
      -- External filter: show buffers outside the current scope CWD
      -- Scope CWD comes from: persisted buffer subproject (a-S) > buffer scope toggle (a-s) > vim.fn.getcwd()
      -- a-e: toggle external on/off
      -- a-s: upward traversal through subproject chain (short-lived)
      -- a-S: subproject picker with separate buffer persistence
      transform = function(item, ctx)
        local show_external = ctx and ctx.picker and ctx.picker.opts.external
        -- Scope can come from:
        -- 1) transient toggle state (_buffer_scope_cwd via a-s), or
        -- 2) persisted buffer subproject (picker_buffer_cwd_state_value via a-S).
        local scope_cwd = ctx and ctx.picker and ctx.picker.opts._buffer_scope_cwd
        if scope_cwd == nil then
          scope_cwd = vim.g.picker_buffer_cwd_state_value
        end
        local has_scope = type(scope_cwd) == "string" and scope_cwd ~= ""

        -- No scope change and no external: show all buffers (default)
        if not show_external and not has_scope then
          return item
        end

        -- Resolve the effective scope cwd
        scope_cwd = scope_cwd or (ctx and ctx.picker and ctx.picker.opts.cwd) or vim.fn.getcwd()

        local item_path = nil
        local ok, util = pcall(function()
          return require("snacks").picker.util
        end)
        if ok and util then
          item_path = util.path(item)
        end

        -- Check for missing (non-existent) files
        local missing = false
        if item_path and item_path ~= "" then
          missing = vim.fn.filereadable(item_path) == 0 and vim.fn.isdirectory(item_path) == 0
        end

        if vim.g.snacks_debug_external_filter then
          print(
            string.format(
              "external_filter[buffers]: external=%s scope=%s missing=%s file=%s",
              tostring(show_external),
              vim.fn.fnamemodify(scope_cwd, ":~"),
              tostring(missing),
              tostring(item and (item.file or item.text) or "nil")
            )
          )
        end

        -- Path-based filtering
        local is_inside_scope = true
        if item_path then
          local normalized_cwd = vim.fn.fnamemodify(scope_cwd, ":p"):gsub("/$", "") .. "/"
          local normalized_path = vim.fn.fnamemodify(item_path, ":p")
          is_inside_scope = normalized_path:sub(1, #normalized_cwd) == normalized_cwd
        else
          is_inside_scope = pathUtil.is_in_project_dir(item)
        end

        if show_external then
          -- External mode: show buffers OUTSIDE scope cwd + missing buffers
          if missing then
            return true
          end
          return not is_inside_scope
        else
          -- Scope mode (a-s changed scope but external off): show buffers INSIDE scope cwd
          return is_inside_scope and item or false
        end
      end,
      actions = {
        toggle_external_scope = function(picker)
          require("utils.snacks_actions").toggle_external(picker)
        end,
        toggle_buffer_scope = function(picker)
          -- Buffer version of a-s: upward traversal through subproject chain
          local snacks_actions = require "utils.snacks_actions"
          local chain, step_idx = snacks_actions._get_picker_traversal_state(picker, "picker_buffer_cwd_state_value")

          if #chain <= 1 then
            vim.notify("Only one scope available for buffers", vim.log.levels.INFO)
            return
          end

          local next_idx = step_idx + 1
          if next_idx > #chain then
            vim.notify("Returning to initial buffer scope", vim.log.levels.INFO)
            next_idx = 1
          end

          picker.opts._scope_step_index = next_idx

          -- When returning to initial position (index 1), clear scope to show all buffers
          if next_idx == 1 then
            picker.opts._buffer_scope_cwd = nil
          else
            picker.opts._buffer_scope_cwd = chain[next_idx]
          end

          -- Reset external when scope changes
          picker.opts.external = nil

          local short_cwd = vim.fn.fnamemodify(chain[next_idx], ":~")
          if next_idx == 1 then
            vim.notify("Buffer scope: all buffers (initial)", vim.log.levels.INFO)
          elseif next_idx == #chain then
            vim.notify(
              string.format("Buffer scope: git root — %s\nNext toggle returns to initial", short_cwd),
              vim.log.levels.INFO
            )
          else
            vim.notify(string.format("Buffer scope: %s (%d/%d)", short_cwd, next_idx, #chain), vim.log.levels.INFO)
          end
          picker:refresh()
        end,
        select_buffer_subproject = function(picker)
          -- Buffer version of a-S: open subproject picker, persist to buffer-specific state
          require("utils.snacks_actions").select_subproject_cwd(picker, {
            persist_key = "picker_buffer_cwd_state_value",
          })
        end,
      },
      win = {
        input = {
          footer = "a-e: external, a-s: scope, a-S: subproject",
          keys = vim.tbl_extend("force", snacks_picker_group_keys.files_keys.input, {
            ["<M-e>"] = { "toggle_external_scope", mode = { "n", "i" }, desc = "Toggle external buffers" },
            ["<M-b>"] = { "toggle_external_scope", mode = { "n", "i" }, desc = "Toggle external buffers" },
            ["<A-s>"] = { "toggle_buffer_scope", mode = { "n", "i" }, desc = "Cycle buffer scope" },
            ["<M-S>"] = { "select_buffer_subproject", mode = { "n", "i" }, desc = "Pick buffer subproject" },
          }),
        },
      },
    },

    explorer = {
      win = {
        input = {
          keys = vim.tbl_extend("force", {}, snacks_picker_group_keys.files_keys.input),
        },
        list = {
          keys = vim.tbl_extend("force", {}, snacks_picker_shared_keys.copy_path_keys.input),
        },
      },
    },
    -- Git files picker: common + copy path keys + source cycle/grep toggle
    git_files = {
      win = {
        input = {
          keys = vim.tbl_extend(
            "force",
            snacks_picker_shared_keys.common_keys.input,
            snacks_picker_shared_keys.copy_path_keys.input,
            {
              ["<C-space>"] = { "toggle_picker_source", mode = { "n", "i" }, desc = "Cycle File/Buffer/Grep" },
              ["<M-g>"] = { "toggle_grep_picker", mode = { "n", "i" }, desc = "Toggle Grep <-> Source" },
            }
          ),
        },
      },
    },

    -- Git branches picker: common + git-specific actions
    git_branches = {
      win = {
        input = {
          keys = vim.tbl_extend("force", snacks_picker_shared_keys.common_keys.input, {
            ["<C-s>"] = { "my_diff_compare", mode = { "n", "i" }, desc = "Open Diff" },
            ["<C-t>"] = { "test_picker", mode = { "n", "i" }, desc = "Test picker" },
            ["f6"] = { "toggle_diffpreview_alt", mode = { "n", "i" }, desc = "Toggle Delta Mode" },
            ["<C-g>"] = { "open_mr", mode = { "n", "i" }, desc = "Open Merge Request" },
          }),
        },
      },
    },

    -- Git log picker: common + git log actions
    git_log = {
      win = {
        input = {
          keys = vim.tbl_extend("force", snacks_picker_shared_keys.common_keys.input, {
            ["<C-s>"] = { "my_diff_compare", mode = { "n", "i" }, desc = "Open Diff" },
            ["f6"] = { "toggle_diffpreview_alt", mode = { "n", "i" }, desc = "Toggle Delta Mode" },
            ["<C-t>"] = { "test_picker", mode = { "n", "i" }, desc = "Test picker" },
          }),
        },
      },
    },

    -- Grep picker: common + copy path + grep actions
    grep = {
      win = {
        input = {
          keys = vim.tbl_extend(
            "force",
            snacks_picker_group_keys.grep_keys.input,
            make_persist_toggle_keys("grep", true)
          ),
        },
      },
    },

    -- Grep word picker: common + copy path + grep actions
    grep_word = {
      win = {
        input = {
          keys = vim.tbl_extend(
            "force",
            snacks_picker_group_keys.grep_keys.input,
            make_persist_toggle_keys("grep_word", true)
          ),
        },
      },
    },

    -- Todo comments picker: grep-based, supports scope traversal (a-s, a-S, a-e)
    todo_comments = {
      win = {
        input = {
          keys = vim.tbl_extend("force", {}, snacks_picker_group_keys.grep_keys.input),
        },
      },
    },

    -- Quickfix list picker: common + grep actions
    qflist = {
      win = {
        input = {
          keys = vim.tbl_extend("force", {}, snacks_picker_group_keys.grep_keys.input, {
            ["<C-x>"] = { "remove_qf_item", mode = { "n", "i" }, desc = "Remove Quickfix Item" },
          }),
        },
      },
    },
    -- Common win settings used in opts.win in myEditor.lua
    undo = {
      actions = {
        undo_picker_split = require("utils.snacks_actions").undo_picker_split,
      },
      win = {
        input = {
          keys = {
            ["<C-s>"] = {
              "undo_picker_split",
              mode = { "n", "i" },
              desc = "Show diff in new tab",
            },
          },
        },
      },
    },
    -- LuaSnip snippets picker
    snippets = require("utils.snacks_pickers").snippets_source_config,
  },

  -- ===================== common keymap sections ====================

  common = {
    list = {
      keys = {
        ["<C-p>"] = { "focus_preview", desc = "Focus Preview" },
        ["0"] = { "focus_preview", desc = "Focus Preview" },
        ["<c-a>"] = { "sidekick_send", mode = { "n", "i" } },
        ["<a-a>"] = { "select_all", mode = { "n", "i" } },
        ["<a-q>"] = { "qflist", mode = { "n", "i" } },
        ["<c-q>"] = "cancel",
        -- ["<M-w>"] = default  is cycle_win but this will cycle back to input that can alreay be done with / or i
        ["<M-w>"] = "focus_preview",
        ["<M-e>"] = { "toggle_external_scope", mode = { "n", "i" }, desc = "Toggle external filter" },
        ["<M-b>"] = { "toggle_external_scope", mode = { "n", "i" }, desc = "Toggle external filter" },
        ["/"] = false, -- alow search to apply on list
      },
    },
    input = {
      keys = {
        ["<C-y>"] = { "yank", mode = { "n", "i" } },
        -- all below works
        ["<C-c>"] = { "yank_sys", mode = { "n", "i" }, desc = "Yank to system clipboard" },
        -- ["<C-c>"] = { "yank_sys_og", mode = { "n", "i" }, desc = "Yank to system clipboard" },
        -- ["<C-c>"] = { { "yank", "yank_sys" }, mode = { "n", "i" }, desc = "Yank to system clipboard" },
        ["<S-t>"] = { "trouble_open", mode = { "n" }, desc = "Smart open Touble" },
        ["<C-t>"] = { "terminal", mode = { "i" }, desc = "Open terminal from picker" },
        -- ["<C-p>"] = { "focus_preview", desc = "Focus Preview" },
        ["<C-p>"] = false,
        ["<C-n>"] = false,
        ["0"] = { "focus_preview", mode = { "n" }, desc = "Focus Preview" },
        ["<c-a>"] = { "sidekick_send", mode = { "n", "i" } },
        ["<a-a>"] = { "select_all", mode = { "n", "i" } },
        ["<a-q>"] = { "qflist", mode = { "n", "i" } },
        ["<C-q>"] = { "cancel", mode = { "n", "i" }, desc = "Cancel" },
        ["<M-e>"] = { "toggle_external_scope", mode = { "n", "i" }, desc = "Toggle external filter" },
        ["<M-b>"] = { "toggle_external_scope", mode = { "n", "i" }, desc = "Toggle external filter" },
      },
    },
    preview = {
      keys = {
        ["<c-q>"] = "cycle_win",
      },
    },
  },
}
M.snacks_picker_group_keys = snacks_picker_group_keys
--#endregion

return M
