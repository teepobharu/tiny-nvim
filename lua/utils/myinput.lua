-- Clipboard utility for copying to system clipboard
-- Supports multiple copy modes: system clipboard (+), unnamed register, or both
local M = {}

---@enum CopyMode
local CopyMode = {
  PLUS = "plus", -- Copy to + register (system clipboard)
  UNNAMED = "unnamed", -- Copy to unnamed register (normal yank)
  BOTH = "both", -- Copy to both + and unnamed registers
}

---Copy current line to system clipboard
---@param warn boolean Whether to show a notification
function M.copy_yank_to_system(warn)
  vim.cmd "let @* = @0" -- Transfer last yank ("0 register) to system clipboard ("* register)
  -- vim.cmd 'normal! "+yy'
  if warn then
    local textLength = vim.fn.strlen(vim.fn.getreg "*")
    local truncCenterText = textLength > 20 and "..." or ""
    local reg = vim.fn.getreg "*"
    local centerText = vim.fn.strpart(reg, 0, 10)
    local endText = vim.fn.strpart(reg, #reg - 10, 10)
    local result = centerText .. truncCenterText .. endText
    vim.notify("Copied text to system clipboard: " .. result, vim.log.levels.INFO)
  end
end

---Copy text to system clipboard using specified mode
---@param text string The text to copy
---@param mode? "plus"|"unnamed"|"both" Copy mode (default: "plus")
---@return boolean success Whether the copy was successful
function M.copy_to_clipboard(text, mode)
  if not text or text == "" then
    vim.notify("No text to copy", vim.log.levels.WARN)
    return false
  end

  mode = mode or CopyMode.PLUS

  local success = true

  if mode == CopyMode.PLUS or mode == CopyMode.BOTH then
    -- Copy to system clipboard register (+)
    vim.fn.setreg("+", text)
    -- Also try * register for primary selection (macOS/X11)
    pcall(vim.fn.setreg, "*", text)
  end

  if mode == CopyMode.UNNAMED or mode == CopyMode.BOTH then
    -- Copy to unnamed register (default yank register)
    vim.fn.setreg('"', text)
  end

  return success
end

---Copy text with visual feedback
---@param text string The text to copy
---@param mode? "plus"|"unnamed"|"both" Copy mode (default: "plus")
---@param message? string Custom message (optional)
function M.copy_and_notify(text, mode, message)
  mode = mode or CopyMode.PLUS

  if M.copy_to_clipboard(text, mode) then
    local mode_name = mode == CopyMode.PLUS and "system clipboard"
      or mode == CopyMode.UNNAMED and "unnamed register"
      or "clipboard + unnamed"

    local msg = message or ("Copied to " .. mode_name)
    vim.notify(msg, vim.log.levels.INFO)
    return true
  end

  return false
end

---Get current copy mode from options or use default
---@param opts? {copy_mode?: string} Options table
---@return string copy_mode The copy mode to use
function M.get_copy_mode(opts)
  if opts and opts.copy_mode then
    return opts.copy_mode
  end
  return CopyMode.PLUS -- default: system clipboard only
end

return M
