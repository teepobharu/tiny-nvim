local pathUtil = require "utils.mypath"
local keyutil = require "utils.keyutil"
local editor_keymaps = require "utils.editor_keymaps"

local isSnackEnabled = keyutil.isSnackEnabled

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
    version = "^2.1.0",
    keys = editor_keymaps.keymaps.overseer,
    opts = {
      -- default config: https://github.com/stevearc/overseer.nvim/blob/a2734d90c514eea27c4759c9f502adbcdfbce485/lua/overseer/config.lua#L4
      -- seems like already included by default if put inside lua/overseer/template
      template_dirs = {},
      disable_template_modules = {
        -- works
        "overseer.template.common_shell.grep_async", -- Exclude specific module
        -- not work
        -- "common_shell.grep_async",           -- Exclude specific module
      },
      strategy = {
        "terminal",
        use_shell = true,
      },
      -- https://deepwiki.com/search/can-params-return-object-value_cf6755d4-5426-473d-9d19-226d55ef99b7?mode=fast
      task_list = {
        keymaps = {
          ["<A-q>"] = {
            "keymap.run_action",
            opts = { action = "open output in quickfix" },
            desc = "Open task output in the quickfix",
          },
          ["<C-q>"] = { "<CMD>close<CR>", desc = "Close task list" },
          ["a"] = { "keymap.run_action", opts = { action = "edit" }, desc = "Edit task" },
          -- since ^ works no mapping not work ?
          ["<C-s>"] = { "keymap.run_action", opts = { action = "stop" }, desc = "Stop task" },
          ["<C-c>"] = { "keymap.run_action", opts = { action = "stop" }, desc = "Stop task" },
          ["<C-r>"] = { "keymap.run_action", opts = { action = "restart" }, desc = "Restart task" },
          ["<C-x>"] = { "keymap.run_action", opts = { action = "dispose" }, desc = "Dispose task" },
          ["<S-Up>"] = "keymap.scroll_output_up",
          ["<S-Down>"] = "keymap.scroll_output_down",
          ["<C-w>"] = { "keymap.run_action", opts = { action = "watch" }, desc = "Watch file for changes" },
          ["<C-p>"] = { "keymap.run_action", opts = { action = "unwatch" }, desc = "Stop watching file" },
          -- H use to switch buffer ?
          ["H"] = "keymap.prev_task",
          ["J"] = "keymap.prev_task",
          ["L"] = "keymap.next_task",
          ["<C-l>"] = false,
          ["<C-h>"] = false,
          ["<C-j>"] = false,
          ["<C-k>"] = false,
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
    "github/copilot.vim",
    -- v1.58.0 has issue errors 2026-01-26 02:58
    version = "1.57.0",
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
    "CopilotC-Nvim/CopilotChat.nvim",
    enabled = true,
    keys = editor_keymaps.keymaps.copilot_chat,
    opts = {
      -- model = "grok-code-fast-1", -- override claude-sonnet model since not support on my copilot (get ereror)
      model = require("utils.my_ai_constants").DEFAULT_COPILOT_MODEL, -- override claude-sonnet model since not support on my copilot (get ereror)
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
        allow_access_to_git_ignored_files = true, -- still not allow outside repo / root how ?
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
        select_history = "<leader>rh",
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
          external = {
            icon = "🗑️",
            value = true,
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
        actions = vim.tbl_extend("force", editor_keymaps.snacks_common_actions, {}), -- Close vim.tbl_extend for actions
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
        { "<localleader>a", group = "ai", mode = { "n", "v" } },
        { "<leader>S", group = "terminal", mode = { "n", "v" } },
        { "<leader>r", group = "avante/code", mode = { "n" } },
        { "<leader>r", group = "avante/code", mode = { "v" } },
        { "<leader>d", group = "diff/debug", mode = { "n" } },
        { "<leader>d", group = "debug", mode = { "v" } },
        { "<localleader>S", group = "terminal snacks" },
        { "<localleader>T", group = "terminal toggleterm" },
        { "<localleader>F", group = "Format", mode = { "n", "v" } },
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
          group = "quick format",
          mode = { "n", "v" },
          icon = { icon = "📂", color = "black" },
        },
        {
          "<localleader>r",
          group = "code/lsp/lua",
          mode = { "n", "v" },
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
        -- default = { -- this is merged (append as set on default bhevior list extend in lazy merge behavior) in lua/plugins/coding.lua
        --     "avante_commands", "avante_mentions", "avante_files"
        --     -- ,"codecompanion"
        --   },
        providers = {
          -- codecompanion = {
          --   name = "codecompanion",
          --   module = "blink.compat.source",
          --   score_offset = 1000, -- show at a higher priority than lsp
          -- },
          --
          avante_shortcuts = {
            name = "avante_shortcuts",
            module = "blink.compat.source",
            score_offset = 1000, -- show at a higher priority than lsp
            opts = {},
          },
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
          -- already handle by Kaiser-Yang/blink-cmp-avante
          AvanteInput = {
            inherit_defaults = true,
            "avante_commands",
            "avante_mentions",
            "avante_files",
            "avante_shortcuts",
          },
          -- AvanteInput = { 'avante', 'lsp', 'path', 'snippets', 'buffer' },
          -- AvanteInput = { inherit_defaults = true },
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
