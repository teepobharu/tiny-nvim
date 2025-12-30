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
  local remote_name = ref:match("([^/]+)")
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

return M
