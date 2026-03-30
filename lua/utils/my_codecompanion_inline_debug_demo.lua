local M = {}

local LOG_FILE = vim.fn.stdpath "state" .. "/codecompanion-inline-debug.log"

local function append_log(message)
  local timestamp = os.date "%Y-%m-%d %H:%M:%S"
  vim.fn.writefile({ string.format("%s %s", timestamp, message) }, LOG_FILE, "a")
end

local function patch_inline_model_override()
  local ok, Inline = pcall(require, "codecompanion.interactions.inline")
  if not ok or type(Inline) ~= "table" then
    return false, "inline module not available"
  end
  if Inline.__agd_inline_model_override_patched then
    return true
  end
  if type(Inline.parse_special_syntax) ~= "function" then
    return false, "inline parse_special_syntax is not a function"
  end

  local original_parse_special_syntax = Inline.parse_special_syntax

  ---@diagnostic disable-next-line: duplicate-set-field
  function Inline:parse_special_syntax(prompt)
    prompt = original_parse_special_syntax(self, prompt)

    local model_pattern = "model=([^%s]+)"
    local model_match = prompt:match(model_pattern)
    if model_match and self.adapter and self.adapter.schema and self.adapter.schema.model then
      self.adapter.schema.model.default = model_match
      append_log(
        string.format("[InlineModelOverride] adapter=%s model=%s", self.adapter.name or "unknown", model_match)
      )
      prompt = vim.trim(prompt:gsub(model_pattern, "", 1))
    end

    return prompt
  end

  Inline.__agd_inline_model_override_patched = true
  return true
end

local function setup_event_debug()
  local group = vim.api.nvim_create_augroup("CodeCompanionInlineDebugDemo", { clear = true })
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = {
      "CodeCompanionRequestStarted",
      "CodeCompanionRequestFinished",
      "CodeCompanionInlineStarted",
      "CodeCompanionInlineFinished",
    },
    callback = function(event)
      local data = event.data or {}
      local adapter = data.adapter or {}
      append_log(
        string.format(
          "[%s] adapter=%s model=%s id=%s",
          event.match or "User",
          adapter.name or "-",
          adapter.model or "-",
          data.id or "-"
        )
      )
    end,
  })
end

local function setup_commands()
  if vim.fn.exists ":CodeCompanionInlineDebugStatus" == 0 then
    vim.api.nvim_create_user_command("CodeCompanionInlineDebugStatus", function()
      local ok, Inline = pcall(require, "codecompanion.interactions.inline")
      local patched = ok and type(Inline) == "table" and Inline.__agd_inline_model_override_patched == true
      local status = string.format("inline model override patch active=%s log=%s", tostring(patched), LOG_FILE)
      append_log("[Status] " .. status)
      vim.notify(status, vim.log.levels.INFO, { title = "CodeCompanion Debug" })
    end, {
      desc = "Show inline model override patch status",
    })
  end
end

function M.setup()
  if vim.g.codecompanion_inline_debug_demo_loaded then
    return
  end
  vim.g.codecompanion_inline_debug_demo_loaded = true

  setup_event_debug()

  local ok, err = patch_inline_model_override()
  if ok then
    append_log "[Setup] inline model override patch enabled"
  else
    append_log("[Setup] inline model override patch failed: " .. tostring(err))
  end

  setup_commands()
end

return M
