-- Custom overseer actions and enhanced task list configuration
local M = {}

---Custom actions for overseer tasks
---@return table<string, overseer.Action>
M.actions = {
  ["duplicate task"] = {
    desc = "Clone and restart the task as a new task",
    condition = function(task)
      return task.status ~= "PENDING"
    end,
    run = function(task)
      local new_task = task:clone()
      -- Give the duplicate a distinct name
      new_task.name = task.name .. " (copy)"
      -- Add to task list and start
      require("overseer.task_list").touch(new_task)
      new_task:start()
    end,
  },
  -- Clone the task, open the editor on the clone so cmd/name can be changed, then start on save
  ["edit and run as new task"] = {
    desc = "Clone task, edit its command/name, then run as a new task",
    run = function(task)
      local new_task = task:clone()
      new_task.name = task.name .. " (copy)"
      require("overseer.task_list").touch(new_task)
      require("overseer.task_editor").open(new_task, function(edited)
        if edited then
          edited:start()
        else
          -- user cancelled — remove the pending clone from the list
          new_task:dispose(true)
        end
      end)
    end,
  },
  ["copy task command"] = {
    desc = "Copy the task command to clipboard",
    condition = function(task)
      return task.cmd ~= nil
    end,
    run = function(task)
      local cmd = task.cmd
      local cmd_str = type(cmd) == "string" and cmd or table.concat(cmd, " ")
      vim.fn.setreg("+", cmd_str)
      vim.notify("Copied to clipboard: " .. cmd_str, vim.log.levels.INFO)
    end,
  },
  ["copy task name"] = {
    desc = "Copy the task name to clipboard",
    run = function(task)
      vim.fn.setreg("+", task.name)
      vim.notify("Copied task name: " .. task.name, vim.log.levels.INFO)
    end,
  },
}

---Enhanced render function with status icons and key hints
---@param task overseer.Task
---@return overseer.TextChunk[][]
M.render_with_status = function(task)
  local render = require("overseer.render")

  -- Status icons
  local status_icons = {
    PENDING = "󰐪 ",
    RUNNING = "󰐠 ",
    SUCCESS = " ",
    FAILURE = " ",
    CANCELED = "󰃔 ",
    DISPOSED = "󰆴 ",
  }

  local icon = status_icons[task.status] or ""
  local status_hl = "Overseer" .. task.status

  -- Build the status line with icon
  local status_line = {
    { icon .. task.name, status_hl },
  }

  -- Add source info if available
  local ret = { status_line }
  vim.list_extend(ret, render.source_lines(task))

  -- Duration and time info
  table.insert(
    ret,
    render.join(render.duration(task), render.time_since_completed(task, { hl_group = "Comment" }))
  )

  -- Result info
  vim.list_extend(ret, render.result_lines(task, { oneline = true }))

  -- Last line of output
  vim.list_extend(ret, render.output_lines(task, { num_lines = 1 }))

  return render.remove_empty_lines(ret)
end

---Key hints to show in the task list footer
M.key_hints = {
  { key = "<CR>", desc = "Actions" },
  { key = "<A-d>", desc = "Duplicate" },
  { key = "A", desc = "Edit+run copy" },
  { key = "y", desc = "Copy cmd" },
  { key = "Y", desc = "Copy name" },
  { key = "a", desc = "Edit" },
  { key = "<C-r>", desc = "Restart" },
  { key = "<C-c>", desc = "Stop" },
  { key = "dd", desc = "Dispose" },
  { key = "q", desc = "Close" },
}

return M
