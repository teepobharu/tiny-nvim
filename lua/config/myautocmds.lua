-- MY AUTO COMMANDS -----
local M = {}

local function POC()
  -- Add current location to quickfix list
  function M.AddLocationToQuickfixList()
    local current_location = {
      pattern = "",
      valid = 1,
      vcol = 0,
      nr = 0,
      module = "",
      type = "",
      bufnr = vim.fn.bufnr "%",
      lnum = vim.fn.line ".",
      end_lnum = vim.fn.line ".",
      col = 1,
      end_col = vim.fn.len(vim.fn.getline ".") + 1,
      text = vim.fn.trim(vim.fn.getline "."),
    }

    local qflist = vim.fn.getqflist()
    local exists = false
    for _, item in ipairs(qflist) do
      if vim.deep_equal(item, current_location) then
        exists = true
        break
      end
    end

    if not exists then
      vim.cmd "copen"
      table.insert(qflist, current_location)
      vim.fn.setqflist(qflist, "r")
    end
  end

  -- Check if current window is a location list
  function M.WindowIsLocationList()
    local wininfo = vim.fn.getwininfo(vim.fn.win_getid())[1]
    local qfvar = wininfo.quickfix
    local llvar = wininfo.loclist
    return llvar == 1 and qfvar == 1
  end

  -- Check if current window is a quickfix list
  function M.WindowIsQuickfixList()
    local wininfo = vim.fn.getwininfo(vim.fn.win_getid())[1]
    local qfvar = wininfo.quickfix
    local llvar = wininfo.loclist
    return llvar == 0 and qfvar == 1
  end

  -- Check if current window is a list (quickfix or location)
  function M.WindowIsList()
    return M.WindowIsLocationList() or M.WindowIsQuickfixList()
  end

  -- Update the quickfix or location list based on user edits
  function M.UpdateList()
    -- Determine whether the current list is a location list or quickfix list
    local list_type
    if M.WindowIsLocationList() then
      list_type = "location"
    elseif M.WindowIsQuickfixList() then
      list_type = "quickfix"
    else
      return
    end

    -- Save the current cursor line number
    local iniline = vim.fn.line "."

    -- Get the current list
    local old_list = list_type == "location" and vim.fn.getloclist(0) or vim.fn.getqflist()

    -- Get all lines from the current window
    local window_text = vim.api.nvim_buf_get_lines(0, 0, -1, false)

    -- Build a new list based on what's still visible in the window
    local new_list = {}

    for _, list_item in ipairs(old_list) do
      -- Get buffer name
      local buffer_name = vim.fn.bufname(list_item.bufnr)

      -- Format line numbers
      local line_numbers
      local line_numbers2
      if list_item.end_lnum and list_item.end_lnum > 0 and list_item.end_lnum ~= list_item.lnum then
        line_numbers = tostring(list_item.lnum) .. "-" .. tostring(list_item.end_lnum)
        line_numbers2 = tostring(list_item.lnum)
      else
        line_numbers = tostring(list_item.lnum)
        line_numbers2 = tostring(list_item.lnum) .. "-" .. tostring(list_item.end_lnum)
      end
      local column_numbers = tostring(list_item.col) .. "-" .. tostring(list_item.end_col)
      local preview_text = vim.fn.trim(list_item.text or "")

      -- Format column numbers
      local column_numbers = tostring(list_item.col) .. "-" .. tostring(list_item.end_col)

      -- Get preview text
      local preview_text = vim.fn.trim(list_item.text or "")

      -- Build display text
      local display_text = buffer_name .. "|" .. line_numbers .. " col " .. column_numbers .. "| " .. preview_text
      local display_text2 = buffer_name .. "|" .. line_numbers2 .. " col " .. column_numbers .. "| " .. preview_text

      -- DO NOT REMOVE THESE INFO comments : Sample format of a quickfix/location list window line (what window_text contains):
      --   /absolute/path/to/file.lua|12-15 col 3-20| preview text of the line
      -- Or for a single line/column entry:
      --   /absolute/path/to/file.lua|42 col 7-7| preview text of the line
      -- Where:
      --   buffer_name    = /absolute/path/to/file.lua
      --   line_numbers   = "12-15" (range) or "42" (single line)
      --   column_numbers = "3-20" (range) or "7-7" (single column)
      --   preview_text   = trimmed text for the item
      -- The code below checks if display_text is present in the current list window lines to determine if the item still exists.

      -- sample qflist - old_list: { {
      --   bufnr = 15,
      --   col = 1,
      --   end_col = 0,
      --   end_lnum = 0,
      --   lnum = 1,
      --   module = "",
      --   nr = 0,
      --   pattern = "",
      --   text = "/Users/tharutaipree/dotfiles/.config/raycast/myscript/devtools/ag_registryrepo.sh",
      --   type = "",
      --   valid = 1,
      --   vcol = 0
      -- }
      -- }

      -- Check if the item exists in the current window text
      local found = false
      for _, line in ipairs(window_text) do
        if line == display_text then
          found = true
          break
        end
      end

      if found then
        table.insert(new_list, list_item)
      end
    end

    -- Update the list
    if list_type == "location" then
      vim.fn.setloclist(0, new_list, "r")
    else
      vim.fn.setqflist(new_list, "r")
    end

    -- Restore the cursor position
    vim.api.nvim_win_set_cursor(0, { iniline, 0 })

    -- Make sure the list is modifiable
    vim.bo.modifiable = true
  end

  -- Helper function to close quickfix or location list
  local function close_qf_or_loclist()
    local ft = vim.bo.filetype
    if ft == "qf" then
      vim.cmd "cclose"
    elseif ft == "lqf" or ft == "loclist" then
      vim.cmd "lclose"
    else
      print "Not a quickfix or location list buffer"
    end
  end

  -- Autocommands
  vim.api.nvim_create_autocmd("BufWinEnter", {
    pattern = "*",
    callback = function()
      if M.WindowIsList() then
        vim.bo.modifiable = true
      end
    end,
  })

  vim.api.nvim_create_autocmd("TextChanged", {
    pattern = "*",
    callback = function()
      if M.WindowIsList() then
        M.UpdateList()
      end
    end,
  })

  -- Set buffer-local keymap for qf and location list buffers
  vim.api.nvim_create_autocmd("FileType", {
    pattern = { "qf", "lqf", "loclist" },
    callback = function()
      vim.keymap.set("n", "<leader>qQ", close_qf_or_loclist, { buffer = true, silent = true })
      vim.keymap.set("n", "<C-s>", M.UpdateList, { buffer = true })
    end,
  })
end

--#region: use case switch open selected link in previous buffer:
--vim.api.nvim_create_autocmd("WinEnter", {
vim.api.nvim_create_autocmd("WinEnter", {
  callback = function()
    vim.g.prev_win = vim.g.current_win
    vim.g.current_win = vim.api.nvim_get_current_win()
  end,
})

--

return M
