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

  local remote_ref = line:match("^remotes/(.-)%s+")
  if remote_ref then
    commit_hash = remote_ref
  else
    commit_hash = line:match("^(%S+)")
  end

  local file_path = vim.fn.expand "%:p"
  vim.cmd("tabnew " .. file_path)
  gitsigns.diffthis(commit_hash, { vertical = true })
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

-- Helper function to open file diff with gitsigns
-- @param file_path string: File path (relative or absolute)
-- @param ref string: Git reference to compare with
local function open_file_with_gitsigns_diff(file_path, ref)
  if not pcall(require, "gitsigns") then
    vim.notify("Gitsigns is not available", vim.log.levels.ERROR)
    return
  end

  local git_root = Snacks.git.get_root()

  -- Convert to absolute path if needed
  if vim.fn.filereadable(file_path) == 0 then
    file_path = git_root .. "/" .. file_path
  end

  -- Open file in new tab
  vim.cmd("tabnew " .. vim.fn.fnameescape(file_path))

  -- Show diff with gitsigns
  require("gitsigns").diffthis(ref, {
    vertical = true,
  })
end

-- Helper function to open current buffer in new tab with gitsigns diff
-- @param ref string: Git reference to compare with
local function open_current_buffer_with_gitsigns_diff(ref)
  if not pcall(require, "gitsigns") then
    vim.notify("Gitsigns is not available", vim.log.levels.ERROR)
    return
  end

  local current_file = vim.api.nvim_buf_get_name(0)

  if current_file == "" then
    vim.notify("No file in current buffer", vim.log.levels.WARN)
    return
  end

  -- Open in new tab
  vim.cmd("tabnew " .. vim.fn.fnameescape(current_file))

  -- Show diff with gitsigns
  require("gitsigns").diffthis(ref, {
    vertical = true,
  })
end

-- Helper function to build remote URL for a file at a specific ref
-- @param file_path string: File path (relative or absolute)
-- @param ref string: Git reference (branch, tag, or commit)
-- @return string|nil: Remote URL or nil if error
local function build_remote_url(file_path, ref)
  local git_root = Snacks.git.get_root()
  if not git_root then
    return nil
  end

  -- Convert to absolute path if needed
  if vim.fn.filereadable(file_path) == 0 then
    file_path = git_root .. "/" .. file_path
  end

  -- Get relative path from git root
  local rel_path = file_path:gsub("^" .. vim.pesc(git_root) .. "/?" , "")

  -- Get remote path using gitUtil
  local remote_path = gitUtil.get_remote_path("origin")

  if not remote_path or remote_path == "" then
    return nil
  end

  -- Build URL - detect GitLab vs GitHub
  local url
  if remote_path:match("gitlab") then
    -- GitLab style: /-/blob/
    url = string.format("https://%s/-/blob/%s/%s", remote_path, ref, rel_path)
  else
    -- GitHub style: /blob/
    url = string.format("https://%s/blob/%s/%s", remote_path, ref, rel_path)
  end

  return url
end

-- Helper function to open file in remote at specific ref
-- @param file_path string: File path (relative or absolute)
-- @param ref string: Git reference to open at
local function open_file_in_remote(file_path, ref)
  local url = build_remote_url(file_path, ref)

  if not url then
    vim.notify("Failed to build remote URL", vim.log.levels.ERROR)
    return
  end

  -- Get filename for notification
  local filename = vim.fn.fnamemodify(file_path, ":t")

  -- Open in browser
  vim.fn.jobstart({ "open", url }, { detach = true })
  vim.notify(string.format("Opening %s @ %s in browser", filename, ref), vim.log.levels.INFO)
end

-- Export helper functions that are used in opts
M.helpers = {
  get_current_buffer_path = get_current_buffer_path,
  toggle_diffpreview_alt = toggle_diffpreview_alt,
  open_current_buffer_with_gitsigns_diff = open_current_buffer_with_gitsigns_diff,
  -- #region: local used
  -- open_file_with_gitsigns_diff = open_file_with_gitsigns_diff,
  -- fzfcompareref = fzfcompareref,
  -- build_remote_url = build_remote_url,
  -- open_file_in_remote = open_file_in_remote,
  -- #endregion
}

-- Keymap configurations by plugin
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
      ":OverseerTaskAction<CR>",
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
        desc = "Code Companion - Chat",
        mode = "v",
      },
      {
        companion_prefix .. "M",
        "<cmd>CodeCompanion /short-staged-commit<cr>",
        desc = "Code Companion - Git commit message (staged)",
      },
      {
        companion_prefix .. "Q",
        "<cmd>'<,'>CodeCompanion<cr>",
        desc = "Code Companion - Quick chat",
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
  avante = require("utils.my_avante_utils").generate_avante_keymaps({
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
    }
  }),

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
    {
      "<leader>fs",
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
      "<leader>gO",
      function()
        Snacks.gitbrowse({   
          branch = require("utils.git").git_main_branch(),
          what = "file",
        })
      end,
      desc = "Git open remote main",
      mode = { "n", "x" }
    },
    {
      "<leader>fw",
      function()
        local snacks_util = require("utils.snacks_terminal")
        local picker_opts = snacks_util.get_initial_picker_state({
          show_empty = true,
          smartcase = false,
          ignorecase = true,
          hidden = true,
          live = true, -- force in live mode (normally it switch to non live mode)
          args = { "--ignore-case"},
        })

        Snacks.picker.grep_word(picker_opts)
      end,
      desc = "Grep cwd:Git Ignorecase",
      mode = { "n", "x" },
    },
    {
      "<leader>fW",
      function()
        local snacks_util = require("utils.snacks_terminal")
        local picker_opts = snacks_util.get_initial_picker_state({
          show_empty = true,
          need_search = false,
          live = true,
          hidden = true,
        })

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
        local notcurdir = (
          curword == "" or (vim.fn.filereadable(filepath) == 0 and vim.fn.isdirectory(filepath) == 0)
        )
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
      "<C-e>",
      function()
        local snacks_util = require("utils.snacks_terminal")
        local picker_opts = snacks_util.get_initial_picker_state({
          win = {
            input = {
              keys = {
                ["<C-space>"] = { "toggle_files_buffers", mode = { "n", "i" }, desc = "Toggle File/Buffer" },
              },
            },
          },
        })
        Snacks.picker.smart(picker_opts)
      end,
      desc = "Find Smart",
    },
    {
      "<leader><space>",
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
        Snacks.picker.grep(
          require("utils.snacks_terminal").get_initial_picker_state({
            title = "Grep Subproject",
            search = inputUtils.is_visual_mode() and inputUtils.getSelectedLines('visual_selection'),
            }, { cwd_default = "subproject", use_previous_cwd_state = false }
          )
        )
      end,
      mode = { "n", "x"},
      desc = "Grep Dir Monorepo Selected",
    },
    {
      "<leader>fWg",
      function()
        Snacks.picker.grep(
          require("utils.snacks_terminal").get_initial_picker_state({
            title = "Grep Monorepo Files",
          }, { cwd_default = "subproject", use_previous_cwd_state = false }
          )
      )
      end,
      desc = "Grep Dir Monorepo",
    },
    {
      "<leader>ff",
      function()
        Snacks.picker.files(
          require("utils.snacks_terminal").get_initial_picker_state({
            search = inputUtils.is_visual_mode() and inputUtils.getSelectedLines('visual_selection'),
          })
        )
      end,
      desc = "Find Files",
      mode = { "n", "v" },
    },
    {
      "<leader>sb", 
      -- normal mode set in default snacks
      function()
        Snacks.picker.lines(
          require("utils.snacks_terminal").get_initial_picker_state({
            search = inputUtils.is_visual_mode() and inputUtils.getSelectedLines('visual_selection'),
          })
        )
      end,
      desc = "Buffer Lines Selected",
      mode = "x"
    },
    {
      "<leader>sB",
      -- normal mode set in default snacks
      function()
        Snacks.picker.grep_buffers(
          require("utils.snacks_terminal").get_initial_picker_state({
            search = inputUtils.is_visual_mode() and inputUtils.getSelectedLines('visual_selection'),
          })
        )
      end,
      desc = "Grep Open Buffers Selected",
      mode = "x"
    },
    {
      "<leader>fF",
      function()
        Snacks.picker.files(
          require("utils.snacks_terminal").get_initial_picker_state({
            search = inputUtils.is_visual_mode() and inputUtils.getSelectedLines('visual_selection'),
            title = "Find Files Monorepo/Subproject",
          }, { cwd_default = "subproject", use_previous_cwd_state = false }
          )
        )
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

return M
