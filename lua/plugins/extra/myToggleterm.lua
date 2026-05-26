local lazygitTerm = { count = 100 }
local KeyUtils = require("utils.keyutil")
local key_g = KeyUtils.key_g
local key_l = KeyUtils.key_l
local isSnacksEnable = KeyUtils.isSnackEnabled

local function lazygit_full_float_opts()
  return {
    width = math.max(1, vim.o.columns - 2),
    height = math.max(1, vim.o.lines - vim.o.cmdheight - 3),
    row = 0,
    col = 0,
  }
end

local function toggle_lazygit_float_size(term)
  if not (term and term.window and vim.api.nvim_win_is_valid(term.window)) then
    return
  end
  if not term:is_float() then
    vim.notify("LazyGit size toggle only supports floating toggleterm windows", vim.log.levels.WARN)
    return
  end

  term.lazygit_original_float_opts = term.lazygit_original_float_opts or vim.deepcopy(term.float_opts or {})
  term.lazygit_expanded = not term.lazygit_expanded
  term.float_opts = term.lazygit_expanded
    and vim.tbl_extend("force", vim.deepcopy(term.lazygit_original_float_opts), lazygit_full_float_opts())
    or vim.deepcopy(term.lazygit_original_float_opts)
  require("toggleterm.ui").update_float(term)
end

local function set_lazygit_size_keymap(term)
  local opts = { buffer = term.bufnr, nowait = true, desc = "Toggle LazyGit Size" }
  vim.keymap.set({ "n", "t" }, "<A-m>", function()
    toggle_lazygit_float_size(term)
  end, opts)
end

function sentSelectedToTerminal()
  local mode = vim.fn.mode()
  if mode == "V" then
    require("toggleterm").send_lines_to_terminal("visual_lines", true, { args = vim.v.count1 })
  elseif mode == "\22" then -- "\22" is the ASCII representation for CTRL-V
    -- print("in ^V mode")
    require("toggleterm").send_lines_to_terminal("visual_selection", true, { args = vim.v.count1 })
  elseif mode == "v" then
    -- print("in v mode")
    require("toggleterm").send_lines_to_terminal("visual_selection", true, { args = vim.v.count1 })
  else
    -- vim.cmd("ToggleTermSendCurrentLine") -- will not auto propogate
    require("toggleterm").send_lines_to_terminal("single_line", true, { args = vim.v.count1 })
  end
end

---@param termOpts TermCreateArgs?
---@param name string
local isToggleCurrentLazyTerm = function(name, termOpts)
  if lazygitTerm[name] and lazygitTerm[name].term then
    lazygitTerm[name].term:toggle()
  else
    local lazygitBaseTerm = {
      on_create = function(term)
        -- vim.notify("OPEN.CREATE", vim.log.levels.INFO, { title = "Lazygit" })
        -- These keys will overwrite the lazygit keymap !! - only t mode keymap will work
        vim.api.nvim_buf_set_keymap(term.bufnr, "t", "<c-q>", "<cmd>stopinsert<CR>", { noremap = true, silent = true })
        vim.api.nvim_buf_set_keymap(term.bufnr, "n", "<c-q>", "<cmd>close<CR>", { noremap = true, silent = true })
        vim.api.nvim_buf_set_keymap(term.bufnr, "t", "<c-q>", "<cmd>close<CR>", { noremap = true, silent = true })
        vim.api.nvim_buf_set_keymap(term.bufnr, "t", "<c-_>", "<cmd>stopinsert<CR>", { noremap = true, silent = true })
        -- All keys (q) break when type in input prompt a
        -- q will quit like Q
        -- Q already do the job to quit buffer (still work on typing input)
        -- vim.api.nvim_buf_set_keymap(term.bufnr, "t", "Q", "<cmd>bd!<CR>", { noremap = true, silent = true })
        vim.notify("ON CREATE" .. name, vim.log.levels.INFO, { title = "Lazygit"})
        lazygitTerm.count = lazygitTerm.count + 1
      end,
      -- TODO: when press Q will not exit yet
      on_exit = function(t, jobnum, exit_code, namein)
        vim.notify("ON Exit " .. name .. " namein " .. namein " code=" .. exit_code, vim.log.levels.INFO, { title = "Lazygit"})
        lazygitTerm[name] = {}
      end,
      on_open = function(term)
        vim.cmd("startinsert!")
        vim.notify("OPEN " .. name, vim.log.levels.INFO, { title = "Lazygit" })

        -- Allow to make it work for lazygit for Esc and ctrl + hjkl
        vim.keymap.set("t", "<c-h>", "<c-h>", { buffer = term.bufnr, nowait = true })
        vim.keymap.set("t", "<c-j>", "<c-j>", { buffer = term.bufnr, nowait = true })
        vim.keymap.set("t", "<c-k>", "<c-k>", { buffer = term.bufnr, nowait = true })
        vim.keymap.set("t", "<c-l>", "<c-l>", { buffer = term.bufnr, nowait = true })
        vim.keymap.set("t", "<esc>", "<esc>", { buffer = term.bufnr, nowait = true })
        set_lazygit_size_keymap(term)


        local opts = { buffer = term.bufnr, nowait = true }
        local currDir = lazygitTerm[name].term.direction or "float"
        opts.desc = "Toggle layout all"
        -- vim.keymap.set("t", "<c-\\>", function()
        vim.keymap.set("t", "<M-1>", function()
          local nextDirection = currDir == "float" and "vertical" or currDir == "vertical" and "horizontal" or currDir == "horizontal" and "tab" or "float"
          lazygitTerm[name].term:toggle()
          local win_count = 1
          if nextDirection == "horizontal" or nextDirection == "vertical" then
            win_count = vim.fn.winnr('$')
          end
          local size = win_count == 1 and 50 or 95

          if currDir == "tab" then
            local tab_count = vim.fn.tabpagenr('$')
            local curr_tab = vim.fn.tabpagenr()
            if tab_count > 1 and curr_tab > 1 and curr_tab < tab_count then
              vim.cmd("tabprevious")
            end
          end
          -- __AUTO_GENERATED_PRINT_VAR_START__
          print([==[isToggleCurrentLazyTerm#if#on_open#(anon) win_count:]==], vim.inspect(win_count)) -- __AUTO_GENERATED_PRINT_VAR_END__
          lazygitTerm[name].term:toggle(size, nextDirection)
        end, { buffer = term.bufnr, nowait = true })

        opts.desc = "Toggle layout flat/tab"
        vim.keymap.set("t", "<M-2>", function()
          local nextDirection = currDir == "float" and "tab" or "float"
          lazygitTerm[name].term:toggle()
          if currDir == "tab" then
            local tab_count = vim.fn.tabpagenr('$')
            local curr_tab = vim.fn.tabpagenr()
            if tab_count > 1 and curr_tab > 1 and curr_tab < tab_count then
              vim.cmd("tabprevious")
            end
          end
          lazygitTerm[name].term:toggle(95, nextDirection)
          -- vim.cmd("TmuxNavigatePrevious")
        end, opts)

        opts.desc = "Toggle layout vert/horiz"
        vim.keymap.set("t", "<M-3>", function()
          local nextDirection = currDir == "horizontal" and "vertical" or "horizontal"
          local win_count = 1
          if nextDirection == "horizontal" or nextDirection == "vertical" then
            win_count = vim.fn.winnr('$')
          end
          local size = win_count == 1 and 50 or 95

          lazygitTerm[name].term:toggle()
          lazygitTerm[name].term:toggle(size, nextDirection)
        end, opts)
      end,
      -- function to run on closing the terminal
      -- Will trigger even when use c-q
      on_close = function(_)
        vim.notify("Closing term: " .. name, vim.log.levels.INFO, { title = "Lazygit" })
        vim.cmd("startinsert!")
      end,
    }
    require("utils.lazygit").open() -- overide nvim edit set key config for lazygit
    termOpts.on_open = lazygitBaseTerm.on_open
    termOpts.on_create = lazygitBaseTerm.on_create
    termOpts.on_close = lazygitBaseTerm.on_close
    -- https://github.com/akinsho/toggleterm.nvim?tab=readme-ov-file#custom-terminal-usage
    -- termOpts.hidden = true -- doesnot really work in this fn but works in demo code - do not show when toggle with ToggleTerm cmd
    -- termOpts.count = 100 -- since hidden not work move the term to high count to avoid toggle it (but need to avoid overriding same num)
    termOpts.count = lazygitTerm.count -- since hidden not work move the term to high count to avoid toggle it
    -- __AUTO_GENERATED_PRINT_VAR_START__
    print([==[isToggleCurrentLazyTerm#if termOpts:]==], vim.inspect(termOpts)) -- __AUTO_GENERATED_PRINT_VAR_END__
    local lazygit = require("toggleterm.terminal").Terminal:new(termOpts)

    -- local Terminal  = require('toggleterm.terminal').Terminal
    -- local lazygit = Terminal:new({ cmd = "lazygit", hidden = true })
    -- lazygit:toggle()
    -- sleep 1s
    -- toggle again 
    --



    lazygitTerm[name] = {
      term = lazygit,
    }
    lazygitTerm[name].term:toggle()
  end
  lazygitTerm.last_toggle = name
end

-- check key overrides in lua/config/mykeymaps.lua:350
return {
  "akinsho/toggleterm.nvim",
  version = "*",
  -- enabled = true,
  -- cmd = { "ToggleTerm", "TermSelect", "ToggleTermSetName", "ToggleTermSendCurrentLine" },
  opts = {
    persist_size = false,
    persist_mode = false,
    -- open_mapping = [[<c-\>]],
  },
  keys = {
    -- c; c= c\ c/ not working
    -- {
    --   "<c-_>",
    --   desc = "Toggle term",
    -- },
    {
      "<leader><c-space>",
      function()
        vim.cmd(":ToggleTerm " .. vim.v.count1)
      end,
      desc = "Toggle ToggleTerm",
    },
    -- these mapping does not work
    -- { "<c-/>", function() Snacks.terminal() end, desc = "Snacks Terminal" },
    -- { "<Esc>[47;5u", function() Snacks.terminal() end, desc = "Snacks Terminal" },
-- >", function() vim.cmd(":ToggleTerm " .. vim.v.count1) end, desc = "Toggle Terminal" },
    -- { "<c-/>", function() vim.cmd(":ToggleTerm " .. vim.v.count1) end, desc = "Toggle Terminal" },
    -- { "<C-/", false },
    -- {
    --   isSnacksEnable and "<c-_>" or "<c-:>",
    --   function()
    --     if isSnacksEnable then
    --       Snacks.terminal()
    --     else
    --       require("toggleterm").toggle()
    --     end
    --   end,
    --   desc = "Toggle term",
    -- },
    -- end test mapping
    {
      "<localleader><c-_>",
      "<cmd>:ToggleTermSendCurrentLine<cr>",
      desc = "Send current line to terminal",
    },
    {
      -- "<leader><c-_>",
      "<localleader>Ta",
      function()
        set_opfunc(function(motion_type)
          require("toggleterm").send_lines_to_terminal(motion_type, false, { args = vim.v.count })
        end)
        vim.api.nvim_feedkeys("ggg@G''", "n", false)
      end,
      desc = "Send all / visual selection to terminal",
    },
    {
      "<localleader>t",
      sentSelectedToTerminal,
      desc = "Send visual selection to terminal",
      mode = { "n", "v" },
    },
    -- { -- seem not to work use c-space to
    --   "<localleader>tf",
    --   "<cmd>:ToggleTerm direction=float<cr>",
    --   desc = "Toggle term Float",
    -- },
    -- {
    --   "<localleader>th",
    --   "<cmd>:ToggleTerm direction=horizontal<cr>",
    --   desc = "Toggle term Horiz",
    -- },
    -- {
    --   "<localleader>tv",
    --   "<cmd>:ToggleTerm direction=vertical<cr>",
    --   desc = "Toggle term vertical",
    -- },
    {
      "<localleader>Tt",
      sentSelectedToTerminal,
      desc = "Send selection to Toggle terminal",
    },
    {
      "<localleader>Tr",
      "<cmd>:ToggleTermSetName<cr>",
      desc = "Set Terminal Name",
    },
    {
      "<localleader>Ts",
      "<cmd>:TermSelect<cr>",
      desc = "Find Term",
    },
    {
      "<leader>" .. key_g .. "l",
      function()
        require("utils.lazygit").blame_line()
      end,
      desc = "Git Blame Line",
      mode = "n",
    },

    {
      "<leader>" .. key_l .. "c",
      function()
        local dotfilescwd = vim.fn.expand("$DOTFILES_DIR")
        isToggleCurrentLazyTerm("_lc", {
          cmd = "lazygit",
          dir = dotfilescwd,
          direction = "float",
        })
      end,
      desc = "Lazygit Config Toggle",
      mode = "n",
    },
    -- see: https://github.com/LazyVim/LazyVim/blob/b8bdebe5be7eba91db23e43575fc1226075f6a56/lua/lazyvim/util/lazygit.lua#L64
    --       map("n", "<leader>gg", function() LazyVim.lazygit( { cwd = LazyVim.root.git() }) end, { desc = "Lazygit (Root Dir)" })
    -- map("n", "<leader>gG", function() LazyVim.lazygit() end, { desc = "Lazygit (cwd)" })
    -- map("n", "<leader>gb", LazyVim.lazygit.blame_line, { desc = "Git Blame Line" })
    -- map("n", "<leader>gB", LazyVim.lazygit.browse, { desc = "Git Browse" })
    {
      "<leader>" .. key_g .. "G",
      function()
        local lazycwd = require("utils.root").cwd()
        isToggleCurrentLazyTerm("_gG", {
          cmd = "lazygit",
          dir = lazycwd,
          direction = "float",
          float_opts = {
            width = math.floor(vim.o.columns * 0.99),
            height = math.floor(vim.o.lines * 0.99),
          },
        })
      end,
      desc = "Lazygit Toggle (CWD)",
      mode = "n",
    },
    {
      "<leader>" .. key_g .. "g",
      function()
        isToggleCurrentLazyTerm("_gg", {
          cmd = "lazygit",
          dir = "git_dir",
          direction = "float",
          float_opts = {
            width = math.floor(vim.o.columns * 0.95),
            height = math.floor(vim.o.lines * 0.95),
          },

        })
      end,
      desc = "Lazygit Toggle",
      mode = "n",
    },
  },
}
