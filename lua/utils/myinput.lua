-- Clipboard utility for copying to system clipboard
-- Supports multiple copy modes: system clipboard (+), unnamed register, or both
local M = {}

---@enum CopyMode
local CopyMode = {
  PLUS = "plus", -- Copy to + register (system clipboard)
  UNNAMED = "unnamed", -- Copy to unnamed register (normal yank)
  BOTH = "both", -- Copy to both + and unnamed registers
}

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
