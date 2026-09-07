-- mcphub.nvim backend: attach to an existing hub, or spawn one locally.
--
-- MCP_HUB_MODE:
--   auto   (default) attach when MCP_HUB_SERVER_URL is set, else spawn
--   attach connect to MCP_HUB_SERVER_URL (default http://127.0.0.1:37373)
--   spawn  start a local hub; ignores MCP_HUB_SERVER_URL
--
-- Spawn extras: MCP_HUB_FORK_CLI, MCP_HUB_FORK_REPO, else bundled binary.
-- Config path: MCPHUB_CONFIG, else $DOTFILES_DIR/ai/mcp/mcphub.json

local M = {}

local function first_existing_cli(candidates)
  for _, candidate in ipairs(candidates) do
    if vim.fn.filereadable(candidate) == 1 then
      return candidate
    end
  end
  return ""
end

local function cli_from_repo(repo_path)
  local repo = vim.trim(repo_path or "")
  if repo == "" then
    return ""
  end
  return first_existing_cli {
    repo .. "/dist/cli.js",
    repo .. "/src/utils/cli.js",
  }
end

function M.mode()
  local mode = vim.trim(vim.env.MCP_HUB_MODE or "auto"):lower()
  if mode ~= "attach" and mode ~= "spawn" and mode ~= "auto" then
    mode = "auto"
  end
  local url = vim.trim(vim.env.MCP_HUB_SERVER_URL or "")
  if mode == "auto" then
    mode = url ~= "" and "attach" or "spawn"
  end
  if mode == "attach" and url == "" then
    url = "http://127.0.0.1:37373"
  end
  if mode == "spawn" then
    url = ""
  end
  return mode, url
end

function M.config_path()
  local from_env = vim.trim(vim.env.MCPHUB_CONFIG or "")
  if from_env ~= "" then
    return vim.fn.expand(from_env)
  end
  local dotfiles = vim.env.DOTFILES_DIR or vim.fn.expand "~/dotfiles"
  return vim.fn.expand(dotfiles .. "/ai/mcp/mcphub.json")
end

function M.resolve()
  local mode, server_url = M.mode()
  if mode == "attach" then
    -- mcphub.nvim still runs `cmd --version` before attach; bundled binary is enough.
    return {
      mode = "attach",
      use_bundled_binary = true,
      server_url = server_url,
      cmd = nil,
      cmdArgs = nil,
      workspace_enabled = false,
    }
  end

  local cli_path = ""
  local fork_cli_env = vim.trim(vim.env.MCP_HUB_FORK_CLI or "")
  if fork_cli_env ~= "" then
    if vim.fn.filereadable(fork_cli_env) == 1 then
      cli_path = fork_cli_env
    else
      vim.notify(("mcphub: MCP_HUB_FORK_CLI not readable, ignoring: %s"):format(fork_cli_env), vim.log.levels.WARN)
    end
  end
  if cli_path == "" then
    cli_path = cli_from_repo(vim.env.MCP_HUB_FORK_REPO)
  end
  if cli_path == "" then
    for _, repo in ipairs {
      vim.fn.expand "~/projects/mcp-hub",
      vim.fn.expand "~/worktree/mcp-hub",
    } do
      cli_path = cli_from_repo(repo)
      if cli_path ~= "" then
        break
      end
    end
  end

  if cli_path ~= "" then
    return {
      mode = "spawn",
      use_bundled_binary = false,
      server_url = nil,
      cmd = "node",
      cmdArgs = { cli_path },
      workspace_enabled = nil,
    }
  end

  return {
    mode = "spawn",
    use_bundled_binary = true,
    server_url = nil,
    cmd = nil,
    cmdArgs = nil,
    workspace_enabled = nil,
  }
end

return M
