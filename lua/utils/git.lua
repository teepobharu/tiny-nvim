local M = {}

local pathUtil = require "utils.path"

local function trim_system_output(cmd)
  local result = vim.fn.systemlist(cmd)
  if vim.v.shell_error ~= 0 then
    return nil
  end

  local value = result[1]
  if not value or value == "" then
    return nil
  end

  return value
end

function M.git_main_branch()
  local git_dir = vim.fn.system "git rev-parse --git-dir 2> /dev/null"
  if vim.v.shell_error ~= 0 then
    return nil
  end

  local refs = {
    "refs/heads/main",
    "refs/heads/trunk",
    "refs/heads/mainline",
    "refs/heads/default",
    "refs/heads/master",
    "refs/remotes/origin/main",
    "refs/remotes/origin/trunk",
    "refs/remotes/origin/mainline",
    "refs/remotes/origin/default",
    "refs/remotes/origin/master",
    "refs/remotes/upstream/main",
    "refs/remotes/upstream/trunk",
    "refs/remotes/upstream/mainline",
    "refs/remotes/upstream/default",
    "refs/remotes/upstream/master",
  }

  for _, ref in ipairs(refs) do
    local show_ref = vim.fn.system("git show-ref -q --verify " .. ref)
    if vim.v.shell_error == 0 then
      return ref:gsub("^refs/%w+/", "")
    end
  end

  return "master"
end

function M.get_remote_path(upstream)
  if not upstream or upstream == "" then
    upstream = "origin"
  end
  local remote_url = vim.fn.system("git config --get remote." .. upstream .. ".url"):gsub("\n", "")
  if remote_url == "" then
    remote_url = vim.fn.system("git remote -v | awk '{print $2}' | head -n1"):gsub("\n", "")
  end
  -- Remove the protocol part (git@ or https://) and remove the first : after the protocol
  local path = remote_url:gsub("^git@", ""):gsub("^https?://", "")
  -- remove the first colon only
  path = path:gsub(":", "/", 1)
  -- Remove the .git suffix
  path = path:gsub("%.git$", "")
  return path
end

function M.get_current_branch_or_hash()
  local branch = vim.fn.system("git rev-parse --abbrev-ref HEAD"):gsub("\n", "")
  if branch == "HEAD" then
    -- Detached HEAD, get the commit hash instead
    branch = vim.fn.system("git rev-parse HEAD"):gsub("\n", "")
  end
  return branch
end

--- Get detailed metadata for a git reference
--- Extracts branch name, full ref path, ref without prefix, and commit SHA
--- @param ref_name string Reference name/alias (e.g., "origin/main", "HEAD~1", "abc123", "HEAD@{u}")
--- @return GitRefMetadata|nil Metadata table or nil if invalid
--- @class GitRefMetadata
--- @field ref string Original reference input
--- @field fullref string|nil Full reference path (e.g., "refs/heads/main", "refs/remotes/origin/main")
--- @field branch string|nil Clean branch name without remote prefix (e.g., "main" from "refs/remotes/origin/main")
--- @field remote string|nil Remote name if ref is a remote branch (e.g., "origin"), nil for local branches/commits
--- @field sha string|nil Full commit SHA (40 characters)
--- @field valid boolean Whether the ref exists
--- @field resolved_ref string|nil The resolved reference (branch name or SHA, whichever is preferred)
--- @field resolved_with_remote string|nil Same as resolved_ref but includes remote prefix for remote branches (e.g., "origin/main")
--- @field resolve_ref_type "branch"|"sha"|"unknown" Type of resolved reference
function M.get_ref_metadata(ref_name)
  if not ref_name or ref_name == "" then
    return nil
  end

  local metadata = {
    ref = ref_name,
    fullref = nil,
    branch = nil,
    remote = nil,
    sha = nil,
    valid = false,
    resolved_ref = nil,
    resolved_with_remote = nil,
    resolve_ref_type = "unknown",
  }

  -- Verify ref exists
  vim.fn.systemlist { "git", "rev-parse", "--verify", ref_name }
  if vim.v.shell_error ~= 0 then
    return metadata
  end
  metadata.valid = true

  -- Get full ref name (e.g., refs/heads/main, refs/remotes/origin/main)
  local full_ref = vim.fn.systemlist({ "git", "rev-parse", "--symbolic-full-name", ref_name })[1]
  if full_ref and full_ref ~= "" then
    metadata.fullref = full_ref

    -- Extract clean branch name without refs/ prefix and remote name
    local branch_name = ""
    if full_ref:find "^refs/heads/" then
      -- Local branch: refs/heads/main -> main
      branch_name = full_ref:sub(12)
      metadata.remote = nil
    elseif full_ref:find "^refs/remotes/" then
      -- Remote branch: refs/remotes/origin/main -> extract remote and branch
      local remote_and_branch = full_ref:sub(14) -- Remove "refs/remotes/"
      local remote_name = remote_and_branch:match "^([^/]+)/"
      branch_name = remote_and_branch:gsub("^[^/]+/", "") -- Remove remote prefix
      metadata.remote = remote_name
    else
      -- Other cases: detached HEAD, tags, etc.
      -- Try using --abbrev-ref to get a readable name
      local abbrev_ref = vim.fn.systemlist({ "git", "rev-parse", "--abbrev-ref", ref_name })[1]
      if abbrev_ref and abbrev_ref ~= "" and vim.v.shell_error == 0 then
        branch_name = abbrev_ref
      end
    end
    metadata.branch = branch_name
  end

  -- Get commit SHA
  local sha = vim.fn.systemlist({ "git", "rev-parse", ref_name })[1]
  if sha and sha ~= "" and vim.v.shell_error == 0 then
    metadata.sha = sha
  end

  -- Resolve ref: Prefer branch name if available, otherwise use SHA
  if metadata.valid then
    if metadata.branch and metadata.branch ~= "" then
      metadata.resolved_ref = metadata.branch
      metadata.resolve_ref_type = "branch"
      -- Build resolved_with_remote: include remote prefix for remote branches
      if metadata.remote then
        metadata.resolved_with_remote = metadata.remote .. "/" .. metadata.branch
      else
        metadata.resolved_with_remote = metadata.branch
      end
    elseif metadata.sha and metadata.sha ~= "" then
      metadata.resolved_ref = metadata.sha
      metadata.resolved_with_remote = metadata.sha
      metadata.resolve_ref_type = "sha"
    end
  end

  return metadata
end

---@param ref string | nil -- If nil, use main branch
---@param mode "file" | "commit" | "branch"
---@param file string|nil
function M.get_branch_url(ref, mode, file)
  -- print([==[function mode:]==], vim.inspect(mode)) -- __AUTO_GENERATED_PRINT_VAR_END__
  if not ref or ref == "" then
    ref = M.git_main_branch()
  end
  local file_path = file or vim.fn.expand "%:p"
  local line_number = vim.fn.line "."

  local gitroot = pathUtil.get_git_root()
  if not gitroot then
    vim.notify("Not in a git repository", vim.log.levels.WARN)
    return ""
  end

  local remote_name = ref:match "([^/]+)" or "origin"
  local remote_path = M.get_remote_path(remote_name)
  local ref_no_remote = ref:gsub("^[^/]+/", "") -- remove remote
  local gitrootescape = vim.pesc(gitroot)
  local git_file_path = file_path:gsub(gitrootescape .. "/?", "")
  local url_pattern = "https://%s/blob/%s/%s#L%d"
  local url = ""
  local is_commit = ref_no_remote:match "[0-9a-fA-F]+$" ~= nil and (#ref_no_remote == 40 or #ref_no_remote == 7)
  -- print([==[function is_commit:]==], vim.inspect(is_commit))

  if mode == "file" then
    url = string.format(url_pattern, remote_path, ref_no_remote, git_file_path, line_number)
  else
    if mode == "commit" then
      url = string.format("https://%s/commit/%s", remote_path, ref_no_remote)
    else
      -- remove remote parts
      url = string.format("https://%s/tree/%s", remote_path, ref_no_remote)
    end
  end
  return url
end

---@param ref string
---@param mode "file" | "commit" | "branch"
---@param file string|nil
function M.open_remote(ref, mode, file)
  local url = M.get_branch_url(ref, mode, file)
  vim.fn.jobstart({ "open", url }, { detach = true })
end

---Open merge request for a branch
---@param branch string The branch name (can include remote prefix like "origin/feature-branch")
function M.open_mr(branch)
  if not branch or branch == "" then
    vim.notify("No branch provided", vim.log.levels.WARN)
    return
  end

  -- incorrect logic: also remove other branch prefix out Remove remote prefix if present (e.g., "origin/feature-branch" -> "feature-branch")
  -- local branch_name = branch:gsub("^[^/]+/", "")
  local branch_name = branch

  -- Detect git hosting provider
  local remote_path = M.get_remote_path "origin"

  local cmd_util = require "utils.cmd"

  if remote_path:match "gitlab" then
    -- GitLab MR - try to view first, fallback to create if not exists
    cmd_util.run_command({ "glab", "mr", "view", "-w", branch_name }, {
      success = function()
        vim.notify("Opening GitLab MR for: " .. branch_name, vim.log.levels.INFO)
      end,
      fail = function(error)
        local error_msg = table.concat(error, "\n")
        -- Check if error indicates MR doesn't exist
        if error_msg:match "not found" or error_msg:match "no merge request" or error_msg:match "could not find" then
          vim.notify("MR not found, creating new MR for: " .. branch_name, vim.log.levels.INFO)
          -- Fallback to creating MR
          cmd_util.run_command({ "glab", "mr", "create", "-w" }, {
            success = function()
              vim.notify("Created and opened GitLab MR for: " .. branch_name, vim.log.levels.INFO)
            end,
            fail = function(create_error)
              vim.notify("Failed to create MR: " .. table.concat(create_error, "\n"), vim.log.levels.ERROR)
            end,
          })
        elseif error_msg:match "looking for beginning of value" then
          vim.notify("glab error: Check connection to gitlab or auth", vim.log.levels.ERROR)
          -- check auth result
          vim.fn.jobstart({ "glab", "auth", "status" }, {
            on_stdout = function(_, data, _)
              if data then
                vim.notify("glab auth status:\n" .. table.concat(data, "\n"), vim.log.levels.INFO)
              end
            end,
            on_stderr = function(_, data, _)
              if data then
                vim.notify("glab auth status error:\n" .. table.concat(data, "\n"), vim.log.levels.ERROR)
              end
            end,
            detach = true,
          })
        else
          vim.notify("glab error: " .. error_msg, vim.log.levels.ERROR)
        end
      end,
    })
  elseif remote_path:match "github" then
    -- GitHub PR - try to view first, fallback to create if not exists
    cmd_util.run_command({ "gh", "pr", "view", "-w", branch_name }, {
      success = function()
        vim.notify("Opening GitHub PR for: " .. branch_name, vim.log.levels.INFO)
      end,
      fail = function(error)
        local error_msg = table.concat(error, "\n")
        -- Check if error indicates PR doesn't exist
        if
          error_msg:match "no pull requests found"
          or error_msg:match "not found"
          or error_msg:match "could not find"
        then
          vim.notify("PR not found, creating new PR for: " .. branch_name, vim.log.levels.INFO)
          -- Fallback to creating PR
          cmd_util.run_command({ "gh", "pr", "create", "-w" }, {
            success = function()
              vim.notify("Created and opened GitHub PR for: " .. branch_name, vim.log.levels.INFO)
            end,
            fail = function(create_error)
              vim.notify("Failed to create PR: " .. table.concat(create_error, "\n"), vim.log.levels.ERROR)
            end,
          })
        else
          vim.notify("gh error: " .. error_msg, vim.log.levels.ERROR)
        end
      end,
    })
  else
    vim.notify("Unsupported git hosting provider: " .. remote_path, vim.log.levels.WARN)
  end
end

--#region Git Helper Functions for Pickers

--- Helper function to open file diff with gitsigns
--- @param file_path string File path (relative or absolute)
--- @param ref string Git reference to compare with
function M.open_file_with_gitsigns_diff(file_path, ref)
  if not pcall(require, "gitsigns") then
    vim.notify("Gitsigns is not available", vim.log.levels.ERROR)
    return
  end

  local git_root = Snacks.git.get_root()

  if vim.fn.filereadable(file_path) == 0 then
    file_path = git_root .. "/" .. file_path
  end

  vim.cmd("tabnew " .. vim.fn.fnameescape(file_path))

  require("gitsigns").diffthis(ref, {
    vertical = true,
  })
end

--- Helper function to open current buffer in new tab with gitsigns diff
--- @param ref string Git reference to compare with
function M.open_current_buffer_with_gitsigns_diff(ref)
  if not pcall(require, "gitsigns") then
    vim.notify("Gitsigns is not available", vim.log.levels.ERROR)
    return
  end

  local current_file = vim.api.nvim_buf_get_name(0)

  if current_file == "" then
    vim.notify("No file in current buffer", vim.log.levels.WARN)
    return
  end

  vim.cmd("tabnew " .. vim.fn.fnameescape(current_file))

  require("gitsigns").diffthis(ref, {
    vertical = true,
  })
end

--- Helper function to build remote URL for a file at a specific ref
--- @param file_path string File path (relative or absolute)
--- @param ref string Git reference (branch, tag, or commit)
--- @return string|nil Remote URL or nil if error
function M.build_remote_url(file_path, ref)
  local git_root = Snacks.git.get_root()
  if not git_root then
    return nil
  end

  if vim.fn.filereadable(file_path) == 0 then
    file_path = git_root .. "/" .. file_path
  end

  local rel_path = file_path:gsub("^" .. vim.pesc(git_root) .. "/?", "")
  local remote_path = M.get_remote_path "origin"

  if not remote_path or remote_path == "" then
    return nil
  end

  local url
  if remote_path:match "gitlab" then
    url = string.format("https://%s/-/blob/%s/%s", remote_path, ref, rel_path)
  else
    url = string.format("https://%s/blob/%s/%s", remote_path, ref, rel_path)
  end

  return url
end

--- Helper function to open file in remote at specific ref
--- @param file_path string File path (relative or absolute)
--- @param ref string Git reference to open at
function M.open_file_in_remote(file_path, ref)
  local url = M.build_remote_url(file_path, ref)

  if not url then
    vim.notify("Failed to build remote URL", vim.log.levels.ERROR)
    return
  end

  local filename = vim.fn.fnamemodify(file_path, ":t")

  vim.fn.jobstart({ "open", url }, { detach = true })
  vim.notify(string.format("Opening %s @ %s in browser", filename, ref), vim.log.levels.INFO)
end

--- Get current git branch name
--- @return string Branch name
function M.get_current_git_branch()
  local branch = vim.fn.system("git rev-parse --abbrev-ref HEAD"):gsub("\n", "")
  if vim.v.shell_error ~= 0 or branch == "" then
    return "HEAD"
  end
  return branch
end

--- Get commits between two refs
--- @param from_ref string Starting reference (inclusive)
--- @param to_ref string Ending reference (exclusive, typically HEAD)
--- @return table List of commit hashes (short format)
function M.get_commits_between(from_ref, to_ref)
  if not from_ref or not to_ref then
    return {}
  end

  -- Get commits in range from_ref..to_ref
  local commits = vim.fn.systemlist {
    "git",
    "log",
    "--oneline",
    "--pretty=format:%H",
    from_ref .. ".." .. to_ref,
  }

  if vim.v.shell_error ~= 0 then
    return {}
  end

  return commits
end

--- Get short commit hash (7 chars)
--- @param ref string Git reference (commit hash, branch name, etc.)
--- @return string Short commit hash or empty string if invalid
function M.get_short_hash(ref)
  if not ref or ref == "" then
    return ""
  end

  local short_hash = vim.fn.system("git rev-parse --short " .. ref):gsub("\n", "")
  if vim.v.shell_error ~= 0 then
    return ""
  end

  return short_hash
end

--- Get ref branch name
--- @param ref string Git reference
--- @return string Branch name or empty string if it's a detached HEAD/commit
function M.get_ref_branch_name(ref)
  if not ref or ref == "" then
    return ""
  end

  -- Try symbolic-ref first (for branch refs)
  local branch = vim.fn.system("git symbolic-ref --short " .. ref):gsub("\n", "")
  if vim.v.shell_error == 0 and branch ~= "" then
    return branch
  end

  -- For refs/remotes/origin/main -> origin/main
  local fullref = vim.fn.system("git rev-parse --symbolic-full-name " .. ref):gsub("\n", "")
  if fullref:find "^refs/remotes/" then
    return fullref:sub(14) -- Remove "refs/remotes/"
  elseif fullref:find "^refs/heads/" then
    return fullref:sub(12) -- Remove "refs/heads/"
  end

  return ""
end

--- Format a git ref for display (shows branch or short hash)
--- @param ref string Git reference
--- @return string Formatted display string
function M.format_ref_display(ref)
  if not ref or ref == "" then
    return "unknown"
  end

  local branch = M.get_ref_branch_name(ref)
  if branch ~= "" then
    return branch
  end

  local short_hash = M.get_short_hash(ref)
  if short_hash ~= "" then
    return short_hash
  end

  return ref
end

--#endregion Git Helper Functions for Pickers

--#region Submodule Helper Functions

--- Get superproject root if current directory is in a submodule
--- @param dir string|nil Directory to check (default: cwd)
--- @return string|nil Superproject root path or nil
function M.get_superproject_root(dir)
  dir = dir or vim.fn.getcwd()
  local cmd = string.format("git -C %s rev-parse --show-superproject-working-tree 2>/dev/null", vim.fn.shellescape(dir))
  local result = vim.fn.systemlist(cmd)[1]
  return result and result ~= "" and result or nil
end

--- Get git working tree metadata for a directory
--- @param dir string|nil Directory to inspect (default: cwd)
--- @return { git_dir: string, common_dir: string, toplevel: string }|nil
function M.get_worktree_metadata(dir)
  dir = dir or vim.fn.getcwd()

  local git_dir = trim_system_output({ "git", "-C", dir, "rev-parse", "--absolute-git-dir" })
  local common_dir = trim_system_output({ "git", "-C", dir, "rev-parse", "--git-common-dir" })
  local toplevel = trim_system_output({ "git", "-C", dir, "rev-parse", "--show-toplevel" })

  if not git_dir or not common_dir or not toplevel then
    return nil
  end

  local metadata = {
    git_dir = vim.fs.normalize(git_dir),
    common_dir = vim.fs.normalize(common_dir),
    toplevel = vim.fs.normalize(toplevel),
  }
  return metadata
end

--- Check whether a directory is using a linked git worktree checkout
--- Returns true for linked worktrees and false for the main checkout or non-git dirs.
--- @param dir string|nil Directory to inspect (default: cwd)
--- @return boolean
function M.is_worktree_dir(dir)
  local metadata = M.get_worktree_metadata(dir)
  if not metadata then
    return false
  end

  return metadata.git_dir ~= metadata.common_dir
end

--- Check if a directory is inside a git submodule
--- Combined approach: check .git file + parse content
--- @param dir string Directory to check
--- @return boolean
function M.is_in_submodule(dir)
  local git_path = dir .. "/.git"

  -- Fast check: if .git is a directory, it's a normal repo
  if vim.fn.isdirectory(git_path) == 1 then
    return false
  end

  -- Check if .git is a file (submodule or worktree)
  if vim.fn.filereadable(git_path) == 1 then
    local content = vim.fn.readfile(git_path)[1] or ""
    -- Submodule: "gitdir: ../../.git/modules/name"
    -- Worktree:  "gitdir: /path/to/repo/.git/worktrees/name"
    if content:match "modules" then
      return true
    end
  end

  return false
end

--- Get the root directory of a submodule
--- @param dir string Directory inside submodule
--- @return string|nil Submodule root path or nil
function M.get_submodule_root(dir)
  if not M.is_in_submodule(dir) then
    return nil
  end

  local cmd = string.format("git -C %s rev-parse --show-toplevel 2>/dev/null", vim.fn.shellescape(dir))
  local result = vim.fn.systemlist(cmd)[1]
  return result and result ~= "" and result or nil
end

--#endregion Submodule Helper Functions

--#region Git Helper Functions for Diff Changes
-- Helper to extract file status (M/A/D/R) from name-status output
local function get_file_status(name_status, filename)
  for line in name_status:gmatch "[^\r\n]+" do
    -- Match status at start of line
    local status, file = line:match "^(%S+)%s+(.+)"
    if file and file:match(vim.pesc(filename)) then
      return status
    end
  end
  return "M" -- default to Modified
end

-- Helper to parse rename paths from numstat output
-- Handles patterns like: "path/{old => new}/file.txt" or "{old => new}"
local function parse_rename(rename_str)
  -- Pattern 1: "path/{old => new}/rest"
  local prefix, old_name, new_name, suffix = rename_str:match "(.-)%{(.-)%s*=>%s*(.-)%}(.*)"
  if prefix and old_name and new_name then
    return prefix .. old_name .. suffix, prefix .. new_name .. suffix
  end

  -- Pattern 2: Direct rename without braces (from name-status)
  local old_path, new_path = rename_str:match "(.+)%s+=>%s+(.+)"
  if old_path and new_path then
    return old_path:match "^%s*(.-)%s*$", new_path:match "^%s*(.-)%s*$"
  end

  return rename_str, rename_str
end

-- Find first matching file treatment rule (first match wins)
-- @param filename string: file path to match
-- @param treatments table|nil: array of { pattern = "lua pattern or *", skip_diff_threshold = number, trim_diff = bool }
-- @return table|nil: matched treatment rule or nil
local function find_file_treatment(filename, treatments)
  if not treatments or #treatments == 0 then
    return nil
  end
  for _, rule in ipairs(treatments) do
    if rule.pattern == "*" or filename:match(rule.pattern) then
      return rule
    end
  end
  return nil
end

-- Trim diff text to first N/2 and last N/2 lines
-- @param diff_text string: full diff output
-- @param max_lines number: max lines to keep
-- @return string: trimmed diff
local function trim_diff_lines(diff_text, max_lines)
  local lines = {}
  for line in diff_text:gmatch "[^\n]*" do
    table.insert(lines, line)
  end
  -- Remove trailing empty line from gmatch
  if #lines > 0 and lines[#lines] == "" then
    table.remove(lines)
  end
  if #lines <= max_lines then
    return diff_text
  end
  local half = math.floor(max_lines / 2)
  local result = {}
  for i = 1, half do
    table.insert(result, lines[i])
  end
  table.insert(result, string.format("... (%d lines trimmed) ...", #lines - max_lines))
  for i = #lines - half + 1, #lines do
    table.insert(result, lines[i])
  end
  return table.concat(result, "\n")
end

-- Get filtered staged diff with large files shown as summary only
-- @param threshold number: minimum total line changes to show as summary (default: 50)
-- @param opts table|nil: options { file_treatments = table, total_threshold = number }
--   file_treatments: array of rules (first match wins), each rule:
--     { pattern = "lua pattern or *" }                             -- skip diff entirely
--     { pattern = "*", skip_diff_threshold = 100, trim_diff = true } -- trim if diff > N lines
-- @return string: formatted diff output
function M.get_filtered_staged_diff(threshold, opts)
  threshold = threshold or 50
  opts = opts or {}
  local file_treatments = opts.file_treatments
  local total_threshold = opts.total_threshold or 700

  -- Get numstat (line counts per file)
  local numstat = vim.fn.system "git diff --staged --numstat"
  if vim.v.shell_error ~= 0 or numstat == "" then
    return "No staged changes"
  end

  -- Calculate total lines changed across all files
  local total_changes = 0
  for line in numstat:gmatch "[^\r\n]+" do
    local added, deleted = line:match "(%S+)%s+(%S+)"
    if added and deleted and added ~= "-" and deleted ~= "-" then
      total_changes = total_changes + (tonumber(added) or 0) + (tonumber(deleted) or 0)
    end
  end

  -- If total changes <= threshold, show full diff
  if total_changes <= total_threshold then
    return vim.fn.system "git diff --staged"
  end

  -- Get name-status (M/A/D/R status per file)
  local name_status = vim.fn.system "git diff --staged --name-status"

  local large_files = {}
  local small_files = {}
  local renames = {}
  local binaries = {}
  local all_files_summary = {}

  -- Parse numstat and categorize files
  for line in numstat:gmatch "[^\r\n]+" do
    local added, deleted, filename = line:match "(%S+)%s+(%S+)%s+(.+)"

    if filename then
      local status = get_file_status(name_status, filename)

      -- Check if binary file (git shows "- -" for binary)
      if added == "-" and deleted == "-" then
        table.insert(binaries, filename)
        table.insert(all_files_summary, string.format("%s %s (binary)", status, filename))
      -- Check if rename (contains "{old => new}")
      elseif filename:match "{.*=>.*}" then
        table.insert(renames, filename)
        local old_name, new_name = parse_rename(filename)
        table.insert(all_files_summary, string.format("R %s -> %s", old_name, new_name))
      else
        -- Calculate total changes
        local added_num = tonumber(added) or 0
        local deleted_num = tonumber(deleted) or 0
        local total = added_num + deleted_num

        -- Add to summary (all files)
        table.insert(all_files_summary, string.format("%s %s +%s -%s", status, filename, added, deleted))

        if total > threshold then
          table.insert(large_files, {
            file = filename,
            added = added,
            deleted = deleted,
            status = status,
          })
        else
          table.insert(small_files, filename)
        end
      end
    end
  end

  -- Build output
  local output = {}

  -- Section 1: ALL FILES SUMMARY
  if #all_files_summary > 0 then
    table.insert(output, "=== FILES CHANGED ===")
    for _, summary in ipairs(all_files_summary) do
      table.insert(output, summary)
    end
    table.insert(output, "")
  end

  -- Section 2: LARGE FILE CHANGES (>threshold lines) - SUMMARY ONLY
  local large_visible = {}
  for _, item in ipairs(large_files) do
    local treatment = find_file_treatment(item.file, file_treatments)
    -- No treatment or treatment has display opts → show in summary
    if not treatment or treatment.skip_diff_threshold or treatment.trim_diff then
      table.insert(large_visible, item)
    end
    -- Treatment with only pattern (no opts) → skip entirely
  end

  if #large_visible > 0 then
    table.insert(output, string.format("=== LARGE FILES (>%d line changes) - SUMMARY ===", threshold))
    for _, item in ipairs(large_visible) do
      table.insert(output, string.format("%s %s +%s -%s", item.status, item.file, item.added, item.deleted))
    end
    table.insert(output, "")
  end

  -- Section 3: SMALL FILES (<= threshold) - DIFF with treatments
  local small_full = {} -- files to show full diff
  local small_treated = {} -- files needing individual treatment (trim)
  for _, file in ipairs(small_files) do
    local treatment = find_file_treatment(file, file_treatments)
    if not treatment then
      -- No treatment → full diff
      table.insert(small_full, file)
    elseif treatment.skip_diff_threshold or treatment.trim_diff then
      -- Has display opts → apply treatment per file
      table.insert(small_treated, { file = file, treatment = treatment })
    end
    -- Treatment with only pattern (no opts) → skip entirely
  end

  if #small_full > 0 or #small_treated > 0 then
    table.insert(output, string.format("=== SMALL FILES (<=%d line changes) - FULL DIFF ===", threshold))
    table.insert(output, "")

    -- Full diff files (batch)
    if #small_full > 0 then
      local escaped_files = {}
      for _, file in ipairs(small_full) do
        table.insert(escaped_files, vim.fn.shellescape(file))
      end
      local files_arg = table.concat(escaped_files, " ")
      local small_diff = vim.fn.system("git diff --staged -- " .. files_arg)
      if small_diff ~= "" then
        table.insert(output, small_diff)
      end
    end

    -- Treated files (individual diff with trim)
    for _, entry in ipairs(small_treated) do
      local file_diff = vim.fn.system("git diff --staged -- " .. vim.fn.shellescape(entry.file))
      if file_diff ~= "" then
        local t = entry.treatment
        if t.trim_diff and t.skip_diff_threshold then
          file_diff = trim_diff_lines(file_diff, t.skip_diff_threshold)
        end
        table.insert(output, file_diff)
      end
    end
  end

  return table.concat(output, "\n")
end
--#endregion
return M
