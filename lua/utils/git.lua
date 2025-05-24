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

---@param ref string
---@param mode "file" | "commit" | "branch"
function M.get_branch_url(ref, mode)
  -- print([==[function mode:]==], vim.inspect(mode)) -- __AUTO_GENERATED_PRINT_VAR_END__
  local file_path = vim.fn.expand("%:p")
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
function M.open_remote(ref, mode)
  local url = M.get_branch_url(ref, mode)
  vim.fn.jobstart({ "open", url }, { detach = true })
end

return M
