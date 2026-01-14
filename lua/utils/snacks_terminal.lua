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

  -- Use preview - either built-in string or custom function
  if picker_opts.preview then
    pick_opts.preview = picker_opts.preview
  end

  -- Add custom actions if provided
  if picker_opts.actions then
    pick_opts.actions = picker_opts.actions
  end

  -- Add custom window keys if provided
  if picker_opts.win then
    pick_opts.win = picker_opts.win
  end

  Snacks.picker.pick(pick_opts)
end

-- Custom Pickers
M.custom_git_pickers = {}

-- Helper function to open file diff with gitsigns
-- @param file_path string: File path (relative or absolute)
-- @param ref string: Git reference to compare with
local function open_file_with_gitsigns_diff(file_path, ref)
  if not pcall(require, "gitsigns") then
    vim.notify("Gitsigns is not available", vim.log.levels.ERROR)
    return
  end

  local git_root = Snacks.git.get_root()

  -- Convert to absolute path if needed
  if vim.fn.filereadable(file_path) == 0 then
    file_path = git_root .. "/" .. file_path
  end

  -- Open file in new tab
  vim.cmd("tabnew " .. vim.fn.fnameescape(file_path))

  -- Show diff with gitsigns
  require("gitsigns").diffthis(ref, {
    vertical = true,
  })
end

-- Helper function to open current buffer in new tab with gitsigns diff
-- @param ref string: Git reference to compare with
local function open_current_buffer_with_gitsigns_diff(ref)
  if not pcall(require, "gitsigns") then
    vim.notify("Gitsigns is not available", vim.log.levels.ERROR)
    return
  end

  local current_file = vim.api.nvim_buf_get_name(0)

  if current_file == "" then
    vim.notify("No file in current buffer", vim.log.levels.WARN)
    return
  end

  -- Open in new tab
  vim.cmd("tabnew " .. vim.fn.fnameescape(current_file))

  -- Show diff with gitsigns
  require("gitsigns").diffthis(ref, {
    vertical = true,
  })
end

-- Helper function to build remote URL for a file at a specific ref
-- @param file_path string: File path (relative or absolute)
-- @param ref string: Git reference (branch, tag, or commit)
-- @return string|nil: Remote URL or nil if error
local function build_remote_url(file_path, ref)
  local git_root = Snacks.git.get_root()
  if not git_root then
    return nil
  end

  -- Convert to absolute path if needed
  if vim.fn.filereadable(file_path) == 0 then
    file_path = git_root .. "/" .. file_path
  end

  -- Get relative path from git root
  local rel_path = file_path:gsub("^" .. vim.pesc(git_root) .. "/?", "")

  -- Get remote path using gitUtil
  local gitUtil = require("utils.git")
  local remote_path = gitUtil.get_remote_path("origin")

  if not remote_path or remote_path == "" then
    return nil
  end

  -- Build URL - detect GitLab vs GitHub
  local url
  if remote_path:match("gitlab") then
    -- GitLab style: /-/blob/
    url = string.format("https://%s/-/blob/%s/%s", remote_path, ref, rel_path)
  else
    -- GitHub style: /blob/
    url = string.format("https://%s/blob/%s/%s", remote_path, ref, rel_path)
  end

  return url
end

-- Helper function to open file in remote at specific ref
-- @param file_path string: File path (relative or absolute)
-- @param ref string: Git reference to open at
local function open_file_in_remote(file_path, ref)
  -- __AUTO_GENERATED_PRINT_VAR_START__
  print([==[open_file_in_remote ref:]==], vim.inspect(ref)) -- __AUTO_GENERATED_PRINT_VAR_END__
  local url = build_remote_url(file_path, ref)

  if not url then
    vim.notify("Failed to build remote URL", vim.log.levels.ERROR)
    return
  end

  -- Get filename for notification
  local filename = vim.fn.fnamemodify(file_path, ":t")

  -- Open in browser
  vim.fn.jobstart({ "open", url }, { detach = true })
  vim.notify(string.format("Opening %s @ %s in browser", filename, ref), vim.log.levels.INFO)
end

function M.custom_git_pickers.git_show()
  pick_cmd_result {
    cmd = "git",
    args = { "diff-tree", "--no-commit-id", "--name-only", "--diff-filter=d", "HEAD", "-r" },
    name = "git_show",
    title = "Git Last Commit",
    preview = "git_show",
    actions = {
      open_file_diff = function(picker, item)
        if not item or not item.file then
          vim.notify("No file selected", vim.log.levels.WARN)
          return
        end

        picker:close()
        open_file_with_gitsigns_diff(item.file, "HEAD~1")
      end,
      open_remote_at_ref = function(picker, item)
        if not item or not item.file then
          vim.notify("No file selected", vim.log.levels.WARN)
          return
        end

        open_file_in_remote(item.file, "HEAD~1")
      end,
      open_remote_at_head = function(picker, item)
        if not item or not item.file then
          vim.notify("No file selected", vim.log.levels.WARN)
          return
        end

        open_file_in_remote(item.file, "HEAD")
      end,
    },
    win = {
      input = {
        keys = {
          ["<C-g>"] = {
            "open_file_diff",
            mode = { "n", "i" },
            desc = "Open file diff in new tab"
          },
          ["<C-o>"] = {
            "open_remote_at_ref",
            mode = { "n", "i" },
            desc = "Open file in remote at compared ref"
          },
          ["<C-O>"] = {
            "open_remote_at_head",
            mode = { "n", "i" },
            desc = "Open file in remote at HEAD"
          },
        },
      },
      list = {
        keys = {
          ["<C-g>"] = {
            "open_file_diff",
            mode = { "n", "i" },
            desc = "Open file diff in new tab"
          },
          ["<C-o>"] = {
            "open_remote_at_ref",
            mode = { "n", "i" },
            desc = "Open file in remote at compared ref"
          },
          ["<C-O>"] = {
            "open_remote_at_head",
            mode = { "n", "i" },
            desc = "Open file in remote at HEAD"
          },
        },
      },
    },
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

  -- Capture upstream_ref for the action closure
  local captured_ref = upstream_ref

  pick_cmd_result {
    cmd = "git",
    -- Dynamically compare with upstream or origin default branch
    -- Prefers branch upstream if it has changes, otherwise uses origin's default branch
    args = { "diff-tree", "--no-commit-id", "--name-only", "--diff-filter=d", upstream_ref .. "..HEAD", "-r" },
    name = "git_diff_upstream",
    title = "Git Branch Changed Files (vs " .. upstream_ref .. ")",
    -- Use built-in git_diff preview
    preview = "git_diff",
    actions = {
      open_file_diff = function(picker, item)
        if not item or not item.file then
          vim.notify("No file selected", vim.log.levels.WARN)
          return
        end

        picker:close()
        open_file_with_gitsigns_diff(item.file, captured_ref)
      end,
      open_remote_at_ref = function(picker, item)
        if not item or not item.file then
          vim.notify("No file selected", vim.log.levels.WARN)
          return
        end

        open_file_in_remote(item.file, captured_ref)
      end,
      open_remote_at_head = function(picker, item)
        if not item or not item.file then
          vim.notify("No file selected", vim.log.levels.WARN)
          return
        end

        open_file_in_remote(item.file, "HEAD")
      end,
    },
    win = {
      input = {
        keys = {
          ["<C-g>"] = {
            "open_file_diff",
            mode = { "n", "i" },
            desc = "Open file diff in new tab"
          },
          ["<C-o>"] = {
            "open_remote_at_ref",
            mode = { "n", "i" },
            desc = "Open file in remote at upstream ref"
          },
          ["<C-2>"] = {
            "open_remote_at_head",
            mode = { "n", "i" },
            desc = "Open file in remote at HEAD"
          },
        },
      },
      list = {
        keys = {
          ["<C-g>"] = {
            "open_file_diff",
            mode = { "n", "i" },
            desc = "Open file diff in new tab"
          },
          ["<C-o>"] = {
            "open_remote_at_ref",
            mode = { "n", "i" },
            desc = "Open remote compared ref"
          },
          ["<C-1>"] = {
            "open_remote_at_head",
            mode = { "n", "i" },
            desc = "Open remote at HEAD"
          },
        },
      },
    },
  }
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
    fullRef = nil,
    refSha = nil,
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
  -- git rev-parse --symbolic-full-name HEAD@{u}
  -- git rev-parse --symbolic-full-name HEAD~3 (empty)
  if full_ref and full_ref ~= "" then
    stats.ref = full_ref
  else
    stats.fullRef = nil
  end
  
  -- git rev-parse HEAD~3
  local ref_sha = vim.fn.systemlist({ "git", "rev-parse", ref })[1]
  if ref_sha and ref_sha ~= "" then
    stats.refSha = ref_sha
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
          -- Check commit distance - only add if within 20 commits
          local commit_count_output = vim.fn.systemlist({ "git", "rev-list", "--count", branch .. "..HEAD" })
          -- __AUTO_GENERATED_PRINT_VAR_START__
          print([==[collect_candidate_refs#if#for#if#if :]==], vim.inspect(table.concat({  "git", "rev-list", "--count", branch .. "..HEAD" }, " "))) -- __AUTO_GENERATED_PRINT_VAR_END__
          print([==[collect_candidate_refs#if#for#if#if commit_count_output:]==], vim.inspect(commit_count_output)) -- __AUTO_GENERATED_PRINT_VAR_END__
          if vim.v.shell_error == 0 and commit_count_output[1] then
            local commit_distance = tonumber(commit_count_output[1])
            if commit_distance and commit_distance <= 20 then
              -- Check if this branch contains update-refs (from git rebase --update-refs)
              local has_update_refs = false
              local update_ref_command = { "git", "for-each-ref", "--format=%(refname:short) %(objectname)", "refs/rewritten/" }
              -- __AUTO_GENERATED_PRINT_VAR_START__
              print([==[collect_candidate_refs#if#for#if#if#if#if update_ref_command:]==], vim.inspect(table.concat(update_ref_command, " "))) -- __AUTO_GENERATED_PRINT_VAR_END__

              local update_refs = vim.fn.systemlist(update_ref_command)
              if vim.v.shell_error == 0 and #update_refs > 0 then
                for _, ref_line in ipairs(update_refs) do
                  local ref_name, ref_sha = ref_line:match("^(%S+)%s+(%S+)$")
                  if ref_sha then
                    -- Check if this update-ref's commit is reachable from the branch
                    vim.fn.systemlist({ "git", "merge-base", "--is-ancestor", ref_sha, branch })
                    if vim.v.shell_error == 0 then
                      has_update_refs = true
                      break
                    end
                  end
                end
              end

              -- Add candidate with metadata about update-refs
              add_candidate(branch, 2)
              -- Store metadata for later use if needed
              if has_update_refs then
                -- You can add this info to the stats if desired
                -- This branch contains update-refs from a rebase
              end
            end
          end
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
    -- Use built-in git_diff preview
    preview = "git_diff",
    actions = {
      open_file_diff = function(picker, item)
        if not item or not item.file then
          vim.notify("No file selected", vim.log.levels.WARN)
          return
        end

        picker:close()
        open_file_with_gitsigns_diff(item.file, selected_ref_stats.refAlias)
      end,
      open_remote_at_ref = function(picker, item)
        if not item or not item.file then
          vim.notify("No file selected", vim.log.levels.WARN)
          return
        end

        open_file_in_remote(item.file, selected_ref_stats.refAlias)
      end,
      open_remote_at_head = function(picker, item)
        if not item or not item.file then
          vim.notify("No file selected", vim.log.levels.WARN)
          return
        end

        open_file_in_remote(item.file, "HEAD")
      end,
    },
    win = {
      input = {
        keys = {
          ["<C-h>"] = {
            function(picker)
              if on_back then
                picker:close()
                on_back()
              end
            end,
            mode = { "n", "i" },
            desc = "Back to ref selection"
          },
          ["<C-g>"] = {
            "open_file_diff",
            mode = { "n", "i" },
            desc = "Open file diff in new tab"
          },
          ["<C-o>"] = {
            "open_remote_at_ref",
            mode = { "n", "i" },
            desc = "Open file in remote at selected ref"
          },
          ["<M-o>"] = {
            "open_remote_at_head",
            mode = { "n", "i" },
            desc = "Open file in remote at HEAD"
          },
        },
      },
      list = {
        keys = {
          ["<C-g>"] = {
            "open_file_diff",
            mode = { "n", "i" },
            desc = "Open file diff in new tab"
          },
          ["<M-o>"] = {
            "open_remote_at_ref",
            mode = { "n", "i" },
            desc = "Open file in remote at selected ref"
          },
          ["<C-h>"] = {
            function(picker)
              if on_back then
                picker:close()
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
      fullRef = candidate.fullRef,
      refSha = candidate.refSha,
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

  local getMetaText = function(item)
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

    local meta_text = (#meta > 0) and table.concat(meta, " | ") or ""
    return meta_text
  end

  local current_branch_ref = vim.fn.systemlist({ "git", "branch", "--show-current" })[1] or "HEAD"

  Snacks.picker.pick({
    source = "git_refs",
    title = "Select Reference to Compare vs (" .. current_branch_ref .. ")",
    items = picker_items,
    -- Custom formatted display with counts
    format = function(item)
      local meta_text = getMetaText(item)
      local refShow = nil
      -- print([==[M.custom_change_list_picker#format#if item.refAlias and item.ref:]==], vim.inspect({ item.refAlias, item.ref })) -- __AUTO_GENERATED_PRINT_VAR_END__
      if item.refAlias ~= item.ref then
        -- local item = { ref = "refs/remotes/origin/2601-assetmapfb", refAlias = "origin/2601-assetmapfb" }
        local cleanRef = item.ref:gsub("^refs/heads/", "")
        cleanRef = cleanRef:gsub("^refs/remotes/", "")
        if cleanRef == item.refAlias then
          refShow = item.refAlias
        else
          refShow = item.refAlias .. " (" .. cleanRef .. ")"
        end
      elseif item.fullRef == nil then
          refShow = item.refAlias .. "(" .. item.refSha .. ")"
      else
        refShow = item.refAlias or item.ref or item.refSha
      end
      -- local meta = {}
      -- if item.commitsAheadCount and item.commitsAheadCount > 0 then
      --   table.insert(meta, string.format("+%d ahead", item.commitsAheadCount))
      -- end
      -- if item.commitsBehindCount and item.commitsBehindCount > 0 then
      --   table.insert(meta, string.format("-%d behind", item.commitsBehindCount))
      -- end
      -- if item.fileChangesCount and item.fileChangesCount > 0 then
      --   table.insert(meta, string.format("%d files", item.fileChangesCount))
      -- end
      -- if (item.lineAddedCount and item.lineAddedCount > 0) or (item.lineDeletedCount and item.lineDeletedCount > 0) then
      --   table.insert(meta, string.format("+%d/-%d lines", item.lineAddedCount or 0, item.lineDeletedCount or 0))
      -- end
      --
      -- local meta_text = (#meta > 0) and (" — " .. table.concat(meta, " | ")) or ""

      return {
        { refShow, "SnacksPickerTitle" },
        { " ", "Comment" },
        { meta_text, "Comment" },
      }
    end,

    -- Enhanced preview: show commit log and diff stat for the ref
    preview = function(ctx)
      local item = ctx and ctx.item
      if not item or not item.refAlias then
        return nil
      end

      local ref = item.refAlias
      local preview_lines = {}

      -- Add metadata header
      vim.list_extend(preview_lines, {"=== Commits ===", ""})
      local meta_text = getMetaText(item)
      if meta_text and meta_text ~= "" then
        vim.list_extend(preview_lines, { meta_text, "" })
      end

      -- Check if there are any commits
      local commit_count_output = vim.fn.systemlist({
        "git", "rev-list", "--count", ref .. "..HEAD"
      })
      local commit_count = tonumber(commit_count_output[1]) or 0

      if commit_count == 0 then
        -- No commits difference
        vim.list_extend(preview_lines, {"No commit changes between " .. ref .. " and HEAD", ""})
      else
        -- Get commit log (limit to 50)
        local log_limit = 50
        local log_output = vim.fn.systemlist({
          "git", "--no-pager", "log", "--oneline", "--graph", "--decorate",
          "-n", tostring(log_limit),
          ref .. "..HEAD"
        })

        vim.list_extend(preview_lines, log_output or {})

        -- Add disclaimer if there are more commits than shown
        if commit_count > log_limit then
          vim.list_extend(preview_lines, {
            "",
            string.format("... and %d more commits (showing first %d)",
              commit_count - log_limit, log_limit)
          })
        end
      end

      -- File changes section
      vim.list_extend(preview_lines, {"", "=== Changes ===", ""})

      -- Check file count first to optimize
      local file_count = item.fileChangesCount or 0

      if file_count == 0 then
        vim.list_extend(preview_lines, {"No file changes"})
      else
        local stat_output
        if file_count > 100 then
          -- Optimize for large changesets - show only first 100 files
          -- Use shell command with pipe for proper handling
          local cmd = string.format(
            "git --no-pager diff --stat %s..HEAD | head -n 101",
            vim.fn.shellescape(ref)
          )
          stat_output = vim.fn.systemlist(cmd)

          vim.list_extend(preview_lines, stat_output or {})
          vim.list_extend(preview_lines, {
            "",
            string.format("... and %d more files (showing first 100 for performance)",
              file_count - 100)
          })
        else
          -- Show all files for reasonable changesets
          stat_output = vim.fn.systemlist({
            "git", "--no-pager", "diff", "--stat",
            ref .. "..HEAD"
          })
          vim.list_extend(preview_lines, stat_output or {})
        end
      end

      -- Write to preview buffer
      if ctx.buf and vim.api.nvim_buf_is_valid(ctx.buf) then
        vim.api.nvim_buf_set_option(ctx.buf, "modifiable", true)
        vim.api.nvim_buf_set_lines(ctx.buf, 0, -1, false, preview_lines)
        vim.api.nvim_buf_set_option(ctx.buf, "modifiable", false)
        vim.bo[ctx.buf].filetype = "git"
        return true
      end

      return nil
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
--
-- #region Simple custom actions :

-- #endregion

-- Toggle CWD scope for pickers (files/grep/etc)
-- Cycles through: current dir → git root → sub-project dir → previous buffer dir
function M.toggle_cwd_files_grep(picker, item)
  local path = require("utils.path")
  local pathUtil = require("utils.mypath")

  -- Get available cwd options
  local current_dir = vim.fn.getcwd()
  local git_root = path.get_root_directory()
  local prev_buffer_dir = pathUtil.get_previous_buffer_dir()

  -- Get sub-project info with metadata
  local sub_project_info = pathUtil.get_sub_project_dir(prev_buffer_dir, true)
  local sub_project_dir = sub_project_info and sub_project_info.dir or nil

  -- Initialize cwd cycle state if not exists
  if not vim.g.picker_cwd_cycle_state then
    vim.g.picker_cwd_cycle_state = "current"
  end

  -- Define the initial cycle order (will be filtered for duplicates/invalid)
  local cycle_order = {"current", "gitroot", "subproject", "prevbuffer", "current_d1"}

  -- Map states to actual directories
  local cwd_map = {
    gitroot = git_root,
    subproject = sub_project_dir,
    current = current_dir,
    current_d1 = current_dir, -- Same as current, but with depth-1 search for grep
    prevbuffer = prev_buffer_dir,
  }

  -- Keep track of all states that map to the same directory
  -- seen_dirs[dir_key] = { "state1", "state2", ... }
  local seen_dirs = {}
  local unique_cycle_order = {}

  for _, state in ipairs(cycle_order) do
    local dir = cwd_map[state]
    -- Only add if directory is valid and not seen before
    if dir and dir ~= "" and vim.fn.isdirectory(dir) == 1 then
      -- Treat current_d1 as distinct from current (different grep behavior)
      local dir_key = (state == "current_d1") and "current_d1" or dir

      if not seen_dirs[dir_key] then
        -- First time seeing this directory - initialize list with this state
        seen_dirs[dir_key] = { state }
        table.insert(unique_cycle_order, state)
      else
        -- Duplicate directory - add state to the list but don't add to cycle order
        table.insert(seen_dirs[dir_key], state)
        -- Remove duplicate from cwd_map
        cwd_map[state] = nil
      end
    else
      -- Remove invalid directories
      cwd_map[state] = nil
    end
  end

  -- Update cycle_order to only include unique, valid directories
  cycle_order = unique_cycle_order

  -- If all directories are the same or invalid, keep at least current
  if #cycle_order == 0 then
    cycle_order = {"current"}
    cwd_map = { current = current_dir }
  end

  -- If only one unique directory, notify user and don't cycle
  if #cycle_order == 1 then
    vim.notify("Only one unique directory available - no other scopes to cycle to", vim.log.levels.INFO)
    return
  end

  -- Find next valid state in the new cycle_order
  local current_state_idx = nil
  for i, state in ipairs(cycle_order) do
    if state == vim.g.picker_cwd_cycle_state then
      current_state_idx = i
      break
    end
  end

  -- If current state is not in cycle (was removed as duplicate), start from beginning
  if not current_state_idx then
    current_state_idx = 0
  end

  -- Move to next state
  local next_idx = (current_state_idx % #cycle_order) + 1
  vim.g.picker_cwd_cycle_state = cycle_order[next_idx]
  vim.g.picker_cwd_cycle_state_value = cwd_map[vim.g.picker_cwd_cycle_state]
  Snacks.notify.info("CWD Cycle State changed to: " .. vim.g.picker_cwd_cycle_state)
  local new_cwd = cwd_map[vim.g.picker_cwd_cycle_state]

  -- Get current picker source and pattern
  local source = picker.init_opts and picker.init_opts.source
  -- search = for grep pickers
  local filter_pattern = picker.input.filter and (picker.input.filter.pattern ~= "" and picker.input.filter.pattern)
  local filter_search = picker.input.filter and (picker.input.filter.search ~= "" and picker.input.filter.search)

  -- State labels
  local state_labels = {
    current = cwd_map.current == cwd_map.gitroot and "Default/Git" or "Default/current",
    current_d1 = (cwd_map.current == cwd_map.gitroot and "Default/Git" or "Default/current") .. "(D=1)",
    gitroot = "Git Root",
    subproject = (function()
      -- Use metadata to show project type and matched file if available
      if sub_project_info and sub_project_info.project_type then
        local label = "Sub-Project"
        -- Add project type
        if sub_project_info.project_type ~= "gitroot" then
          label = label .. " (" .. sub_project_info.project_type .. ")"
        end
        -- if sub_project_info.matched_file then
        --   label = label .. " [" .. sub_project_info.matched_file .. "]"
        -- end
        return label
      end
      return "Sub-Project Dir"
    end)(),
    prevbuffer = "Previous Buf Dir",
  }

  -- Alias configuration for shorter display names in duplicate list
  local state_aliases = {
    subproject = "subp",
    prevbuffer = "pbuf",
    current = "cur",
    -- current_d1 and gitroot are excluded via exclusion list
  }

  -- States to exclude from duplicate append text
  local excluded_label_text = {
    gitroot = true,
    current_d1 = true,
  }

  -- Notify user about the change
  vim.notify(
    string.format("CWD: %s\n%s", state_labels[vim.g.picker_cwd_cycle_state], new_cwd),
    vim.log.levels.INFO
  )

  -- -- Close current picker
  -- picker:close()

  -- Build picker params with scope label in title
  local scope_label = state_labels[vim.g.picker_cwd_cycle_state]

  -- Append duplicate state names (excluding current state) to scope label
  local current_state = vim.g.picker_cwd_cycle_state
  local current_dir = new_cwd
  local dir_key = (current_state == "current_d1") and "current_d1" or current_dir

  if seen_dirs[dir_key] and #seen_dirs[dir_key] > 1 then
    -- Get duplicate states excluding the current one and excluded states
    local dup_states = {}
    for _, state in ipairs(seen_dirs[dir_key]) do
      if state ~= current_state and not excluded_label_text[state] then
        -- Use alias if available, otherwise use the state name
        local display_name = state_aliases[state] or state
        table.insert(dup_states, display_name)
      end
    end

    -- Append duplicate state names if any
    if #dup_states > 0 then
      scope_label = scope_label .. " (=" .. table.concat(dup_states, ",") .. ")"
    end
  end
  local picker_params = {
    cwd = new_cwd,
    pattern = filter_pattern or "",
    search = filter_search or "",
    live = picker.opts.supports_live and picker.opts.live,
    show_empty = true,
    title = string.format("%s [%s]", source or "Picker", scope_label),
  }
  local hidden_state = picker.opts.hidden
  local ignored_state = picker.opts.ignored

  -- Fallback to init_opts if opts don't have the values
  if hidden_state == nil and picker.init_opts then
    hidden_state = picker.init_opts.hidden
  end
  if ignored_state == nil and picker.init_opts then
    ignored_state = picker.init_opts.ignored
  end

  if hidden_state ~= nil then
    picker_params.hidden = hidden_state
  end
  if ignored_state ~= nil then
    picker_params.ignored = ignored_state
  end

  -- Add git_cwd=true when current cwd is equal to git root
  if new_cwd == git_root and git_root and git_root ~= "" then
    picker_params.git_cwd = true
  end

  -- Handle different picker types and preserve their state
  if vim.g.picker_cwd_cycle_state == "current_d1" and type(source) == "string" and (source:match("grep") or source:match("files")) and not source:match("^git") then
    picker_params.args = { "--max-depth", "1" }
  end
  -- clone picker_params in to picker.opts
  picker.opts.cwd =picker_params.cwd
  picker.opts.args = picker_params.args
  picker.opts.pattern = picker_params.pattern
  picker.opts.search = picker_params.search
  picker.opts.live = picker_params.live
  picker.opts.show_empty = true
  picker.title = picker_params.title
  picker.opts.git_cwd = picker_params.git_cwd
  picker:refresh()
  
  local backupmanual_whenneed = function()
    if source == "files" then
      -- Add max-depth for current_d1 mode (depth 1 search) - fd supports --max-depth
      Snacks.picker.files(picker_params)
    elseif source == "grep" then
      -- Add max-depth for current_d1 mode (depth 1 search) - ripgrep supports --max-depth
      Snacks.picker.grep(picker_params)
    elseif source == "buffers" then
      -- Buffers picker - preserve any relevant state
      Snacks.picker.buffers(picker_params)
    -- elseif source == "git_files" then
    --   -- Git files picker
    --   Snacks.picker.git_files(picker_params)
    else
      Snacks.notify.warn("picker source" .. tostring(source) .. "Not configured to use change cwd")
      -- check for Snacks.picker[source]
      if Snacks.picker[source] and type(Snacks.picker[source]) == "function" then
        Snacks.picker[source](picker_params)
      else
        Snacks.notify.warn("Unknown picker source: " .. tostring(source) .. ". Falling back to smart picker.")
        -- Fallback to smart picker for unknown sources
        Snacks.picker.smart(picker_params)
      end
    end

    -- Re-enter insert mode after picker opens (Snacks default behavior)
    vim.defer_fn(function()
      if vim.api.nvim_get_mode().mode == "n" then
        vim.cmd("startinsert")
      end
    end, 50)
  end
end

-- Get initial picker state with persistent cwd
-- @param pickerOpts table: Base picker options to merge with
-- @param opts table: Options for state initialization
--   - cwd_default string: Default cwd type (see enum below)
-- @enum CwdDefaultType
--   "git"        -- Use git root as cwd
--   "current"    -- Use current working directory
--   "subproject" -- Use subproject root as cwd
-- @return table: Merged picker options with cwd state
---@param pickerOpts table
---@param opts { cwd_default: "git"|"current"|"subproject" , use_previous_cwd_state : boolean}
---@return table
function M.get_initial_picker_state(pickerOpts, opts)
  opts = opts or {}
  local cwd_default = opts.cwd_default 

  local path = require("utils.path")
  local pathUtil = require("utils.mypath")

  -- Map of default cwd types
  local cwd_defaultmap = {
    git = path.get_root_directory() or Snacks.git.get_root(),
    current = vim.fn.getcwd(),
    subproject = pathUtil.get_sub_project_dir(),
  }

  -- Get cwd - use persisted state if available, otherwise use default
  -- TODO: check if interfere with normal cwd behavior (empty/default)
  -- local cwd = vim.g.picker_cwd_cycle_state_value or cwd_defaultmap[cwd_default] or vim.fn.getcwd()
  local cwd = nil
  local cwd_state = vim.g.picker_cwd_cycle_state_value
  local cwd_fallback = cwd_defaultmap[cwd_default]
  local git_root = path.get_root_directory() or Snacks.git.get_root()

  -- Build resuld
  local result = vim.deepcopy(pickerOpts) or {}

  if cwd_state and opts.use_previous_cwd_state ~= false then
    cwd = cwd_state
  else
    -- Use default cwd if no previous state or empty if no default
    if not cwd and not result.cwd and cwd_fallback then
      cwd = cwd_fallback
    end
  end

  local is_cwd_git_ui = git_root and (cwd and cwd == git_root or cwd_defaultmap["current"] == git_root)

  if cwd then
    result.cwd = cwd
    -- Snacks.notify.info("Use cwd " .. tostring(cwd_default))
  end
  -- Set git_cwd flag if current cwd is the git root
  if is_cwd_git_ui then
    result.git_cwd = true
  else
    result.custom_cwd = result.cwd and true or nil
  end

  local args = pickerOpts.args or {}
  local has_ignore_case = vim.tbl_contains(args, "-i") or vim.tbl_contains(args, "--ignore-case")
  if has_ignore_case then
    result.case_nonsensitive_custom = true
  end


  return result
end
-- Adjust max-depth for files/grep pickers dynamically
-- @param direction number: 1 to increase depth, -1 to decrease depth, 0 to reset to unlimited
function M.adjust_picker_depth(picker, item, direction, max_depth_limit)
  -- Get current depth from picker.opts (not global)
  local current_depth = picker.opts.max_depth
  local new_depth

  if direction == 0 then
    -- Reset to unlimited
    -- Return early if already unlimited
    if current_depth == nil then
      return
    end
    new_depth = nil
  elseif direction > 0 then
    -- Increase depth (make it deeper)
    if current_depth == nil then
      new_depth = 10 -- Start with 10 if unlimited
    else
      new_depth = current_depth + 1
      -- enable this if you want to cap max depth
      if max_depth_limit and new_depth > max_depth_limit then
        new_depth = nil -- Remove limit at max
      end
    end
  else
    -- Decrease depth (make it shallower)
    if current_depth == nil then
      new_depth = 10 -- Start with 10 if unlimited
    elseif current_depth > 1 then
      new_depth = current_depth - 1
    else
      new_depth = 1 -- Minimum depth is 1
    end
  end

  -- Store depth in picker.opts
  picker.opts.max_depth = new_depth

  local depth_label = new_depth and tostring(new_depth) or "unlimited"
  -- Update args based on depth
  if new_depth then
    picker.opts.args = { "--max-depth", tostring(new_depth) }
  else
    -- Remove depth args when unlimited
    picker.opts.args = nil
  end

  -- Update title to show depth
  -- Snacks.notify.info("Updating picker title with depth: " .. depth_label)

  if picker.title then
    -- __AUTO_GENERATED_PRINT_VAR_START__
    -- Remove existing -d={number} pattern
    -- Also replace (Depth {number}) if exists
    local base_title = picker.title:gsub("%s*%-d=%d+", "")
    base_title = base_title:gsub("%s*%((Depth%s*%d+|Unlimited)%s*%)", "")

    -- Add new depth indicator if depth is set
    if new_depth then
      picker.title = base_title .. " -d=" .. tostring(new_depth)

    else
      picker.title = base_title
    end
  end

  -- Refresh picker with new args
  picker:refresh()
end

-- Export helper functions for use in other modules
M.open_file_with_gitsigns_diff = open_file_with_gitsigns_diff
M.open_current_buffer_with_gitsigns_diff = open_current_buffer_with_gitsigns_diff
M.open_file_in_remote = open_file_in_remote
M.build_remote_url = build_remote_url

--#region Path Copy Utilities for Snacks Picker

-- Get the selected file path from picker item
-- Handles both file picker items and explorer items
local function get_item_path(item)
  if not item then
    return nil
  end

  -- Try different path fields in order of preference
  return item._path or item.file or item.path
end

-- Get relative path from source to target with ../ if outside
local function get_relative_path_with_parent(target_path, source_path)
  if not target_path or target_path == "" then
    return nil
  end

  -- Ensure absolute paths
  target_path = vim.fn.fnamemodify(target_path, ":p")
  source_path = vim.fn.fnamemodify(source_path, ":p")

  -- Find common prefix
  local target_parts = vim.split(target_path, "/", { plain = true })
  local source_parts = vim.split(source_path, "/", { plain = true })

  local common_len = 0
  for i = 1, math.min(#target_parts, #source_parts) do
    if target_parts[i] == source_parts[i] then
      common_len = i
    else
      break
    end
  end

  -- Build relative path
  local ups = #source_parts - common_len - 1 -- -1 because last part is filename
  local rel_parts = {}

  -- Add ../ for each level up
  for _ = 1, ups do
    table.insert(rel_parts, "..")
  end

  -- Add remaining target parts
  for i = common_len + 1, #target_parts do
    table.insert(rel_parts, target_parts[i])
  end

  return table.concat(rel_parts, "/")
end

-- Generate different path formats
local function generate_path_formats(file_path)
  local git_root = Snacks.git.get_root()
  local cwd = vim.fn.getcwd()

  -- Get previous/active buffer path
  local prev_buf = vim.api.nvim_buf_get_name(vim.fn.bufnr("#"))
  local current_buf = vim.api.nvim_buf_get_name(0)
  local ref_buf_path = (prev_buf ~= "" and prev_buf) or current_buf

  local formats = {
    {
      label = "Relative to Previous/Active Buffer (with ../)",
      path = get_relative_path_with_parent(file_path, ref_buf_path),
      key = "buffer",
    },
    {
      label = "Relative to Git Root",
      path = git_root and file_path:gsub("^" .. vim.pesc(git_root) .. "/?", "") or nil,
      key = "git",
    },
    {
      label = "Relative to Current CWD",
      path = vim.fn.fnamemodify(file_path, ":."),
      key = "cwd",
    },
    {
      label = "Absolute Path",
      path = vim.fn.fnamemodify(file_path, ":p"),
      key = "absolute",
    },
  }

  return formats
end

-- Copy path to clipboard and notify
local function copy_to_clipboard(path, label)
  if not path or path == "" then
    vim.notify("Path is empty or invalid", vim.log.levels.WARN)
    return false
  end

  -- Copy to system clipboard and unnamed register
  vim.fn.setreg("+", path)
  vim.fn.setreg('"', path)

  vim.notify(
    string.format("Copied %s:\n%s", label, path),
    vim.log.levels.INFO
  )

  return true
end

-- Picker action: Copy relative path to previous/active buffer
function M.copy_path_relative_buffer(picker, item)
  local file_path = get_item_path(item)
  if not file_path then
    vim.notify("No file path found", vim.log.levels.WARN)
    return
  end

  local prev_buf = vim.api.nvim_buf_get_name(vim.fn.bufnr("#"))
  local current_buf = vim.api.nvim_buf_get_name(0)
  local ref_buf_path = (prev_buf ~= "" and prev_buf) or current_buf

  local rel_path = get_relative_path_with_parent(file_path, ref_buf_path)
  if copy_to_clipboard(rel_path, "relative path (to buffer)") then
    picker:close()
  end
end

-- Picker action: Copy relative path to git root
function M.copy_path_relative_git(picker, item)
  local file_path = get_item_path(item)
  if not file_path then
    vim.notify("No file path found", vim.log.levels.WARN)
    return
  end

  local git_root = Snacks.git.get_root()
  if not git_root then
    vim.notify("Not in a git repository", vim.log.levels.WARN)
    return
  end

  local rel_path = file_path:gsub("^" .. vim.pesc(git_root) .. "/?", "")
  if copy_to_clipboard(rel_path, "relative path (to git root)") then
    picker:close()
  end
end

-- Picker action: Copy relative path to current CWD
function M.copy_path_relative_cwd(picker, item)
  local file_path = get_item_path(item)
  if not file_path then
    vim.notify("No file path found", vim.log.levels.WARN)
    return
  end

  local rel_path = vim.fn.fnamemodify(file_path, ":.")
  if copy_to_clipboard(rel_path, "relative path (to cwd)") then
    picker:close()
  end
end

-- Picker action: Copy absolute path
function M.copy_path_absolute(picker, item)
  local file_path = get_item_path(item)
  if not file_path then
    vim.notify("No file path found", vim.log.levels.WARN)
    return
  end

  local abs_path = vim.fn.fnamemodify(file_path, ":p")
  if copy_to_clipboard(abs_path, "absolute path") then
    picker:close()
  end
end

-- Picker action: Open Snacks picker to choose copy format with preview
function M.copy_path_select(picker, item)
  local file_path = get_item_path(item)
  if not file_path then
    vim.notify("No file path found", vim.log.levels.WARN)
    return
  end

  local formats = generate_path_formats(file_path)

  -- Filter out invalid paths and prepare picker items
  local picker_items = {}
  for _, format in ipairs(formats) do
    if format.path and format.path ~= "" then
      table.insert(picker_items, {
        text = format.label,
        path = format.path,
        label = format.label,
        key = format.key,
      })
    end
  end

  if #picker_items == 0 then
    vim.notify("No valid path formats available", vim.log.levels.WARN)
    return
  end

  -- Store the parent picker to close it after selection
  local parent_picker = picker

  Snacks.picker.pick({
    source = "path_formats",
    title = "Select Path Format to Copy",
    items = picker_items,
    format = function(picker_item)
      return {
        { picker_item.label, "SnacksPickerTitle" },
        { picker_item.path, "Normal" },
      }
    end,
    preview = function(ctx)
      local picker_item = ctx.item
      if not picker_item then
        return false
      end

      -- Build preview showing the path that will be copied
      local lines = {
        "Path Format: " .. picker_item.label,
        "",
        "Path to copy:",
        picker_item.path,
        "",
        "---",
        "",
        "Press <CR> to copy to clipboard",
      }

      -- Write into the preview buffer
      if ctx.buf and vim.api.nvim_buf_is_valid(ctx.buf) then
        vim.api.nvim_buf_set_option(ctx.buf, "modifiable", true)
        vim.api.nvim_buf_set_lines(ctx.buf, 0, -1, false, lines)
        vim.api.nvim_buf_set_option(ctx.buf, "modifiable", false)
        vim.bo[ctx.buf].filetype = "text"
        return true
      end

      return false
    end,
    confirm = function(format_picker, selected_item)
      format_picker:close()
      if selected_item and copy_to_clipboard(selected_item.path, selected_item.label) then
        parent_picker:close()
      end
    end,
  })
end

-- Export path copy actions
M.path_copy_actions = {
  copy_path_relative_buffer = M.copy_path_relative_buffer,
  copy_path_relative_git = M.copy_path_relative_git,
  copy_path_relative_cwd = M.copy_path_relative_cwd,
  copy_path_absolute = M.copy_path_absolute,
  copy_path_select = M.copy_path_select,
}

--#endregion Path Copy Utilities

return M
