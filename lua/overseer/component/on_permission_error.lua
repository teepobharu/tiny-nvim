---@type overseer.ComponentFileDefinition
return {
  desc = "Detect permission errors and notify with fix command",
  params = {
    auto_chmod = {
      desc = "Auto chmod +x the file and notify (does not auto-retry)",
      type = "boolean",
      default = false,
    },
  },
  constructor = function(params)
    return {
      detected = false,
      on_output_lines = function(self, task, lines)
        if self.detected then
          return
        end
        for _, line in ipairs(lines) do
          -- Match common permission error patterns
          if line:match("Permission denied") or line:match("permission denied") or line:match("EACCES") then
            self.detected = true
            -- Try to extract the file path from the error
            local denied_file = line:match(":%s*(.-):%s*[Pp]ermission denied") or line:match("open '(.-)'") or ""

            if params.auto_chmod and denied_file ~= "" then
              local chmod_ok = os.execute(string.format("chmod +x %q", denied_file))
              if chmod_ok then
                vim.notify(string.format("Auto-fixed: chmod +x %s\nRerun with <leader>or", denied_file), vim.log.levels.INFO)
              else
                vim.notify(
                  string.format(
                    "Permission denied: %s\nchmod failed - check ownership:\n  ls -la %s\n  sudo chmod +x %s",
                    denied_file,
                    denied_file,
                    denied_file
                  ),
                  vim.log.levels.ERROR
                )
              end
            else
              vim.notify(
                string.format(
                  "Permission denied%s\nFix: chmod +x <file> then rerun with <leader>or",
                  denied_file ~= "" and (": " .. denied_file) or ""
                ),
                vim.log.levels.WARN
              )
            end
            return
          end

          -- Also detect "command not found" (exit code 127)
          if line:match("command not found") or line:match("No such file or directory") then
            self.detected = true
            local missing_cmd = line:match("(%S+):%s*command not found") or line:match("(%S+):%s*No such file") or ""
            vim.notify(
              string.format(
                "Command not found%s\nCheck: which %s\nOr install the required tool.",
                missing_cmd ~= "" and (": " .. missing_cmd) or "",
                missing_cmd
              ),
              vim.log.levels.WARN
            )
            return
          end
        end
      end,
    }
  end,
}
