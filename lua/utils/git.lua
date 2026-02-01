local M = {}

local pathUtil = require("utils.path")

function M.git_main_branch()
  local git_dir = vim.fn.system("git rev-parse --git-dir 2> /dev/null")
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
  vim.fn.systemlist({ "git", "rev-parse", "--verify", ref_name })
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
    if full_ref:find("^refs/heads/") then
      -- Local branch: refs/heads/main -> main
      branch_name = full_ref:sub(12)
      metadata.remote = nil
    elseif full_ref:find("^refs/remotes/") then
      -- Remote branch: refs/remotes/origin/main -> extract remote and branch
      local remote_and_branch = full_ref:sub(14) -- Remove "refs/remotes/"
      local remote_name = remote_and_branch:match("^([^/]+)/")
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
  local file_path = file or vim.fn.expand("%:p")
  local line_number = vim.fn.line(".")

  local gitroot = pathUtil.get_git_root()
  if not gitroot then
    vim.notify("Not in a git repository", vim.log.levels.WARN)
    return ""
  end

  local remote_name = ref:match("([^/]+)") or "origin"
  local remote_path = M.get_remote_path(remote_name)
  local ref_no_remote = ref:gsub("^[^/]+/", "") -- remove remote
  local gitrootescape = vim.pesc(gitroot)
  local git_file_path = file_path:gsub(gitrootescape .. "/?", "")
  local url_pattern = "https://%s/blob/%s/%s#L%d"
  local url = ""
  local is_commit = ref_no_remote:match("[0-9a-fA-F]+$") ~= nil and (#ref_no_remote == 40 or #ref_no_remote == 7)
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
  local remote_path = M.get_remote_path("origin")

  local cmd_util = require("utils.cmd")

  if remote_path:match("gitlab") then
    -- GitLab MR - try to view first, fallback to create if not exists
    cmd_util.run_command({ "glab", "mr", "view", "-w", branch_name }, {
      success = function()
        vim.notify("Opening GitLab MR for: " .. branch_name, vim.log.levels.INFO)
      end,
      fail = function(error)
        local error_msg = table.concat(error, "\n")
        -- Check if error indicates MR doesn't exist
        if error_msg:match("not found") or error_msg:match("no merge request") or error_msg:match("could not find") then
          vim.notify("MR not found, creating new MR for: " .. branch_name, vim.log.levels.INFO)
          -- Fallback to creating MR
          cmd_util.run_command({ "glab", "mr", "create", "-w" }, {
            success = function()
              vim.notify("Created and opened GitLab MR for: " .. branch_name, vim.log.levels.INFO)
            end,
            fail = function(create_error)
              vim.notify("Failed to create MR: " .. table.concat(create_error, "\n"), vim.log.levels.ERROR)
            end
          })
        elseif error_msg:match("looking for beginning of value") then
          vim.notify("glab error: Check connection to gitlab or auth", vim.log.levels
            .ERROR)
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
      end
    })
  elseif remote_path:match("github") then
    -- GitHub PR - try to view first, fallback to create if not exists
    cmd_util.run_command({ "gh", "pr", "view", "-w", branch_name }, {
      success = function()
        vim.notify("Opening GitHub PR for: " .. branch_name, vim.log.levels.INFO)
      end,
      fail = function(error)
        local error_msg = table.concat(error, "\n")
        -- Check if error indicates PR doesn't exist
        if error_msg:match("no pull requests found") or error_msg:match("not found") or error_msg:match("could not find") then
          vim.notify("PR not found, creating new PR for: " .. branch_name, vim.log.levels.INFO)
          -- Fallback to creating PR
          cmd_util.run_command({ "gh", "pr", "create", "-w" }, {
            success = function()
              vim.notify("Created and opened GitHub PR for: " .. branch_name, vim.log.levels.INFO)
            end,
            fail = function(create_error)
              vim.notify("Failed to create PR: " .. table.concat(create_error, "\n"), vim.log.levels.ERROR)
            end
          })
        else
          vim.notify("gh error: " .. error_msg, vim.log.levels.ERROR)
        end
      end
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

--#endregion Git Helper Functions for Pickers

return M
