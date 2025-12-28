-- Snacks terminal utilities for sending lines/visual selections
-- Similar functionality to ToggleTerm's send_lines_to_terminal

local term_util = require("utils.term_util")
-- done : send with vcount 20251209:17:34:53

local M = {}

-- Get detailed information about a terminal
local function get_terminal_info(terminal)
  local info = {
    terminal = terminal,
    buf = terminal.buf,
    win = terminal.win,
    id = terminal.id or 1, -- Default to 1 if no id
    closed = terminal.closed or false,
    win_valid = false,
    visible_in_current_tab = false,
    tab = nil,
    name = nil,
  }

  -- Check if window is valid
  if terminal.win and vim.api.nvim_win_is_valid(terminal.win) then
    info.win_valid = true

    -- Get the tab page for this window
    info.tab = vim.api.nvim_win_get_tabpage(terminal.win)

    -- Check if it's in the current tab
    local current_tab = vim.api.nvim_get_current_tabpage()
    info.visible_in_current_tab = (info.tab == current_tab)
  end

  -- Get terminal name from buffer or winbar
  if terminal.buf and vim.api.nvim_buf_is_valid(terminal.buf) then
    -- Try to get term_title from buffer variable
    local ok, term_title = pcall(vim.api.nvim_buf_get_var, terminal.buf, 'term_title')
    if ok and term_title then
      info.name = term_title
    else
      info.name = string.format("Terminal %d", info.id)
    end
  end

  return info
end

-- Find the best terminal to use based on visibility and count
local function find_best_terminal(terminals, count)
  if #terminals == 0 then
    return nil
  end

  -- If count is specified, use that terminal (user explicitly chose it)
  if count and count > 0 then
    -- First try to match the explicit count to a terminal's assigned id
    for _, term in ipairs(terminals) do
      -- Match by terminal.id if present
      if term.id and term.id == count then
        return term
      end

      -- Match by buffer variable snacks_terminal.id if present
      if term.buf and vim.api.nvim_buf_is_valid(term.buf) then
        local ok, buf_var = pcall(vim.api.nvim_buf_get_var, term.buf, 'snacks_terminal')
        if ok and buf_var and buf_var.id == count then
          return term
        end
      end
    end

    -- Fallback to positional indexing if no id match found
    local idx = math.min(count, #terminals)
    return terminals[idx]
  end

  -- No count specified - find visible terminal in current tab first
  local current_tab = vim.api.nvim_get_current_tabpage()
  local terminal_infos = {}

  -- Gather info about all terminals
  for i, term in ipairs(terminals) do
    local info = get_terminal_info(term)
    info.index = i
    table.insert(terminal_infos, info)
  end

  -- Priority 1: Visible terminal in current tab
  for _, info in ipairs(terminal_infos) do
    if info.visible_in_current_tab and info.win_valid and not info.closed then
      return info.terminal
    end
  end

  -- Priority 2: Any valid terminal in current tab (even if hidden)
  for _, info in ipairs(terminal_infos) do
    if info.tab == current_tab and not info.closed then
      return info.terminal
    end
  end

  -- Priority 3: First non-closed terminal
  for _, info in ipairs(terminal_infos) do
    if not info.closed then
      return info.terminal
    end
  end

  -- Fallback: First terminal
  return terminals[1]
end

-- Get the current Snacks terminal or create one
local function get_snacks_terminal(count)
  local terminals = require("snacks").terminal.list()

  -- Find an existing terminal or create a new one
  if #terminals > 0 then
    return find_best_terminal(terminals, count)
  else
    -- Create a new terminal only if none exist
    return require("snacks").terminal()
  end
end

-- Send text to Snacks terminal
local function send_to_snacks_terminal(text, count)
  local terminal = get_snacks_terminal(count)

  if not terminal or not terminal.buf then
    vim.notify("No Snacks terminal available", vim.log.levels.ERROR)
    return
  end

  -- Get the terminal channel
  local chan = vim.bo[terminal.buf].channel
  if not chan or chan == 0 then
    vim.notify("Terminal channel not available", vim.log.levels.ERROR)
    return
  end

  -- Send the text to terminal
  vim.fn.chansend(chan, text .. "\n")

  -- Show the terminal if it's hidden
  if terminal.closed or not terminal.win or not vim.api.nvim_win_is_valid(terminal.win) then
    terminal:show()
  end
end

-- Send current line to Snacks terminal
function M.send_current_line(count)
  local line = vim.api.nvim_get_current_line()
  send_to_snacks_terminal(line, count)
end

-- Send all buffer content to Snacks terminal
function M.send_all_lines(count)
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local text = table.concat(lines, "\n")
  send_to_snacks_terminal(text, count)
end

function M.send_previous_selection(count)
  -- previous selected with gv
  local current_win = vim.api.nvim_get_current_win()
  local curr_pos = vim.api.nvim_get_current_cursor and vim.api.nvim_get_current_cursor() or vim.api.nvim_win_get_cursor(current_win)
  vim.cmd("normal! gv")
  local start_pos = vim.fn.getpos("v") -- Use 'v' for visual mode
  local end_pos = vim.fn.getpos(".")   -- Use '.' for current cursor position in visual mode
  local lines = vim.api.nvim_buf_get_lines(0, start_pos[2] - 1, end_pos[2], false)
  local text = table.concat(lines, "\n")
  if #lines == 0 then
    vim.notify("No lines selected", vim.log.levels.WARN)
    return
  end

  -- clear visual
  vim.cmd("normal! \27")
  send_to_snacks_terminal(text, count)

  -- restore window and cursor
  vim.api.nvim_set_current_win(current_win)
  pcall(vim.api.nvim_win_set_cursor, 0, curr_pos)
  vim.cmd("stopinsert")
end

-- Export the send function with count support
function M.send_to_snacks_terminal(text, count)
  -- Capture count at the time of function call
  local terminal_count = count or (vim.v.count > 0 and vim.v.count or nil)
  send_to_snacks_terminal(text, terminal_count)
end

--#region Pickers Docs
-- Pickers sample
-- with format : https://github.com/folke/snacks.nvim/discussions/498
--#endregion

--#region Pickers tmux

local function _get_tmux_windows()
    local windows_raw = vim.fn.system("tmux list-windows -F '#{window_index}: #{window_name}'")
    local windows = {}

    for window in windows_raw:gmatch("[^\r\n]+") do
      table.insert(windows, { text = window })
    end

    return windows
end

function M.pick_tmux_window()
  local windows = _get_tmux_windows()

  Snacks.picker.pick({
    source = "tmux_windows",
    items = windows,
    format = "text",
    layout = {
      preset = "vscode",
    },
    confirm = function(picker, item)
      picker:close()
      local window_index = item.text:match("^(%d+):")
      if window_index then
        vim.fn.system(string.format("tmux select-window -t %s", window_index))
      end
    end,
  })
end

--#endregion

--#region Pickers Git file pick

local function pick_cmd_result(picker_opts)
  local git_root = Snacks.git.get_root()
  local function finder(opts, ctx)
    -- Merge picker_opts into opts for proc
    local proc_opts = vim.tbl_extend("force", opts, {
      cmd = picker_opts.cmd,
      args = picker_opts.args,
      transform = function(item)
        item.cwd = picker_opts.cwd or git_root
        item.file = item.text
      end,
    })

    return require("snacks.picker.source.proc").proc(proc_opts, ctx)
  end

  local pick_opts = {
    source = picker_opts.name,
    finder = finder,
    format = "file",
    title = picker_opts.title,
  }

  -- Use custom preview function if provided
  if picker_opts.preview_fn then
    pick_opts.preview = function(ctx)
      local item = ctx and ctx.item
      if not item then
        return nil
      end

      -- Call preview function safely
      local ok, res = pcall(picker_opts.preview_fn, item, ctx)
      if not ok then
        -- If preview function errored, write the error into the preview buffer if available
        if ctx and ctx.buf and vim.api.nvim_buf_is_valid(ctx.buf) then
          vim.api.nvim_buf_set_option(ctx.buf, "modifiable", true)
          vim.api.nvim_buf_set_lines(ctx.buf, 0, -1, false, {"Preview error:", tostring(res)})
          vim.api.nvim_buf_set_option(ctx.buf, "modifiable", false)
          return true
        end
        return nil
      end

      if not res then
        return nil
      end

      local rtype = type(res)

      -- If preview_fn returned a preview spec table (cmd/args or text/ft), handle accordingly
      if rtype == "table" then
        -- If res is a proc spec (cmd/args), return it directly
        if res.cmd or res.args then
          return res
        end

        -- If res contains text, populate preview buffer if available
        if res.text then
          if ctx and ctx.buf and vim.api.nvim_buf_is_valid(ctx.buf) then
            vim.api.nvim_buf_set_option(ctx.buf, "modifiable", true)
            local lines = vim.split(res.text, "\n")
            vim.api.nvim_buf_set_lines(ctx.buf, 0, -1, false, lines)
            vim.api.nvim_buf_set_option(ctx.buf, "modifiable", false)
            if res.ft then
              vim.bo[ctx.buf].filetype = res.ft
            end
            return true
          else
            -- Return a simple preview spec with text
            return { text = res.text, ft = res.ft }
          end
        end

        -- Otherwise return the table and hope Snacks knows how to handle it
        return res

      elseif rtype == "string" then
        -- Treat string as raw preview text
        if ctx and ctx.buf and vim.api.nvim_buf_is_valid(ctx.buf) then
          vim.api.nvim_buf_set_option(ctx.buf, "modifiable", true)
          vim.api.nvim_buf_set_lines(ctx.buf, 0, -1, false, vim.split(res, "\n"))
          vim.api.nvim_buf_set_option(ctx.buf, "modifiable", false)
          return true
        end
        return { text = res }

      elseif rtype == "boolean" then
        -- Allow explicit boolean returned by preview fn
        return res

      elseif rtype == "function" then
        -- If the preview fn returned a function, call it with ctx
        local ok2, handled = pcall(res, ctx)
        if ok2 then return handled end
        return nil
      end

      return nil
    end
  elseif picker_opts.preview then
    pick_opts.preview = picker_opts.preview
  end

  Snacks.picker.pick(pick_opts)
end

-- Custom Pickers
M.custom_git_pickers = {}

function M.custom_git_pickers.git_show()
  pick_cmd_result {
    cmd = "git",
    args = { "diff-tree", "--no-commit-id", "--name-only", "--diff-filter=d", "HEAD", "-r" },
    name = "git_show",
    title = "Git Last Commit",
    preview = "git_show",
  }
end


local function make_git_preview(item, upstream_ref)
  if not item or not item.file then
    return nil
  end

  local file = vim.fn.expand(item.file)
  local file_dir = vim.fn.fnamemodify(file, ":h")

  -- get git root
  local git_root_lines = vim.fn.systemlist({ "git", "-C", file_dir, "rev-parse", "--show-toplevel" })
  if vim.v.shell_error ~= 0 or not git_root_lines[1] or git_root_lines[1] == "" then
    -- not in a git repo -> fallback: show file contents
    return {
      cmd = "cat",
      args = { file },
      ft = vim.bo.filetype or vim.fn.fnamemodify(file, ":e"),
    }
  end
  local git_root = git_root_lines[1]

  -- get path relative to repo root (works only for tracked files)
  local rel_lines = vim.fn.systemlist({ "git", "-C", git_root, "ls-files", "--full-name", "--", file })
  if vim.v.shell_error ~= 0 or not rel_lines[1] or rel_lines[1] == "" then
    -- untracked file -> fallback to showing file contents
    return {
      cmd = "cat",
      args = { file },
      ft = vim.bo.filetype or vim.fn.fnamemodify(file, ":e"),
    }
  end
  local relpath = rel_lines[1]

  -- decide diff range: use provided upstream_ref or auto-detect
  local diff_range
  if upstream_ref then
    diff_range = upstream_ref .. "..HEAD"
  else
    vim.fn.systemlist({ "git", "-C", git_root, "rev-parse", "--verify", "HEAD@{u}" })
    diff_range = (vim.v.shell_error == 0) and "HEAD@{u}..HEAD" or "HEAD~1..HEAD"
  end

  return {
    cmd = "git",
    args = { "-c", "core.pager=", "diff", diff_range, "--", relpath },
    cwd = git_root,
    ft = "diff",
  }
end

--@type: snacks.picker.preview
function M.custom_git_pickers.git_diff_upstream()
  local upstream_ref = nil
  local use_branch_upstream = false

  -- Step 1: Check if branch has an upstream (HEAD@{u})
  vim.fn.systemlist({ "git", "rev-parse", "--verify", "HEAD@{u}" })
  local has_upstream = (vim.v.shell_error == 0)

  if has_upstream then
    -- Step 2: Check if there are any differences between HEAD@{u}..HEAD
    local diff_output = vim.fn.systemlist({ "git", "diff-tree", "--no-commit-id", "--name-only", "--diff-filter=d", "HEAD@{u}..HEAD", "-r" })
    local has_changes = (vim.v.shell_error == 0 and #diff_output > 0 and diff_output[1] ~= "")

    if has_changes then
      -- Use branch upstream if there are changes
      upstream_ref = "HEAD@{u}"
      use_branch_upstream = true
    end
  end

  -- Step 3: If no upstream or no changes, try update-refs or local branches
  if not upstream_ref then
    -- Get origin's default branch name for later use
    local origin_default = nil
    local default_branch_cmd = vim.fn.systemlist({ "git", "symbolic-ref", "refs/remotes/origin/HEAD", "--short" })
    if vim.v.shell_error == 0 and default_branch_cmd[1] and default_branch_cmd[1] ~= "" then
      origin_default = default_branch_cmd[1] -- e.g., "origin/main"
    end

    -- Step 3a: Check for furthest update-refs (from git rebase --update-refs)
    local update_refs = vim.fn.systemlist({ "git", "for-each-ref", "--format=%(refname:short)", "refs/rewritten/" })
    if vim.v.shell_error == 0 and #update_refs > 0 then
      -- Use the last (furthest) update-ref
      upstream_ref = update_refs[#update_refs]
    end

    -- Step 3b: If no update-refs, check if any local branch tip matches origin default
    if not upstream_ref and origin_default then
      local origin_sha = vim.fn.systemlist({ "git", "rev-parse", origin_default })[1]
      if vim.v.shell_error == 0 and origin_sha then
        -- Get all local branches
        local local_branches = vim.fn.systemlist({ "git", "for-each-ref", "--format=%(refname:short) %(objectname)", "refs/heads/" })
        -- git for-each-ref --format="%(refname:short) %(objectname)" refs/heads/
        for _, branch_line in ipairs(local_branches) do
          local branch_name, branch_sha = branch_line:match("^(%S+)%s+(%S+)$")
          if branch_sha == origin_sha then
            upstream_ref = branch_name
            break
          end
        end
      end
    end

    -- Step 3c: If no matching local branch, try local branch with same name as origin default
    if not upstream_ref and origin_default then
      -- Extract branch name from origin/main -> main
      local local_branch_name = origin_default:match("^origin/(.+)$")
      if local_branch_name then
        vim.fn.systemlist({ "git", "rev-parse", "--verify", local_branch_name })
        if vim.v.shell_error == 0 then
          upstream_ref = local_branch_name
        end
      end
    end
  end

  -- Step 4: Final fallback to origin's default branch or HEAD~1
  if not upstream_ref then
    -- Try to get the default branch from origin using symbolic-ref
    local default_branch_cmd = vim.fn.systemlist({ "git", "symbolic-ref", "refs/remotes/origin/HEAD", "--short" })
    if vim.v.shell_error == 0 and default_branch_cmd[1] and default_branch_cmd[1] ~= "" then
      upstream_ref = default_branch_cmd[1] -- e.g., "origin/main" or "origin/master"
    else
      -- Fallback: try origin/main, then origin/master
      vim.fn.systemlist({ "git", "rev-parse", "--verify", "origin/main" })
      if vim.v.shell_error == 0 then
        upstream_ref = "origin/main"
      else
        vim.fn.systemlist({ "git", "rev-parse", "--verify", "origin/master" })
        if vim.v.shell_error == 0 then
          upstream_ref = "origin/master"
        else
          -- Last resort: use HEAD~1
          upstream_ref = "HEAD~1"
          vim.notify("No upstream or origin default branch found, comparing with HEAD~1", vim.log.levels.WARN)
        end
      end
    end
  end

  pick_cmd_result {
    cmd = "git",
    -- Dynamically compare with upstream or origin default branch
    -- Prefers branch upstream if it has changes, otherwise uses origin's default branch
    args = { "diff-tree", "--no-commit-id", "--name-only", "--diff-filter=d", upstream_ref .. "..HEAD", "-r" },
    name = "git_diff_upstream",
    title = "Git Branch Changed Files",
    -- Use helper preview function to show file diff in preview
    preview_fn = function(item, _ctx)
      if not item or not item.file then
        return nil
      end
      return make_git_preview(item, upstream_ref)
    end,
  }
end

-- Step 2: File list picker for selected ref
local function show_file_list_picker(selected_ref_stats, on_back)
  local git_root = Snacks.git.get_root()

  Snacks.picker.pick({
    source = "git_diff_files",
    title = "Changed Files vs " .. selected_ref_stats.refAlias,
    finder = function(opts, ctx)
      local proc_opts = vim.tbl_extend("force", opts, {
        cmd = "git",
        args = { "diff", "--name-only", "--diff-filter=d", selected_ref_stats.refAlias .. "..HEAD" },
        cwd = git_root,
        transform = function(item)
          item.cwd = git_root
          item.file = item.text
          return item
        end,
      })
      return require("snacks.picker.source.proc").proc(proc_opts, ctx)
    end,
    format = "file",
    -- Use helper preview function to show file diff in preview
    preview_fn = function(item, _ctx)
      return make_git_preview(item)
    end,
    win = {
      input = {
        keys = {
          ["<C-[>"] = {
            function(picker)
              picker:close()
              if on_back then
                on_back()
              end
            end,
            mode = { "n", "i" },
            desc = "Back to ref selection"
          },
        },
      },
    },
  })
end

-- -- NOTES (do not remove)
--
-- PERFORMANCE OPTIMIZATION TODO:
-- The first step picker can be slow because get_ref_stats() runs multiple git commands
-- for each candidate ref (diff --numstat, diff --name-status, rev-list for ahead/behind counts).
-- This results in 6-10 git commands per ref * number of refs.
--
-- Optimization strategies:
-- 1. LAZY LOADING: Only compute stats for visible items + current selection
--    - Start with minimal data (just refAlias)
--    - Compute full stats on-demand when item is selected/previewed
--    - Cache results to avoid recomputation
--
-- 2. PARALLEL EXECUTION: Run git commands concurrently using vim.loop
--    - Use vim.loop.spawn() or vim.system() with callbacks
--    - Batch multiple refs together
--    - Update picker items as data arrives
--
-- 3. OPTIMIZE GIT COMMANDS: Reduce number of git calls
--    - Single git diff with --numstat and --name-status together
--    - Use git rev-list with --count --left-right to get both ahead/behind in one call
--    - Example: git rev-list --count --left-right HEAD...ref
--
-- 4. SMART FILTERING: Skip refs that won't be useful
--    - Skip refs with 0 commits ahead (same as HEAD)
--    - Limit to top N most relevant refs based on priority
--
-- 5. PROGRESSIVE ENHANCEMENT: Show basic info first, enrich later
--    - Display refs immediately with "..." placeholders
--    - Update display as stats are computed in background
--
-- Recommended approach: Combine #1 (lazy loading) + #3 (optimize git commands)
-- This would reduce initial load from seconds to <100ms
--
-- Helper function to get stats for a ref comparison
local function get_ref_stats(ref)
  local stats = {
    refAlias = ref,
    ref = ref,
    fileChangesCount = 0,
    fileAddedCount = 0,
    fileDeletedCount = 0,
    lineChangesCount = 0,
    lineAddedCount = 0,
    lineDeletedCount = 0,
    commitsBehindCount = 0,
    commitsAheadCount = 0,
    text = "",
    valid = false,
  }

  -- Verify ref exists
  vim.fn.systemlist({ "git", "rev-parse", "--verify", ref })
  if vim.v.shell_error ~= 0 then
    return stats
  end
  stats.valid = true

  -- Get full ref name
  local full_ref = vim.fn.systemlist({ "git", "rev-parse", "--symbolic-full-name", ref })[1]
  if full_ref and full_ref ~= "" then
    stats.ref = full_ref
  end

  -- Get file stats using diff
  local diff_stat = vim.fn.systemlist({ "git", "diff", "--numstat", ref .. "..HEAD" })
  if vim.v.shell_error == 0 then
    for _, line in ipairs(diff_stat) do
      if line ~= "" then
        local added, deleted = line:match("^(%d+)%s+(%d+)")
        if added and deleted then
          stats.fileChangesCount = stats.fileChangesCount + 1
          stats.lineAddedCount = stats.lineAddedCount + tonumber(added)
          stats.lineDeletedCount = stats.lineDeletedCount + tonumber(deleted)
        end
      end
    end
    stats.lineChangesCount = stats.lineAddedCount + stats.lineDeletedCount
  end

  -- Get file added/deleted counts
  local diff_name_status = vim.fn.systemlist({ "git", "diff", "--name-status", ref .. "..HEAD" })
  if vim.v.shell_error == 0 then
    for _, line in ipairs(diff_name_status) do
      local status = line:match("^(%a)")
      if status == "A" then
        stats.fileAddedCount = stats.fileAddedCount + 1
      elseif status == "D" then
        stats.fileDeletedCount = stats.fileDeletedCount + 1
      end
    end
  end

  -- Get commit counts
  local ahead = vim.fn.systemlist({ "git", "rev-list", "--count", ref .. "..HEAD" })[1]
  if vim.v.shell_error == 0 and ahead then
    stats.commitsAheadCount = tonumber(ahead) or 0
  end

  local behind = vim.fn.systemlist({ "git", "rev-list", "--count", "HEAD.." .. ref })[1]
  if vim.v.shell_error == 0 and behind then
    stats.commitsBehindCount = tonumber(behind) or 0
  end

  -- Build display text
  local parts = { stats.refAlias }
  if stats.commitsAheadCount > 0 then
    table.insert(parts, string.format("+%d ahead", stats.commitsAheadCount))
  end
  if stats.commitsBehindCount > 0 then
    table.insert(parts, string.format("-%d behind", stats.commitsBehindCount))
  end
  if stats.fileChangesCount > 0 then
    table.insert(parts, string.format("%d files", stats.fileChangesCount))
  end
  if stats.lineAddedCount > 0 or stats.lineDeletedCount > 0 then
    table.insert(parts, string.format("+%d/-%d lines", stats.lineAddedCount, stats.lineDeletedCount))
  end
  stats.text = table.concat(parts, " | ")

  return stats
end

-- Collect all candidate refs
local function collect_candidate_refs()
  local candidates = {}
  local seen_refs = {}

  -- Helper to add candidate if not seen
  local function add_candidate(refAlias, priority)
    if not seen_refs[refAlias] then
      local stats = get_ref_stats(refAlias)
      if stats.valid then
        stats.priority = priority
        table.insert(candidates, stats)
        seen_refs[refAlias] = true
      end
    end
  end

  -- 1. Update-ref furthest base (from git rebase --update-refs)
  local update_refs = vim.fn.systemlist({ "git", "for-each-ref", "--format=%(refname:short)", "refs/rewritten/" })
  if vim.v.shell_error == 0 and #update_refs > 0 then
    -- Use the last (furthest) update-ref
    add_candidate(update_refs[#update_refs], 1)
  end

  -- 2. Other local branches that might be base for current branch
  -- Find branches where their HEAD is an ancestor of current HEAD
  local current_branch = vim.fn.systemlist({ "git", "branch", "--show-current" })[1]
  local origin_default = vim.fn.systemlist({ "git", "symbolic-ref", "refs/remotes/origin/HEAD", "--short" })[1]
  local origin_default_local = origin_default and origin_default:match("^origin/(.+)$")

  local local_branches = vim.fn.systemlist({ "git", "for-each-ref", "--format=%(refname:short)", "refs/heads/" })
  if vim.v.shell_error == 0 then
    for _, branch in ipairs(local_branches) do
      if branch ~= current_branch and branch ~= origin_default_local then
        -- Check if this branch is an ancestor of HEAD
        vim.fn.systemlist({ "git", "merge-base", "--is-ancestor", branch, "HEAD" })
        if vim.v.shell_error == 0 then
          add_candidate(branch, 2)
        end
      end
    end
  end

  -- 3. HEAD@{u} (branch upstream)
  add_candidate("HEAD@{u}", 3)

  -- 4. Origin default local branch (main or master)
  if origin_default_local then
    add_candidate(origin_default_local, 4)
  end

  -- 5. Origin default branch (origin/main or origin/master)
  if origin_default then
    add_candidate(origin_default, 5)
  else
    add_candidate("origin/main", 5)
    add_candidate("origin/master", 5)
  end

  -- 6. HEAD~1
  add_candidate("HEAD~1", 6)

  -- Sort by priority
  table.sort(candidates, function(a, b)
    return a.priority < b.priority
  end)

  return candidates
end

-- Step 2: File list picker for selected ref
local function show_file_list_picker(selected_ref_stats, on_back)
  local git_root = Snacks.git.get_root()

  print("=== show_file_list_picker ===")
  print("Selected ref: " .. selected_ref_stats.refAlias)
  print("Git root: " .. (git_root or "nil"))
  print("File changes: " .. selected_ref_stats.fileChangesCount)

  Snacks.picker.pick({
    source = "git_diff_files",
    title = "Changed Files vs " .. selected_ref_stats.refAlias,
    finder = function(opts, ctx)
      print("Finder: Getting changed files for " .. selected_ref_stats.refAlias)
      local proc_opts = vim.tbl_extend("force", opts, {
        cmd = "git",
        args = { "diff", "--name-only", "--diff-filter=d", selected_ref_stats.refAlias .. "..HEAD" },
        cwd = git_root,
        transform = function(item)
          item.cwd = git_root
          item.file = item.text
          return item
        end,
      })
      return require("snacks.picker.source.proc").proc(proc_opts, ctx)
    end,
    format = "file",
    preview = function(ctx)
      local item = ctx and ctx.item
      print("=== File Preview Debug ===")
      print("ctx:", vim.inspect(ctx))
      print("item:", item and vim.inspect(item) or "nil")

      if not item or not item.file then
        print("Preview SKIP: no item or file")
        return nil
      end

      print("Preview: showing diff for file: " .. item.file)
      print("Preview: ref: " .. selected_ref_stats.refAlias)
      print("Preview: git_root: " .. (git_root or "nil"))

      local preview_spec = {
        cmd = "git",
        args = { "diff", selected_ref_stats.refAlias .. "..HEAD", "--", item.file },
        cwd = git_root,
        ft = "diff",
      }
      print("Preview spec:", vim.inspect(preview_spec))
      return preview_spec
    end,
    win = {
      input = {
        keys = {
          ["<C-[>"] = {
            function(picker)
              print("Back to ref selection")
              picker:close()
              if on_back then
                on_back()
              end
            end,
            mode = { "n", "i" },
            desc = "Back to ref selection"
          },
        },
      },
    },
  })
end

-- Step 1: Ref selection picker
function M.custom_change_list_picker()
  local git_root = Snacks.git.get_root()
  local candidates = collect_candidate_refs()

  if #candidates == 0 then
    vim.notify("No valid refs found for comparison", vim.log.levels.WARN)
    return
  end

  -- Transform candidates to ensure proper structure for picker
  local picker_items = {}
  for _, candidate in ipairs(candidates) do
    table.insert(picker_items, {
      text = candidate.text,
      refAlias = candidate.refAlias,
      ref = candidate.ref,
      priority = candidate.priority,
      fileChangesCount = candidate.fileChangesCount,
      fileAddedCount = candidate.fileAddedCount,
      fileDeletedCount = candidate.fileDeletedCount,
      lineChangesCount = candidate.lineChangesCount,
      lineAddedCount = candidate.lineAddedCount,
      lineDeletedCount = candidate.lineDeletedCount,
      commitsBehindCount = candidate.commitsBehindCount,
      commitsAheadCount = candidate.commitsAheadCount,
    })
  end

  Snacks.picker.pick({
    source = "git_refs",
    title = "Select Reference to Compare",
    items = picker_items,
    -- Custom formatted display with counts
    format = function(item)
      local meta = {}
      if item.commitsAheadCount and item.commitsAheadCount > 0 then
        table.insert(meta, string.format("+%d ahead", item.commitsAheadCount))
      end
      if item.commitsBehindCount and item.commitsBehindCount > 0 then
        table.insert(meta, string.format("-%d behind", item.commitsBehindCount))
      end
      if item.fileChangesCount and item.fileChangesCount > 0 then
        table.insert(meta, string.format("%d files", item.fileChangesCount))
      end
      if (item.lineAddedCount and item.lineAddedCount > 0) or (item.lineDeletedCount and item.lineDeletedCount > 0) then
        table.insert(meta, string.format("+%d/-%d lines", item.lineAddedCount or 0, item.lineDeletedCount or 0))
      end

      local meta_text = (#meta > 0) and (" — " .. table.concat(meta, " | ")) or ""

      return {
        { item.refAlias or item.text or "<ref>", "SnacksPickerTitle" },
        { meta_text, "Comment" },
      }
    end,

    -- Enhanced preview: show commit log (top N) and diff stat for the ref
    preview = function(ctx)
      local item = ctx and ctx.item
      if not item or not item.refAlias then
        return nil
      end

      local ref = item.refAlias
      -- Limit output size for preview to avoid huge buffers
      local log_cmd = string.format("git --no-pager log --oneline --graph --decorate %s..HEAD | sed -n '1,200p'", ref)
      local stat_cmd = string.format("git --no-pager diff --stat %s..HEAD | sed -n '1,200p'", ref)
      print([==[M.custom_change_list_picker#preview stat_cmd:]==], vim.inspect(stat_cmd)) -- __AUTO_GENERATED_PRINT_VAR_END__
      local combined = log_cmd .. "\n\n" .. stat_cmd

      return {
        cmd = "bash",
        args = { "-lc", combined },
        cwd = git_root,
        ft = "git",
      }
    end,

    confirm = function(picker, item)
      picker:close()
      if item then
        -- Open step 2: file list picker
        show_file_list_picker(item, function()
          -- Callback to return to step 1
          M.custom_change_list_picker()
        end)
      end
    end,
  })
end

function WorkingSamplePickerWithCustomPreviewAndList()
-- Simple custom picker with:
-- - custom items
-- - custom display (format)
-- - custom preview
  -- 1) Define items (any table; just ensure they have at least `text`)
  local items = {
    {
      text = "Item A",
      detail = "This is item A. It does something interesting.",
      extra = "extra A data",
    },
    {
      text = "Item B",
      detail = "Item B has a different description.",
      extra = "extra B data",
    },
    {
      text = "Item C",
      detail = "Yet another item with custom data.",
      extra = "extra C data",
    },
  }

  --@type: snacks.picker
  Snacks.picker({
    items = items,

    ----------------------------------------------------------------
    -- 2) Custom format: how each row is rendered in the list
    ----------------------------------------------------------------
    -- Return a list of “chunks”. Each chunk is:
    -- { text, hl_group? } or more advanced structures.
    format = function(item, picker)
      -- show: [Item A] - This is item A. It does something interesting.
      return {
        { "[" .. (item.text or "") .. "]", "SnacksPickerTitle" },
        { " - ", "Comment" },
        { item.detail or "", "Normal" },
      }
    end,

    ----------------------------------------------------------------
    -- 3) Custom preview: what appears in the preview window
    ----------------------------------------------------------------
    -- Preview function: (ctx) -> boolean?
    -- ctx.item: current item
    -- ctx.buf: buffer handle for preview
    -- ctx.win: window handle for preview
    preview = function(ctx)
      local item = ctx.item
      if not item then
        return false
      end

      -- Build preview text
      local lines = {
        "Name:   " .. (item.text or ""),
        "Detail: " .. (item.detail or ""),
        "",
        "Extra data:",
        vim.inspect(item.extra),
      }

      -- Write into the preview buffer
      vim.api.nvim_buf_set_option(ctx.buf, "modifiable", true)
      vim.api.nvim_buf_set_lines(ctx.buf, 0, -1, false, lines)
      vim.api.nvim_buf_set_option(ctx.buf, "modifiable", false)

      -- optionally set filetype for syntax highlight
      vim.bo[ctx.buf].filetype = "markdown"

      return true
    end,

    ----------------------------------------------------------------
    -- 4) What happens when user confirms a selection
    ----------------------------------------------------------------
    confirm = function(picker, item)
      if not item then
        picker:close()
        return
      end
      picker:close()

      -- Example “next step”
      print("You picked:", item.text)
      print("Detail:    ", item.detail)
      print("Extra:     ", item.extra)
    end,
    ---@class snacks.picker.config
    ---@type snacks.picker.layout.Config
    layout = {
      preset = "default",
      hidden = false,
      layout = {
        backdrop = false,
        height = 0.7,
        -- box = "horizontal",
      },
    }
  })
end

--#endregion

return M

-- TODO
-- fix custom_change_list_picker not show inside ref log step
