local Lsp = require("utils.lsp")
local keyutil = require("utils.keyutil")
local isSnackEnabled = keyutil.isSnackEnabled
local key_f = keyutil.key_f
local key_s = keyutil.key_s
local key_g = keyutil.key_g

local function symbols_filter(entry, ctx)
  if ctx.symbols_filter == nil then
    ctx.symbols_filter = Lsp.get_kind_filter(ctx.bufnr) or false
  end
  if ctx.symbols_filter == false then
    return true
  end
  return vim.tbl_contains(ctx.symbols_filter, entry.kind)
end

return {
  {
    "ahmedkhalf/project.nvim",
    config = function(_, opts)
      require("project_nvim").setup(opts)
    end,
  },
  {
    "ibhagwan/fzf-lua",
    event = "VeryLazy",
    opts = {
      hls = {
        border = "FloatBorder",
        cursorline = "Visual",
        cursorlinenr = "Visual",
        backdrop = "FzfLuaBackdrop",
      },
      fzf_colors = false,
      -- History file
      fzf_opts = {
        ["--history"] = vim.fn.stdpath("data") .. "/fzf-lua-history",
        ["--info"] = false,
        ["--border"] = false,
        ["--preview-window"] = false,
        ["--no-scrollbar"] = true,
      },
      winopts = {
        width = 0.8,
        height = 0.8,
        row = 0.5,
        col = 0.5,
        preview = {
          layout = "flex",
          flip_columns = 130,
          scrollchars = { "┃", "" },
        },
        backdrop = 60,
        -- title         = "Title",
        -- title_pos     = "center",        -- 'left', 'center' or 'right'
        -- title_flags = false, -- uncomment to disable title flags
        -- defaults keys:
        -- alt-i: toggle ignore
        -- alt-h: toggle hidden
        -- alt-f: toggle follow
      },
      files = {
        multiprocess = true,
        git_icons = false,
        file_icons = false,
      },
      grep = {
        multiprocess = true,
      },
      git = {
        files = {
          multiprocess = true,
        },
        status = {
          winopts = {
            preview = { vertical = "down:70%", horizontal = "right:70%" },
          },
        },
        commits = { winopts = { preview = { vertical = "down:60%" } } },
        bcommits = { winopts = { preview = { vertical = "down:60%" } } },
        branches = {
          winopts = {
            preview = { vertical = "down:75%", horizontal = "right:75%" },
          },
        },
      },
      defaults = {
        -- VS Code style
        formatter = { "path.filename_first", 2 },
      },
      lsp = {
        symbols = {
          symbol_hl = function(s)
            return "TroubleIcon" .. s
          end,
          symbol_fmt = function(s)
            return s:lower() .. "\t"
          end,
          child_prefix = false,
          path_shorten = 1,
        },
        code_actions = {
          winopts = {
            preview = { layout = "reverse-list", horizontal = "right:75%" },
          },
        },
      },
    },
    config = function(_, options)
      local fzf_lua = require("fzf-lua")
      local actions = require("fzf-lua.actions")
      local config = require("fzf-lua.config")

      -- Files actions
      config.defaults.actions.files["alt-."] = actions.toggle_hidden

      -- Trouble
      config.defaults.actions.files["ctrl-t"] = require("trouble.sources.fzf").actions.open

      -- Refer https://github.com/ibhagwan/fzf-lua/blob/main/lua/fzf-lua/defaults.lua#L69 for default keymaps
      -- Shift+up/down to move the preview window
      -- Alt+q to send to quickfix
      -- Alt+a to toggle all
      fzf_lua.setup(options)

      -- if snack not enable do below
      if isSnackEnabled then
        return
      end
      -- disable in favor of snacks since
      -- avante and copilot chat can see multi select UI but still not work like fzf
      -- Automatic sizing of height/width of vim.ui.select
      fzf_lua.register_ui_select(function(_, items)
        local min_h, max_h = 0.60, 0.80
        local h = (#items + 4) / vim.o.lines
        if h < min_h then
          h = min_h
        elseif h > max_h then
          h = max_h
        end
        return { winopts = { height = h, width = 0.80, row = 0.40 } }
      end)

      -- Refer https://github.com/ibhagwan/fzf-lua/issues/602
      vim.lsp.handlers["textDocument/codeAction"] = fzf_lua.lsp_code_actions
      vim.lsp.handlers["textDocument/definition"] = function()
        fzf_lua.lsp_definitions({ jump1 = true, ignore_current_line = true })
      end
      vim.lsp.handlers["textDocument/declaration"] = fzf_lua.lsp_declarations
      vim.lsp.handlers["textDocument/typeDefinition"] = fzf_lua.lsp_typedefs
      vim.lsp.handlers["textDocument/implementation"] = fzf_lua.lsp_implementations
      vim.lsp.handlers["textDocument/documentSymbol"] = fzf_lua.lsp_document_symbols
      vim.lsp.handlers["workspace/symbol"] = fzf_lua.lsp_workspace_symbols
      vim.lsp.handlers["callHierarchy/incomingCalls"] = fzf_lua.lsp_incoming_calls
      vim.lsp.handlers["callHierarchy/outgoingCalls"] = fzf_lua.lsp_outgoing_calls
    end,
    keys = {
      { "<esc>", "<cmd>close<cr>", ft = "fzf", mode = "t", nowait = true },
      { "<c-j>", "<Down>", ft = "fzf", mode = "t", nowait = true },
      { "<c-k>", "<Up>", ft = "fzf", mode = "t", nowait = true },
      {
        "<C-g>",
        "<cmd> :FzfLua grep_project<CR>",
        desc = "Find Grep",
      },
      {
        "<C-g>",
        function()
          -- Grep visual selection in the current directory or lsp root or git root
          local root_dir = require("utils.root").get()
          local fzf_lua = require("fzf-lua")

          fzf_lua.grep_visual({
            cwd = root_dir,
            rg_opts = "--column --hidden --smart-case --color=always --no-heading --line-number -g '!{.git,node_modules}/'",
            multiprocess = true,
          })
        end,
        desc = "Search Grep in visual selection",
        mode = "v",
      },
      {
        "<leader>" .. key_s .. "w",
        function()
          local root_dir = require("utils.root").git()
          local fzf_lua = require("fzf-lua")

          fzf_lua.grep_visual({
            cwd = root_dir,
            rg_opts = "--column --hidden --smart-case --color=always --no-heading --line-number -g '!{.git,node_modules}/'",
            multiprocess = true,
          })
        end,
        desc = "Search word in visual selection (git root)",
        mode = "v",
      },
      {
        "<leader>" .. key_f .. "g",
        "<cmd> :FzfLua grep_project --cmd 'git grep --line-number --column --color=always'<CR>",
        desc = "Find Git Grep",
      },
      -- Find open buffers
      {
        "<leader>" .. key_f .. "b",
        "<cmd>FzfLua buffers sort_mru=true sort_lastused=true<cr>",
        desc = "Find Buffers",
      },
      {
        not isSnackEnabled and "<localleader>," or "<leader>,",
        "<cmd>FzfLua buffers sort_mru=true sort_lastused=true<cr>",
        desc = "Switch Buffer",
      },
      -- Find recent files
      {
        "<leader>" .. key_f .. "r",
        function()
          local root_dir = require("utils.root").git()
          require("fzf-lua").oldfiles({ cwd = root_dir })
        end,
        desc = "Find Recent Files",
      },
      -- Resume last fzf command
      {
        "<leader>" .. key_f .. "R",
        "<cmd> :FzfLua resume<CR>",
        desc = "Resume Fzf",
      },
      -- File file by live grep, better for large projects
      {
        "<leader>" .. key_f .. "l",
        function()
          local root_dir = require("utils.root").git()
          local fzf_lua = require("fzf-lua")
          fzf_lua.live_grep({
            cwd = root_dir,
            rg_opts = "--column --hidden --smart-case --color=always --no-heading --line-number -g '!{.git,node_modules}/'",
            multiprocess = true,
          })
        end,
        desc = "Find Live Grep (including hidden files)",
      },
      {
        not isSnackEnabled and "<C-e>" or "<localleader><C-e>",
        function()
          local root_dir = require("utils.root").get()
          require("fzf-lua").files({
            cwd = root_dir,
            cwd_prompt = false,
          })
        end,
        desc = "Find Files at project directory",
      },
      {
        not isSnackEnabled and "<leader><space>" or "<localleader><space>",
        function()
          local root_dir = require("utils.root").git()
          require("fzf-lua").files({
            cwd = root_dir,
            cwd_prompt = false,
          })
        end,
        desc = "Find Files at project directory",
      },
      {
        isSnackEnabled and "<localleader>/" or "<leader>/",
        function()
          local root_dir = require("utils.root").get()
          require("fzf-lua").live_grep({ cwd = root_dir, multiprocess = true })
        end,
        desc = "Grep Files at current directory",
      },
      {
        "<leader>" .. key_f .. "f",
        function()
          local root_dir = require("utils.root").git()
          require("fzf-lua").git_files({ cwd = root_dir })
        end,
        desc = "Find Git Files",
      },
      {
        "<leader>" .. key_f .. "c",
        function()
          require("fzf-lua").files({ cwd = "~/.config/nvim" })
        end,
        desc = "Find Neovim Configs",
      },
      { "<leader>" .. key_s .. "b", "<cmd> :FzfLua grep_curbuf<CR>", desc = "Search Current Buffer" },
      { "<leader>" .. key_s .. "B", "<cmd> :FzfLua lines<CR>", desc = "Search Lines in Open Buffers" },
      {
        "<leader>" .. key_s .. "w",
        function()
          local root_dir = require("utils.root").git()
          require("fzf-lua").grep_cword({ cwd = root_dir, multiprocess = true })
        end,
        desc = "Search word under cursor (git root)",
      },
      {
        "<leader>" .. key_s .. "W",
        function()
          local root_dir = require("utils.root").git()
          require("fzf-lua").grep_cWORD({ cwd = root_dir, multiprocess = true })
        end,
        desc = "Search WORD under cursor (git root)",
      },
      {
        "<leader>" .. key_g .. "s",
        function()
          local root_dir = require("utils.root").git()
          require("fzf-lua").git_status({ cwd = root_dir })
        end,
        desc = "Git Status",
      },
      { "<leader>" .. key_g .. "c", "<cmd> :FzfLua git_commits<CR>", desc = "Git Commits" },
      { "<leader>" .. key_g .. "b", "<cmd> :FzfLua git_branches<CR>", desc = "Git Branches" },
      { "<leader>" .. key_g .. "B", "<cmd> :FzfLua git_bcommits<CR>", desc = "Git Buffer Commits" },
      { "<leader>" .. key_s .. "a", "<cmd> :FzfLua commands<CR>", desc = "Find Actions" },
      { "<leader>" .. key_s .. "d", "<cmd>FzfLua diagnostics_document<cr>", desc = "Document Diagnostics" },
      { "<leader>" .. key_s .. "D", "<cmd>FzfLua diagnostics_workspace<cr>", desc = "Workspace Diagnostics" },
      { "<leader>" .. key_s .. ":", "<cmd> :FzfLua command_history<CR>", desc = "Find Command History" },
      {
        "<leader>" .. key_s .. "s",
        function()
          require("fzf-lua").lsp_document_symbols({
            regex_filter = symbols_filter,
          })
        end,
        desc = "Goto Symbol",
      },
      {
        "<leader>" .. key_s .. "S",
        function()
          require("fzf-lua").lsp_live_workspace_symbols({
            regex_filter = symbols_filter,
          })
        end,
        desc = "Goto Symbol (Workspace)",
      },
      { "<leader>" .. key_s .. "i", "<cmd> :FzfLua lsp_incoming_calls<CR>", desc = "LSP Incoming Calls" },
      { "<leader>" .. key_s .. "o", "<cmd> :FzfLua lsp_outgoing_calls<CR>", desc = "LSP Outgoing Calls" },
      { "<leader>" .. key_s .. "k", "<cmd> :FzfLua keymaps<CR>", desc = "Search Keymaps" },
      { "<leader>" .. key_s .. "m", "<cmd> :FzfLua marks<CR>", desc = "Search Marks" },
      { "<leader>" .. key_s .. "c", "<cmd> :FzfLua colorschemes<CR>", desc = "Search colorschemes" },
      { "<leader>" .. key_s .. "h", "<cmd> :FzfLua help_tags<CR>", desc = "Search Help" },
      { "<leader>" .. key_s .. "j", "<cmd>FzfLua jumps<cr>", desc = "Search Jumplist" },
      { "<leader>" .. key_s .. "q", "<cmd> :FzfLua quickfix<CR>", desc = "Search Quickfix" },
      {
        "<leader>" .. key_f .. "p",
        function()
          local fzf_lua = require("fzf-lua")

          local ok, _ = pcall(require, "project_nvim")
          if not ok then
            vim.notify("Project.nvim is not installed", vim.log.levels.ERROR, { title = "Fzf Lua" })
            return
          end

          local history = require("project_nvim.utils.history")
          local results = history.get_recent_projects()
          fzf_lua.fzf_exec(results, {
            actions = {
              ["default"] = {
                function(selected)
                  fzf_lua.files({ cwd = selected[1] })
                end,
              },
            },
          })
        end,
        desc = "Search Recent Projects",
      },
    },
  },
  -- vim.tbl_deep_extend("force", fzfLuaMe, and Util.merge does not work
  --  fzfLuaMe,
  --  mywhichkey,
  {
    "folke/todo-comments.nvim",
    optional = true,
    keys = {
      {
        "<leader>" .. key_s .. "t",
        function()
          require("todo-comments.fzf").todo()
        end,
        desc = "Todo",
      },
      {
        "<leader>" .. key_s .. "T",
        function()
          require("todo-comments.fzf").todo({ keywords = { "TODO", "FIX", "FIXME" } })
        end,
        desc = "Todo/Fix/Fixme",
      },
    },
  },
}

-- __AUTO_GENERATED_PRINT_VAR_START__
-- print([==[ output:]==], vim.inspect(output)) -- __AUTO_GENERATED_PRINT_VAR_END__
-- return output
