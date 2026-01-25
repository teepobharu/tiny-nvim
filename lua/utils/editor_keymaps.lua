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
  local commit_hash

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
      ":OverseerRun run script<CR>",
      desc = "Run script",
    },
    {
      "<leader>oP",
      function()
        require("overseer").run_task { name = "run script" }
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
  codecompanion = function()
    local companion_prefix = vim.g.ai_prefix_key or "<leader>A"
    return {
      {
        companion_prefix .. "a",
        "<cmd>CodeCompanionAction<cr>",
        desc = "Code Companion - actions",
        mode = "v",
      },
      {
        companion_prefix .. "A",
        "<cmd>CodeCompanionChat Add<cr>",
        desc = "Code Companion - Add selected",
        mode = "v",
      },
      {
        companion_prefix .. "V",
        "<cmd>CodeCompanionChat<cr>",
        desc = "Code Companion - Add and Toggle",
        mode = "v",
      },
      {
        companion_prefix .. "v",
        "<cmd>CodeCompanionChat<cr>",
        mode = "v",
      },
      {
        companion_prefix .. "q",
        "<cmd>CodeCompanionChat<cr>",
        desc = "Code Companion - Ask New Add selected",
        mode = "v",
      },
      {
        companion_prefix .. "M",
        "<cmd>CodeCompanion /short-staged-commit<cr>",
        desc = "Code Companion - Git commit message (staged)",
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
    }
  end,

  -- Copilot Chat
  copilot_chat = {
    {
      "<localleader>aE",
      "<cmd>CopilotChatBuffEdit<cr>",
      desc = "~ Copilot Chat Buf Edit ",
    },
  },

  -- Avante AI
  -- Keymaps are generated from my_avante_utils.lua using generate_avante_keymaps()
  -- This provides a clear mapping structure and reduces duplication
  --
  -- Structure:
  --   <leader>rsm - Select model (lean/copilot only)
  --   <leader>rsM - Select model (all/with AGD)
  --   <leader>rs[f|F|h|H|c|C] - Copilot models (visual=ask, normal=switch)
  --     f/F = fast (GPT-4.1-mini, GPT-5-mini)
  --     h/H = heavy (Claude Sonnet 4.5, Claude Opus 4.5)
  --     c/C = codex (GPT-5.1-codex-max, GPT-5.1-codex-mini)
  --   <leader>rS[f|F|h|H|c] - AGD models (visual=ask, normal=switch)
  --     f/F = fast OpenAI AGD, h/H = Claude AGD, c = GPT-5.2 AGD
  avante = require("utils.my_avante_utils").generate_avante_keymaps {
    {
      "<leader>rsm",
      function()
        require("utils.my_avante_utils").select_model_lean()
      end,
      desc = "Avante Models (lean/copilot)",
      mode = "n",
    },
    {
      "<leader>rsM",
      function()
        require("utils.my_avante_utils").select_model_all()
      end,
      desc = "Avante Models (all/AGD)",
      mode = "n",
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
    { "<leader>bg", ":BufferLinePick<CR>", desc = "Buffer Group Toggle Pin" },
    { "<leader>bup", ":BufferLineGroupToggle ungrouped<CR>", desc = "Buffer Group Toggle ungroup" },
    { "<leader>bup", ":BufferLineGroupToggle pinned<CR>", desc = "Buffer Group Toggle ungroup" },
    { "<leader>bcP", ":BufferLineGroupClose pinned<CR>", desc = "Buffer Close pin" },
    { "<leader>bcp", ":BufferLineGroupClose ungrouped<CR>", desc = "Buffer Close ungroup" },
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
      "<leader>fG",
      function()
        require("utils.snacks_terminal").custom_git_pickers.git_diff_upstream()
      end,
      desc = "Git File Upstream",
    },
    {
      "<leader>fL",
      function()
        require("utils.snacks_terminal").custom_git_pickers.git_last_commit_show()
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
      "<leader>fw",
      function()
        local snacks_util = require "utils.snacks_terminal"
        local picker_opts = snacks_util.get_initial_picker_state {
          show_empty = true,
          smartcase = false,
          ignorecase = true,
          hidden = true,
          live = true, -- force in live mode (normally it switch to non live mode)
          args = { "--ignore-case" },
        }

        Snacks.picker.grep_word(picker_opts)
      end,
      desc = "Grep cwd:Git Ignorecase",
      mode = { "n", "x" },
    },
    {
      "<leader>fW",
      function()
        local snacks_util = require "utils.snacks_terminal"
        local picker_opts = snacks_util.get_initial_picker_state {
          show_empty = true,
          need_search = false,
          live = true,
          hidden = true,
        }

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
                ["<C-space>"] = { "toggle_files_buffers", mode = { "n", "i" }, desc = "Toggle File/Buffer" },
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
        Snacks.picker.buffers {
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
        }, { cwd_default = "subproject", use_previous_cwd_state = false }))
      end,
      desc = "Grep Dir Monorepo",
    },
    {
      "<leader>ff",
      function()
        Snacks.picker.files(require("utils.snacks_terminal").get_initial_picker_state {
          search = inputUtils.is_visual_mode() and inputUtils.getSelectedLines "visual_selection",
        })
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
        }, { cwd_default = "subproject", use_previous_cwd_state = false }))
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
        ["ctrl-s"] = fzfcompareref,
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
-- These create reusable actions for git operations, file operations, etc.
M.snacks_action_factories = {
  --- Create git file actions with ref resolution
  --- @param ref_provider string
  --- @param no_resolve boolean
  --- @return table actions Table containing action functions with metadata fields:
  ---   - open_file_diff: function(picker, item) - Open file with diff against ref
  ---   - open_remote_at_ref: function(picker, item) - Open file in remote at ref
  ---   - open_remote_at_head: function(picker, item) - Open file in remote at HEAD
  create_git_file_actions = function(ref_provider, no_resolve)
    local ref = ref_provider
    if not no_resolve and ref_provider then
      ref = ref_provider and gitUtil.get_ref_metadata(ref_provider).resolved_ref or ref_provider
    end
    return {

      -- Action functions
      open_file_diff = function(picker, item)
        if not item or not item.file then
          vim.notify("No file selected", vim.log.levels.WARN)
          return
        end
        picker:close()
        open_file_with_gitsigns_diff(item.file, ref)
      end,
      open_remote_at_ref = function(picker, item)
        if not item or not item.file then
          vim.notify("No file selected", vim.log.levels.WARN)
          return
        end
        open_file_in_remote(item.file, ref)
      end,
      open_remote_at_head = function(picker, item)
        if not item or not item.file then
          vim.notify("No file selected", vim.log.levels.WARN)
          return
        end
        open_file_in_remote(item.file, "HEAD")
      end,
    }
  end,
}

-- Snacks picker actions (stateless functions)
-- Delegates to utils/snacks_actions.lua
M.snacks_actions = {
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
  copy_path_select = function(picker, item)
    require("utils.snacks_actions").copy_path_select(picker, item)
  end,
  toggle_external = function(picker)
    require("utils.snacks_actions").toggle_external(picker)
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
    },
  },
  -- Common keys used across multiple pickers
  common_keys = {
    input = {
      ["<C-o>"] = { "open_file_remote", mode = { "n", "i" }, desc = "Open File Remote" },
      ["<M-e>"] = { "toggle_external", mode = { "n", "i" }, desc = "Toggle external filter" },
      ["<M-b>"] = { "toggle_external", mode = { "n", "i" }, desc = "Toggle external filter" },
    },
  },
  -- Copy path actions - applies to file/grep/explorer pickers
  copy_path_keys = {
    input = {
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
        ["<C-space>"] = { "toggle_files_buffers", mode = { "n", "i" }, desc = "Toggle File/Buffer" },
        ["<A-s>"] = { "toggle_cwd_files_grep", mode = { "n", "i" }, desc = "Cycle CWD Scope" },
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
        ["<C-x>"] = { "remove_qf_item", mode = { "n", "i" }, desc = "Remove QF Item" },
        ["<A-s>"] = { "toggle_cwd_files_grep", mode = { "n", "i" }, desc = "Cycle CWD Scope" },
      }
    ),
  },

  -- Git diff & remote actions - for git file pickers
  git_file_keys = {
    input = {
      ["<C-g>"] = { "open_file_diff", mode = { "n", "i" }, desc = "Open file diff in new tab" },
      ["<C-o>"] = { "open_remote_at_ref", mode = { "n", "i" }, desc = "Open file in remote at ref" },
      ["<C-O>"] = { "open_remote_at_head", mode = { "n", "i" }, desc = "Open file in remote at HEAD" },
      ["<M-e>"] = { "toggle_external", mode = { "n", "i" }, desc = "Toggle missing files" },
      ["<M-b>"] = { "toggle_external", mode = { "n", "i" }, desc = "Toggle missing files" },
    },
    list = {
      ["<C-g>"] = { "open_file_diff", mode = { "n", "i" }, desc = "Open file diff in new tab" },
      ["<C-o>"] = { "open_remote_at_ref", mode = { "n", "i" }, desc = "Open file in remote at ref" },
      ["<C-O>"] = { "open_remote_at_head", mode = { "n", "i" }, desc = "Open file in remote at HEAD" },
      ["<M-e>"] = { "toggle_external", mode = { "n", "i" }, desc = "Toggle missing files" },
      ["<M-b>"] = { "toggle_external", mode = { "n", "i" }, desc = "Toggle missing files" },
    },
  },

  -- Alternate git keys for upstream picker (using different keybinds)
  git_file_keys_upstream = {
    input = {
      ["<C-g>"] = { "open_file_diff", mode = { "n", "i" }, desc = "Open file diff in new tab" },
      ["<C-o>"] = { "open_remote_at_ref", mode = { "n", "i" }, desc = "Open file in remote at upstream ref" },
      ["<C-2>"] = { "open_remote_at_head", mode = { "n", "i" }, desc = "Open file in remote at HEAD" },
      ["<M-e>"] = { "toggle_external", mode = { "n", "i" }, desc = "Toggle missing files" },
      ["<M-b>"] = { "toggle_external", mode = { "n", "i" }, desc = "Toggle missing files" },
    },
    list = {
      ["<C-g>"] = { "open_file_diff", mode = { "n", "i" }, desc = "Open file diff in new tab" },
      ["<C-o>"] = { "open_remote_at_ref", mode = { "n", "i" }, desc = "Open remote compared ref" },
      ["<C-1>"] = { "open_remote_at_head", mode = { "n", "i" }, desc = "Open remote at HEAD" },
      ["<M-e>"] = { "toggle_external", mode = { "n", "i" }, desc = "Toggle missing files" },
      ["<M-b>"] = { "toggle_external", mode = { "n", "i" }, desc = "Toggle missing files" },
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
        ["<C-g>"] = { "open_file_diff", mode = { "n", "i" }, desc = "Open file diff in new tab" },
        ["<C-o>"] = { "open_remote_at_ref", mode = { "n", "i" }, desc = "Open file in remote at selected ref" },
        ["<M-o>"] = { "open_remote_at_head", mode = { "n", "i" }, desc = "Open file in remote at HEAD" },
        ["<M-e>"] = { "toggle_external", mode = { "n", "i" }, desc = "Toggle missing files" },
        ["<M-b>"] = { "toggle_external", mode = { "n", "i" }, desc = "Toggle missing files" },
      },
      list = {
        ["<C-g>"] = { "open_file_diff", mode = { "n", "i" }, desc = "Open file diff in new tab" },
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
        ["<M-e>"] = { "toggle_external", mode = { "n", "i" }, desc = "Toggle missing files" },
        ["<M-b>"] = { "toggle_external", mode = { "n", "i" }, desc = "Toggle missing files" },
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
          keys = vim.tbl_extend("force", {}, snacks_picker_group_keys.files_keys.input),
        },
      },
    },
    -- Buffers picker: common + copy path + file-specific actions
    buffers = {
      -- https://deepwiki.com/search/suggest-way-to-achieve-the-act_13b29d19-06dc-4383-bc2b-5871786b2b2e?mode=deep
      transform = function(item, ctx)
        local show_external = ctx and ctx.picker and ctx.picker.opts.external
        local missing = false
        local path = nil
        if show_external then
          local ok, util = pcall(function()
            return require("snacks").picker.util
          end)
          if ok and util then
            path = util.path(item)
          end
          if path and path ~= "" then
            missing = vim.fn.filereadable(path) == 0 and vim.fn.isdirectory(path) == 0
          end
        end

        if vim.g.snacks_debug_external_filter then
          print(
            string.format(
              "external_filter[buffers]: show_external=%s missing=%s file=%s",
              tostring(show_external),
              tostring(missing),
              tostring(item and (item.file or item.text) or "nil")
            )
          )
        end

        if not show_external then
          return item
        end

        if missing then
          return true
        end

        return not pathUtil.is_in_project_dir(item)
      end,
      actions = {
        toggle_external = function(picker)
          require("utils.snacks_actions").toggle_external(picker)
        end,
      },
      win = {
        input = {
          footer = "filter external A-e/b",
          keys = vim.tbl_extend("force", snacks_picker_group_keys.files_keys.input, {
            ["<M-e>"] = { "toggle_external", mode = { "n", "i" }, desc = "Toggle external buffers" },
            ["<M-b>"] = { "toggle_external", mode = { "n", "i" }, desc = "Toggle external buffers" },
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
    -- Git files picker: common + copy path keys
    git_files = {
      win = {
        input = {
          keys = vim.tbl_extend(
            "force",
            snacks_picker_shared_keys.common_keys.input,
            snacks_picker_shared_keys.copy_path_keys.input
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
          keys = vim.tbl_extend("force", {}, snacks_picker_group_keys.grep_keys.input),
        },
      },
    },

    -- Grep word picker: common + copy path + grep actions
    grep_word = {
      win = {
        input = {
          keys = vim.tbl_extend("force", {}, snacks_picker_group_keys.grep_keys.input),
          -- keys = snacks_picker_group_keys.grep_keys.input,
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
        ["<M-e>"] = { "toggle_external", mode = { "n", "i" }, desc = "Toggle external filter" },
        ["<M-b>"] = { "toggle_external", mode = { "n", "i" }, desc = "Toggle external filter" },
        ["/"] = false, -- alow search to apply on list
      },
    },
    input = {
      keys = {
        ["<C-y>"] = { "yank", mode = { "n", "i" } },
        ["<S-t>"] = { "trouble_open", mode = { "n" }, desc = "Smart open Touble" },
        ["<C-t>"] = { "terminal", mode = { "i" }, desc = "Open terminal from picker" },
        -- ["<C-p>"] = { "focus_preview", desc = "Focus Preview" },
        ["<C-p>"] = false,
        ["<C-n>"] = false,
        ["0"] = { "focus_preview", mode = { "n" }, desc = "Focus Preview" },
        ["<c-a>"] = { "sidekick_send", mode = { "n", "i" } },
        ["<a-a>"] = { "select_all", mode = { "n", "i" } },
        ["<a-q>"] = { "qflist", mode = { "n", "i" } },
        ["<c-q>"] = "cancel",
        ["<M-e>"] = { "toggle_external", mode = { "n", "i" }, desc = "Toggle external filter" },
        ["<M-b>"] = { "toggle_external", mode = { "n", "i" }, desc = "Toggle external filter" },
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
