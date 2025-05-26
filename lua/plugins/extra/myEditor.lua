local pathUtil = require("utils.mypath")
local gitUtil = require("utils.git")
local keyutil = require("utils.keyutil")
local Lsp = require("utils.lsp")
local isSnackEnabled = keyutil.isSnackEnabled
local key_f = keyutil.key_f
local key_s = keyutil.key_s
local key_g = keyutil.key_g
local open_remote = gitUtil.open_remote

local mapping_key_prefix = vim.g.ai_prefix_key or "<leader>A" -- orginal from codecompanion.lua

return {
  -- Disabled list
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
    keys = {
      {
        "<leader>ow",
        function()
          local overseer = require("overseer")
          overseer.run_template({ name = "run script" }, function(task)
            if task then
              task:add_component({ "restart_on_save", paths = { vim.fn.expand("%:p") } })
              local main_win = vim.api.nvim_get_current_win()
              overseer.run_action(task, "open vsplit")
              vim.api.nvim_set_current_win(main_win)
            else
              vim.notify("WatchRun not supported for filetype " .. vim.bo.filetype, vim.log.levels.ERROR)
            end
          end)
        end,
        desc = "WatchRun",
      },
      {
        "<leader>oT",
        ":OverseerTaskAction<CR>", -- Add the command you want to run here
        desc = "Run Overseer Task Action",
      },
      {
        "<leader>oQ",
        ":OverseerDeleteBundle<CR>",
        desc = "Delete Overseer Bundle",
      },
      {
        "<leader>oC",
        ":OverseerClearCache<CR>",
        desc = "Clear Overseer Cache",
      },
      {
        "<leader>os",
        ":OverseerSaveBundle<CR>",
        desc = "Save Overseer Bundle",
      },
      {
        "<leader>ol",
        ":OverseerLoadBundle<CR>",
        desc = "Load Overseer Bundle",
      },
      {
        "<leader>on",
        ":OverseerBuild<CR>",
        desc = "New Task",
      },
    },
    opts = {
      -- default config: https://github.com/stevearc/overseer.nvim/blob/a2734d90c514eea27c4759c9f502adbcdfbce485/lua/overseer/config.lua#L4
      templates = {
        "builtin",
        "user.run_script",
        "common_shell.grep_async",
        "agoda.android_client.and_build",
        "agoda.mmb.mmb_pick",
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
  {
    "olimorris/codecompanion.nvim",
    keys = {
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
          vim.cmd("CodeCompanion")
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
  },
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    enabled = true,
    keys = {
      {
        "<leader>aE",
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
    opts = {
      mappings = {
        -- edit = "<leader>rE", -- does not overwrite why ?
        --- @class AvanteConflictMappings
        sidebar = {
          -- apply_all = "A",
          -- apply_cursor = "a",
          -- retry_user_request = "r",
          -- edit_user_request = "e",
          switch_windows = "<C-w>",
          -- reverse_switch_windows = "<S-Tab>",
        },
      },
    },
  },
  {
    "jellydn/quick-code-runner.nvim",
    keys = {
      {
        "<leader>cP",
        "gg0vGg$:QuickCodeRunner<CR>",
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
          pathUtil.get_pythonpath(false, true) .. " -u",
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
          "deno run",
        },
        --  end common -------------------
        sh = {
          "bash",
        },
      },
      global_files = {
        javascript = pathUtil.get_global_file_by_type("js"),
        typescript = pathUtil.get_global_file_by_type("ts"),
        python = pathUtil.get_global_file_by_type("py"),
        go = pathUtil.get_global_file_by_type("go"),
        lua = pathUtil.get_global_file_by_type("lua"),
        --  end common -------------------
        sh = pathUtil.get_global_file_by_type("sh"),
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
              -- Custom action to open remote file

              local ref = selected[1]
              ref = ref:gsub("^[^/]+/", "")
              local sanitized_ref = ref:match("([^%s]+)$") -- remove all space nonrelated ref prefixes
              open_remote(sanitized_ref, "file")
              open_remote(sanitized_ref, "branch")
            end,
          },
        },
        bcommits = {
          actions = {
            ["ctrl-o"] = function(selected)
              -- Custom action to open remote file
              local commit_hash = selected[1]:match("%w+")
              open_remote(commit_hash, "file")
              open_remote(commit_hash, "commit")
            end,
          },
        },
        blame = {
          actions = {
            ["ctrl-o"] = function(selected)
              -- Custom action to open remote file
              local commit_hash = selected[1]:match("%w+")
              open_remote(commit_hash, "file")
              open_remote(commit_hash, "commit")
            end,
          },
        },
        commits = {
          actions = {
            -- ["default"] = function(selected)
            --   -- Default action (e.g., open commit diff)
            -- end,
            ["ctrl-o"] = function(selected)
              -- Custom action to open remote file
              local commit_hash = selected[1]:match("%w+")
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
  {
    "folke/persistence.nvim",
    opts = {
      dir = vim.fn.stdpath("state") .. "/my-sessions/", -- directory where session files are saved
    },
    keys = {
      { "<leader>qs", function() require("persistence").save() end, desc = "Save session" },
      { "<leader>ql", function() require("persistence").load({ last = true }) end, desc = "Restore last session" },
      { "<leader>qS", function() require("persistence").select() end, desc = "Select session to restore" },
      { "<leader>qd", function() require("persistence").stop() end, desc = "Stop persistence" },
    },
  },
  {
    "folke/snacks.nvim",
    enabled = isSnackEnabled,
    opts = {
      picker = {
        formatters = {
          file = {
            truncate = 200,
          },
        },
        ui_select = true, -- boolean set `vim.ui.select` to a snacks picker, might conflict with fzf
        sources = {
          -- sample pickers: https://github.com/WizardStark/dotfiles/blob/main/home/.config/nvim/lua/workspaces/ui.lua#L417
          git_branches = {
            win = {
              input = {
                keys = {
                  ["<C-s>"] = { "my_diff_compare", mode = { "n", "i" }, desc = "Open Diff" },
                  -- ["<C-t>"] = { "test_picker", mode = { "n", "i" }, desc = "Test picker" },
                },
              },
            },
          },
          git_log = {
            win = {
              input = {
                keys = {
                  ["<C-s>"] = { "my_diff_compare", mode = { "n", "i" }, desc = "Open Diff" },
                },
              },
            },
          },
        },
        actions = {
          test_picker = function(picker, item)
            print([==[ item:]==], vim.inspect(item)) -- __AUTO_GENERATED_PRINT_VAR_END__
            picker:close()
          end,
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
            vim.cmd("tabnew")
            vim.cmd("b#") -- switch to the previous buffer
            vim.cmd("bd#") -- delete the previous buffer (empty buffer)
            print([==[run my_diff_compare ref:]==], vim.inspect(ref)) -- __AUTO_GENERATED_PRINT_VAR_END__
            require("gitsigns").diffthis(ref, {
              vertical = true,
            })
          end,
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
        "<c-_>",
        false
      },
      {
        "<leader>gb",
        function()
          Snacks.picker.git_branches()
        end,
        desc = "Git Branches",
      },
    },
  },
  {
    "folke/which-key.nvim",
    optional = true,
    opts = {
      spec = vim.list_extend({
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
          icon = { icon = "" },
          color = "black",
        },
        {
          "<localleader>c",
          group = "file/dir",
          mode = { "n" },
          icon = { icon = "📂" },
          color = "black",
        },
        {
          "<localleader>f",
          group = "file/find",
          mode = { "n" },
          icon = { icon = "📂" },
          color = "black",
        },
        {
          "<localleader>r",
          group = "code/lsp/lua",
          mode = { "n" },
          icon = { icon = "💻" },
          color = "black",
        },
      }, isSnackEnabled and {
        {
          "<leader>L",
          group = "linter/lsp",
          mode = { "n" },
          color = "black",
        },
        {
          "<leader>" .. key_f,
          group = "Find(Fzf)",
          mode = { "n" },
          icon = { icon = "" },
          color = "black",
        },
        {
          "<leader>" .. key_g,
          group = "Git(Fzf)",
          mode = { "n", "v" },
          icon = { icon = "" },
          color = "black",
        },
        {
          "<leader>" .. key_s,
          group = "Search(Fzf)",
          mode = { "n", "v" },
          icon = { icon = "" },
          color = "black",
        },
      } or {}),
    },
  }, -- { import = "plugins.extras.copilot-chat-v2" },
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
  -- { import = "plugins.extras.telescope-lazy" },
  { import = "plugins.extras.myNoice" },
  { import = "plugins.extras.telescope" },
  -- { import = "plugins.extras.neotree" },
  -- { import = "plugins.extras.fzf" },
  -- { import = "plugins.extras.telescope-map-essntials" },
}

