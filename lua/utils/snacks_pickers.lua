-- Snacks Picker utilities
-- Custom snacks pickers extracted from snacks_terminal.lua
-- Includes: session picker, tmux picker, git pickers, change list picker

local M = {}

local git_util = require "utils.git"
local term_util = require "utils.term_util"
local clipboardUtil = require "utils.myinput"
local uv = vim.uv or vim.loop

local function resolve_item_path(item, fallback_cwd)
  local file = item and (item.file or item.text) or nil
  if not file or file == "" then
    return nil
  end

  if file:match "^%a:[/\\]" or file:sub(1, 1) == "/" then
    return file
  end

  local cwd = item.cwd or fallback_cwd
  if not cwd or cwd == "" then
    return file
  end

  return cwd .. "/" .. file
end

local function is_missing_file(item, fallback_cwd)
  local path = resolve_item_path(item, fallback_cwd)
  if not path then
    return false
  end
  return uv.fs_stat(path) == nil
end

local function should_keep_item(item, fallback_cwd, filter_missing, show_missing)
  if filter_missing == false then
    return true
  end

  if show_missing then
    return true
  end

  return not is_missing_file(item, fallback_cwd)
end

local function with_external_actions(actions)
  return vim.tbl_extend("force", actions or {}, {
    toggle_external = function(picker)
      require("utils.snacks_actions").toggle_external(picker)
    end,
  })
end

local function build_git_status_map(base_ref)
  local file_status_map = {}
  if not base_ref or base_ref == "" then
    return file_status_map
  end

  local status_output = vim.fn.systemlist {
    "git",
    "diff",
    "--name-status",
    base_ref .. "..HEAD",
  }

  if vim.v.shell_error == 0 then
    for _, line in ipairs(status_output) do
      if line ~= "" then
        -- Parse status format: "M\tfile.lua" or "A\tfile.lua" or "D\tfile.lua"
        local status, file = line:match "^(%a)%s+(.+)$"
        if status and file then
          file_status_map[file] = status
        end
      end
    end
  end

  return file_status_map
end

local function git_status_formatter(file_status_map)
  return function(item)
    local file = item.file or item.text or ""
    if file == "" then
      return "file"
    end

    local status = file_status_map[file] or "M"
    local status_icons = {
      A = { icon = "[A]", hl = "DiagnosticOk" },
      M = { icon = "[M]", hl = "DiagnosticInfo" },
      D = { icon = "[D]", hl = "DiagnosticError" },
      R = { icon = "[R]", hl = "DiagnosticWarn" },
      C = { icon = "[C]", hl = "DiagnosticWarn" },
      T = { icon = "[T]", hl = "Comment" },
    }

    local status_info = status_icons[status] or { icon = "[?]", hl = "Comment" }

    return {
      { status_info.icon .. " ", status_info.hl },
      { file, "SnacksPickerFile" },
    }
  end
end

local function preview_git_diff_with_base(base_ref)
  return function(ctx)
    if not base_ref or base_ref == "" then
      return require("snacks.picker.preview").git_diff(ctx)
    end

    if not ctx or not ctx.item or not ctx.item.file or ctx.item.file == "" then
      return require("snacks.picker.preview").none(ctx)
    end

    local cmd = { "git", "--no-pager" }
    local extra_args = ctx.picker
      and ctx.picker.opts
      and ctx.picker.opts.previewers
      and ctx.picker.opts.previewers.git
      and ctx.picker.opts.previewers.git.args
    if extra_args then
      vim.list_extend(cmd, extra_args)
    end

    vim.list_extend(cmd, { "diff", base_ref .. "..HEAD", "--", ctx.item.file })
    return require("snacks.picker.preview").cmd(cmd, ctx, { ft = "diff" })
  end
end

local function debug_external_filter(ctx, item, info)
  if not vim.g.snacks_debug_external_filter then
    return
  end
  local source = ctx and ctx.picker and (ctx.picker.opts.source or ctx.picker.source) or "picker"
  local file = item and item.file or item and item.text or "nil"
  print(string.format("external_filter[%s]: %s | file=%s", tostring(source), info or "", tostring(file)))
end

--#region Session Picker (migrated from fzf-lua)

--- Session picker using snacks
--- Lists sessions from vim.g.startify_session_dir
--- Actions:
---   - confirm (Enter): SLoad <session>
---   - save_session (C-s): SSave! <session> using query or selection
---   - delete_session (C-x): SDelete! <session> with confirmation
function M.session_picker()
  local session_dir = vim.g.startify_session_dir or "~/.config/nvim/session"
  -- Expand tilde before checking directory
  session_dir = vim.fn.expand(session_dir)

  -- Ensure session directory exists
  if vim.fn.isdirectory(session_dir) == 0 then
    vim.notify("Session directory does not exist: " .. session_dir, vim.log.levels.WARN)
    return
  end

  -- Helper function to scan sessions
  local function scan_sessions()
    local sessions = {}
    local handle = vim.loop.fs_scandir(session_dir)
    if handle then
      while true do
        local name, type = vim.loop.fs_scandir_next(handle)
        if not name then
          break
        end
        if type == "file" and name:match "^[%a%d][%w_]*$" then
          table.insert(sessions, {
            text = name,
            file = session_dir .. "/" .. name,
          })
        end
      end
    end
    return sessions
  end

  -- Initial scan
  local initial_sessions = scan_sessions()
  if #initial_sessions == 0 then
    vim.notify("No sessions found in: " .. session_dir, vim.log.levels.INFO)
    return
  end

  Snacks.picker.pick {
    source = "sessions",
    title = "Sessions (C-s: save, C-x: delete)",
    finder = function(_opts, _ctx)
      local sessions = scan_sessions()
      return sessions
    end,
    format = "text",
    layout = {
      preset = "select",
    },
    actions = {
      save_session = function(picker, item)
        local query = picker.input.filter and picker.input.filter.pattern or ""
        local session_name = (query ~= "" and query) or (item and item.text) or ""

        if session_name == "" then
          vim.ui.input({ prompt = "Save Session As: " }, function(input)
            if input and input ~= "" then
              vim.cmd("SSave! " .. input)
              vim.notify("Session Saved: " .. input, vim.log.levels.INFO)
              vim.defer_fn(function()
                picker:refresh()
              end, 100)
            end
          end)
        else
          vim.cmd("SSave! " .. session_name)
          vim.notify("Session Saved: " .. session_name, vim.log.levels.INFO)
          vim.defer_fn(function()
            picker:refresh()
          end, 100)
        end
      end,
      delete_session = function(picker, item)
        if not item then
          vim.notify("No session selected", vim.log.levels.WARN)
          return
        end
        local session = item.text
        vim.ui.select({ "Yes", "No" }, {
          prompt = "Delete session '" .. session .. "'?",
        }, function(choice)
          if choice == "Yes" then
            vim.cmd("SDelete! " .. session)
            vim.notify("Session Deleted: " .. session, vim.log.levels.INFO)
            vim.defer_fn(function()
              picker:refresh()
            end, 100)
          end
        end)
      end,
    },
    win = {
      input = {
        keys = {
          ["<C-s>"] = { "save_session", mode = { "n", "i" }, desc = "Save session" },
          ["<C-x>"] = { "delete_session", mode = { "n", "i" }, desc = "Delete session" },
        },
      },
    },
    confirm = function(picker, item)
      picker:close()
      if item then
        vim.cmd("SLoad " .. item.text)
      end
    end,
  }
end

--#endregion Session Picker

--#region Tmux Picker

local function _get_tmux_windows()
  local windows_raw = vim.fn.system "tmux list-windows -F '#{window_index}: #{window_name}'"
  local windows = {}

  for window in windows_raw:gmatch "[^\r\n]+" do
    table.insert(windows, { text = window })
  end

  return windows
end

function M.pick_tmux_window()
  local windows = _get_tmux_windows()

  Snacks.picker.pick {
    source = "tmux_windows",
    items = windows,
    format = "text",
    layout = {
      preset = "vscode",
    },
    confirm = function(picker, item)
      picker:close()
      local window_index = item.text:match "^(%d+):"
      if window_index then
        vim.fn.system(string.format("tmux select-window -t %s", window_index))
      end
    end,
  }
end

--#endregion Tmux Picker

--#region Git Pickers

--- Generic command result picker factory
--- @param picker_opts table Configuration for the picker
---   - cmd: string Command to run
---   - args: table Command arguments
---   - name: string Source name
---   - title: string Picker title
---   - preview: string|function Preview configuration
---   - actions: table Custom actions
---   - win: table Window configuration
---   - cwd: string|nil Working directory
local function pick_cmd_result(picker_opts)
  local git_root = Snacks.git.get_root()
  local function finder(opts, ctx)
    local show_missing = opts.external == true
    local proc_opts = vim.tbl_extend("force", opts, {
      cmd = picker_opts.cmd,
      args = picker_opts.args,
      transform = function(item)
        item.cwd = picker_opts.cwd or git_root
        item.file = item.text
        local missing = is_missing_file(item, item.cwd)
        local keep = should_keep_item(item, item.cwd, picker_opts.filter_missing, show_missing)
        debug_external_filter(
          ctx,
          item,
          string.format("show_missing=%s missing=%s keep=%s", tostring(show_missing), tostring(missing), tostring(keep))
        )
        if not keep then
          return false
        end
        return item
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

  if picker_opts.preview then
    pick_opts.preview = picker_opts.preview
  end

  pick_opts.actions = with_external_actions(picker_opts.actions)
  if picker_opts.toggles then
    pick_opts.toggles = picker_opts.toggles
  end
  if picker_opts.external == nil then
    pick_opts.external = false
  else
    pick_opts.external = picker_opts.external
  end

  if picker_opts.win then
    pick_opts.win = picker_opts.win
  end

  Snacks.picker.pick(pick_opts)
end

-- Custom Git Pickers
M.custom_git_pickers = {}

--- Git last commit files picker with increment/decrement support
--- Shows files changed between HEAD~N and HEAD (range diff)
--- Use <C-j>/<C-k> to adjust the base ref (never goes below HEAD~1)
--- Example: HEAD~1..HEAD -> <C-k> -> HEAD~2..HEAD -> <C-k> -> HEAD~3..HEAD
function M.custom_git_pickers.git_last_commit_show()
  local editor_keymaps = require "utils.editor_keymaps"
  local git_root = Snacks.git.get_root()

  -- State management for range navigation
  -- base_offset represents N in HEAD~N, minimum is 1
  local state = {
    base_offset = 1, -- Start at HEAD~1..HEAD
    max_offset = 100, -- Maximum history depth
  }

  -- Get the base ref string (e.g., "HEAD~3")
  local function get_base_ref()
    return "HEAD~" .. state.base_offset
  end

  -- Get formatted display for the range
  -- Format: <[branch]:shorthash>..<HEAD:shorthash> (N commits)
  local function get_range_display()
    local base_ref = get_base_ref()
    local base_short = git_util.get_short_hash(base_ref)
    local base_branch = git_util.get_ref_branch_name(base_ref)
    local head_short = git_util.get_short_hash("HEAD")

    -- Build base display: branch:hash or just hash
    local base_display = base_branch ~= "" and (base_branch .. ":" .. base_short) or base_short
    local head_display = head_short ~= "" and head_short or "HEAD"
    local commit_count = state.base_offset

    return base_display .. ".." .. head_display .. " (" .. commit_count .. " commits)"
  end

  -- Get file count for current range
  local function get_file_count()
    local cmd = "git diff --name-only --diff-filter=d " .. get_base_ref() .. "..HEAD | wc -l"
    return vim.fn.system(cmd):gsub("\n", "")
  end

  -- Navigate forward (decrease offset, closer to HEAD, but never below 1)
  local function move_range_forward()
    if state.base_offset <= 1 then
      vim.notify("Already at HEAD~1 (minimum range)", vim.log.levels.WARN)
      return
    end

    state.base_offset = state.base_offset - 1
    local display = get_range_display()
    local file_count = get_file_count()
    vim.notify("Range: " .. display .. " (" .. file_count .. " changed files)", vim.log.levels.INFO)

    -- Get the real picker using Snacks.picker.get() since key callbacks receive snacks.win, not picker
    local pickers = Snacks.picker.get({ source = "git_show" })
    local picker = pickers[1]
    if picker then
      vim.schedule(function()
        picker.title = display
        picker:update_titles()
        picker:refresh()
      end)
    end
  end

  -- Navigate backward (increase offset, further from HEAD)
  local function move_range_backward()
    if state.base_offset >= state.max_offset then
      vim.notify("Already at maximum history depth", vim.log.levels.WARN)
      return
    end

    -- Verify the commit exists before incrementing
    local next_ref = "HEAD~" .. (state.base_offset + 1)
    vim.fn.system("git rev-parse --verify " .. next_ref .. " 2>/dev/null")
    if vim.v.shell_error ~= 0 then
      vim.notify("No more commits in history", vim.log.levels.WARN)
      return
    end

    state.base_offset = state.base_offset + 1
    local display = get_range_display()
    local file_count = get_file_count()
    vim.notify("Range: " .. display .. " (" .. file_count .. " changed files)", vim.log.levels.INFO)

    -- Get the real picker using Snacks.picker.get() since key callbacks receive snacks.win, not picker
    local pickers = Snacks.picker.get({ source = "git_show" })
    local picker = pickers[1]
    if picker then
      vim.schedule(function()
        picker.title = display
        picker:update_titles()
        picker:refresh()
      end)
    end
  end

  -- Custom actions for this range
  local custom_actions = {
    open_file_diff = function(picker, item)
      if not item or not item.file then
        vim.notify("No file selected", vim.log.levels.WARN)
        return
      end
      local base_ref = get_base_ref()
      vim.notify("DEBUG: open_file_diff - file=" .. item.file .. ", base_ref=" .. base_ref, vim.log.levels.INFO)
      picker:close()
      git_util.open_file_with_gitsigns_diff(item.file, base_ref)
    end,
    open_remote_at_ref = function(picker, item)
      if not item or not item.file then
        vim.notify("No file selected", vim.log.levels.WARN)
        return
      end
      git_util.open_file_in_remote(item.file, "HEAD")
    end,
  }

  local git_keys = editor_keymaps.snacks_picker_group_keys.git_file_keys

  Snacks.picker.pick {
    source = "git_show",
    title = get_range_display(),
    finder = function(opts, ctx)
      local base_ref = get_base_ref()
      local file_status_map = build_git_status_map(base_ref)
      local proc_opts = vim.tbl_extend("force", opts, {
        cmd = "git",
        args = { "diff", "--name-only", "--diff-filter=d", base_ref .. "..HEAD" },
        cwd = git_root,
        transform = function(item)
          item.cwd = git_root
          item.file = item.text
          local keep = should_keep_item(item, git_root, true, false)
          if not keep then
            return false
          end
          return item
        end,
      })
      return require("snacks.picker.source.proc").proc(proc_opts, ctx)
    end,
    format = function(item)
      local file_status_map = build_git_status_map(get_base_ref())
      return git_status_formatter(file_status_map)(item)
    end,
    preview = function(ctx)
      return preview_git_diff_with_base(get_base_ref())(ctx)
    end,
    actions = with_external_actions(custom_actions),
    win = {
      input = {
        footer = "<C-j> shrink range • <C-k> expand range",
        keys = vim.tbl_extend("force", git_keys.input, {
          ["<C-j>"] = {
            function()
              move_range_forward()
            end,
            mode = { "n", "i" },
            desc = "Shrink range (closer to HEAD)",
          },
          ["<C-k>"] = {
            function()
              move_range_backward()
            end,
            mode = { "n", "i" },
            desc = "Expand range (further from HEAD)",
          },
        }),
      },
      list = {
        keys = vim.tbl_extend("force", git_keys.list, {
          ["<C-j>"] = {
            function()
              move_range_forward()
            end,
            mode = { "n", "i" },
            desc = "Shrink range (closer to HEAD)",
          },
          ["<C-k>"] = {
            function()
              move_range_backward()
            end,
            mode = { "n", "i" },
            desc = "Expand range (further from HEAD)",
          },
        }),
      },
    },
  }
end

--- Git diff upstream picker
--- Shows files changed between upstream and HEAD
--- Automatically detects upstream reference
function M.custom_git_pickers.git_diff_upstream()
  local editor_keymaps = require "utils.editor_keymaps"
  local upstream_ref = nil

  -- Step 1: Check if branch has an upstream (HEAD@{u})
  vim.fn.systemlist { "git", "rev-parse", "--verify", "HEAD@{u}" }
  local has_upstream = (vim.v.shell_error == 0)

  if has_upstream then
    -- git diff-tree --no-commit-id --name-only --diff-filter=d HEAD@{u}..HEAD -r
    -- git diff --no-commit-id --diff-filter=d HEAD@{u}..HEAD -r
    local diff_output = vim.fn.systemlist {
      "git",
      "diff-tree",
      "--no-commit-id",
      "--name-only",
      "--diff-filter=d",
      "HEAD@{u}..HEAD",
      "-r",
    }
    local has_changes = (vim.v.shell_error == 0 and #diff_output > 0 and diff_output[1] ~= "")

    if has_changes then
      upstream_ref = "HEAD@{u}"
    end
  end

  -- Step 2: If no upstream or no changes, try update-refs or local branches
  if not upstream_ref then
    local origin_default = nil
    local default_branch_cmd = vim.fn.systemlist { "git", "symbolic-ref", "refs/remotes/origin/HEAD", "--short" }
    if vim.v.shell_error == 0 and default_branch_cmd[1] and default_branch_cmd[1] ~= "" then
      origin_default = default_branch_cmd[1]
    end

    -- Check for update-refs
    local update_refs = vim.fn.systemlist { "git", "for-each-ref", "--format=%(refname:short)", "refs/rewritten/" }
    if vim.v.shell_error == 0 and #update_refs > 0 then
      upstream_ref = update_refs[#update_refs]
    end

    -- Check if any local branch tip matches origin default
    if not upstream_ref and origin_default then
      local origin_sha = vim.fn.systemlist({ "git", "rev-parse", origin_default })[1]
      if vim.v.shell_error == 0 and origin_sha then
        local local_branches =
          vim.fn.systemlist { "git", "for-each-ref", "--format=%(refname:short) %(objectname)", "refs/heads/" }
        for _, branch_line in ipairs(local_branches) do
          local branch_name, branch_sha = branch_line:match "^(%S+)%s+(%S+)$"
          if branch_sha == origin_sha then
            upstream_ref = branch_name
            break
          end
        end
      end
    end

    -- Try local branch with same name as origin default
    if not upstream_ref and origin_default then
      local local_branch_name = origin_default:match "^origin/(.+)$"
      if local_branch_name then
        vim.fn.systemlist { "git", "rev-parse", "--verify", local_branch_name }
        if vim.v.shell_error == 0 then
          upstream_ref = local_branch_name
        end
      end
    end
  end

  -- Step 3: Final fallback
  if not upstream_ref then
    local default_branch_cmd = vim.fn.systemlist { "git", "symbolic-ref", "refs/remotes/origin/HEAD", "--short" }
    if vim.v.shell_error == 0 and default_branch_cmd[1] and default_branch_cmd[1] ~= "" then
      upstream_ref = default_branch_cmd[1]
    else
      vim.fn.systemlist { "git", "rev-parse", "--verify", "origin/main" }
      if vim.v.shell_error == 0 then
        upstream_ref = "origin/main"
      else
        vim.fn.systemlist { "git", "rev-parse", "--verify", "origin/master" }
        if vim.v.shell_error == 0 then
          upstream_ref = "origin/master"
        else
          upstream_ref = "HEAD~1"
          vim.notify("No upstream or origin default branch found, comparing with HEAD~1", vim.log.levels.WARN)
        end
      end
    end
  end

  local captured_ref = upstream_ref
  local actions = editor_keymaps.snacks_action_factories.create_git_file_actions(captured_ref, false)
  local git_keys = editor_keymaps.snacks_picker_group_keys.git_file_keys_upstream
  local ref_metadata = git_util.get_ref_metadata(upstream_ref)
  local base_ref = ref_metadata and ref_metadata.resolved_with_remote or upstream_ref
  local file_status_map = build_git_status_map(base_ref)

  pick_cmd_result {
    cmd = "git",
    args = { "diff-tree", "--no-commit-id", "--name-only", "--diff-filter=d", base_ref .. "..HEAD", "-r" },
    name = "git_diff_upstream",
    title = "Git Branch Changed Files (vs " .. base_ref .. ")",
    preview = preview_git_diff_with_base(base_ref),
    actions = actions,
    win = {
      input = {
        keys = git_keys.input,
      },
      list = {
        keys = git_keys.list,
      },
    },
    format = git_status_formatter(file_status_map),
  }
end

--#endregion Git Pickers

--#region Custom Change List Picker (Two-stage ref comparison)

-- Helper function to get stats for a ref comparison
local function get_ref_stats(ref)
  local stats = {
    refAlias = ref,
    ref = ref,
    fullRef = nil,
    branch = nil,
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

  local metadata = git_util.get_ref_metadata(ref)
  if not metadata or not metadata.valid then
    return stats
  end

  stats.valid = metadata.valid
  stats.fullRef = metadata.fullref
  stats.branch = metadata.branch
  stats.refSha = metadata.sha
  stats.ref = metadata.ref

  -- Get file stats
  local diff_stat = vim.fn.systemlist { "git", "diff", "--numstat", ref .. "..HEAD" }
  if vim.v.shell_error == 0 then
    for _, line in ipairs(diff_stat) do
      if line ~= "" then
        local added, deleted = line:match "^(%d+)%s+(%d+)"
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
  local diff_name_status = vim.fn.systemlist { "git", "diff", "--name-status", ref .. "..HEAD" }
  if vim.v.shell_error == 0 then
    for _, line in ipairs(diff_name_status) do
      local status = line:match "^(%a)"
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

  local function add_candidate(refAlias, priority, ref_type)
    if not seen_refs[refAlias] then
      local stats = get_ref_stats(refAlias)
      if stats.valid then
        stats.priority = priority
        stats.ref_type = ref_type or "other"
        table.insert(candidates, stats)
        seen_refs[refAlias] = true
      end
    end
  end

  -- 1. Update-ref furthest base (rebase/autosquash base)
  local update_refs = vim.fn.systemlist { "git", "for-each-ref", "--format=%(refname:short)", "refs/rewritten/" }
  if vim.v.shell_error == 0 and #update_refs > 0 then
    add_candidate(update_refs[#update_refs], 1, "rebase-base")
  end

  -- 2. Other local branches
  local current_branch = vim.fn.systemlist({ "git", "branch", "--show-current" })[1]
  local origin_default = vim.fn.systemlist({ "git", "symbolic-ref", "refs/remotes/origin/HEAD", "--short" })[1]
  local origin_default_local = origin_default and origin_default:match "^origin/(.+)$"

  local local_branches = vim.fn.systemlist { "git", "for-each-ref", "--format=%(refname:short)", "refs/heads/" }
  if vim.v.shell_error == 0 then
    for _, branch in ipairs(local_branches) do
      if branch ~= current_branch and branch ~= origin_default_local then
        vim.fn.systemlist { "git", "merge-base", "--is-ancestor", branch, "HEAD" }
        if vim.v.shell_error == 0 then
          local commit_count_output = vim.fn.systemlist { "git", "rev-list", "--count", branch .. "..HEAD" }
          if vim.v.shell_error == 0 and commit_count_output[1] then
            local commit_distance = tonumber(commit_count_output[1])
            if commit_distance and commit_distance <= 20 then
              add_candidate(branch, 2, "local")
            end
          end
        end
      end
    end
  end

  -- 3. HEAD@{u} (upstream tracking branch)
  add_candidate("HEAD@{u}", 3, "upstream")

  -- 4. Origin default local branch
  if origin_default_local then
    add_candidate(origin_default_local, 4, "default")
  end

  -- 5. Origin default branch (remote)
  if origin_default then
    add_candidate(origin_default, 5, "default")
  else
    add_candidate("origin/main", 5, "default")
    add_candidate("origin/master", 5, "default")
  end

  -- 6. HEAD~1 (fallback)
  add_candidate("HEAD~1", 6, "previous")

  table.sort(candidates, function(a, b)
    return a.priority < b.priority
  end)

  return candidates
end

-- Step 2: File list picker for selected ref with increment/decrement base ref
local function show_file_list_picker(selected_ref_stats, on_back)
  local editor_keymaps = require "utils.editor_keymaps"
  local git_root = Snacks.git.get_root()
  local ref_metadata = git_util.get_ref_metadata(selected_ref_stats.refAlias)
  local initial_base_ref = ref_metadata and ref_metadata.resolved_with_remote or selected_ref_stats.refAlias

  -- State management for base_ref navigation
  local state = {
    current_base_ref = initial_base_ref,
    initial_base_ref = initial_base_ref,
    commits_history = nil, -- Will be populated lazily
  }

  -- Utility: Update commit history cache
  local function update_commits_history()
    state.commits_history = git_util.get_commits_between(state.initial_base_ref, "HEAD")
  end

  -- Utility: Get formatted display string for base ref (branch or short hash)
  local function get_base_ref_display()
    local display = git_util.format_ref_display(state.current_base_ref)
    local short_hash = git_util.get_short_hash(state.current_base_ref)
    if short_hash and short_hash ~= "" then
      local branch = git_util.get_ref_branch_name(state.current_base_ref)
      if branch and branch ~= "" then
        return branch .. " (" .. short_hash .. ")"
      else
        return short_hash
      end
    end
    return display
  end

  -- Utility: Get range display for titles: [branch]:hash..HEAD:hash (N commits)
  local function get_range_display(from_ref)
    local from_short = git_util.get_short_hash(from_ref)
    local from_branch = git_util.get_ref_branch_name(from_ref)
    local head_short = git_util.get_short_hash("HEAD")

    -- Build from_display: [branch]:hash or just hash
    local from_display = from_branch ~= "" and ("[" .. from_branch .. "]:" .. from_short) or from_short
    -- Always include HEAD: prefix for consistency
    local head_display = "HEAD:" .. head_short

    -- Get commit count between refs
    local commit_count = vim.fn.system("git rev-list --count " .. from_ref .. "..HEAD"):gsub("\n", "")
    commit_count = tonumber(commit_count) or 0

    return from_display .. ".." .. head_display .. " (" .. commit_count .. " commits)"
  end

  -- Utility: Move base_ref forward (towards HEAD, closer commits)
  local function move_base_ref_forward()
    if not state.commits_history then
      update_commits_history()
    end

    local commits = state.commits_history
    if not commits or #commits == 0 then
      vim.notify("No commits to move forward", vim.log.levels.WARN)
      return
    end

    -- Find current base_ref in the commits history
    local current_idx = nil
    local current_sha = vim.fn.system("git rev-parse " .. state.current_base_ref):gsub("\n", "")

    for i, commit in ipairs(commits) do
      if commit:sub(1, #current_sha) == current_sha then
        current_idx = i
        break
      end
    end

    if not current_idx then
      -- Base ref not in history, start from the end (closest to HEAD)
      current_idx = #commits
    end

    -- Move forward (decrease index, closer to HEAD)
    if current_idx > 1 then
      state.current_base_ref = commits[current_idx - 1]
      local new_display = get_base_ref_display()
      local cmd = "git diff --name-only --diff-filter=d " .. state.current_base_ref .. "..HEAD"
      local file_count = vim.fn.system(cmd .. " | wc -l"):gsub("\n", "")
      vim.notify("Ref: " .. new_display .. " (" .. file_count .. " changed files)", vim.log.levels.INFO)
      -- Get the real picker using Snacks.picker.get() since key callbacks receive snacks.win, not picker
      local pickers = Snacks.picker.get({ source = "git_diff_files" })
      local picker = pickers[1]
      if picker then
        vim.schedule(function()
          picker.title = "Changed files (" .. get_range_display(state.current_base_ref) .. ")"
          picker:update_titles()
          picker:refresh()
        end)
      end
    else
      vim.notify("Already at HEAD", vim.log.levels.WARN)
    end
  end

  -- Utility: Move base_ref backward (away from HEAD, further commits)
  local function move_base_ref_backward()
    if not state.commits_history then
      update_commits_history()
    end

    local commits = state.commits_history
    if not commits or #commits == 0 then
      vim.notify("No commits to move backward", vim.log.levels.WARN)
      return
    end

    -- Find current base_ref in the commits history
    local current_idx = nil
    local current_sha = vim.fn.system("git rev-parse " .. state.current_base_ref):gsub("\n", "")

    for i, commit in ipairs(commits) do
      if commit:sub(1, #current_sha) == current_sha then
        current_idx = i
        break
      end
    end

    if not current_idx then
      -- Base ref not in history, start from beginning
      current_idx = 1
    end

    -- Move backward (increase index, further from HEAD)
    if current_idx < #commits then
      state.current_base_ref = commits[current_idx + 1]
      local new_display = get_base_ref_display()
      local cmd = "git diff --name-only --diff-filter=d " .. state.current_base_ref .. "..HEAD"
      local file_count = vim.fn.system(cmd .. " | wc -l"):gsub("\n", "")
      vim.notify("Ref: " .. new_display .. " (" .. file_count .. " changed files)", vim.log.levels.INFO)
      -- Get the real picker using Snacks.picker.get() since key callbacks receive snacks.win, not picker
      local pickers = Snacks.picker.get({ source = "git_diff_files" })
      local picker = pickers[1]
      if picker then
        vim.schedule(function()
          picker.title = "Changed files (" .. get_range_display(state.current_base_ref) .. ")"
          picker:update_titles()
          picker:refresh()
        end)
      end
    else
      vim.notify("Already at base ref", vim.log.levels.WARN)
    end
  end

  -- Custom actions that dynamically reference current base_ref
  local custom_actions = {
    open_file_diff = function(picker, item)
      if not item or not item.file then
        vim.notify("No file selected", vim.log.levels.WARN)
        return
      end
      picker:close()
      git_util.open_file_with_gitsigns_diff(item.file, state.current_base_ref)
    end,
    open_remote_at_ref = function(picker, item)
      if not item or not item.file then
        vim.notify("No file selected", vim.log.levels.WARN)
        return
      end
      git_util.open_file_in_remote(item.file, state.current_base_ref)
    end,
    open_remote_at_head = function(picker, item)
      if not item or not item.file then
        vim.notify("No file selected", vim.log.levels.WARN)
        return
      end
      git_util.open_file_in_remote(item.file, "HEAD")
    end,
  }

  local git_keys = editor_keymaps.snacks_picker_group_keys.git_file_keys_with_back(on_back)

  local range_display = get_range_display(initial_base_ref)
  local ref_type_label = ref_metadata and ref_metadata.resolve_ref_type ~= "unknown"
      and " (" .. ref_metadata.resolve_ref_type .. ")"
    or ""

  Snacks.picker.pick {
    source = "git_diff_files",
    title = "Changed files (" .. range_display .. ")" .. ref_type_label,
    external = false,
    finder = function(opts, ctx)
      local show_missing = opts.external == true
      local file_status_map = build_git_status_map(state.current_base_ref)
      local proc_opts = vim.tbl_extend("force", opts, {
        cmd = "git",
        args = { "diff", "--name-only", "--diff-filter=d", state.current_base_ref .. "..HEAD" },
        cwd = git_root,
        transform = function(item)
          item.cwd = git_root
          item.file = item.text
          local missing = is_missing_file(item, git_root)
          local keep = should_keep_item(item, git_root, true, show_missing)
          debug_external_filter(
            ctx,
            item,
            string.format(
              "show_missing=%s missing=%s keep=%s",
              tostring(show_missing),
              tostring(missing),
              tostring(keep)
            )
          )
          if not keep then
            return false
          end
          return item
        end,
      })
      return require("snacks.picker.source.proc").proc(proc_opts, ctx)
    end,
    format = function(item)
      local file_status_map = build_git_status_map(state.current_base_ref)
      return git_status_formatter(file_status_map)(item)
    end,
    preview = function(ctx)
      return preview_git_diff_with_base(state.current_base_ref)(ctx)
    end,
    actions = with_external_actions(custom_actions),
    win = {
      input = {
        footer = "<C-h> back • <C-j> next ref • <C-k> prev ref",
        keys = vim.tbl_extend("force", git_keys.input, {
          ["<C-j>"] = {
            function()
              move_base_ref_forward()
            end,
            mode = { "n", "i" },
            desc = "Next commit (closer to HEAD)",
          },
          ["<C-k>"] = {
            function()
              move_base_ref_backward()
            end,
            mode = { "n", "i" },
            desc = "Previous commit (away from HEAD)",
          },
        }),
      },
      list = {
        keys = vim.tbl_extend("force", git_keys.list, {
          ["<C-j>"] = {
            function()
              move_base_ref_forward()
            end,
            mode = { "n", "i" },
            desc = "Next commit (closer to HEAD)",
          },
          ["<C-k>"] = {
            function()
              move_base_ref_backward()
            end,
            mode = { "n", "i" },
            desc = "Previous commit (away from HEAD)",
          },
        }),
      },
    },
  }
end

--- Two-stage ref comparison picker
--- Step 1: Select a reference to compare against
--- Step 2: Browse changed files with that reference
function M.custom_change_list_picker()
  local candidates = collect_candidate_refs()

  if #candidates == 0 then
    vim.notify("No valid refs found for comparison", vim.log.levels.WARN)
    return
  end

  local picker_items = {}
  for _, candidate in ipairs(candidates) do
    table.insert(picker_items, {
      text = candidate.text,
      refAlias = candidate.refAlias,
      ref = candidate.ref,
      branch = candidate.branch,
      fullRef = candidate.fullRef,
      refSha = candidate.refSha,
      priority = candidate.priority,
      ref_type = candidate.ref_type,
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

  -- Ref type display badges with colors
  local ref_type_badges = {
    ["rebase-base"] = { label = "rebase", hl = "DiagnosticWarn" },
    ["upstream"] = { label = "upstream", hl = "DiagnosticInfo" },
    ["default"] = { label = "default", hl = "DiagnosticOk" },
    ["local"] = { label = "local", hl = "Comment" },
    ["previous"] = { label = "prev", hl = "Comment" },
    ["other"] = { label = "", hl = "Comment" },
  }

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
    return (#meta > 0) and table.concat(meta, " | ") or ""
  end

  local current_branch_ref = vim.fn.systemlist({ "git", "branch", "--show-current" })[1] or "HEAD"

  Snacks.picker.pick {
    source = "git_refs",
    title = "Select Reference to Compare vs (" .. current_branch_ref .. ")",
    items = picker_items,
    format = function(item)
      local meta_text = getMetaText(item)
      local refShow = nil
      if item.refAlias ~= item.ref then
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

      -- Build formatted output with ref type badge
      local badge = ref_type_badges[item.ref_type] or ref_type_badges["other"]
      local result = {}

      -- Add ref type badge if present
      if badge.label and badge.label ~= "" then
        table.insert(result, { "[" .. badge.label .. "] ", badge.hl })
      end

      table.insert(result, { refShow, "SnacksPickerTitle" })
      table.insert(result, { " ", "Comment" })
      table.insert(result, { meta_text, "Comment" })

      return result
    end,
    preview = function(ctx)
      local item = ctx and ctx.item
      if not item or not item.refAlias then
        return nil
      end

      local ref = item.refAlias
      local preview_lines = {}

      vim.list_extend(preview_lines, { "=== Commits ===", "" })
      local meta_text = getMetaText(item)
      if meta_text and meta_text ~= "" then
        vim.list_extend(preview_lines, { meta_text, "" })
      end

      local commit_count_output = vim.fn.systemlist {
        "git",
        "rev-list",
        "--count",
        ref .. "..HEAD",
      }
      local commit_count = tonumber(commit_count_output[1]) or 0

      if commit_count == 0 then
        vim.list_extend(preview_lines, { "No commit changes between " .. ref .. " and HEAD", "" })
      else
        local log_limit = 50
        local log_output = vim.fn.systemlist {
          "git",
          "--no-pager",
          "log",
          "--oneline",
          "--graph",
          "--decorate",
          "-n",
          tostring(log_limit),
          ref .. "..HEAD",
        }
        vim.list_extend(preview_lines, log_output or {})
        if commit_count > log_limit then
          vim.list_extend(preview_lines, {
            "",
            string.format("... and %d more commits (showing first %d)", commit_count - log_limit, log_limit),
          })
        end
      end

      vim.list_extend(preview_lines, { "", "=== Changes ===", "" })

      local file_count = item.fileChangesCount or 0
      if file_count == 0 then
        vim.list_extend(preview_lines, { "No file changes" })
      else
        local stat_output
        if file_count > 100 then
          local cmd = string.format("git --no-pager diff --stat %s..HEAD | head -n 101", vim.fn.shellescape(ref))
          stat_output = vim.fn.systemlist(cmd)
          vim.list_extend(preview_lines, stat_output or {})
          vim.list_extend(preview_lines, {
            "",
            string.format("... and %d more files (showing first 100 for performance)", file_count - 100),
          })
        else
          stat_output = vim.fn.systemlist {
            "git",
            "--no-pager",
            "diff",
            "--stat",
            ref .. "..HEAD",
          }
          vim.list_extend(preview_lines, stat_output or {})
        end
      end

      if ctx.buf and vim.api.nvim_buf_is_valid(ctx.buf) then
        vim.api.nvim_buf_set_option(ctx.buf, "modifiable", true)
        vim.api.nvim_buf_set_lines(ctx.buf, 0, -1, false, preview_lines)
        vim.api.nvim_buf_set_option(ctx.buf, "modifiable", false)
        vim.bo[ctx.buf].filetype = "git"
        return true
      end

      return nil
    end,
    actions = {
      open_gitsigns_diff = function(picker, item)
        if not item or not item.refAlias then
          vim.notify("No reference selected", vim.log.levels.WARN)
          return
        end
        picker:close()
        git_util.open_current_buffer_with_gitsigns_diff(item.refAlias)
      end,
    },
    win = {
      input = {
        keys = {
          ["<C-s>"] = { "open_gitsigns_diff", mode = { "n", "i" }, desc = "Open Gitsigns diff with ref" },
        },
      },
    },
    confirm = function(picker, item)
      picker:close()
      if item then
        show_file_list_picker(item, function()
          M.custom_change_list_picker()
        end)
      end
    end,
  }
end

--#endregion Custom Change List Picker

--#region Terminal Picker

--- Terminal buffer picker
--- Shows all terminal buffers with preview
function M.custom_terminal_show()
  local terminals = term_util.get_terminal_buffers()

  Snacks.picker.pick {
    source = "select",
    title = "Terminal Buffers",
    items = terminals,
    format = function(item, opts)
      return term_util.format_terminal(item, opts)
    end,
    layout = {
      preview = {
        layout = "flex",
      },
      layout = {
        box = "horizontal",
        width = 0.9,
        height = 0.9,
        {
          box = "vertical",
          width = 0.4,
          { win = "input", height = 1 },
          { win = "list" },
        },
        { win = "preview", width = 0.6 },
      },
    },
    actions = {
      confirm = function(picker, item)
        picker:close()
        if item and item.buf then
          vim.api.nvim_set_current_buf(item.buf)
        end
      end,
    },
    win = {
      input = {
        keys = {
          ["<C-Space>"] = {
            "focus_preview",
            mode = { "n", "i" },
            desc = "Focus preview",
          },
          ["<c-x>"] = {
            function(picker, item)
              if item and item.buf then
                vim.api.nvim_buf_delete(item.buf, { force = true })
                picker:refresh()
              end
            end,
            mode = { "n", "i" },
            desc = "Delete terminal buffer",
          },
        },
      },
      list = {
        keys = {
          ["<C-Space>"] = { "focus_preview", desc = "Focus preview" },
          ["<C-x>"] = function(picker, item)
            if item and item.buf then
              vim.api.nvim_buf_delete(item.buf, { force = true })
              picker:refresh()
            end
          end,
        },
      },
    },
  }
end

--#endregion Terminal Picker

--#region Picker State Utilities

--- Get initial picker state with persistent cwd
--- @param pickerOpts table Base picker options to merge with
--- @param opts table Options for state initialization
---   - cwd_default: "git"|"current"|"subproject" Default cwd type
---   - use_previous_cwd_state: boolean Whether to use persisted cwd state
--- @return table Merged picker options with cwd state
function M.get_initial_picker_state(pickerOpts, opts)
  opts = opts or {}
  local cwd_default = opts.cwd_default

  local path = require "utils.path"
  local pathUtil = require "utils.mypath"

  local cwd_defaultmap = {
    git = path.get_root_directory() or Snacks.git.get_root(),
    current = vim.fn.getcwd(),
    subproject = pathUtil.get_sub_project_dir(),
  }

  local cwd = nil
  local cwd_state = vim.g.picker_cwd_cycle_state_value
  local cwd_fallback = cwd_defaultmap[cwd_default]
  local git_root = path.get_root_directory() or Snacks.git.get_root()

  local result = vim.deepcopy(pickerOpts) or {}

  if cwd_state and opts.use_previous_cwd_state ~= false then
    cwd = cwd_state
  else
    if not cwd and not result.cwd and cwd_fallback then
      cwd = cwd_fallback
    end
  end

  local is_cwd_git_ui = git_root and (cwd and cwd == git_root or cwd_defaultmap["current"] == git_root)

  if cwd then
    result.cwd = cwd
  end

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

--#endregion Picker State Utilities

--#region Code Ref Picker

--- Picker for current buffer code references (relative/absolute)
function M.code_ref_picker(opts)
  opts = opts or {}
  local code_ref = require("utils.code_ref")
  local use_visual = opts.visual or false
  local show_char = vim.g.code_ref_show_char_range or false

  local items = code_ref.current_options(show_char, use_visual)
  if not items or #items == 0 then
    vim.notify("No code reference available (missing file path)", vim.log.levels.WARN)
    return
  end

  local hide_col = vim.g.code_ref_hide_col or false
  local char_label
  if use_visual then
    char_label = show_char and " [char: on]" or " [char: off]"
  else
    char_label = hide_col and " [col: hidden]" or " [col: shown]"
  end
  local title = (opts.title or "Code Reference (Enter: copy)") .. char_label

  Snacks.picker.pick {
    source = "code_ref",
    title = title,
    layout = {
      preview = false,
    },
    items = items,
    format = function(item)
      return {
        { item.label, "SnacksPickerTitle" },
        { ": ", "Comment" },
        { item.text, "Normal" },
      }
    end,
    win = {
      input = {
        keys = {
          ["<A-c>"] = {
            function()
              -- In range mode: toggle char range; in non-range mode: toggle hide col
              if use_visual then
                vim.g.code_ref_show_char_range = not (vim.g.code_ref_show_char_range or false)
                vim.notify("Char range: " .. (vim.g.code_ref_show_char_range and "enabled" or "disabled"), vim.log.levels.INFO)
              else
                vim.g.code_ref_hide_col = not (vim.g.code_ref_hide_col or false)
                vim.notify("Column: " .. (vim.g.code_ref_hide_col and "hidden" or "shown"), vim.log.levels.INFO)
              end

              local pickers = Snacks.picker.get({ source = "code_ref" })
              local cur_picker = pickers and pickers[1]
              if cur_picker then
                cur_picker:close()
              end

              -- Reopen with updated items (reads fresh global state)
              vim.schedule(function()
                M.code_ref_picker({ visual = use_visual, title = opts.title })
              end)
            end,
            mode = { "n", "i" },
            desc = "Toggle char/col in references",
          },
        },
      },
    },
    confirm = function(picker, item)
      if not item then
        return
      end
      code_ref.copy_current {
        format = item.format,
        absolute = item.absolute,
        copy_mode = "plus",
        show_char_range = vim.g.code_ref_show_char_range or false,
        visual = use_visual,
      }
      picker:close()
    end,
  }
end

--#endregion Code Ref Picker

-- Export pick_cmd_result for use in other modules
M.pick_cmd_result = pick_cmd_result

return M
