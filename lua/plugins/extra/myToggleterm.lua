local lazygitTerm = {}
local KeyUtils = require("utils.keyutil")
local key_g = KeyUtils.key_g
local key_l = KeyUtils.key_l
local isSnacksEnable = KeyUtils.isSnackEnabled

function sentSelectedToTerminal()
  local mode = vim.fn.mode()
  if mode == "V" then
    -- print("in V mode")
    require("toggleterm").send_lines_to_terminal("visual_lines", true, { args = vim.v.count })
  elseif mode == "\22" then -- "\22" is the ASCII representation for CTRL-V
    -- print("in ^V mode")
    require("toggleterm").send_lines_to_terminal("visual_selection", true, { args = vim.v.count })
  elseif mode == "v" then
    -- print("in v mode")
    require("toggleterm").send_lines_to_terminal("visual_selection", true, { args = vim.v.count })
  else
    require("toggleterm").send_lines_to_terminal("single_line", true, {})
  end
end

---@param termOpts TermCreateArgs?
---@param name string
local isToggleCurrentLazyTerm = function(name, termOpts)
  if lazygitTerm and lazygitTerm.term and name == lazygitTerm.name then
    lazygitTerm.term:toggle()
  else
    local lazygitBaseTerm = {
      on_create = function(term)
        -- vim.notify("OPEN.CREATE", vim.log.levels.INFO, { title = "Lazygit" })
        -- These keys will overwrite the lazygit keymap !! - only t mode keymap will work
        vim.api.nvim_buf_set_keymap(term.bufnr, "t", "<c-q>", "<cmd>close<CR>", { noremap = true, silent = true })
        -- All keys (q) break when type in input prompt a
        -- q will quit like Q
        -- Q already do the job to quit buffer (still work on typing input)
        -- vim.api.nvim_buf_set_keymap(term.bufnr, "t", "Q", "<cmd>bd!<CR>", { noremap = true, silent = true })
      end,
      on_open = function(term)
        vim.cmd("startinsert!")
        -- vim.notify("OPEN", vim.log.levels.INFO, { title = "Lazygit" })

        -- Allow to make it work for lazygit for Esc and ctrl + hjkl
        vim.keymap.set("t", "<c-h>", "<c-h>", { buffer = term.bufnr, nowait = true })
        vim.keymap.set("t", "<c-j>", "<c-j>", { buffer = term.bufnr, nowait = true })
        vim.keymap.set("t", "<c-k>", "<c-k>", { buffer = term.bufnr, nowait = true })
        vim.keymap.set("t", "<c-l>", "<c-l>", { buffer = term.bufnr, nowait = true })
        vim.keymap.set("t", "<esc>", "<esc>", { buffer = term.bufnr, nowait = true })
      end,
      -- function to run on closing the terminal
      on_close = function(_)
        -- vim.notify("Closing", vim.log.levels.INFO, { title = "Lazygit" })
        vim.cmd("startinsert!")
      end,
    }
    require("utils.lazygit").open() -- overide nvim edit set key config for lazygit
    termOpts.on_open = lazygitBaseTerm.on_open
    termOpts.on_create = lazygitBaseTerm.on_create
    termOpts.on_close = lazygitBaseTerm.on_close
    local lazygit = require("toggleterm.terminal").Terminal:new(termOpts)
    lazygitTerm = {
      name = name,
      term = lazygit,
    }
    lazygitTerm.term:toggle()
  end
end

return {
  "akinsho/toggleterm.nvim",
  enabled = true,
  opts = {
    persist_size = false,
    persist_mode = false,
    -- open_mapping = isSnacksEnable and [[<localleader-t>]] or [[<c-_>]],
  },
  keys = {
    -- c; c= c\ c/ not working
    -- {
    --   "<c-_>",
    --   desc = "Toggle term",
    -- },
    {
      "<leader><c-_>",
      "<cmd>:ToggleTerm<cr>",
      desc = "Toggle term",
    },
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
      mode = "v",
    },
    {
      "<localleader>T",
      sentSelectedToTerminal,
      desc = "Send visual selection to terminal",
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
      "<localleader>ft",
      "<cmd>:2ToggleTerm<cr>",
      desc = "Find Terminal",
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
        })
      end,
      desc = "Lazygit Toggle",
      mode = "n",
    },
  },
}
