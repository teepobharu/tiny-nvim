local M = {}

local RELEASES_URL = "https://github.com/OmniSharp/omnisharp-roslyn/releases"
local RELEASES_API_URL = "https://api.github.com/repos/OmniSharp/omnisharp-roslyn/releases/latest"

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO)
end

local function run_capture(cmd, timeout)
  timeout = timeout or 30000
  if vim.system then
    local proc = vim.system(cmd, { text = true })
    local result = proc:wait(timeout)
    if not result then
      pcall(proc.kill, proc, 15)
      pcall(proc.wait, proc)
      return false, "", "Timed out"
    end
    local ok = result.code == 0
    return ok, result.stdout or "", result.stderr or ""
  end

  local output = vim.fn.system(cmd)
  local ok = vim.v.shell_error == 0
  return ok, output or "", ok and "" or "Command failed"
end

local function run_step(step)
  local cmd = step.cmd
  local ok, out, err = run_capture(cmd, step.timeout or 120000)
  return ok, out, err
end

local function open_releases_page()
  vim.fn.jobstart({ "open", RELEASES_URL }, { detach = true })
end

local function normalize_version(ver)
  if not ver or ver == "" then
    return nil
  end
  if ver:sub(1, 1) == "v" then
    return ver
  end
  return "v" .. ver
end

local function get_platform_info()
  local u = vim.loop.os_uname()
  local sys = (u and u.sysname) or ""
  local machine = (u and u.machine) or ""

  local os_key = "osx"
  if sys == "Linux" then
    os_key = "linux"
  elseif sys:match "Windows" then
    os_key = "win"
  end

  local arch_key = "x64"
  if machine == "arm64" or machine == "aarch64" then
    arch_key = "arm64"
  elseif machine == "x86_64" or machine == "amd64" then
    arch_key = "x64"
  end

  return {
    sysname = sys,
    machine = machine,
    os_key = os_key,
    arch_key = arch_key,
  }
end

local function decode_json(body)
  local ok, parsed = pcall(vim.json.decode, body)
  if not ok then
    return nil
  end
  return parsed
end

function M.get_latest_release()
  local body
  local ok, out, err

  if vim.fn.executable "gh" == 1 then
    ok, out, err = run_capture({ "gh", "api", "repos/OmniSharp/omnisharp-roslyn/releases/latest" }, 30000)
    if ok and out ~= "" then
      body = out
    end
  end

  if not body and vim.fn.executable "curl" == 1 then
    ok, out, err = run_capture({ "curl", "-fsSL", RELEASES_API_URL }, 30000)
    if ok and out ~= "" then
      body = out
    end
  end

  if not body then
    return nil, string.format("Could not fetch latest release (last error: %s)", err or "unknown")
  end

  local parsed = decode_json(body)
  if not parsed or type(parsed) ~= "table" then
    return nil, "Could not parse latest release response"
  end
  if not parsed.tag_name or type(parsed.assets) ~= "table" then
    return nil, "Latest release response missing tag_name/assets"
  end

  return parsed
end

function M.pick_asset(release)
  if not release or type(release.assets) ~= "table" then
    return nil, "Invalid release assets"
  end

  local platform = get_platform_info()
  local exact = string.format("omnisharp-%s-%s-net6.0.tar.gz", platform.os_key, platform.arch_key)
  for _, asset in ipairs(release.assets) do
    if asset.name == exact then
      return asset
    end
  end

  local candidates = {}
  for _, asset in ipairs(release.assets) do
    if
      type(asset.name) == "string"
      and asset.name:find(platform.os_key, 1, true)
      and asset.name:find(platform.arch_key, 1, true)
    then
      local score = 0
      if asset.name:find("net6.0", 1, true) then
        score = score + 40
      end
      if asset.name:sub(-7) == ".tar.gz" then
        score = score + 20
      elseif asset.name:sub(-4) == ".zip" then
        score = score + 10
      end
      table.insert(candidates, { asset = asset, score = score })
    end
  end

  table.sort(candidates, function(a, b)
    return a.score > b.score
  end)

  if #candidates == 0 then
    return nil,
      string.format(
        "No matching release asset for %s/%s; open releases page and choose manually",
        platform.os_key,
        platform.arch_key
      )
  end

  return candidates[1].asset
end

function M.resolve_install_plan()
  local release, release_err = M.get_latest_release()
  if not release then
    return nil, release_err
  end

  local asset, asset_err = M.pick_asset(release)
  if not asset then
    return nil, asset_err
  end

  local version = normalize_version(release.tag_name)
  local install_dir = vim.fn.expand("~/.local/opt/omnisharp-" .. version)
  local bin_dir = vim.fn.expand "~/.local/bin"
  local archive = asset.browser_download_url
  local is_targz = asset.name:sub(-7) == ".tar.gz"
  local is_zip = asset.name:sub(-4) == ".zip"

  local steps = {
    {
      desc = "Create install directory",
      cmd = { "mkdir", "-p", install_dir },
    },
    {
      desc = "Create local bin directory",
      cmd = { "mkdir", "-p", bin_dir },
    },
  }

  if is_targz then
    table.insert(steps, {
      desc = "Download and extract OmniSharp tarball",
      cmd = { "sh", "-c", string.format("curl -fL %q | tar -xz -C %q", archive, install_dir) },
    })
  elseif is_zip then
    local archive_path = install_dir .. "/" .. asset.name
    table.insert(steps, {
      desc = "Download OmniSharp zip",
      cmd = { "curl", "-fL", archive, "-o", archive_path },
    })
    table.insert(steps, {
      desc = "Extract OmniSharp zip",
      cmd = { "unzip", "-o", archive_path, "-d", install_dir },
    })
  else
    return nil, "Unsupported asset format: " .. asset.name
  end

  table.insert(steps, {
    desc = "Ensure OmniSharp binary executable",
    cmd = {
      "sh",
      "-c",
      string.format(
        "if [ -f %q ]; then chmod +x %q; fi; if [ -f %q ]; then chmod +x %q; fi",
        install_dir .. "/OmniSharp",
        install_dir .. "/OmniSharp",
        install_dir .. "/omnisharp",
        install_dir .. "/omnisharp"
      ),
    },
  })

  table.insert(steps, {
    desc = "Update omnisharp symlink",
    cmd = {
      "sh",
      "-c",
      string.format(
        "if [ -x %q ]; then ln -sf %q %q; elif [ -x %q ]; then ln -sf %q %q; else echo 'OmniSharp binary not found in %s' >&2; exit 1; fi",
        install_dir .. "/OmniSharp",
        install_dir .. "/OmniSharp",
        bin_dir .. "/omnisharp",
        install_dir .. "/omnisharp",
        install_dir .. "/omnisharp",
        bin_dir .. "/omnisharp",
        install_dir
      ),
    },
  })

  return {
    version = version,
    asset_name = asset.name,
    asset_url = archive,
    release_url = release.html_url or RELEASES_URL,
    install_dir = install_dir,
    bin_dir = bin_dir,
    steps = steps,
  }
end

function M.format_plan_lines(plan)
  local lines = {
    "OmniSharp install/upgrade plan",
    "",
    "Version: " .. plan.version,
    "Asset:   " .. plan.asset_name,
    "URL:     " .. plan.asset_url,
    "Dir:     " .. plan.install_dir,
    "",
    "Commands:",
  }

  for i, step in ipairs(plan.steps) do
    local cmd_str = type(step.cmd) == "table" and table.concat(step.cmd, " ") or tostring(step.cmd)
    table.insert(lines, string.format("%d) %s", i, step.desc))
    table.insert(lines, "   " .. cmd_str)
  end

  return lines
end

function M.show_install_info()
  local plan, err = M.resolve_install_plan()
  if not plan then
    notify("C# LSP install info failed: " .. err, vim.log.levels.ERROR)
    open_releases_page()
    return nil, err
  end

  local lines = M.format_plan_lines(plan)
  notify(table.concat(lines, "\n"), vim.log.levels.INFO)
  return plan
end

local function confirm_yes_no(prompt, cb)
  if vim.ui and type(vim.ui.confirm) == "function" then
    vim.ui.confirm(prompt, cb)
    return
  end
  vim.ui.select({ "Yes", "No" }, { prompt = prompt }, function(choice)
    cb(choice == "Yes" and 1 or 0)
  end)
end

local function execute_plan(plan, label)
  notify(string.format("%s OmniSharp %s (%s)", label, plan.version, plan.asset_name), vim.log.levels.INFO)

  for _, step in ipairs(plan.steps) do
    local ok, _, err = run_step(step)
    if not ok then
      notify(
        string.format("%s failed at '%s': %s", label, step.desc, err ~= "" and err or "unknown error"),
        vim.log.levels.ERROR
      )
      return false
    end
  end

  local ok, out = run_capture { "sh", "-c", "command -v omnisharp || true" }
  if ok and out and out:gsub("%s+", "") ~= "" then
    notify("OmniSharp is ready: " .. out:gsub("%s+$", ""), vim.log.levels.INFO)
  else
    notify("Install completed but omnisharp not found in PATH. Ensure ~/.local/bin is in PATH.", vim.log.levels.WARN)
  end
  return true
end

function M.install_latest()
  local plan, err = M.resolve_install_plan()
  if not plan then
    notify("Install failed to resolve: " .. err, vim.log.levels.ERROR)
    open_releases_page()
    return
  end

  local prompt = string.format("Install OmniSharp %s (%s)?", plan.version, plan.asset_name)
  confirm_yes_no(prompt, function(choice)
    if choice ~= 1 then
      notify("OmniSharp install cancelled", vim.log.levels.INFO)
      return
    end
    execute_plan(plan, "Installed")
  end)
end

function M.upgrade_latest()
  local plan, err = M.resolve_install_plan()
  if not plan then
    notify("Upgrade failed to resolve: " .. err, vim.log.levels.ERROR)
    open_releases_page()
    return
  end

  local prompt = string.format("Upgrade OmniSharp to %s (%s)?", plan.version, plan.asset_name)
  confirm_yes_no(prompt, function(choice)
    if choice ~= 1 then
      notify("OmniSharp upgrade cancelled", vim.log.levels.INFO)
      return
    end
    execute_plan(plan, "Upgraded")
  end)
end

function M.open_releases_page()
  open_releases_page()
end

return M
