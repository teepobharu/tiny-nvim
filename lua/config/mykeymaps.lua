local opts = { noremap = true, silent = true }
local keymap = vim.keymap.set
local Cmd = require("utils.cmd")
local inputUtil = require("utils.input")
-- ===========================
-- LAZY NVIM ====================
-- =======================

-- Setup keys
-- check using :letmapleader or :let maplocalleader
-- -> need to put inside plugins mapping also to make it work on those mapping
-- command completion in command line mode
keymap("n", "<leader>ll", "<cmd>Lazy<CR>", { desc = "Lazy" })
-- keymap("n", "<leader>lx", "<cmd>LazyExtras<CR>", { desc = "Lazy Extras" })

-- ============================
-- EDITING
-- ============================
-- Move Lines (add silence original didnot have will blip in visual mode)
keymap("n", "<A-j>", "<cmd>m .+1<cr>==", { desc = "Move Down", silent = true })
keymap("n", "<A-k>", "<cmd>m .-2<cr>==", { desc = "Move Up", silent = true })
keymap("i", "<A-j>", "<esc><cmd>m .+1<cr>==gi", { desc = "Move Down", silent = true })
keymap("i", "jk", "<esc>", { desc = "Exit Insert Mode", silent = true })
opts.desc = "Comment Line"
keymap("i", "<A-/>", "<esc>mt<cmd>normal gcc<cr>`tji", opts)
-- keymap("v", "A-/", "gc", opts) -- v mode not work
keymap("i", "<A-k>", "<esc><cmd>m .-2<cr>==gi", { desc = "Move Up", silent = true })
keymap("v", "<A-j>", ":m '>+1<cr>gv=gv", { desc = "Move Down", silent = true })
keymap("v", "<A-k>", ":m '<-2<cr>gv=gv", { desc = "Move Up", silent = true })

vim.cmd([[
  cnoremap <expr> <C-j> wildmenumode() ? "\<C-N>" : "\<C-j>"
  cnoremap <expr> <C-k> wildmenumode() ? "\<C-P>" : "\<C-k>"
]])

local function handleMode(mode)
  return function()
    if vim.fn.mode() == mode then
      vim.cmd("normal! y")
    else
      -- do as normal trigger for visual mode / visual line modejgc
      if mode == "v" then
        vim.cmd("normal! v")
      elseif mode == "V" then
        vim.cmd("normal! V")
      else
        -- Handle unexpected mode by falling back to default key bindings
        vim.notify("Unexpected mode: " .. vim.fn.mode(), vim.log.levels.WARN)
        vim.cmd("normal! gv")
      end
    end
  end
end

opts.desc = "Yank in visual"
keymap("v", "v", handleMode("v"), opts)
keymap("v", "V", handleMode("V"), opts)

local keymap = vim.keymap.set
-- Duplicate line and preserve previous yank register
--  support mode v as
function duplicateselected()
  local saved_unnamed = vim.fn.getreg('"')

  local current_selected_line = ""
  local current_mode = vim.fn.mode()
  if current_mode == "v" or current_mode == "V" then
    -- Get the selected lines
    current_selected_line = vim.fn.getline("`<", "`>")
  else
    current_selected_line = vim.fn.getline(".")
  end

  -- Duplicate the current line or selected lines
  if current_mode == "v" or current_mode == "V" then
    -- In visual mode, use normal command to duplicate lines
    vim.api.nvim_command("normal! y`>p`>")
    -- vim.api.nvim_command("normal! y`>$p`>") -- new line (will not work with v mode not new line)
  else
    -- In normal mode, duplicate the current line
    vim.cmd("normal! yyp")
  end

  -- Restore previous yank registers
  vim.fn.setreg('"', saved_unnamed)
end

-- above cause to move when quit with Esc
--
-- H and L to change buffer (LAZY)
keymap("n", "<A-d>", duplicateselected, { desc = "Duplicate line and preserve yank register" })
keymap("v", "<A-d>", duplicateselected, { desc = "Duplicate line and preserve yank register" })
-- " Copy to system clipboard

-- vnoremap <leader>y "+y
-- nnoremap <leader>Y "+yg_
-- nnoremap <leader>y "+y
-- nnoremap <leader>yy "+yy

-- copy to nvim only not system clipboard
vim.opt.clipboard = ""

keymap("n", "YY", '"+yy', { desc = "Copy to system clipboard" })
keymap("v", "Y", '"+y', { desc = "Copy to system clipboard" })
keymap("v", "<C-c>", '"+y', { desc = "Copy to system clipboard" })

-- ============================
--  Navigations
-- ============================
--- Easier access to beginning and end of lines
keymap("v", "<A-h>", "^", {
  desc = "Go to start of line",
  silent = true,
})

keymap("v", "<A-l>", "$", {
  desc = "Go to end of line",
  silent = true,
})

-- v mode esc to exit visual modej
keymap("v", "<C-q>", "<esc>", { desc = "exit" })
keymap("v", "<C-j>", "<C-d>", { desc = "Move page down" })
keymap("v", "<C-k>", "<C-u>", { desc = "Move page up" })

-- /Users/tharutaipree/dotfiles/README.mdTmux navigation - move to plugins config

-- ============================
--   Windows and Tabs
-- ============================
keymap("n", "<leader>wh", ":sp<CR>", { desc = "HSplit", silent = true })
keymap("n", "<leader>wv", ":vs<CR>", { desc = "VSplit", silent = true })
keymap("n", "<M-Tab>", ":tabnext<CR>", { noremap = true, silent = true })
keymap("t", "<M-Tab>", "<cmd>tabnext<CR>", { noremap = true, silent = true })
keymap("n", "<leader>wp", ":windo b#<CR>", { desc = "Previous Window", silent = true })

-- map("n", "<C-Up>", ":resize -3<CR>", opts)
-- map("n", "<C-Down>", ":resize +3<CR>", opts)
-- map("n", "<C-Left>", ":vertical resize -3<CR>", opts)
-- map("n", "<C-Right>", ":vertical resize +3<CR>", opts)

-- Resize with ESC keys - up down use for auto cmpl
keymap("n", "<Up>", ":resize -3<CR>", opts)
keymap("n", "<Down>", ":resize +3<CR>", opts)
keymap("n", "<Left>", "<cmd>vertical resize -3<CR>", opts)
keymap("n", "<Right>", "<cmd>vertical resize +3<CR>", opts)
-- map("n", "H", ":bp<CR>", { desc = "Previous Buffer", silent = true })
-- map("n", "L", ":bn<CR>", { desc = "Next Buffer", silent = true })
-- use <l>bd instead
opts.desc = "Close buffer"
keymap("n", "<leader>bd", ":b#|bd#<CR>", opts)
-- map("n", "<leader>wX", ":bd!<CR>", { desc = "Force close buffer" })

local function toggle_fold_or_clear_highlight()
  if vim.fn.foldlevel(".") > 0 then
    vim.api.nvim_input("za")
  else
    vim.cmd("nohlsearch")
  end
end
keymap("n", "<Esc>", toggle_fold_or_clear_highlight, { expr = true, silent = true, noremap = true })
-- Terminal & Commands
-- ============================
opts.desc = "Toggle Normal"
keymap("t", "<C-q>", "<c-\\><c-n>", { desc = "Enter Normal Mode" })
opts.desc = nil

local getTermBuffer = function()
  local term_buffers = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local ft = vim.bo[buf].filetype -- toggleterm
    -- local buf_name = vim.api.nvim_buf_get_name(buf) -- bufname can change when rename buff
    -- __AUTO_GENERATED_PRINT_VAR_START__
    -- print([==[for ft:]==], "bufno=" .. buf .. "ft" .. vim.inspect(ft)) -- __AUTO_GENERATED_PRINT_VAR_END__
    local is_toggleterm = ft == "toggleterm"
    if is_toggleterm then
      -- __AUTO_GENERATED_PRINT_VAR_START__
      table.insert(term_buffers, buf)
      -- print([==[_G.cycle_term_buffers#for#if is_toggleterm:]==], buf_name)
    end
    -- if buf_name:match("term://.*toggleterm#.*") then
    --   table.insert(term_buffers, buf)
    -- end
  end
  return term_buffers
end

function _G.cycle_term_buffers()
  local term_buffers = getTermBuffer()
  if #term_buffers == 0 then
    print("No terminal buffers found")
    return
  end

  local current_buf = vim.api.nvim_get_current_buf()
  local next_buf = nil

  for i, buf in ipairs(term_buffers) do
    if buf == current_buf then
      next_buf = term_buffers[(i % #term_buffers) + 1]
      break
    end
  end

  if not next_buf then
    next_buf = term_buffers[1]
  end

  vim.api.nvim_set_current_buf(next_buf)
end

function _G.cycle_term_layout()
  local termlayout = vim.g.mytoggtermlayout or "horizontal"
  if termlayout == "float" then
    vim.g.mytoggtermlayout = "horizontal"
    -- elseif termlayout == "horizontal" then -- vertical not working (same as horizontal)
    -- vim.g.mytoggtermlayout = "vertical"
    -- elseif termlayout == "vertical" then -- tab use case not good
    --   vim.g.mytoggtermlayout = "tab"
  else
    vim.g.mytoggtermlayout = "float"
  end
  vim.cmd("ToggleTerm")
  termlayout = vim.g.mytoggtermlayout
  vim.cmd("ToggleTerm direction=" .. termlayout)
  -- enter normal mode again from insert terminal mode
  vim.cmd("stopinsert")
end

function _G.create_new_term()
  local term_buffers = getTermBuffer()
  -- #term#<id>
  local next_id = 1
  local sorted_term_num = {}
  for i, buf in ipairs(term_buffers) do
    local bufname = vim.api.nvim_buf_get_name(buf)
    local id = bufname:match("term://.*#(%d+)$")
    if tonumber(id) > 0 then
      table.insert(sorted_term_num, tonumber(id))
    end
  end
  table.sort(sorted_term_num)
  for i, id in ipairs(sorted_term_num) do
    if next_id < id then
      break
    else
      next_id = next_id + 1
    end
  end
  local command = next_id .. "ToggleTerm"
  vim.cmd(command)
end

function _G.set_toggleterm_keymaps()
  -- run on all terminal buffers
  -- https://github.com/akinsho/toggleterm.nvim?tab=readme-ov-file#terminal-window-mappings
  local opts = opts
  opts.buffer = 0
  local ft = vim.bo.filetype -- toggleterm
  local is_toggleterm = ft == "toggleterm"
  local buffername = vim.fn.expand("%:t")
  if string.find(buffername, "lazygit") then
    print("Lazygit buffer")
  else
    opts.desc = "Enter normal mode"
    vim.keymap.set("t", "jk", [[<C-\><C-n>]], opts)
    opts.desc = "Toggle Term <num> (press with <n> to open other term)"
    vim.keymap.set("n", "<C-t>", [[<Cmd>exe v:count1 . "ToggleTerm"<CR>]], opts)
    vim.keymap.set("n", "<localleader>tt", [[<Cmd>exe v:count1 . "ToggleTerm"<CR>]], opts)

    opts.desc = "Toggle Layout"
    vim.keymap.set("n", "<C-SPACE>", ":lua cycle_term_layout()<CR>", opts)
    opts.desc = "Create new Term"
    vim.keymap.set("n", "<C-n>", ":lua create_new_term()<CR>", opts)
    -- durection=float|horizontal|vertical
    opts.desc = "Quit Current Term"
    vim.keymap.set("n", "Q", ":bd!<CR>", opts)
    vim.keymap.set(
      "n",
      "<c-e>",
      ":lua cycle_term_buffers()<CR>",
      { buffer = 0, desc = "Cycle term buffer", noremap = true, silent = true }
    )
    -- cycle through all terminal buffers
    -- J and K to move between all buffers next and rpev
    opts.desc = "Toggle Term next toggle"
    vim.keymap.set("n", "J", [[<Cmd>exe v:count1 . "ToggleTerm"<CR>]], opts)
  end
  -- what about buffername ?
  -- if not lazygit then do mapping
  -- resize
  opts.desc = "Resize" -- not working
  -- vim.keymap.set("t", "Up", [[<C-\><C-n>:resize -3<CR>]], opts)
  -- vim.keymap.set("t", "Down", [[:resize +3<CR>]], opts)
  -- vim.keymap.set("t", "<C-Left>", [[<C-\><C-n>:vertical resize -3<CR>]], opts)
  -- vim.keymap.set("t", "<C-Right>", [[<C-\><C-n>:vertical resize +3<CR>]], opts)
  -- vim.keymap.set("t", "<C-l>", [[<Cmd>wincmd l<CR>]], opts)
  -- vim.keymap.set("t", "<C-w>", [[<C-\><C-n><C-w>]], opts)
end
keymap("n", ";", ":", { desc = "CMD enter command mode" })

vim.api.nvim_create_user_command("OpenTerminalInSplitWithCwd", function()
  local cwd = vim.fn.expand("%:p:h")

  vim.api.nvim_command("split | lcd " .. cwd .. " | terminal")
end, {})
keymap("n", "<Leader>t.", ":OpenTerminalInSplitWithCwd<CR>", { noremap = true, silent = true })
-- ===========================================
--  Search
-- ===============================================
-- before adding to search copy to system clipboard first
keymap("v", "//", "y/\\V<C-R>=escape(@\",'/\\')<CR><CR>", { desc = "Search selected visual" })
keymap("v", "//", "\"+y/\\V<C-R>=escape(@\",'/\\')<CR><CR>", { desc = "Search selected visual" })
--
--
-- ===========================================
-- GIT
-- ===============================================

function gitsigns_jump_next_hunk()
  if vim.wo.diff then
    return "]c"
  end
  vim.schedule(function()
    require("gitsigns").nav_hunk("next")
  end)
  return "<Ignore>"
end
function gitsigns_jump_prev_hunk()
  if vim.wo.diff then
    return "[c"
  end
  vim.schedule(function()
    require("gitsigns").nav_hunk("prev")
  end)
  return "<Ignore>"
end
keymap("n", "<C-S-j>", gitsigns_jump_next_hunk, { desc = "Jump to next hunk", expr = true })
keymap("n", "<C-M-j>", gitsigns_jump_next_hunk, { desc = "Jump to next hunk", expr = true })
keymap("n", "<C-S-k>", gitsigns_jump_prev_hunk, { desc = "Jump to prev hunk", expr = true })
keymap("n", "<C-M-k>", gitsigns_jump_prev_hunk, { desc = "Jump to prev hunk", expr = true })
opts.desc = "Reset hunk"
keymap("n", "<M-z>", function()
  require("gitsigns").reset_hunk()
end, opts)
keymap("v", "<M-z>", ":Gitsigns reset_hunk<cr>", opts)
opts.desc = nil
-- Reconsidered
-- keymap("n", "<leader>gbc", ":Telescope git_bcommits<cr>", { silent = true, desc = "Git BCommits" })
-- keymap("n", "<leader>gbr", ":Telescope git_branches<cr>", { silent = true, desc = "Git Branches" })
-- keymap("n", "<leader>gbl", ":Gitsigns toggle_current_line_blame<cr>", { silent = true, desc = "Blame Inline Toggle" })
-- keymap("n", "<leader>gbL", ":Git blame<cr>", { silent = true, desc = "Git Blame" })
-- keymap("n", "<leader>gbb", ":Git blame<cr>", { silent = true, desc = "Git Blame" })
-- ===============================================
-- LOCALLEADER ==========================
-- ===============================================
local function addNvimConfigInRoot()
  local pathUtil = require("utils.path")
  local git_dir = pathUtil.get_git_root() or vim.fn.getcwd()
  local nvim_config = git_dir .. "/.nvim-config.lua"
  if vim.fn.filereadable(nvim_config) == 1 then
    vim.notify(nvim_config .. "already exists", vim.log.levels.WARN)
    vim.cmd("edit " .. nvim_config)
    return
  end

  local config = [[
-- Project specifc (not tracked original by git - followed by readme 22 Sep 2024)
-- This is example of .nvim-config.lua can be put in any project folders
-- Enable extra plugins for this project
-- vim.g.enable_plugins = {
--  wakatime = "no",
--  ["no-neck-pain"] = "yes"
--  }
--  vim.g.enable_langs = {
--  python = "no",
--  }
--  ... Please edit the DEFAULT settings below ...
]]
  -- append nvim base config content to the file $DOTFILES/$NVIM_DIR/$NVIM_CONFIG
  local nvim_base_config = vim.fn.stdpath("config") .. "/lua/config/mydefault-nvim-config.lua"
  if vim.fn.filereadable(nvim_base_config) == 1 then
    local base_config = vim.fn.readfile(nvim_base_config)
    for _, line in ipairs(base_config) do
      config = config .. line .. "\n"
    end
  end

  local config_lines = vim.split(config, "\n")
  vim.fn.writefile(config_lines, nvim_config)

  -- open that file in new window
  vim.cmd("edit " .. nvim_config)
  vim.notify("nvim-config.lua created at: " .. nvim_config, vim.log.levels.INFO)
end

-- ===============
-- LSP
-- ===============

-- Restart LSP client by name
Cmd.create_cmd("RestartLspClients", function()
  require("utils.lsp_setup").processLspClients("restart")
end, { nargs = 0 })

-- Stop LSP clients by name
Cmd.create_cmd("StopLspClients", function()
  require("utils.lsp_setup").processLspClients("stop")
end, { nargs = 0 })

keymap("n", "<leader>Lr", ":RestartLspClients<CR>", { desc = "LSPRestart", noremap = true, silent = true })
keymap("n", "<leader>Lx", ":StopLspClients<CR>", { desc = "LSP Stop", noremap = true, silent = true })
keymap("n", "<leader>Li", ":check lsp<CR>", { desc = "LSP Info", noremap = true, silent = true })

--   # which key migrate .nvim $HOME/.config/nvim/keys/which-key.vim
keymap("n", "<c-q>", ":q<CR>", { desc = "Close", noremap = true, silent = true })
keymap("n", "<localleader>q", ":q<CR>", { desc = "Close", noremap = true, silent = true })
keymap("n", "<localleader>cd", ":lcd%:p:h <CR>", { desc = "CD to current dir" })
keymap("n", "<localleader>cn", ':let @+=expand("%:t")<CR>', { desc = "Copy basefilename into reg" })
-- copy relative filepath name
keymap("n", "<localleader>cf", ":let @+=@%<CR>", { desc = "Copy relative filepath name" })
-- copy absolute filepath - use neotree (no relative file)
keymap("n", "<localleader>cF", ':let @+=expand("%:p")<CR>', { desc = "Copy absolute filepath" })
-- lsp / files
keymap("n", "<localleader>rs", "", { desc = "Setup" })
keymap(
  "n",
  "<localleader>rsp",
  require("utils.lsp_setup").addVenvPyrightConfig,
  { desc = "Python Setup pyright config " }
)
keymap(
  "n",
  "<localleader>rsb",
  require("utils.lsp_setup").copyBiomeConfigFromToCurrentGitRoot,
  { desc = "Setup biome config" }
)
keymap("n", "<localleader>rsn", addNvimConfigInRoot, { desc = "Setup nvim proj lang & plugin config" })
keymap("n", "<localleader>rp", "", { desc = "Profile" })
keymap("n", "<localleader>rl", ":luafile %<CR>", { desc = "Reload Lua file" })
keymap("v", "<localleader>rl", ":luafile %<CR>", { desc = "Reload Lua file" })
keymap("n", "<localleader>rps", function()
  vim.cmd([[
		:profile start /tmp/nvim-profile.log
		:profile func *
		:profile file *
	]])
end, { desc = "Profile Start" })

keymap("n", "<localleader>rpe", function()
  vim.cmd([[
		:profile stop
		:e /tmp/nvim-profile.log
	]])
end, { desc = "Profile End" })

--profile

-- ===========================
-- Custom commands ====================
-- =======================

local function rename_buffer()
  local old_name = vim.fn.expand("%")
  local new_name = vim.fn.input("Enter new buffer name: ", old_name)

  -- If user provided a new name and it's different from the old name
  if new_name ~= "" and new_name ~= old_name then
    -- Rename the buffer
    vim.api.nvim_buf_set_name(0, new_name)
    print("Buffer renamed to " .. new_name)
  else
    print("Buffer not renamed.")
  end
end

-- map("n", "<leader>n", "", { desc = "+CustomCommands" })
-- map("n", "<leader>nn", "<cmd>so $MYVIMRC<CR>", { desc = "Source Config" })
-- map("n", "<leader>S", "<cmd>SSave<CR>", { desc = "Save Session" })
-- map('n', '<Leader>nm', ':messages <CR>', { noremap = true, silent = true, desc = 'Show messages' })
-- map to get current basefile name

-- map('n', '<Leader>nM', [[:redir @a<CR>:messages<CR>:redir END<CR>:put! a<CR>]], { noremap = true, silent = true, desc = 'Print messages' })
-- Bind a key to invoke the renaming function
keymap("n", "<leader>bR", rename_buffer, { desc = "Rename Buffer", noremap = true, silent = true })

local open_command = "xdg-open"
if vim.fn.has("mac") == 1 then
  open_command = "open"
end

local function url_repo()
  local cursorword = vim.fn.mode() == "v" and vim.fn.getreg("v") or vim.fn.expand("<cfile>")
  -- __AUTO_GENERATED_PRINT_VAR_START__
  print([==[url_repo cursorword:]==], vim.inspect(cursorword)) -- __AUTO_GENERATED_PRINT_VAR_END__
  if string.find(cursorword, "^[a-zA-Z0-9-_.]*/[a-zA-Z0-9-_.]*$") then
    cursorword = "https://github.com/" .. cursorword
  end
  print(cursorword or "")
  return cursorword or ""
end

local function url_repo(tryParseGit)
  local cursorword = vim.fn.expand("<cfile>")
  -- __AUTO_GENERATED_PRINT_VAR_START__
  print([==[url_repo cursorword:]==], vim.inspect(cursorword)) -- __AUTO_GENERATED_PRINT_VAR_END__
  if tryParseGit and string.find(cursorword, "^[a-zA-Z0-9-_.]*/[a-zA-Z0-9-_.]*$") then
    cursorword = "https://github.com/" .. cursorword
  end
  print(cursorword or "")
  return cursorword or ""
end

local function run_command(command, callback)
  callback = callback or {}
  callback.success = callback.success or function() end
  callback.fail = callback.fail or function() end
  -- callback.out = callback.out or false
  -- callback.stderr = callback.stderr or false

  vim.fn.jobstart(command, {
    on_stdout = callback.out and function(_, data, _)
      print("[stdout " .. vim.inspect(command) .. "]:", vim.inspect(data))
    end or nil,
    on_stderr = callback.stderr and function(_, data, _)
      print("[stderr " .. vim.inspect(command) .. "]:", vim.inspect(data))
    end or nil,
    on_exit = function(_, code, _)
      print("[exit " .. vim.inspect(command) .. " ] code =", data)
      if code ~= 0 then
        callback.success(_, code, _)
      else
        callback.fail(_, code, _)
      end
    end,
    detach = true,
  })
end

keymap({ "n", "v" }, "gx", function()
  local url_or_word = url_repo(true)
  -- copy to register + if not empty
  run_command({ open_command, url_or_word })
  --   vim.fn.jobstart({ open_command, url_or_word }, { detach = true }) -- not work in tmux
  if url_or_word ~= "" then
    vim.fn.setreg("+", url_or_word)
  end
end, { silent = true, desc = "Copy word / Open url" })

keymap({ "n", "v" }, "gGs", function()
  local text = inputUtil.get_selected_or_cursor_word()
  -- __AUTO_GENERATED_PRINT_VAR_START__
  print([==[(anon) text:]==], vim.inspect(text)) -- __AUTO_GENERATED_PRINT_VAR_END__
  local escaped_text = text:gsub(" ", "%%20")
  -- __AUTO_GENERATED_PRINT_VAR_
  print([==[(anon) escaped_text:]==], vim.inspect(escaped_text)) -- __AUTO_GENERATED_PRINT_VAR_END__
  local search_url = "https://www.google.com/search?q=" .. escaped_text
  run_command({ open_command, search_url })
end, { silent = true, desc = "Google Search" })

keymap({ "n", "v" }, "gX", function()
  local url_or_word = url_repo()
  -- copy to register + if not empty
  -- if extension is in .log or .xlsx or .pdf .powerpoint .docx ,... use normal open function
  local normal_ext_open = vim.fn.match(url_or_word, [[\.\(log\|pdf\|docx\|pptx\|xlsx\)$]]) > -1
  -- use one regex matcher

  local callback = nil
  if normal_ext_open then
    command_run = open_command
  else
    command_run = "code --goto"
    callback = {
      fail = function(_, code, _)
        print("code cmd fail try again with cmd: ", open_command)
        vim.fn.jobstart({ open_command, url_or_word }, { detach = true })
      end,
    }

    -- /Users/tharutaipree/.config/nvim2_jelly_lzmigrate/lua/config/mykeymaps.lua
    -- vim.fn.jobstart("echo 'hello' && some error here", {
    -- vim.fn.jobstart({ open_command, "-a", "code", url_or_word }, { -- get error command not found
    -- vim.fn.jobstart(open_command .. " -a " .. "code " .. url_or_word ,{
    -- local callback = {
    --     success = function(_, code, _)
    --         print("success code=", code)
    --     end,
    --     fail = function(_, code, _)
    --         print("fail code=", code)
    --     end,
    -- }
    -- vim.fn.jobstart("env && code " .. url_or_word ,{

    -- get error code is not executable how to make code a known command
    -- __AUTO_GENERATED_PRINT_VAR_START__
    -- local code_command = open_command .. "-a code"
    -- __AUTO_GENERATED_PRINT_VAR_START__
  end
  run_command(command_run .. url_or_word, callback)
end, { silent = true, desc = "Open in vscode" })

set_opfunc = vim.fn[vim.api.nvim_exec(
  [[
  func s:set_opfunc(val)
    let &opfunc = a:val
  endfunc
  echon get(function('s:set_opfunc'), 'name')
]],
  true
)]

-- ==================================================
-- MY Autocommands
local function augroup(name)
  return vim.api.nvim_create_augroup("nvim_ide_my_" .. name, { clear = true })
end
-- local function set_mappings()
-- Map J and K in quickfix window
local quickfixAndTroubleGroup = augroup("QuickfixAndTroubleMappings")
vim.api.nvim_create_autocmd("FileType", {
  group = quickfixAndTroubleGroup,
  pattern = "qf",
  callback = function()
    vim.api.nvim_buf_set_keymap(0, "n", "H", ":colder<CR>", { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(0, "n", "L", ":cnewer<CR>", { noremap = true, silent = true })
  end,
})

-- -- Map J and K in trouble window with refresh
-- vim.api.nvim_create_autocmd("FileType", {
--   group = quickfixAndTroubleGroup,
--   pattern = {
--     "Trouble",
--     "trouble",
--   },
--   callback = function()
--     vim.api.nvim_buf_set_keymap(0, "n", "H", ":colder | Trouble qflist refresh<CR>", { noremap = true, silent = true })
--     vim.api.nvim_buf_set_keymap(0, "n", "L", ":cnewer | Trouble qflist refresh<CR>", { noremap = true, silent = true })
--   end,
-- })

-- ===============================================
-- DELETE MAP ==========================
-- ===============================================
-- disabled in keymaps.lua (original)
-- if you only want these mappings for toggle term use term://*toggleterm#* instead
if not vim.g.vscode then
  vim.cmd("autocmd! TermOpen term://* lua set_toggleterm_keymaps()")
  vim.api.nvim_del_keymap("i", "<A-j>")
  vim.api.nvim_del_keymap("i", "<A-k>")
  vim.api.nvim_del_keymap("n", "<C-c>")
end
-- OVERRIDE MAP ==========================
keymap("n", "zj", "zj")
keymap("n", "zk", "zk")
