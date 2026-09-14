-- Read-only discovery for the MCPHub AI Agent Settings dashboard.
--
-- The view receives declarative roots from myAi.lua.  It intentionally scans
-- only configured paths, never invokes agent CLIs, and never reads config
-- contents.  That keeps dashboard rendering safe for IDE-backed agents such
-- as Cursor while still showing which local/user setup files and skills exist.

local uv = vim.uv or vim.loop

local M = {
  _cache = {},
}

local CACHE_TTL_NS = 1000 * 1000 * 1000

local function normalize_path(path)
  local expanded = vim.fn.expand(path or "")
  if expanded == "" then
    return ""
  end
  if expanded:sub(1, 1) ~= "/" then
    expanded = vim.fn.fnamemodify(expanded, ":p")
  end
  return vim.fs.normalize(expanded)
end

local function resolve_path(root, path)
  local expanded = vim.fn.expand(path or "")
  if expanded == "" then
    return normalize_path(root)
  end
  if expanded:sub(1, 1) == "/" then
    return normalize_path(expanded)
  end
  if not root or root == "" then
    return normalize_path(expanded)
  end
  return normalize_path((root or "") .. "/" .. expanded)
end

local function stat(path)
  if path == "" then
    return nil
  end
  return uv.fs_stat(path)
end

local function path_exists(path)
  return stat(path) ~= nil
end

local function is_directory(path)
  local info = stat(path)
  return info and info.type == "directory" or false
end

local function display_name(path)
  local parent = vim.fn.fnamemodify(path, ":h")
  local name = vim.fn.fnamemodify(parent, ":t")
  return name ~= "" and name or vim.fn.fnamemodify(path, ":t")
end

local function mode_includes(mode, scope)
  return mode == "full" or mode == nil or scope == mode
end

local function target_from(value, root, fallback_label, kind)
  local source = type(value) == "table" and value or { path = value }
  local target = vim.deepcopy(source)
  target.label = target.label or fallback_label or vim.fn.fnamemodify(target.path or "", ":t")
  target.kind = kind or target.kind or "setup"
  target.path = resolve_path(root, target.path)
  target.exists = path_exists(target.path)
  return target
end

local function add_target(items, seen, target)
  if not target.path or target.path == "" then
    return
  end
  local key = target.path .. "\0" .. tostring(target.matcher or "")
  if seen[key] then
    return
  end
  seen[key] = true
  table.insert(items, target)
end

local function collect_root(root_cfg, mode, result, skill_seen, file_seen)
  local scope = root_cfg.scope or "user"
  if not mode_includes(mode, scope) then
    return
  end

  local root_path = normalize_path(root_cfg.path)
  local root = {
    id = root_cfg.id or root_cfg.label or root_path,
    label = root_cfg.label or root_cfg.id or root_path,
    scope = scope,
    path = root_path,
    exists = is_directory(root_path),
    skills = 0,
  }
  table.insert(result.roots, root)

  for _, file in ipairs(root_cfg.setup_files or root_cfg.files or {}) do
    add_target(result.files, file_seen, target_from(file, root_path, nil, "setup"))
  end

  for _, skill_dir in ipairs(root_cfg.skill_dirs or {}) do
    local absolute_dir = resolve_path(root_path, skill_dir)
    if is_directory(absolute_dir) then
      for _, skill_file in ipairs(vim.fn.globpath(absolute_dir, "**/SKILL.md", false, true)) do
        local path = normalize_path(skill_file)
        if not skill_seen[path] then
          skill_seen[path] = true
          root.skills = root.skills + 1
          table.insert(result.skills, {
            label = display_name(path),
            path = path,
            scope = scope,
            root_label = root.label,
            exists = true,
          })
        end
      end
    end
  end
end

local function collect_config_targets(agent_cfg, result, file_seen)
  if agent_cfg.config_path then
    add_target(result.files, file_seen, target_from({
      label = "primary config",
      path = agent_cfg.config_path,
      matcher = agent_cfg.config_matcher,
    }, "", nil, "config"))
  end

  for _, target in ipairs(agent_cfg.config_alternates or {}) do
    add_target(result.files, file_seen, target_from(target, "", "config", "config"))
  end
end

local function inspect_group(spec, mode)
  local result = {
    id = spec.id,
    label = spec.label,
    profile = spec.profile,
    available = spec.available,
    roots = {},
    files = {},
    skills = {},
  }
  local skill_seen = {}
  local file_seen = {}

  for _, root in ipairs(spec.roots or {}) do
    collect_root(root, mode, result, skill_seen, file_seen)
  end
  for _, target in ipairs(spec.config_targets or {}) do
    add_target(result.files, file_seen, target_from(target, "", "config", "config"))
  end
  if spec.agent_cfg then
    collect_config_targets(spec.agent_cfg, result, file_seen)
  end

  table.sort(result.roots, function(a, b)
    return a.label < b.label
  end)
  table.sort(result.files, function(a, b)
    return a.label < b.label
  end)
  table.sort(result.skills, function(a, b)
    return a.label < b.label
  end)

  local existing_roots = 0
  for _, root in ipairs(result.roots) do
    if root.exists then
      existing_roots = existing_roots + 1
    end
  end
  local existing_files = 0
  for _, target in ipairs(result.files) do
    if target.exists then
      existing_files = existing_files + 1
    end
  end

  result.existing_roots = existing_roots
  result.existing_files = existing_files
  result.state = "missing"
  local expected = #result.roots + #result.files
  local existing = existing_roots + existing_files
  if expected > 0 and existing == expected then
    result.state = "ready"
  elseif existing > 0 then
    result.state = "partial"
  end
  return result
end

local function cache_key(mode)
  return table.concat({ mode or "full", vim.fn.getcwd() }, "\0")
end

function M.invalidate()
  M._cache = {}
end

---@param agents_cfg table[]
---@param settings_cfg table
---@param mode string|nil
---@return table
function M.inspect(agents_cfg, settings_cfg, mode)
  mode = mode or settings_cfg.default_mode or "full"
  local key = cache_key(mode)
  local now = uv.hrtime()
  local cached = M._cache[key]
  if cached and now - cached.at < CACHE_TTL_NS then
    return cached.value
  end

  local groups = {}
  if #(settings_cfg.shared_roots or {}) > 0 then
    table.insert(groups, inspect_group({
      id = "shared",
      label = settings_cfg.shared_label or "Shared agent setup",
      roots = settings_cfg.shared_roots,
    }, mode))
  end

  local ok, agents = pcall(require, "utils.mcphub_agents")
  for _, agent_cfg in ipairs(agents_cfg or {}) do
    local profile = ok and agents.normalize_profile(agent_cfg) or {
      id = agent_cfg.id or agent_cfg.name,
      label = agent_cfg.label or agent_cfg.id or agent_cfg.name,
    }
    table.insert(groups, inspect_group({
      id = profile.id,
      label = profile.label,
      profile = profile,
      available = ok and agents.is_available(profile) or nil,
      roots = agent_cfg.settings_roots or {},
      agent_cfg = agent_cfg,
    }, mode))
  end

  local summary = {
    groups = #groups,
    ready = 0,
    partial = 0,
    missing = 0,
    skills = 0,
  }
  for _, group in ipairs(groups) do
    summary[group.state] = (summary[group.state] or 0) + 1
    summary.skills = summary.skills + #group.skills
  end

  local value = {
    mode = mode,
    groups = groups,
    summary = summary,
  }
  M._cache[key] = { at = now, value = value }
  return value
end

function M.next_mode(current, modes)
  modes = modes or { "full", "user", "local" }
  for index, mode in ipairs(modes) do
    if mode == current then
      return modes[(index % #modes) + 1]
    end
  end
  return modes[1] or "full"
end

return M
