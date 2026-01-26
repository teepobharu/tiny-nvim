
-- command to test
BASHCMD=[[
```sh
Without runtimepath cant resolve in clean mode

when run with clean normally not run init.lua automatically 
- issue = not run init.lua automatically 
- issue = no resolution
alias vc='nvim --clean -c "set rtp+=$XDG_CONFIG_HOME/$NVIM_APPNAME" -c "lua require(\"config.mykeymaps\")"'

when run with noplugin issue = below no keymaps also
alias vcc='nvim --clean -c "set rtp+=$XDG_CONFIG_HOME/$NVIM_APPNAME"'

```
]]

-- Q: once started and require later this flag will be empty ? 
-- A: still persisted example: { "nvim", "--embed", "--clean", "-c", "set rtp+=/Users/tharutaipree/.config/nvim3_jelly_tinynvim" }
local is_noplugin = false
for _, arg in ipairs(vim.v.argv) do
  print([==[for arg:]==], vim.inspect(vim.v.argv)) -- __AUTO_GENERATED_PRINT_VAR_END__
  if arg == "--noplugin" or arg == "--clean" then
    is_noplugin = true
    break
  end
end

if is_noplugin then
  print("Started with --noplugin or --clean")
  -- ~/.vimrc  
  --
  -- source ~/.vim.rc
  function ImportVimRC()
    vim.cmd('source ~/.vimrc')
  end
  local ok, err = pcall(importvimrc)
  if not ok then
    vim.notify('Failed to import vimrc: ' .. tostring(err), vim.log.levels.WARN)
  end

-- Usage: call ImportVimRC() to source your vim.rc file
  -- use default statuscolumn settings (currently use snacks)
  vim.opt.statuscolumn = ""
  -- Disable specific logic here
  -- Simple keymap for clean version 
  vim.keymap.set('n', '<leader>vc', ':!nvim --clean -c "set rtp+=$XDG_CONFIG_HOME/$NVIM_APPNAME" -c "lua require(\\"config.mykeymaps\\")"<CR>', { noremap = true, silent = true, desc = "Start Neovim clean with mykeymaps" })

  -- output record vim :messages output to new temp buffer
  vim.keymap.set('n', '<leader>dm', function()
    vim.cmd('new')
    local messages = vim.api.nvim_exec2('messages', { output = true }).output
    vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(messages, '\n'))
  end, { noremap = true, silent = true, desc = "Open messages in new buffer" })

  -- descding output
  vim.keymap.set('n', '<leader>dM', function()
    vim.cmd('new')
    local messages = vim.api.nvim_exec2('messages', { output = true }).output
    local lines = vim.split(messages, '\n')
    table.sort(lines, function(a, b) return a > b end) -- sort descending
    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  end, { noremap = true, silent = true, desc = "Open messages in new buffer (sorted desc)" })

end
