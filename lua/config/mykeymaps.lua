local opts = { noremap = true, silent = true }
local myPathUtil = require "utils.mypath"
local keymap = vim.keymap.set
local Cmd = require "utils.cmd"
local run_command = Cmd.run_command
local inputUtil = require "utils.input"
local codeRef = require "utils.code_ref"
local clipboardUtil = require "utils.myinput"

local function copy_code_ref(format, absolute, copy_mode, visual)
  return codeRef.copy_current {
    format = format,
    absolute = absolute,
    copy_mode = copy_mode or "plus",
    show_char_range = vim.g.code_ref_show_char_range,
    visual = visual or false,
  }
end

vim.api.nvim_create_user_command("CopyCodeRef", function(cmd)
  local format = cmd.args ~= "" and cmd.args or "colon"
  local absolute = cmd.bang or false
  copy_code_ref(format, absolute)
end, {
  nargs = "?",
  bang = true,
  complete = function()
    return { "colon", "space", "at", "at_caps", "hash" }
  end,
})

local function open_obsidian_vault_audit(cmd)
  require("utils.obsidian_vault_audit").pick { scan = not cmd.bang }
end

vim.api.nvim_create_user_command("ObsidianVaultAudit", open_obsidian_vault_audit, {
  bang = true,
  force = true,
  desc = "Audit Obsidian vault registry/config cleanup with Snacks",
})

vim.api.nvim_create_user_command("SnacksObsidianVaultAudit", open_obsidian_vault_audit, {
  bang = true,
  force = true,
  desc = "Audit Obsidian vault registry/config cleanup with Snacks",
})
-- ===========================
-- LAZY NVIM ====================
-- =======================

-- Setup keys
local function diffoff_all_buffers()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    vim.api.nvim_buf_call(buf, function()
      vim.cmd "diffoff"
    end)
  end
end

keymap(
  "n",
  "<leader>dX",
  diffoff_all_buffers,
  { desc = "Turn off diff mode for all buffers", noremap = true, silent = true }
)
-- check using :letmapleader or :let maplocalleader
-- -> need to put inside plugins mapping also to make it work on those mapping
-- command completion in command line mode
keymap("n", "<leader>ll", "<cmd>Lazy<CR>", { desc = "Lazy" })
-- keymap("n", "<leader>lx", "<cmd>LazyExtras<CR>", { desc = "Lazy Extras" })

-- ============================
-- EDITING
-- ============================
-- selection
keymap("n", "<M-a>", function()
  vim.cmd "normal! ggVG"
end, { noremap = true, silent = true })

keymap("v", "<M-a>", ":'<,'>QuickCodeRunner<CR>", { noremap = true, silent = true })
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

vim.cmd [[
  cnoremap <expr> <C-j> wildmenumode() ? "\<C-N>" : "\<C-j>"
  cnoremap <expr> <C-k> wildmenumode() ? "\<C-P>" : "\<C-k>"
]]

local function handleMode(mode)
  return function()
    if vim.fn.mode() == mode then
      vim.cmd "normal! y"
    else
      -- do as normal trigger for visual mode / visual line modejgc
      if mode == "v" then
        vim.cmd "normal! v"
      elseif mode == "V" then
        vim.cmd "normal! V"
      else
        -- Handle unexpected mode by falling back to default key bindings
        vim.notify("Unexpected mode: " .. vim.fn.mode(), vim.log.levels.WARN)
        vim.cmd "normal! gv"
      end
    end
  end
end

opts.desc = "Yank in visual"
keymap("v", "v", handleMode "v", opts)
keymap("v", "V", handleMode "V", opts)

-- Duplicate line and preserve previous yank register
--  support mode v as
function duplicateselected()
  local saved_unnamed = vim.fn.getreg '"'

  local current_selected_line = ""
  local current_mode = vim.fn.mode()
  if current_mode == "v" or current_mode == "V" then
    -- Get the selected lines
    current_selected_line = vim.fn.getline("`<", "`>")
  else
    current_selected_line = vim.fn.getline "."
  end

  -- Duplicate the current line or selected lines
  if current_mode == "v" or current_mode == "V" then
    -- In visual mode, use normal command to duplicate lines
    vim.api.nvim_command "normal! y`>p`>"
    -- vim.api.nvim_command("normal! y`>$p`>") -- new line (will not work with v mode not new line)
  else
    -- In normal mode, duplicate the current line
    vim.cmd "normal! yyp"
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

-- Copy to system clipboard (+ register) using simple vim.cmd
keymap("n", "YY", function()
  vim.cmd 'normal! "+yy'
  vim.notify("Copied line to system clipboard", vim.log.levels.INFO)
end, { desc = "Copy line to system clipboard" })

keymap("v", "Y", function()
  vim.cmd 'normal! "+y'
  vim.notify("Copied selection to system clipboard", vim.log.levels.INFO)
end, { desc = "Copy selection to system clipboard" })

keymap("v", "<C-c>", function()
  vim.cmd 'normal! "+y'
  vim.notify("Copied selection to system clipboard", vim.log.levels.INFO)
end, { desc = "Copy selection to system clipboard" })

keymap("n", "<localleader>cc", function()
  require("utils.myinput").copy_yank_to_system(true)
end, { desc = "Copy yank to system clipboard" })
--
-- Code reference copies (copy to system clipboard only)
-- Code reference keymaps with visual mode support
-- Separate n/v keymaps so the visual flag is known at registration time
local function create_code_ref_keymap(key, format, absolute, desc)
  keymap("n", key, function()
    copy_code_ref(format, absolute, "plus", false)
  end, { desc = desc })
  keymap("v", key, function()
    copy_code_ref(format, absolute, "plus", true)
  end, { desc = desc })
end

-- Relative paths (lowercase suffix)
create_code_ref_keymap("<localleader>crr", "colon", false, "CodeRef rel path:line:col")
create_code_ref_keymap("<localleader>crs", "space", false, "CodeRef rel path line:col")
create_code_ref_keymap("<localleader>cra", "at_caps", false, "CodeRef rel @path Lline:Ccol")
create_code_ref_keymap("<localleader>crb", "at", false, "CodeRef rel @path line:col")
create_code_ref_keymap("<localleader>crh", "hash", false, "CodeRef rel path#LlineCcol")

-- Absolute paths (uppercase suffix)
create_code_ref_keymap("<localleader>crR", "colon", true, "CodeRef ABS path:line:col")
create_code_ref_keymap("<localleader>crS", "space", true, "CodeRef ABS path line:col")
create_code_ref_keymap("<localleader>crA", "at_caps", true, "CodeRef ABS @path Lline:Ccol")
create_code_ref_keymap("<localleader>crB", "at", true, "CodeRef ABS @path line:col")
create_code_ref_keymap("<localleader>crH", "hash", true, "CodeRef ABS path#LlineCcol")

-- Picker (visual: capture flag before picker opens)
keymap("n", "<localleader>crp", function()
  require("utils.snacks_pickers").code_ref_picker { visual = false }
end, { desc = "CodeRef picker (copy to clipboard)" })
keymap("v", "<localleader>crp", function()
  require("utils.snacks_pickers").code_ref_picker { visual = true }
end, { desc = "CodeRef picker (copy to clipboard)" })

-- Toggle char range in references
keymap("n", "<localleader>crT", function()
  require("utils.code_ref").toggle_char_range()
end, { desc = "Toggle char range in code refs" })

-- Toggle hide column entirely
keymap("n", "<localleader>crt", function()
  require("utils.code_ref").toggle_hide_col()
end, { desc = "Toggle hide column in code refs" })

-- Git Pickers
keymap("n", "<leader>fu", function()
  require("utils.snacks_pickers").custom_git_pickers.git_diff_merge_base()
end, { desc = "Git diff merge-base (increment/decrement)" })

keymap("n", "<leader>fWs", function()
  require("utils.workspace_all").pick_config()
end, { desc = "Workspace configs" })

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
keymap("i", "<A-h>", "<C-o>^", { desc = "Go to start of line", silent = true })
keymap("i", "<A-l>", "<C-o>$", { desc = "Go to end of line", silent = true })
keymap("i", "<C-M-l>", "<C-o>e", { desc = "Move Forward Word", silent = true })
keymap("i", "<C-M-h>", "<C-o>b", { desc = "Move Backward Word", silent = true })

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
keymap("n", "<C-M-l>", ":tabnext<CR>", { desc = "Next Tab", silent = true })
keymap("n", "<C-M-h>", ":tabprevious<CR>", { desc = "Previous Tab", silent = true })
keymap("n", "<C-M-h>", ":tabprevious<CR>", { desc = "Previous Tab", silent = true })
-- map("n", "<C-Up>", ":resize -3<CR>", opts)
-- map("n", "<C-Down>", ":resize +3<CR>", opts)
-- map("n", "<C-Left>", ":vertical resize -3<CR>", opts)
-- map("n", "<C-Right>", ":vertical resize +3<CR>", opts)

local function calculate_tab_target(direction)
  -- Use vcount if provided; otherwise move left (wrap to last when at first)
  local total = vim.fn.tabpagenr "$"
  local curr = vim.fn.tabpagenr()
  -- __AUTO_GENERATED_PRINT_VAR_START__
  -- print([==[calculate_tab_target curr:]==], vim.inspect(curr .. "/".. total)) -- __AUTO_GENERATED_PRINT_VAR_END__
  if direction == "left" then
    if curr <= 1 then
      return total
    else
      return curr - 2
    end
  elseif direction == "right" then
    if curr == total then
      return 0
    else
      return curr + 1
    end
  end
end
-- Prompt for target index (always prompt)
keymap("n", "<leader><Tab>m", function()
  local total = vim.fn.tabpagenr "$"
  local count = vim.v.count
  local current = vim.fn.tabpagenr()

  local calculate_tab_pos = function(n)
    local offset = (current < n) and 1 or 0
    -- left and right shift adjustment
    print("[==[(anon)#calculate_tab_idx#if total:]==]", vim.inspect(n .. "." .. total)) -- __AUTO_GENERATED_PRINT_VAR_END__
    if n > total then
      return total
    elseif n <= 1 then
      return 0
    else
      return n - 1 + offset
    end
  end

  if count ~= 0 then
    vim.cmd("tabmove" .. calculate_tab_pos(count))
  else
    vim.ui.input({ prompt = "Move tab to index (1-" .. total .. ") " }, function(input)
      if not input or input == "" then
        return
      end
      vim.cmd("tabmove " .. calculate_tab_pos(tonumber(input)))
    end)
  end
end, { desc = "Prompt for tab index and move current tab" })
keymap("n", "<leader><Tab>H", function()
  local target = calculate_tab_target "left"
  vim.cmd("tabmove " .. target)
end, { desc = "Move tab left (use vcount) or wrap to last" })

keymap("n", "<leader><Tab>L", function()
  local target = calculate_tab_target "right"
  vim.cmd("tabmove " .. target)
end, { desc = "Move tab right (use vcount) or wrap to first" })

-- Resize with ESC keys - up down use for auto cmpl
keymap("n", "<Up>", ":resize -3<CR>", opts)
keymap("n", "<Down>", ":resize +3<CR>", opts)
keymap("n", "<Left>", "<cmd>vertical resize -3<CR>", opts)
keymap("n", "<Right>", "<cmd>vertical resize +3<CR>", opts)

-- Smart buffer navigation: Try BufferLine first, fallback to native commands
local function smart_buffer_prev()
  local ok = pcall(vim.cmd, "BufferLineCyclePrev")
  if not ok then
    vim.cmd "bprevious"
  end
end

local function smart_buffer_next()
  local ok = pcall(vim.cmd, "BufferLineCycleNext")
  if not ok then
    vim.notify("Error executing BufferLineCycleNext", vim.log.levels.ERROR)
  end
  if not ok then
    vim.cmd "bnext"
  end
end

keymap("n", "<S-h>", smart_buffer_prev, { desc = "Prev Buffer" })
keymap("n", "<S-l>", smart_buffer_next, { desc = "Next Buffer" })

-- map("n", "H", ":bp<CR>", { desc = "Previous Buffer", silent = true })
-- map("n", "L", ":bn<CR>", { desc = "Next Buffer", silent = true })
-- use <l>bd instead
opts.desc = "Close buffer"
keymap("n", "<leader>bd", ":b#|bd#<CR>", opts)
-- map("n", "<leader>wX", ":bd!<CR>", { desc = "Force close buffer" })

local function toggle_fold_or_clear_highlight()
  if vim.fn.foldlevel "." > 0 then
    vim.api.nvim_input "za"
  else
    vim.cmd "nohlsearch"
  end
end
keymap("n", "<Esc>", toggle_fold_or_clear_highlight, { expr = true, silent = true, noremap = true })
-- Terminal & Commands
-- ============================
opts.desc = "Toggle Normal"
keymap("t", "<C-q>", "<c-\\><c-n>", { desc = "Enter Normal Mode" })
keymap("t", "<C-q>", "<c-\\><c-n>:q<CR>", { desc = "Close Terminal", silent = true })

opts.desc = nil

local getTermBuffer = function(filter_ft)
  -- __AUTO_GENERATED_PRINT_VAR_START__
  print([==[getTermBuffer filter_ft:]==], vim.inspect(filter_ft)) -- __AUTO_GENERATED_PRINT_VAR_END__
  local term_buffers = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local ft = vim.bo[buf].filetype -- toggleterm
    local bufName = vim.api.nvim_buf_get_name(buf)
    local is_toggleterm = ft == "toggleterm"
    local is_snacks = ft == "snacks_terminal"
    local is_sidekick = ft == "sidekick_terminal"
    local is_lazygit = bufName:match "lazygit" ~= nil

    local is_term = (filter_ft and ft == filter_ft)
      or (filter_ft == nil and (not is_lazygit and (is_toggleterm or is_snacks)))

    print([==[getTermBuffer#for#if is_term:]==], vim.inspect(is_term)) -- __AUTO_GENERATED_PRINT_VAR_END__
    if is_term == true then
      -- __AUTO_GENERATED_PRINT_VAR_START__
      table.insert(term_buffers, buf)
    end
  end
  return term_buffers
end

function _G.cycle_term_buffers(filter_ft)
  print("G cycle " .. (filter_ft or "x"))
  local term_buffers = getTermBuffer(filter_ft)
  -- __AUTO_GENERATED_PRINT_VAR_START__
  print([==[_G.cycle_term_buffers term_buffers:]==], vim.inspect(term_buffers)) -- __AUTO_GENERATED_PRINT_VAR_END__
  if #term_buffers == 0 then
    print "No terminal buffers found"
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

  print([==[_G.cycle_term_buffers#if next_buf:]==], vim.inspect(next_buf)) -- __AUTO_GENERATED_PRINT_VAR_END__
  -- vim.api.nvim_set_current_win(next_buf)

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
  vim.cmd "ToggleTerm"
  termlayout = vim.g.mytoggtermlayout
  vim.cmd("ToggleTerm direction=" .. termlayout)
  -- enter normal mode again from insert terminal mode
  vim.cmd "stopinsert"
end

function _G.create_new_term()
  local term_buffers = getTermBuffer()
  -- #term#<id>
  local next_id = 1
  local next_buf = nil
  local sorted_term_num = {}
  for i, buf in ipairs(term_buffers) do
    local bufname = vim.api.nvim_buf_get_name(buf)
    -- sample snacks terminal :
    -- term://~/dotfiles//17674:/bin/bash"
    -- sample toggleterm terminal
    -- term://~/dotfiles//30640:/bin/bash;#toggleterm#1

    local id = bufname:match "term://.*#(%d+)$"
    local ft = vim.bo[buf].filetype
    if ft == "toggleterm" then
      id = bufname:match "term://.*#(%d+)$"
    elseif ft == "snacks_terminal" then
      id = bufname:match "term://.*//(%d+):"
    else
      id = bufname:match "term://.*//(%d+):"
    end

    print([==[_G.create_new_term#for#if id:]==], vim.inspect(id)) -- __AUTO_GENERATED_PRINT_VAR_END__
    if tonumber(id) > 0 then
      table.insert(sorted_term_num, { id = tonumber(id), buf = buf })
    end
  end
  table.sort(sorted_term_num, function(a, b)
    return a.id < b.id
  end)

  -- For toggle term to find next avail id
  for i, entry in ipairs(sorted_term_num) do
    if next_id < entry.id then
      break
    else
      next_id = next_id + 1
      next_buf = entry.buf
    end
  end

  local current_ft = vim.bo.filetype
  local command = nil
  if current_ft:match "toggleterm" then
    command = next_id .. "ToggleTerm"
    vim.cmd(command)
  elseif current_ft:match "snacks_terminal" then
    print("Snacks terminal open id " .. next_id)
    command = "SnacksTerm " .. next_id
    require("snacks").open_terminal(next_id)
  else
    -- open that buffer number
    command = "buffer " .. next_id
    vim.cmd("buffer " .. next_id)
  end
end

local function toggleSnacks()
  print "togglesnacks from map inner"
  Snacks.terminal()
end

function _G.set_toggleterm_keymaps()
  -- run on all terminal buffers
  -- https://github.com/akinsho/toggleterm.nvim?tab=readme-ov-file#terminal-window-mappings
  local opts = opts
  local bufnum = vim.api.nvim_get_current_buf()
  opts.buffer = 0 -- only current buffer
  local ft = vim.bo.filetype
  local bufName = vim.api.nvim_buf_get_name(bufnum)
  local is_toggleterm = ft == "toggleterm"
  local is_snacks = ft == "snacks_terminal"
  local is_sidekick = ft == "sidekick_terminal"
  local is_tiny_term = ft == "tiny_term"
  local is_lazygit = bufName:match "lazygit" ~= nil
  -- print([==[_G.set_toggleterm_keymaps bufName:]==], vim.inspect(bufName)) -- __AUTO_GENERATED_PRINT_VAR_END__
  -- print([==[_G.set_toggleterm_keymaps is_lazygit:]==], vim.inspect(is_lazygit)) -- __AUTO_GENERATED_PRINT_VAR_END__

  opts.desc = "Enter normal mode (hjk)"
  vim.keymap.set("t", "hjk", [[<C-\><C-n>]], opts)
  pcall(vim.keymap.del, "t", "jk", { buffer = bufnum })
  pcall(vim.keymap.del, "t", "<Esc><Esc>", { buffer = bufnum })
  if is_snacks or is_tiny_term then
    pcall(vim.keymap.del, "t", "<Esc>", { buffer = bufnum })
  end

  if is_lazygit then
    print "Lazygit buffer"
    if vim.g.lazygit_passthrough_ctrl_hjkl then
      vim.keymap.set("t", "<C-h>", "<C-h>", { buffer = bufnum, nowait = true })
      vim.keymap.set("t", "<C-j>", "<C-j>", { buffer = bufnum, nowait = true })
      vim.keymap.set("t", "<C-k>", "<C-k>", { buffer = bufnum, nowait = true })
      vim.keymap.set("t", "<C-l>", "<C-l>", { buffer = bufnum, nowait = true })
    end
  elseif is_sidekick then
    print "Sidekick buffer"
    -- try remove but still not work usable
    -- vim.api.nvim_del_keymap("t", "<C-h>")
    -- vim.api.nvim_del_keymap("t", "<C-p>")
    -- vim.api.nvim_del_keymap("t", "<C-j>")
    -- vim.api.nvim_del_keymap("t", "<C-h>")
    -- remove_map_if_exists('<C-j>', 't')
    -- remove_map_if_exists('<C-k>', 't')
  else
    -- vim.keymap.set("n", "<C-_>", [[<Cmd>exe v:count1 . "ToggleTerm"<CR>]],
    -- { desc = "Toggle term BF", noremap = true, silent = true })

    -- TODO: still conflicting ?
    -- vim.keymap.set("n", "<C-/>", toggleSnacks, { silent = true, desc = "Toggle snacks BF" })
    -- vim.keymap.set("n", "<C-S-Tab>", toggleSnacks, { silent = true, desc = "Toggle snacks BF" })
    -- vim.keymap.set("n", "<S-A-Tab>", [[<Cmd>exe v:count1 . "ToggleTerm"<CR>]], { desc = "ToggleTerm", silent = true, noremap = true })

    if is_snacks or is_toggleterm then
      opts.desc = "Cycle all terms"
      vim.keymap.set("n", "<S-Tab>", ":lua cycle_term_buffers()<CR>", opts)
      -- conflict with claude code toggle mode  - disable for now
      -- vim.keymap.set("t", "<S-Tab>", cycle_term_buffers, opts)
      opts.desc = "Cycle term buffer"
      -- TODO: this c-s-tab key not working
      vim.keymap.set("n", "<C-S-Tab>", ":lua cycle_term_buffers()<CR>", opts)
      vim.keymap.set({ "t" }, "<C-S-Tab>", function()
        local current_ft = vim.bo.filetype
        print("Cycle map current_ft" .. current_ft)
        cycle_term_buffers(current_ft)
      end, opts)
    end

    if is_snacks then
      -- print("Snacks terminal buffer")
      opts.desc = "Toggle Snacks Term in normal mode"
      opts.desc = "Toggle Snacks Terminal"
      vim.keymap.set("n", "<C-t>", toggleSnacks, opts)

      -- TODO check if can use opts.win.position "float" or "bottom"
      opts.desc = "Toggle Snacks term layout"
      vim.keymap.set({ "t" }, "<C-Tab>", function()
        local buf = vim.api.nvim_get_current_buf()
        local info = vim.b[buf].snacks_terminal
        local new_pos = info.position == "float" and "bottom" or "float"
        info.position = new_pos
        ---        ---@class snacks.terminal.Opts: snacks.terminal.Config
        ------@field cwd? string
        ------@field count? integer
        ------@field env? table<string, string>
        ------@field start_insert? boolean start insert mode when starting the terminal
        ------@field auto_insert? boolean start insert mode when entering the terminal buffer
        ------@field auto_close? boolean close the terminal buffer when the process exits
        ------@field interactive? boolean shortcut for `start_insert`, `auto_close` and `auto_insert` (default: true)
        ---📦 Module
        if info then
          require("snacks.terminal").toggle(info.cmd, info)
        end
      end, opts)

      opts.desc = "Toggle Snacks with cmd"

      vim.keymap.set("n", "<C-i>", function()
        local buf = vim.api.nvim_get_current_buf()
        local info = vim.b[buf].snacks_terminal
        -- debug mode
        -- variables = {
        --   changedtick = 8,
        --   snacks_terminal = {
        --     id = 1
        --   },
        --   term_title = "term://~/dotfiles//60264:/bin/bash",
        --   terminal_job_id = 4,
        --   terminal_job_pid = 60264,
        --   ts_folds = false
        -- },
        --
        print([==[_G.set_toggleterm_keymaps#if#if#(anon) info:]==] .. buf .. " >", vim.inspect(info)) -- __AUTO_GENERATED_PRINT_VAR_END__
        print "Send current word to Snacks terminal"
        -- TODO: make it toggle correctly
        -- __AUTO_GENERATED_PRINT_VAR_START__
        local newcmd = "echo " .. vim.fn.expand "<cword>"
        newcmd = ""
        info.position = "bottom"
        if info then
          require("snacks.terminal").toggle(newcmd, info)
        end
      end, opts)
    elseif is_toggleterm then
      -- print("Toggleterm buffer")
      opts.desc = "Toggle Term in normal mode"
      opts.desc = "Toggle Term <num> (press with <n> to open other term)"
      vim.keymap.set("n", "<C-t>", [[<Cmd>exe v:count1 . "ToggleTerm"<CR>]], opts)
      vim.keymap.set("n", "<localleader>tt", [[<Cmd>exe v:count1 . "ToggleTerm"<CR>]], opts)
      opts.desc = "Toggle Layout"
      vim.keymap.set({ "t" }, "<C-SPACE>", cycle_term_layout, opts)
      vim.keymap.set({ "n" }, "<C-SPACE>", "<Cmd>lua cycle_term_layout()<CR>", opts)
      opts.desc = "Create new Term"
      vim.keymap.set("n", "<C-n>", ":lua create_new_term()<CR>", opts)
      -- Make sure C-_ always use ToggleTerm
      opts.desc = "Toggle Term"
      vim.keymap.set("t", "<C-_>", [[<Cmd>exe v:count1 . "ToggleTerm"<CR>]], opts)
      -- cycle through all terminal buffers
      -- J and K to move between all buffers next and rpev
      opts.desc = "Toggle Term next toggle"
      vim.keymap.set("n", "J", [[<Cmd>exe v:count1 . "ToggleTerm"<CR>]], opts)
    else
      -- print("Other terminal buffer" .. ft)
    end
    -- direction=float|horizontal|vertical
    opts.desc = "Quit Current Term"
    vim.keymap.set("n", "Q", ":bd!<CR>", opts)
  end
  -- what about buffername ?
  -- if not lazygit then do mapping
  -- resize
  -- opts.desc = "Resize" -- not working
  -- vim.keymap.set("t", "Up", [[<C-\><C-n>:resize -3<CR>]], opts)
  -- vim.keymap.set("t", "Down", [[:resize +3<CR>]], opts)
  -- vim.keymap.set("t", "<C-Left>", [[<C-\><C-n>:vertical resize -3<CR>]], opts)
  -- vim.keymap.set("t", "<C-Right>", [[<C-\><C-n>:vertical resize +3<CR>]], opts)
  -- vim.keymap.set("t", "<C-l>", [[<Cmd>wincmd l<CR>]], opts)
  -- vim.keymap.set("t", "<C-w>", [[<C-\><C-n><C-w>]], opts)
end

keymap("n", ";", ":", { desc = "CMD enter command mode" })

vim.api.nvim_create_user_command("OpenTerminalInSplitWithCwd", function()
  local cwd = vim.fn.expand "%:p:h"

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
    require("gitsigns").nav_hunk "next"
  end)
  return "<Ignore>"
end

function gitsigns_jump_prev_hunk()
  if vim.wo.diff then
    return "[c"
  end
  vim.schedule(function()
    require("gitsigns").nav_hunk "prev"
  end)
  return "<Ignore>"
end

-- c-s-k , j
-- ghostty : seem not to work (act as tmux nav to panel on right) but c-s-j works
-- alacritty : not work at all - do nothing
-- iterm2 : works

keymap({ "n", "v" }, "<C-S-j>", gitsigns_jump_next_hunk, { desc = "Jump to next hunk", expr = true })
keymap({ "n", "v" }, "<C-S-k>", gitsigns_jump_prev_hunk, { desc = "Jump to prev hunk", expr = true })
keymap({ "n", "v" }, "<C-M-k>", gitsigns_jump_prev_hunk, { desc = "Jump to prev hunk", expr = true })
keymap({ "n", "v" }, "<C-M-j>", gitsigns_jump_next_hunk, { desc = "Jump to next hunk", expr = true })

-- works in ghostty
-- keymap({ "n", "v" }, "<C-S-y>", gitsigns_jump_prev_hunk, { desc = "Jump to prev hunk", expr = true })
-- keymap({ "n", "v" }, "<M-C-o>", gitsigns_jump_prev_hunk, { desc = "Jump to prev hunk", expr = true })
-- keymap({ "n", "v" }, "<M-C-f>", gitsigns_jump_next_hunk, { desc = "Jump to next hunk", expr = true })

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

local function diff_with_saved()
  local bufnr = vim.api.nvim_get_current_buf()
  local fname = vim.api.nvim_buf_get_name(bufnr)
  if fname == "" then
    vim.notify("Cannot diff: buffer has no file name", vim.log.levels.WARN)
    return
  end
  fname = vim.fn.fnamemodify(fname, ":p")
  if vim.fn.filereadable(fname) == 0 then
    vim.notify("Cannot diff: file not readable on disk", vim.log.levels.WARN)
    return
  end
  local ft = vim.bo[bufnr].filetype
  vim.cmd.diffthis()
  vim.cmd "vertical new"
  vim.bo.buftype = "nofile"
  vim.bo.bufhidden = "wipe"
  vim.bo.swapfile = false
  if ft ~= "" then
    vim.bo.filetype = ft
  end
  vim.cmd("0read ++edit " .. vim.fn.fnameescape(fname))
  vim.bo.modifiable = false
  vim.cmd.diffthis()
  vim.cmd.wincmd "p"
end

-- Diff Operations
keymap("n", "<leader>dS", diff_with_saved, { desc = "Diff vs saved file", noremap = true, silent = true })
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
      print "Unbind ?"
    end
  end,
})

local function addNvimConfigInRoot()
  local pathUtil = require "utils.path"
  local git_dir = pathUtil.get_git_root() or vim.fn.getcwd()
  local nvim_config = git_dir .. "/.nvim-config.lua"
  if vim.fn.filereadable(nvim_config) == 1 then
    vim.notify(nvim_config .. " already exists", vim.log.levels.WARN)
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
  local nvim_base_config = vim.fn.stdpath "config" .. "/lua/config/mydefault-nvim-config.lua"
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
  require("utils.lsp_setup").processLspClients "restart"
end, { nargs = 0 })

-- Stop LSP clients by name
Cmd.create_cmd("StopLspClients", function()
  require("utils.lsp_setup").processLspClients "stop"
end, { nargs = 0 })

Cmd.create_cmd("StopAllLspClients", function()
  local active_clients = vim.lsp.get_active_clients()

  for _, client in ipairs(active_clients) do
    vim.lsp.stop_client(client.id)
  end

  Snacks.debug("Stopped all LSP clients", vim.log.levels.INFO)
end, { nargs = 0 })

-- LSP Client Management: Simple select dialogs (backward compatible)
keymap("n", "<leader>Lr", ":RestartLspClients<CR>", { desc = "LSP Restart (select)", noremap = true, silent = true })
keymap("n", "<leader>Lx", ":StopLspClients<CR>", { desc = "LSP Stop (select)", noremap = true, silent = true })
keymap("n", "<leader>LX", ":StopAllLspClients<CR>", { desc = "LSP Stop All", noremap = true, silent = true })
keymap("n", "<leader>Li", ":check lsp<CR>", { desc = "LSP Info", noremap = true, silent = true })

-- LSP Client Management: Snacks picker with preview (shows full paths, capabilities, etc.)
-- In picker: <C-r> restart, <C-x> stop, <CR> show hint
keymap("n", "<leader>Ll", function()
  require("utils.lsp_setup").lsp_clients_picker()
end, { desc = "LSP Manager (restart/stop/disable/enable/pause/resume)", noremap = true, silent = true })

--   # which key migrate .nvim $HOME/.config/nvim/keys/which-key.vim
keymap("n", "<c-q>", ":q<CR>", { desc = "Close", noremap = true, silent = true })
keymap("n", "<localleader>q", ":q<CR>", { desc = "Close", noremap = true, silent = true })
keymap("n", "<localleader>cd", ":lcd%:p:h <CR>", { desc = "CD to current dir" })
keymap("n", "<localleader>cn", ':let @+=expand("%:t")<CR>', { desc = "Copy basefilename into reg" })
-- copy relative filepath name
keymap("n", "<localleader>cf", function()
  local bufname = vim.api.nvim_buf_get_name(0)
  local rel_path = vim.fn.fnamemodify(bufname, ":.")
  vim.fn.setreg("+", rel_path)
end, { desc = "Copy relative filepath name" })
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
keymap("n", "<localleader>rsn", addNvimConfigInRoot, { desc = "Edit / Setup nvim proj lang & plugin config" })
keymap("n", "<localleader>rp", "", { desc = "Profile" })
keymap("n", "<localleader>rF", ":luafile %<CR>", { desc = "Reload Lua file" })

--- Unified runner for executing selected code (Lua or Vim command)
---@param opts { mode: "lua"|"vim", show_output?: boolean, lastselected?: boolean }
local function execute_selected_code(opts)
  local code
  if opts.lastselected then
    code = inputUtil.getPreviousSelectedText()
  else
    code = inputUtil.getSelectedLines()
  end
  if not code then
    return
  end

  if opts.mode == "lua" then
    local f = load(code)
    if f then
      f()
    end
  elseif opts.mode == "vim" then
    -- strip leading whitespace
    code = code:match "^%s*(.*%S)" or ""
    if code == "" then
      return
    end
    -- auto-prepend ":" if missing
    if not code:match "^:" then
      code = ":" .. code
    end
    -- strip the leading ":" for vim.cmd
    local cmd = code:sub(2)
    if not inputUtil.is_visual_mode() then
      -- replace all initial space and '--''
      cmd = cmd:gsub("^%s*%-*%s*", "")
    end
    local ok, err = pcall(vim.cmd, cmd)
    if not ok then
      vim.notify("Vim cmd failed: " .. tostring(err), vim.log.levels.WARN)
    end
  end

  if opts.show_output then
    local current_win = vim.api.nvim_get_current_win()
    -- some async delay then execute noice
    vim.defer_fn(function()
      require("utils.ui").noice_cmd_tab_aware "all"
      if vim.api.nvim_get_current_win() ~= current_win then
        vim.api.nvim_set_current_win(current_win)
      end
    end, 200)
  end
end

keymap({ "n", "v" }, "<localleader>rl", function()
  execute_selected_code { mode = "lua", show_output = true }
end, { desc = "Execute selected Lua code (show output)" })
keymap({ "n", "v" }, "<localleader>rL", function()
  execute_selected_code { mode = "lua", show_output = false }
end, { desc = "Execute selected Lua code (no output)" })
keymap("n", "<localleader>rT", function()
  execute_selected_code { mode = "lua", lastselected = true }
end, { desc = "Execute last selected Lua code" })

keymap({ "n", "v" }, "<localleader>rv", function()
  execute_selected_code { mode = "vim", show_output = true }
end, { desc = "Execute selected Vim command (show output)" })
keymap({ "n", "v" }, "<localleader>rV", function()
  execute_selected_code { mode = "vim", show_output = false }
end, { desc = "Execute selected Vim command (no output)" })

keymap("n", "<localleader>rsv", "<cmd>so $MYVIMRC<CR>", { desc = "Source NVIM init" })
keymap("n", "<localleader>rsV", "<cmd>so ~/.vimrc<CR>", { desc = "Source ~/.vimrc" })

keymap("n", "<localleader>rps", function()
  vim.cmd [[
		:profile start /tmp/nvim-profile.log
		:profile func *
		:profile file *
	]]
end, { desc = "Profile Start" })

keymap("n", "<localleader>rpe", function()
  vim.cmd [[
		:profile stop
		:e /tmp/nvim-profile.log
	]]
end, { desc = "Profile End" })

--profile

-- ===========================
-- Custom commands ====================
-- =======================

local function rename_buffer()
  local old_name = vim.fn.expand "%"
  local new_name = vim.fn.input("Enter new buffer name: ", old_name)

  -- If user provided a new name and it's different from the old name
  if new_name ~= "" and new_name ~= old_name then
    -- Rename the buffer
    vim.api.nvim_buf_set_name(0, new_name)
    print("Buffer renamed to " .. new_name)
  else
    print "Buffer not renamed."
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
if vim.fn.has "mac" == 1 then
  open_command = "open"
end

-- Clean input by removing newlines and normalizing whitespace

local function url_repo(tryParseGit)
  local cursorword
  local mode = vim.fn.mode()
  if mode == "v" or mode == "V" then
    -- use visual selection if available
    cursorword = inputUtil.get_selected_or_cursor_word()
  else
    cursorword = vim.fn.expand "<cfile>"
  end

  -- Clean the text (remove newlines, trim whitespace)
  cursorword = inputUtil.clean_selected_text(cursorword)

  -- __AUTO_GENERATED_PRINT_VAR_START__
  print([==[url_repo cursorword:]==], vim.inspect(cursorword)) -- __AUTO_GENERATED_PRINT_VAR_END__
  if tryParseGit and cursorword and string.find(cursorword, "^[a-zA-Z0-9-_.]*/[a-zA-Z0-9-_.]*$") then
    cursorword = "https://github.com/" .. cursorword
  end
  print(cursorword or "")
  return cursorword or ""
end

keymap({ "n", "v" }, "gx", function()
  local url_or_word = url_repo(true)
  -- copy to register + if not empty
  run_command { open_command, url_or_word }
  --   vim.fn.jobstart({ open_command, url_or_word }, { detach = true }) -- not work in tmux
  if url_or_word ~= "" then
    vim.fn.setreg("+", url_or_word)
  end
end, { silent = true, desc = "Copy word / Open url" })

-- map key maps to open directory
keymap({ "n", "v" }, "gGs", function()
  local text = inputUtil.get_selected_or_cursor_word()
  text = inputUtil.clean_selected_text(text)

  -- __AUTO_GENERATED_PRINT_VAR_START__
  print([==[(anon) text:]==], vim.inspect(text)) -- __AUTO_GENERATED_PRINT_VAR_END__
  local escaped_text = text and text:gsub(" ", "%%20")
  if not escaped_text or escaped_text == "" then
    print "No text to search"
    return
  end
  -- __AUTO_GENERATED_PRINT_VAR_
  print([==[(anon) escaped_text:]==], vim.inspect(escaped_text)) -- __AUTO_GENERATED_PRINT_VAR_END__
  local search_url = "https://www.google.com/search?q=" .. escaped_text
  run_command { open_command, search_url }
end, { silent = true, desc = "Google Search" })

-- Common function to resolve directory path from cursor/selection
local function resolve_directory_path()
  local selected_or_cursor_word = inputUtil.get_selected_or_cursor_word()
  selected_or_cursor_word = inputUtil.clean_selected_text(selected_or_cursor_word)

  local curr_buffer_path = vim.fn.expand "%:p:h"
  local paths_to_try = {
    selected_or_cursor_word,
    vim.fn.expand "<cfile>",
    curr_buffer_path .. "/" .. vim.fn.expand "<cfile>",
    curr_buffer_path .. "/" .. selected_or_cursor_word,
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
    vim.fn.jobstart { "open", dir_path }
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

keymap("n", "gGO", function()
  require("utils.open_external").pick_current()
end, { desc = "Open current file/dir in external app picker" })

keymap({ "n", "v" }, "gF", function()
  myPathUtil.goto_file_line(false)
end, { desc = "Go to file+line" })

keymap({ "n", "v" }, "gB", function()
  myPathUtil.goto_file_line(true)
end, { desc = "Go to file+line" })

keymap({ "n", "v" }, "gX", function()
  local url_or_word = url_repo()
  -- copy to register + if not empty
  -- if extension is in .log or .xlsx or .pdf .powerpoint .docx ,... use normal open function
  local normal_ext_open = vim.fn.match(url_or_word, [[\.\(log\|pdf\|docx\|pptx\|xlsx\)$]]) > -1
  -- use one regex matcher

  local callback = nil
  local command_run = nil
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
        run_command { open_command, url_or_word }
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
local quickfixAndTroubleGroup = augroup "QuickfixAndTroubleMappings"

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
  local command_sh_add_line_check_exist = "echo '"
    .. table.concat(files, " ")
    .. '\' | xargs -I {} sh -c \'if [ -f {} ]; then echo "" >> "{}"; else echo "File does not exist: {}"; fi\''

  print [==[ Add line ]==] -- __AUTO_GENERATED_PRINT_VAR_END__
  print(command_sh_add_line_check_exist) -- __AUTO_GENERATED_PRINT_VAR_END__
  -- print remove_newline (revert )
  local command_sh_remove_newline = "echo '"
    .. table.concat(files, " ")
    .. '\' | xargs -n 1 -I {} sh -c \'if [ -f {} ]; then sed -i "" "\\$d" "{}"; else echo "File does not exist: {}"; fi\''
  print [==[ Remove line ]==]
  print(command_sh_remove_newline)
  -- print([==[ files:]==], vim.inspect(files)) -- __AUTO_GENERATED_PRINT_VAR_END__
  -- copy files into clipboard split by new line / if want same line can paste in spotlight
  vim.fn.setreg("+", table.concat(files, "\n"))
  vim.notify(" ~ Copied " .. #files .. " files to clipboard", vim.log.levels.INFO)
end

local function open_qflist_in_vscode()
  local files = get_qf_files()
  if #files == 0 then
    print "No files in quickfix list."
    return
  end
  local cmd = "code " .. table.concat(files, " ")
  print "~ Opening files in VSCode with cmd:"
  print(cmd)
  vim.fn.jobstart(cmd, { detach = true })
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "AvanteInput", "codecompanion" },
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
vim.keymap.set({ "n", "v", "i" }, "<C-i><C-v>", function()
  local pasted_image = require("img-clip").paste_image()
  if pasted_image then
    -- "Update" saves only if the buffer has been modified since the last save
    vim.cmd "update"
    print "Image pasted and file saved"
    -- Only if updated I'll refresh the images by clearing them first
    -- I'm using [[ ]] to escape the special characters in a command
    vim.cmd [[lua require("image").clear()]]
    -- Reloads the file to reflect the changes
    vim.cmd "edit!"
    -- Switch back to command mode
    vim.cmd "stopinsert"
  else
    print "No image pasted. File not updated."
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
    image_path = image_path or myPathUtil.getFullPathFromRelativePath(vim.fn.expand "<cfile>")
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
      print "URL image, use 'gx' to open it in the default browser."
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
    print "No image found under the cursor"
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
      print "URL image, use 'gx' to open it in the default browser."
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
    print "No image found under the cursor"
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
      if vim.fn.executable "trash" == 0 then
        vim.api.nvim_echo({
          { "- Trash utility not installed. Make sure to install it first\n", "ErrorMsg" },
          { "- In macOS run `brew install trash`\n", nil },
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
            vim.fn.system { "trash", vim.fn.fnameescape(absolute_image_path) }
          end)

          if success then
            vim.api.nvim_echo({
              { "Image file deleted from disk:\n", "Normal" },
              { absolute_image_path, "Normal" },
            }, false, {})
            -- I'll refresh the images, but will clear them first
            -- I'm using [[ ]] to escape the special characters in a command
            -- vim.cmd([[lua require("image").clear()]]) -- no need since cause issue
            -- Reloads the file to reflect the changes
            vim.cmd "edit!"
          else
            vim.api.nvim_echo({
              { "Failed to delete image file:\n", "ErrorMsg" },
              { absolute_image_path, "ErrorMsg" },
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

  vim.notify("set lsp_format to: " .. vim.g.lsp_format_mode, vim.log.levels.INFO)
end

--@params
---@param timeout_ms integer|nil timeout in milliseconds
---@param isasync boolean|nil specify if formatting is async
---@param formatter table|nil specify formatter(s) to use
---@param auto_expand_visual boolean|nil whether to expand visual selection
local function confformat(timeout_ms, isasync, formatter, auto_expand_visual)
  local conform = require "conform"
  local is_selected = false
  if auto_expand_visual ~= nil then
    is_selected = auto_expand_visual
  else
    local is_visual = vim.fn.mode()
    is_selected = is_visual == "v" or is_visual == "V" or is_visual == "\22"
  end
  -- select down one more line else the last line will not be formatted ??
  local start_pos = vim.fn.getpos "'<"
  local end_pos = vim.fn.getpos "'>"

  if is_selected then
    -- vim.cmd("normal! gvg")
    vim.cmd "normal! gv"
    vim.cmd "normal! j"
  end
  conform.format({ async = isasync or false, timeout_ms = timeout_ms or 5000, formatter = formatter }, function(err)
    if not err then
      vim.cmd ":noautocmd w"
    end
    if vim.startswith(string.lower(vim.fn.mode()), "v") then
      print "stop v mode"
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", true)
      inputUtil.restore_visual_selection(start_pos, end_pos)
    end
  end)
end

local function select_and_format()
  local conform = require "conform"
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

  local is_visual = vim.fn.mode()
  local is_selected = is_visual == "v" or is_visual == "V" or is_visual == "\22"

  vim.ui.select(items, { prompt = "Select formatter:" }, function(choice)
    if choice then
      confformat(nil, false, { choice }, is_selected)
      -- conform.format({ formatters = { choice }, async = false, bufnr = bufnr })
      -- conform.format({ formatters = { choice }, async = false })
      -- save after format without triggering autocmd
      -- vim.cmd(":noautocmd w")
      vim.notify("Formatted with: " .. choice, vim.log.levels.INFO)
    end
  end)
end

-- 3. Map shortcut
--
-- Global format toggle
vim.keymap.set("n", "<localleader>Fd", function()
  vim.cmd "FormatDisable"
end, { desc = "Disable Auto Format (Global)" })
vim.keymap.set("n", "<localleader>Fe", function()
  vim.cmd "FormatEnable"
end, { desc = "Enable Auto Format (Global)" })
-- override current command to make FormatEnable also work on buffer

vim.keymap.set("n", "<localleader>FT", function()
  -- Buffer-local autoformat toggle
  vim.b.disable_autoformat = not vim.b.disable_autoformat
  if vim.b.disable_autoformat then
    vim.print "Autoformat disabled for this buffer"
  else
    vim.print "Autoformat enabled for this buffer"
  end
end, { desc = "Toggle Autoformat (Buffer)" })
-- Buffer-local format toggle
vim.keymap.set("n", "<localleader>FD", function()
  vim.cmd "FormatDisable!"
  vim.notify("Autoformat disabled for this buffer", vim.log.levels.INFO)
end, { desc = "Disable Auto Format (Buffer)" })
vim.keymap.set("n", "<localleader>FE", function()
  vim.b.disable_autoformat = false
  vim.notify("Autoformat enabled for this buffer", vim.log.levels.INFO)
end, { desc = "Enable Auto Format (Buffer)" })
vim.keymap.set("n", "<localleader>Ft", function()
  local auto_format = vim.g.disable_autoformat ~= nil and not vim.g.disable_autoformat or false
  if auto_format then
    vim.cmd "FormatEnable"
  else
    vim.cmd "FormatDisable"
  end
  vim.notify("Auto format " .. (auto_format and "enabled" or "disabled"), vim.log.levels.INFO)
end, { desc = "Toggle Autoformat (Global)" })

vim.keymap.set("n", "<leader>uFt", toggle_lsp_format_mode, { desc = "Toggle LSP Format Mode (prefer/fallback)" })
vim.keymap.set("n", "<localleader>FT", toggle_lsp_format_mode, { desc = "Toggle LSP Format Mode (prefer/fallback)" })
-- vim.keymap.set("n", "<leader>uFT", function() toggle_lsp_format_mode(true) end, { desc = "Toggle LSP Format Mode" })
vim.keymap.set("n", "<leader>uFS", select_and_format, { desc = "Select Formatter to Run" })
vim.keymap.set("", "<localleader>FS", select_and_format, { desc = "Select Formatter to Run" })
vim.keymap.set("n", "<leader>uFf", confformat, { desc = "Format" })
vim.keymap.set("", "<localleader>Ff", confformat, { desc = "Format" })
vim.keymap.set("n", "<leader>uFF", function()
  confformat(10000, true)
end, { desc = "Async Format" })
vim.keymap.set("", "<localleader>FF", function()
  confformat(10000, true)
end, { desc = "Async Format" })
vim.keymap.set("n", "<leader>uFs", ":noautocmd w<CR>", { desc = "Save No Format / C-S-s" })
vim.keymap.set("", "<localleader>Fs", ":noautocmd w<CR>", { desc = "Save No Format" })
vim.keymap.set({ "i", "n" }, "<C-S-s>", ":noautocmd w<CR>", { desc = "Save No Format" })

-- From docs : https://github.com/stevearc/conform.nvim/blob/master/doc/recipes.md#leave-visual-mode-after-range-format
vim.keymap.set("", "<localleader>ff", function()
  require("conform").format({ async = true }, function(err)
    if not err then
      local mode = vim.api.nvim_get_mode().mode
      if vim.startswith(string.lower(mode), "v") then
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", true)
      end
    end
  end)
end, { desc = "Format code" })

-- Special remaps keys
-- Ghostty remapped in ~/dotfiles/.config/ghostty/config:80
-- tested in ghostty non tmux + refresh  (required ghostty remap all works except C-S-A-Tab)
-- vim.keymap.set("n", "<C-Tab>", ":echo C-Tab", { desc = "Test map C-Tab" })             -- seems to work
-- vim.keymap.set("n", "<S-Tab>", ":echo S-Tab", { desc = "Test map S-Tab" })             -- seems to work
-- vim.keymap.set("n", "<C-S-Tab>", ":echo C-S-Tab", { desc = "Test map C-S-Tab" })       -- seems to work
-- vim.keymap.set("n", "<S-A-Tab>", ":echo S-A-Tab", { desc = "Test map S-A-Tab" })       -- seems to work
-- -- no work yet
-- vim.keymap.set("n", "<C-S-A-Tab>", ":echo C-S-A-Tab", { desc = "Test map C-S-A-Tab" }) -- need remap ?

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
  local ok, err
  ok, err = pcall(function()
    vim.cmd "autocmd! TermOpen term://* lua set_toggleterm_keymaps()"
    vim.api.nvim_del_keymap("i", "<A-j>")
    vim.api.nvim_del_keymap("i", "<A-k>")
    vim.api.nvim_del_keymap("n", "<C-c>")
  end)
  if not ok then
    vim.notify("Error in toggleterm setup: " .. tostring(err), vim.log.levels.WARN)
  end
  -- bufferline.nvim once sort need it's own fn's
  -- but this load after lazy ?
  -- vim.api.nvim_del_keymap("n", "<S-h>")
  -- vim.api.nvim_del_keymap("n", "<S-l>")
end
-- GLOBAL
function _G.userdbg(...)
  return require("utils.user_debug").dbg(...)
end

vim.api.nvim_create_user_command("UserToggleDebug", function()
  require("utils.user_debug").toggle()
  vim.print("User debug mode: " .. tostring(require("utils.user_debug").is_enabled()))
end, { desc = "Toggle user debug mode" })

-- OVERRIDE MAP ==========================
keymap("n", "zj", "zj")
keymap("n", "zk", "zk")

-- ===============================================
-- PROMPT HELPER - Load and paste custom prompts
-- ===============================================

-- Paste prompt at cursor position
keymap("n", "<localleader>aP", function()
  local prompts_helper = require "utils.prompts_helper"
  prompts_helper.select_and_paste_prompt { paste_mode = "cursor" }
end, { desc = "Paste prompt at cursor" })

-- ===============================================
-- STARTUP / WORKSPACE COMMANDS
-- ===============================================

require("utils.workspace_all").setup()

-- Shell alias commands: these user commands replace complex inline Lua/vimscript
-- in shell aliases so that `ps` shows a clean command like `nvim -c SessionSelect`
-- instead of raw Lua with parens that break tmux-resurrect replay.

-- vq: persistence.nvim session picker with PWD auto-fill
vim.api.nvim_create_user_command("SessionSelect", function()
  local function run()
    local ok, p = pcall(require, "persistence")
    if not (ok and p and p.select) then
      return
    end
    p.select()
    local pwd = vim.env.PWD or ""
    local home = vim.env.HOME or ""
    if home ~= "" and pwd:sub(1, #home) == home then
      pwd = "~" .. pwd:sub(#home + 1)
    end
    vim.api.nvim_feedkeys(pwd, "t", false)
  end
  if vim.g.lazy_did_setup then
    vim.schedule(run)
  else
    vim.api.nvim_create_autocmd("User", {
      pattern = "LazyDone",
      once = true,
      callback = function()
        vim.schedule(run)
      end,
    })
  end
end, { desc = "Session picker with PWD auto-fill (for vq alias)" })

-- v: load last persistence session
vim.api.nvim_create_user_command("SessionLoadLast", function()
  local ok, p = pcall(require, "persistence")
  if ok and p and p.load then
    p.load { last = true }
  end
end, { desc = "Load last persistence session (for v alias)" })

-- vd: load last persistence session if exist else select
vim.api.nvim_create_user_command("SessionCurrentDir", function()
  -- Confirm to restore the session for the current working directory.
  local ok, persistence = pcall(require, "persistence")
  if not ok then
    vim.notify("persistence.nvim is not available", vim.log.levels.ERROR)
    return
  end

  -- local choice = vim.fn.confirm("Restore session for current directory?", "&Yes\n&Select session...\n&No", 1)
  -- Load session for current directory if it exists, otherwise fall back to selection.
  local session_file = persistence.current()
  if session_file and session_file ~= "" and vim.fn.filereadable(session_file) == 1 then
    persistence.load()
  else
    vim.print "No session found for current directory. Select a session ..."
    persistence.select()
    -- insert text into input of current cwd, use ~ for $HOME
    vim.api.nvim_feedkeys(
      vim.api.nvim_replace_termcodes(
        "<C-r>=substitute(expand('%:p:h'), '^'.escape($HOME, '/'), '~', '')<CR>",
        true,
        false,
        true
      ),
      "n",
      true
    )
  end
end, { desc = "Load last persistence session (for v alias)" })

-- Shell alias commands: these user commands replace complex inline Lua/vimscript
-- in shell aliases so that `ps` shows a clean command like `nvim -c SessionSelect`
-- instead of raw Lua with parens that break tmux-resurrect replay.

-- vq: persistence.nvim session picker with PWD auto-fill
vim.api.nvim_create_user_command("SessionSelect", function()
  local function run()
    local ok, p = pcall(require, "persistence")
    if not (ok and p and p.select) then
      return
    end
    p.select()
    local pwd = vim.env.PWD or ""
    local home = vim.env.HOME or ""
    if home ~= "" and pwd:sub(1, #home) == home then
      pwd = "~" .. pwd:sub(#home + 1)
    end
    vim.api.nvim_feedkeys(pwd, "t", false)
  end
  if vim.g.lazy_did_setup then
    vim.schedule(run)
  else
    vim.api.nvim_create_autocmd("User", {
      pattern = "LazyDone",
      once = true,
      callback = function()
        vim.schedule(run)
      end,
    })
  end
end, { desc = "Session picker with PWD auto-fill (for vq alias)" })

-- v: load last persistence session
vim.api.nvim_create_user_command("SessionLoadLast", function()
  local ok, p = pcall(require, "persistence")
  if ok and p and p.load then
    p.load { last = true }
  end
end, { desc = "Load last persistence session (for v alias)" })

-- vs: open FzfSession picker after startup
vim.api.nvim_create_user_command("FzfSessionDelayed", function()
  vim.fn.timer_start(200, function()
    vim.cmd [[execute "normal \<Esc>:FzfSession\<CR>"]]
  end)
end, { desc = "Open FzfSession picker with delay (for vs alias)" })
