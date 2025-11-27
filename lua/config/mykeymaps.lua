local opts = { noremap = true, silent = true }
local keymap = vim.keymap.set
local Cmd = require("utils.cmd")
local inputUtil = require("utils.input")
local myPathUtil = require("utils.mypath")
-- ===========================
-- LAZY NVIM ====================
-- =======================

-- Setup keys
local function diffoff_all_buffers()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    vim.api.nvim_buf_call(buf, function()
      vim.cmd("diffoff")
    end)
  end
end

keymap("n", "<leader>dX", diffoff_all_buffers,
  { desc = "Turn off diff mode for all buffers", noremap = true, silent = true })
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

-- Diff Operations
keymap("n", "<leader>Gdd", ":if &diff | diffoff | else | diffthis | endif<CR>", { desc = "Toggle Diff Mode" })
keymap("n", "<leader>Gdx", ":diffoff<CR>", { desc = "Diff Off" })
-- diff off
keymap("n", "<leader>dD", ":if &diff | diffoff | else | diffthis | endif<CR>", { desc = "Diff Toggle" })

-- Auto-bind keys in diff mode
vim.api.nvim_create_autocmd("OptionSet", {
  pattern = "diff",
  callback = function()
    -- print("Diff mode changed: wodiff = ", vim.wo.diff)
    -- check if diff mode is enabled can check in cmd with :echo &diff ?
    -- vim.keymap.set("n", "]c", "]c", { desc = "Next Change", buffer = true })
    -- vim.keymap.set("n", "[c", "[c", { desc = "Previous Change", buffer = true })
    keymap("n", "<leader>dd", ":diffoff<CR>", { desc = "Diff Off" })
    keymap("n", "<leader>dx", ":diffoff<CR>", { desc = "Diff Off" })
    keymap("n", "<leader>dt", ":diffthis<CR>", { desc = "Diff this", buffer = true })
    keymap({ "n", "v" }, "<leader>dp", ":diffput<CR>", { desc = "Diff Put", buffer = true })
    keymap({ "n", "v" }, "<leader>dg", ":diffget<CR>", { desc = "Diff Obtain", buffer = true })
    -- both n and v mode wwrks
    if vim.wo.diff then
      -- always map else delete keymap will throw error even mapcheck passed
    else
      keymap("n", "<leader>dd", ":diffthis<CR>", { desc = "Diff On" })
      keymap("n", "<leader>dt", ":diffthis<CR>", { desc = "Diff this", buffer = true })
      -- unbind the rest
      local bufnr = vim.api.nvim_get_current_buf()
      print([==[callback#if bufnr:]==], vim.inspect(bufnr)) -- __AUTO_GENERATED_PRINT_VAR_END__
      -- does not seem to remove
      -- add space
      if vim.fn.mapcheck("<leader>dp", "n") ~= "" then
        vim.api.nvim_buf_del_keymap(bufnr, "n", "<leader>dp")
      end
      if vim.fn.mapcheck("<leader>dp", "v") ~= "" then
        vim.api.nvim_buf_del_keymap(bufnr, "v", "<leader>dp")
      end
      if vim.fn.mapcheck("<leader>dg", "n") ~= "" then
        vim.api.nvim_buf_del_keymap(bufnr, "n", "<leader>dg")
      end
      if vim.fn.mapcheck("<leader>dt", "n") ~= "" then
        vim.api.nvim_buf_del_keymap(bufnr, "n", "<leader>dt")
      end
      if vim.fn.mapcheck("<leader>dg", "v") ~= "" then
        vim.api.nvim_buf_del_keymap(bufnr, "v", "<leader>dg")
      end
      print("Unbind ?")
    end
  end,
})

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

Cmd.create_cmd("StopAllLspClients", function()
  local active_clients = vim.lsp.get_active_clients()

  for _, client in ipairs(active_clients) do
    vim.lsp.stop_client(client.id)
  end

  vim.notify("Stopped all LSP clients", vim.log.levels.INFO)
end, { nargs = 0 })

keymap("n", "<leader>Lr", ":RestartLspClients<CR>", { desc = "LSPRestart", noremap = true, silent = true })
keymap("n", "<leader>Lx", ":StopLspClients<CR>", { desc = "LSP Stop", noremap = true, silent = true })
keymap("n", "<leader>LX", ":StopAllLspClients<CR>", { desc = "LSP Stop", noremap = true, silent = true })
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

  local last_error = nil
  print("running command: ", vim.inspect(command))
  vim.fn.jobstart(command, {
    on_stdout = callback.out or function(_, data, _)
      print("[stdout]", vim.inspect(data))
    end or nil,
    on_stderr = callback.stderr or function(_, data, _)
      print("[stderr]", vim.inspect(data))
      local errfilter = vim.tbl_filter(function(value) return value ~= "" end, data)
      last_error = (#errfilter > 0) and errfilter or last_error
    end or nil,
    on_exit = function(_, _, _)
      print("on_exit last error:", vim.inspect(last_error))
      if last_error then
        callback.fail(last_error)
      else
        callback.success()
      end
    end,
    detach = true,
  })
  -- __AUTO_GENERATED_PRINT_VAR_START__
  print([==[run_command on_exit:]==], vim.inspect(on_exit)) -- __AUTO_GENERATED_PRINT_VAR_END__
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


-- map key maps to open directory
keymap({ "n", "v" }, "gGs", function()
  local text = inputUtil.get_selected_or_cursor_word()
  -- __AUTO_GENERATED_PRINT_VAR_START__
  print([==[(anon) text:]==], vim.inspect(text)) -- __AUTO_GENERATED_PRINT_VAR_END__
  local escaped_text = text and text:gsub(" ", "%%20")
  if not escaped_text or escaped_text == "" then
    print("No text to search")
    return
  end
  -- __AUTO_GENERATED_PRINT_VAR_
  print([==[(anon) escaped_text:]==], vim.inspect(escaped_text)) -- __AUTO_GENERATED_PRINT_VAR_END__
  local search_url = "https://www.google.com/search?q=" .. escaped_text
  run_command({ open_command, search_url })
end, { silent = true, desc = "Google Search" })

-- Common function to resolve directory path from cursor/selection
local function resolve_directory_path()
  local selected_or_cursor_word = inputUtil.get_selected_or_cursor_word()
  local curr_buffer_path = vim.fn.expand("%:p:h")
  local paths_to_try = {
    selected_or_cursor_word,
    vim.fn.expand("<cfile>"),
    curr_buffer_path .. "/" .. vim.fn.expand("<cfile>"),
    curr_buffer_path .. "/" .. selected_or_cursor_word
  }

  local dir_path = nil
  for _, path in ipairs(paths_to_try) do
    if path and path ~= "" then
      if vim.fn.isdirectory(path) > 0 then
        dir_path = path
        break
      else
        local relative_path = curr_buffer_path .. "/" .. path
        if vim.fn.isdirectory(relative_path) > 0 then
          dir_path = relative_path
          break
        end
      end
    end
  end

  -- Fallback to selected word if it's a valid directory
  if not dir_path and selected_or_cursor_word and vim.fn.isdirectory(selected_or_cursor_word) == 1 then
    dir_path = selected_or_cursor_word
  end

  return dir_path, selected_or_cursor_word
end

keymap({ "n", "v" }, "gGo", function()
  local dir_path, selected_word = resolve_directory_path()
  if dir_path then
    -- Open the directory in finder
    vim.fn.jobstart({ "open", dir_path })
  else
    vim.notify("Invalid directory: " .. (dir_path or selected_word or "<nil>"), vim.log.levels.WARN)
  end
end, { desc = "Open dir - select/cursor/file" })

-- Open NeoTree at resolved directory
keymap({ "n", "v" }, "gGd", function()
  local dir_path, selected_word = resolve_directory_path()

  if dir_path then
    vim.cmd("Neotree " .. dir_path)
  else
    vim.notify("Invalid directory: " .. (dir_path or selected_word or "<nil>"), vim.log.levels.WARN)
  end
end, { desc = "Open NeoTree dir - select/cursor/file" })

keymap({ "n" }, "gF", function()
  -- " Enable gf to recognize file:/// paths and navigate to line numbers
  -- set isfname+==file:// -- check with set isfname?
  local function goto_file_line()
    -- Extract file path and line number
    local fileline = vim.fn.expand("<cfile>")
    if fileline:match("^file://") then
      -- Parse the path and line from the format file:///path/to/file:<line>:<column>
      -- Match the file path and line number from a "file://" pattern.
      -- The pattern captures everything after "file://" up to the colon (:) as the file path,
      -- and captures the digits after the colon as the line number.
      -- make sure to handle filepath:line:col where :line:col :line or no line can be passed through / optional
      local path, line, col = fileline:match("file://(.-):(%d*):?(%d*)")
      if path then
        vim.cmd("edit " .. path)
        if line ~= "" then
          vim.cmd(line)
          if col ~= "" then
            vim.cmd("normal! " .. col .. "|")
          end
        end
        return
      end
      print("filematched file:// |  path=", path, "line=", line)
      if path and line then
        vim.cmd("edit " .. path)
        vim.cmd(line)
        return
      end
    end
    -- how to send file via g
    -- file://https://www.goggle.com/search?q=
    -- file://tests/myTest.lua
    -- file:///Users/tharutaipree/dotfiles/.config/nvim3_jelly_tinynvim/tests/myTest.lua
    -- file:///Users/tharutaipree/AgodaGit/fe/mmbweb/src/Clientside/.storybook/preview-head.html
    -- print("Using gF fallback")
    vim.cmd("normal! gf")
  end

  goto_file_line()
end, { desc = "Go to file+line" })

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
      fail = function(err)
        -- usually will not happen if vscode cant open open will not since
        -- file:///pathnotexists X fail -> open notexist X fail
        -- file:///pathexists vscode ok
        print("onfail: retry with cmd: ", open_command)
        run_command({ open_command, url_or_word })
        -- vim.fn.jobstart({ open_command, url_or_word }, { detach = true })
      end,
    }
  end
  run_command(command_run .. " " .. url_or_word, callback)
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

-- Define a base opts table with shared variables and descriptions

local function get_qf_files()
  local files = {}
  for _, item in ipairs(vim.fn.getqflist()) do
    local fname = vim.fn.bufname(item.bufnr)
    if fname ~= "" and not files[fname] then
      files[fname] = true
    end
  end
  return vim.tbl_keys(files)
end

local function print_copy_output()
  local files = {}
  -- __AUTO_GENERATED_PRINT_VAR_START__
  files = get_qf_files()

  -- print file join by space in one line and create command to add new line on these files if exists
  --print the shell command
  -- print total files :
  print([==[ Total files:]==], #files)
  local command_sh_add_line_check_exist =
      "echo '" ..
      table.concat(files, " ") ..
      "' | xargs -I {} sh -c 'if [ -f {} ]; then echo \"\" >> \"{}\"; else echo \"File does not exist: {}\"; fi'"

  print([==[ Add line ]==])              -- __AUTO_GENERATED_PRINT_VAR_END__
  print(command_sh_add_line_check_exist) -- __AUTO_GENERATED_PRINT_VAR_END__
  -- print remove_newline (revert )
  local command_sh_remove_newline =
      "echo '" ..
      table.concat(files, " ") ..
      "' | xargs -n 1 -I {} sh -c 'if [ -f {} ]; then sed -i \"\" \"\\$d\" \"{}\"; else echo \"File does not exist: {}\"; fi'"
  print([==[ Remove line ]==])
  print(command_sh_remove_newline)
  -- print([==[ files:]==], vim.inspect(files)) -- __AUTO_GENERATED_PRINT_VAR_END__
  -- copy files into clipboard split by new line / if want same line can paste in spotlight
  vim.fn.setreg("+", table.concat(files, "\n"))
  vim.notify(" ~ Copied " .. #files .. " files to clipboard", vim.log.levels.INFO)
end

local function open_qflist_in_vscode()
  local files = get_qf_files()
  if #files == 0 then
    print("No files in quickfix list.")
    return
  end
  local cmd = "code " .. table.concat(files, " ")
  print("~ Opening files in VSCode with cmd:")
  print(cmd)
  vim.fn.jobstart(cmd, { detach = true })
end


vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'AvanteInput', 'codecompanion' },
  callback = function()
    print("FILETYPE AUCMD: ", vim.bo.filetype)
    -- cmd shift p
    -- vim.keymap.set({ 'n', 'v' }, '<D-S-v>', ':PasteImage<CR>', { desc = "PasteImage", buffer = true, silent = true })
    -- vim.keymap.set('n', '<D-v>', ':PasteImage<CR>', { desc = "PasteImage", buffer = true, silent = true })
    -- vim.api.nvim_buf_set_keymap(0, 'i', '<D-S-v>', '<Esc>:PasteImage<CR>a',
    -- unbind all of the above
    -- vim.api.nvim_buf_del_keymap(0, 'i', '<D-S-v>')
    -- vim.api.nvim_buf_del_keymap(0, 'i', '<D-v>')
    -- vim.api.nvim_buf_del_keymap(0, 'n', '<D-S-v>')
    -- vim.api.nvim_buf_del_keymap(0, 'n', '<D-v>')
    --   { desc = "PasteImage", noremap = true, silent = true })
    -- vim.keymap.set('n', '<leader>iv', ':PasteImage<CR>', { desc = "PasteImage", buffer = true, silent = true })
    -- vim.keymap.set('n', '<leader>V', ':PasteImage<CR>', { desc = "PasteImage", buffer = true, silent = true })
  end,
})
--
-- TODO checkout keymap by https://www.youtube.com/watch?v=0O3kqGwNzTI
-- https://github.com/linkarzu/dotfiles-latest/blob/4ac00c8653025da331d43adfb892dc7a67ea4c6a/neovim/nvim-lazyvim/lua/config/keymaps.lua
-- ############################################################################
--                             Image section
-- MAPPING for open dir / delete use case SHOULD be ALREADY actionable by NEOTREE go -> Delete / Open
-- ############################################################################

-- I use a Ctrl keymap so that I can paste images in insert mode
-- I tried using <C-v> but duh, that's used for visual block mode
-- so don't do it
vim.keymap.set({ "n", "v", "i" }, "<C-a><C-v>", function()
  local pasted_image = require("img-clip").paste_image()
  if pasted_image then
    -- "Update" saves only if the buffer has been modified since the last save
    vim.cmd("update")
    print("Image pasted and file saved")
    -- Only if updated I'll refresh the images by clearing them first
    -- I'm using [[ ]] to escape the special characters in a command
    vim.cmd([[lua require("image").clear()]])
    -- Reloads the file to reflect the changes
    vim.cmd("edit!")
    -- Switch back to command mode
    vim.cmd("stopinsert")
  else
    print("No image pasted. File not updated.")
  end
end, { desc = "Paste image from system clipboard" })

-- ############################################################################

-- Open image under cursor in the Preview app (macOS)
-- Get the image path: modified to work with absolute path
local function extract_image_path(line)
  -- Pattern to match image path in Markdown
  -- support md ![alt text](image_path) format
  local image_pattern = "%[.-%]%((.-)%)"
  -- Extract relative image path
  local _, _, image_path = string.find(line, image_pattern)
  -- __AUTO_GENERATED_PRINT_VAR_START__
  print([==[extract_image_path image_pattern:]==], vim.inspect(image_pattern)) -- __AUTO_GENERATED_PRINT_VAR_END__
  if not image_path or image_path == "" then
    -- vim.notify("No valid image path found from [] template", vim.log.levels.WARN)
    image_path = image_path or myPathUtil.getFullPathFromRelativePath(vim.fn.expand("<cfile>"))
  end
  return image_path
end

vim.keymap.set("n", "<leader>io", function()
  local function get_image_path()
    return extract_image_path(vim.api.nvim_get_current_line())
  end

  -- Get the image path
  local image_path = get_image_path()

  if image_path then
    -- Check if the image path starts with "http" or "https"
    if string.sub(image_path, 1, 4) == "http" then
      print("URL image, use 'gx' to open it in the default browser.")
    else
      -- Construct absolute image path
      -- local current_file_path = vim.fn.expand("%:p:h")
      -- local absolute_image_path = current_file_path .. "/" .. image_path
      local absolute_image_path = image_path

      -- Construct command to open image in Preview
      local command = "open -a Preview " .. vim.fn.shellescape(absolute_image_path)
      -- Execute the command
      local success = os.execute(command)

      if success then
        print("Opened image in Preview: " .. absolute_image_path)
      else
        print("Failed to open image in Preview: " .. absolute_image_path)
      end
    end
  else
    print("No image found under the cursor")
  end
end, { desc = "(macOS) Open image under cursor in Preview" })

-- ############################################################################

-- Open image under cursor in Finder (macOS)
--
-- THIS ONLY WORKS IF YOU'RE NNNNNOOOOOOTTTTT USING ABSOLUTE PATHS,
-- BUT INSTEAD YOURE USING RELATIVE PATHS
--
-- If using absolute paths, use the default `gx` to open the image instead
vim.keymap.set("n", "<leader>if", function()
  local function get_image_path()
    return extract_image_path(vim.api.nvim_get_current_line())
  end

  local image_path = get_image_path()

  if image_path then
    -- Check if the image path starts with "http" or "https"
    if string.sub(image_path, 1, 4) == "http" then
      print("URL image, use 'gx' to open it in the default browser.")
    else
      -- Construct absolute image path
      -- local absolute_image_path = myPathUtil.getFullPathFromRelativePath(vim.fn.expand("<cfile>"))
      -- local current_file_path = vim.fn.expand("%:p:h")
      -- local absolute_image_path = current_file_path .. "/" .. image_path
      local absolute_image_path = image_path

      -- Open the containing folder in Finder and select the image file
      local command = "open -R " .. vim.fn.shellescape(absolute_image_path)
      local success = vim.fn.system(command)

      if success == 0 then
        print("Opened image in Finder: " .. absolute_image_path)
      else
        print("Failed to open image in Finder: " .. absolute_image_path)
      end
    end
  else
    print("No image found under the cursor")
  end
end, { desc = "(macOS) Open image under cursor in Finder" })

-- ############################################################################

-- Delete image file under cursor using trash app (macOS)
vim.keymap.set("n", "<leader>id", function()
  local function get_image_path()
    return extract_image_path(vim.api.nvim_get_current_line())
  end

  -- Get the image path
  local image_path = get_image_path()

  if image_path then
    -- Check if the image path starts with "http" or "https"
    if string.sub(image_path, 1, 4) == "http" then
      vim.api.nvim_echo({
        { "URL image cannot be deleted from disk.", "WarningMsg" },
      }, false, {})
    else
      -- Construct absolute image path
      -- local current_file_path = vim.fn.expand("%:p:h")
      -- local absolute_image_path = current_file_path .. "/" .. image_path
      local absolute_image_path = image_path

      -- Check if trash utility is installed
      if vim.fn.executable("trash") == 0 then
        vim.api.nvim_echo({
          { "- Trash utility not installed. Make sure to install it first\n", "ErrorMsg" },
          { "- In macOS run `brew install trash`\n",                          nil },
        }, false, {})
        return
      end

      -- Prompt for confirmation before deleting the image
      vim.ui.input({
        prompt = "Delete image file? (y/n) ",
      }, function(input)
        if input == "y" or input == "Y" then
          -- Delete the image file using trash app
          local success, _ = pcall(function()
            vim.fn.system({ "trash", vim.fn.fnameescape(absolute_image_path) })
          end)

          if success then
            vim.api.nvim_echo({
              { "Image file deleted from disk:\n", "Normal" },
              { absolute_image_path,               "Normal" },
            }, false, {})
            -- I'll refresh the images, but will clear them first
            -- I'm using [[ ]] to escape the special characters in a command
            -- vim.cmd([[lua require("image").clear()]]) -- no need since cause issue
            -- Reloads the file to reflect the changes
            vim.cmd("edit!")
          else
            vim.api.nvim_echo({
              { "Failed to delete image file:\n", "ErrorMsg" },
              { absolute_image_path,              "ErrorMsg" },
            }, false, {})
          end
        else
          vim.api.nvim_echo({
            { "Image deletion canceled.", "Normal" },
          }, false, {})
        end
      end)
    end
  else
    vim.api.nvim_echo({
      { "No image found under the cursor", "WarningMsg" },
    }, false, {})
  end
end, { desc = "(macOS) Delete image file under cursor" })

-- ############################################################################
vim.api.nvim_create_autocmd("FileType", {
  group = quickfixAndTroubleGroup,
  pattern = "qf",
  callback = function()
    local quickfix_opts = { noremap = true, silent = true, desc = "Quickfix operation" }
    quickfix_opts.desc = "Go to older list"
    vim.api.nvim_buf_set_keymap(0, "n", "H", ":colder<CR>", quickfix_opts)
    quickfix_opts.desc = "Go to newer list"
    vim.api.nvim_buf_set_keymap(0, "n", "L", ":cnewer<CR>", quickfix_opts)
    -- open in vscode
    -- vim.api.nvim_buf_set_keymap(0, "n", "<C-o>", ":lua print_copy_output()<CR>", { noremap = true, silent = true })
    -- vim.api.nvim_buf_set_keymap(0, "n", "<C-o>", ":lua open_qflist_in_vscode()<CR>", { noremap = true, silent = true })

    quickfix_opts = vim.tbl_extend("force", quickfix_opts, { buffer = true })
    quickfix_opts.desc = "Open in VSCode"
    vim.keymap.set("n", "<C-o>", open_qflist_in_vscode, quickfix_opts)
    quickfix_opts.desc = "Print and Copy Output"
    vim.keymap.set("n", "<C-y>", print_copy_output, quickfix_opts)
  end,
})

vim.api.nvim_create_user_command("FzfSession", function()
  require("config.telescope_pickers").fzf.pickers.session_picker()
end, {})


local function toggle_lsp_format_mode(norequire)
  if vim.g.lsp_format_mode == "prefer" then
    vim.g.lsp_format_mode = "fallback"
  else
    vim.g.lsp_format_mode = "prefer"
  end

  -- if norequire then -- will not update
  vim.notify("set lsp_format to: " .. vim.g.lsp_format_mode, vim.log.levels.INFO)
  --   return
  -- end

  -- BELOW seems not required anymore
  -- local conform = require("conform")
  -- print([==[BEFORE toggle_lsp_format_mode conform:]==], vim.inspect(conform)) -- __AUTO_GENERATED_PRINT_VAR_END__

  -- function getFirstItem(configName)
  --   local myconfig = require("plugins.extra.myEditor")
  --   local conform_spec = nil
  --   local success, result = pcall(function()
  --     for _, plugin in ipairs(myconfig or {}) do
  --       if plugin[1] == configName then
  --         conform_spec = plugin
  --         break
  --       end
  --     end
  --     return conform_spec
  --   end)
  --   return success and result or nil
  -- end
  --
  -- local item = getFirstItem("stevearc/conform.nvim")
  -- local myopts = item.opts or {}
  -- print([==[toggle_lsp_format_mode myopts:]==], vim.inspect(myopts)) -- __AUTO_GENERATED_PRINT_VAR_END__
  -- conform.setup(vim.tbl_deep_extend("force", conform or {}
  --   -- need myopts else it will not works
  --   , myopts,
  --   {
  --     -- default_format_opts = { lsp_format = vim.g.lsp_format_mode },
  --     -- format_on_save = vim.tbl_extend("force", conform.format_on_save or {}, {
  --     --   lsp_format = vim.g.lsp_format_mode,
  --     -- }),
  --   }
  -- ))
  -- vim.notify("Conform lsp_format set to: " .. vim.g.lsp_format_mode, vim.log.levels.INFO)
  -- Update Conform config
  -- local conform = require("conform")
  -- print([==[AFTER toggle_lsp_format_mode conform:]==], vim.inspect(conform))                       -- __AUTO_GENERATED_PRINT_VAR_END__
  -- print([==[AFTER toggle_lsp_format_mode onsave conform:]==], vim.inspect(conform.format_on_save)) -- __AUTO_GENERATED_PRINT_VAR_END__
  --
  -- vim.notify("Conform lsp_format set to: " .. vim.g.lsp_format_mode, vim.log.levels.INFO)
end

local function confformat(timeout_ms, isasync)
  local conform = require("conform")
  conform.format({ async = isasync or false, timeout_ms = timeout_ms or 5000 }, function(err)
    if not err then
      vim.cmd(":noautocmd w")
    end
  end)
end

local function select_and_format()
  local conform = require("conform")
  local bufnr = vim.api.nvim_get_current_buf()
  local formatters = conform.list_formatters(bufnr)
  if not formatters or #formatters == 0 then
    vim.notify("No formatters available", vim.log.levels.WARN)
    return
  end

  local items = {}
  for _, f in ipairs(formatters) do
    table.insert(items, f.name)
  end

  vim.ui.select(items, { prompt = "Select formatter:" }, function(choice)
    if choice then
      conform.format({ formatters = { choice }, async = false, bufnr = bufnr })
      -- save after format without triggggggering autocmd
      vim.cmd(":noautocmd w")
      vim.notify("Formatted with: " .. choice, vim.log.levels.INFO)
    end
  end)
end

-- 3. Map shortcut
vim.keymap.set("n", "<leader>uFt", toggle_lsp_format_mode, { desc = "Toggle LSP Format Mode (prefer/fallback)" })
-- vim.keymap.set("n", "<leader>uFT", function() toggle_lsp_format_mode(true) end, { desc = "Toggle LSP Format Mode" })
vim.keymap.set("n", "<leader>uFS", select_and_format, { desc = "Select Formatter to Run" })
vim.keymap.set("n", "<leader>uFf", confformat, { desc = "Format" })
vim.keymap.set("n", "<leader>uFF", function() confformat(10000, true) end, { desc = "Async Format" })
vim.keymap.set("n", "<leader>uFs", ":noautocmd w<CR>", { desc = "Save No Format" })
-- From docs : https://github.com/stevearc/conform.nvim/blob/master/doc/recipes.md#leave-visual-mode-after-range-format
vim.keymap.set("", "<localleader>F", function()
  require("conform").format({ async = true }, function(err)
    if not err then
      local mode = vim.api.nvim_get_mode().mode
      if vim.startswith(string.lower(mode), "v") then
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", true)
      end
    end
  end)
end, { desc = "Format code" })


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
