local M = {}

local REGISTRY_PATH = vim.fn.expand("~/Library/Application Support/obsidian/obsidian.json")
local APP_SUPPORT_DIR = vim.fn.expand("~/Library/Application Support/obsidian")
local PROFILE_STORE_DIR = vim.fn.expand("~/Library/Application Support/ObsidianPlugins/Profiles")

local CACHE_DIRS = {
  "Cache",
  "Code Cache",
  "GPUCache",
  "DawnGraphiteCache",
  "DawnWebGPUCache",
}

local SCAN_ROOTS = {
  "~/Personal",
  "~/Documents",
  "~/AgodaGit",
  "~/dotfiles",
}

local function path_join(...)
  return table.concat({ ... }, "/"):gsub("/+", "/")
end

local function normalize_path(path)
  if not path or path == "" then return nil end
  return vim.fn.fnamemodify(vim.fn.expand(path), ":p"):gsub("/$", "")
end

local function uri_encode(value)
  return (tostring(value):gsub("[^%w%-%._~]", function(char)
    return string.format("%%%02X", char:byte())
  end))
end

local function obsidian_open_uri(path)
  return "obsidian://open?path=" .. uri_encode(path)
end

local function is_dir(path)
  local stat = path and vim.uv.fs_stat(path)
  return stat and stat.type == "directory"
end

local function is_file(path)
  local stat = path and vim.uv.fs_stat(path)
  return stat and stat.type == "file"
end

local function is_path(path)
  return path and vim.uv.fs_stat(path) ~= nil
end

local function starts_with_path(path, root)
  path, root = normalize_path(path), normalize_path(root)
  return path and root and path ~= root and path:sub(1, #root + 1) == root .. "/"
end

local function read_json(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local text = f:read("*a")
  f:close()
  local ok, data = pcall(vim.json.decode, text)
  return ok and data or nil
end

local function write_json(path, data)
  local encoded = vim.json.encode(data)
  return vim.fn.writefile({ encoded }, path) == 0
end

local function backup_file(path)
  if not is_file(path) then return nil end
  local backup = path .. ".bak." .. os.date("%Y%m%d%H%M%S")
  if vim.fn.writefile(vim.fn.readfile(path), backup) == 0 then return backup end
  return nil
end

local function size_bytes(path)
  if not is_path(path) then return 0 end
  local lines = vim.fn.systemlist({ "du", "-sk", path })
  if vim.v.shell_error ~= 0 or not lines[1] then return 0 end
  local kb = tonumber(lines[1]:match("^(%d+)")) or 0
  return kb * 1024
end

local function format_size(bytes)
  if not bytes or bytes <= 0 then return "0B" end
  local units = { "B", "K", "M", "G" }
  local size = bytes
  local unit = 1
  while size >= 1024 and unit < #units do
    size = size / 1024
    unit = unit + 1
  end
  if unit == 1 then return string.format("%d%s", size, units[unit]) end
  return string.format("%.1f%s", size, units[unit])
end

local function add_reason(reasons, reason)
  if reason and reason ~= "" then table.insert(reasons, reason) end
end

local function sanitize_path(path)
  local value = normalize_path(path) or path or "unknown"
  value = value:gsub("^/", ""):gsub("/", "__"):gsub("[^%w%._%-]+", "_")
  return value ~= "" and value or "unknown"
end

local function quarantine_dest(src)
  local root = path_join(vim.fn.expand("~/.Trash/obsidian-cleanup"), os.date("%Y%m%d"))
  local base = path_join(root, sanitize_path(src))
  local dest = base
  local i = 1
  while is_path(dest) do
    i = i + 1
    dest = base .. "." .. i
  end
  return root, dest
end

local function command_quarantine(src)
  if not src then return nil end
  local root, dest = quarantine_dest(src)
  return ("mkdir -p %s && mv %s %s"):format(vim.fn.shellescape(root), vim.fn.shellescape(src), vim.fn.shellescape(dest))
end

local function read_registry()
  local data = read_json(REGISTRY_PATH)
  if not data then return { vaults = {}, cli = true } end
  data.vaults = data.vaults or {}
  return data
end

local function registry_paths(data)
  local result = {}
  for id, vault in pairs(data.vaults or {}) do
    local path = normalize_path(vault.path)
    if path then result[id] = path end
  end
  return result
end

local function nested_registry_parent(path, paths_by_id, own_id)
  for id, other in pairs(paths_by_id) do
    if id ~= own_id and starts_with_path(path, other) then return other end
  end
  return nil
end

local function is_broad_vault(path)
  local home = normalize_path("~")
  local broad = {
    home,
    normalize_path("~/Documents"),
    normalize_path("~/AgodaGit"),
    normalize_path("~/dotfiles"),
  }
  for _, root in ipairs(broad) do
    if path == root then return true end
  end
  return false
end

local function item_preview(item)
  local lines = {
    "# " .. item.label,
    "",
    "- Status: " .. item.risk,
    "- Kind: " .. item.kind,
    "- Path: `" .. (item.path or "-") .. "`",
  }
  if item.config_path then table.insert(lines, "- Config: `" .. item.config_path .. "`") end
  if item.registry_id then table.insert(lines, "- Registry ID: `" .. item.registry_id .. "`") end
  if item.size_display then table.insert(lines, "- Size: " .. item.size_display) end
  if item.open ~= nil then table.insert(lines, "- Registry open flag: " .. tostring(item.open)) end
  table.insert(lines, "")
  table.insert(lines, "## Reasons")
  if item.reasons and #item.reasons > 0 then
    for _, reason in ipairs(item.reasons) do
      table.insert(lines, "- " .. reason)
    end
  else
    table.insert(lines, "- No cleanup reason detected.")
  end
  table.insert(lines, "")
  table.insert(lines, "## Suggested Action")
  table.insert(lines, item.suggested_action or "Review manually.")
  table.insert(lines, "")
  table.insert(lines, "## Picker Actions")
  table.insert(lines, "- `<CR>`: open vault in Obsidian; non-vault rows reveal path")
  table.insert(lines, "- `<A-o>`: reveal selected path")
  table.insert(lines, "- `<A-y>`: copy this item report")
  table.insert(lines, "- `<A-q>`: quarantine selected config/cache/profile path")
  table.insert(lines, "- `<A-r>`: remove selected Obsidian registry entry")
  table.insert(lines, "- `<C-r>`: refresh audit")
  if item.quarantine_path then
    table.insert(lines, "")
    table.insert(lines, "## Quarantine Command")
    table.insert(lines, "```sh")
    table.insert(lines, command_quarantine(item.quarantine_path) or "")
    table.insert(lines, "```")
  end
  return table.concat(lines, "\n")
end

local function make_item(item)
  item.size_display = item.size_bytes and format_size(item.size_bytes) or nil
  item.label = item.label or item.path or item.kind
  item.text = table.concat({
    item.risk or "",
    item.kind or "",
    item.path or "",
    table.concat(item.reasons or {}, " "),
  }, " ")
  item.preview = { text = item_preview(item), ft = "markdown", loc = false }
  return item
end

local function build_vault_item(id, vault, paths_by_id)
  local path = normalize_path(vault.path)
  local config_path = path and path_join(path, ".obsidian") or nil
  local reasons = {}
  local risk = "keep"
  local suggested = "Keep."
  local exists = is_dir(path)
  local has_config = is_dir(config_path)
  local bytes = has_config and size_bytes(config_path) or 0

  if not path then
    risk = "dead"
    suggested = "Remove this registry entry."
    add_reason(reasons, "Registry entry has no path.")
  elseif not exists then
    risk = "dead"
    suggested = "Remove this registry entry."
    add_reason(reasons, "Registered vault path does not exist.")
  elseif not has_config then
    risk = "review"
    suggested = "Remove registry entry or seed a new config."
    add_reason(reasons, "Registered vault path exists but has no .obsidian directory.")
  elseif bytes == 0 then
    risk = "dead"
    suggested = "Quarantine empty .obsidian and remove registry entry if not intentional."
    add_reason(reasons, ".obsidian directory is empty.")
  else
    local nested = nested_registry_parent(path, paths_by_id, id)
    if nested then
      risk = "review"
      suggested = "Keep only if this nested vault is intentional."
      add_reason(reasons, "Vault is nested under registered vault: " .. nested)
    end
    if is_broad_vault(path) then
      risk = "review"
      suggested = "Keep only if this broad vault root is intentional."
      add_reason(reasons, "Vault root is broad and can accidentally capture many files.")
    end
    if path:find("%.worktrees/", 1, false) then
      risk = "review"
      suggested = "Quarantine config after confirming the worktree vault is no longer needed."
      add_reason(reasons, "Vault is inside a worktree path.")
    end
    if path:find("/lua/plugins/extra", 1, false) then
      risk = "review"
      suggested = "Likely accidental; quarantine .obsidian after confirming."
      add_reason(reasons, "Vault points inside Neovim plugin config.")
    end
    if bytes >= 30 * 1024 * 1024 and path ~= normalize_path("~/Personal/mynotes") then
      risk = "review"
      suggested = "Likely full seeded config; consider replacing with minimal profile-switcher seed."
      add_reason(reasons, "Large .obsidian directory outside the main notes vault.")
    end
  end

  return make_item({
    kind = "vault",
    registry_id = id,
    path = path or vault.path,
    config_path = config_path,
    quarantine_path = has_config and config_path or nil,
    size_bytes = bytes,
    open = vault.open,
    risk = risk,
    reasons = reasons,
    suggested_action = suggested,
    label = "Vault: " .. (path and vim.fn.fnamemodify(path, ":~") or tostring(vault.path)),
  })
end

local function scan_obsidian_dirs()
  local result = {}
  local seen = {}
  for _, root in ipairs(SCAN_ROOTS) do
    local expanded = normalize_path(root)
    if expanded and is_dir(expanded) then
      local lines
      if vim.fn.executable("fd") == 1 then
        lines = vim.fn.systemlist({ "fd", "--hidden", "--absolute-path", "--type", "directory", "--max-depth", "6", "^\\.obsidian$", expanded })
      else
        lines = vim.fn.systemlist({ "find", expanded, "-maxdepth", "6", "-type", "d", "-name", ".obsidian", "-print" })
      end
      for _, path in ipairs(lines or {}) do
        path = normalize_path(path)
        if path and not seen[path] and path:match("/%.obsidian$") then
          seen[path] = true
          table.insert(result, path)
        end
      end
    end
  end
  return result
end

local function build_orphan_config_item(config_path, registered_roots)
  local root_path = config_path:gsub("/%.obsidian$", "")
  local reasons = { "Found .obsidian directory that is not registered as an Obsidian vault." }
  for _, root in pairs(registered_roots) do
    if starts_with_path(root_path, root) then
      add_reason(reasons, "Config is nested under registered vault: " .. root)
      break
    end
  end
  local bytes = size_bytes(config_path)
  local risk = bytes == 0 and "dead" or "review"
  local suggested = bytes == 0 and "Quarantine empty .obsidian." or "Review and quarantine if this vault is stale."
  return make_item({
    kind = "orphan-config",
    path = root_path,
    config_path = config_path,
    quarantine_path = config_path,
    size_bytes = bytes,
    risk = risk,
    reasons = reasons,
    suggested_action = suggested,
    label = "Orphan config: " .. vim.fn.fnamemodify(config_path, ":~"),
  })
end

local function build_cache_item(path)
  local name = vim.fn.fnamemodify(path, ":t")
  return make_item({
    kind = "app-cache",
    path = path,
    quarantine_path = path,
    size_bytes = size_bytes(path),
    risk = "cache",
    reasons = { "Obsidian app cache. Clean only while Obsidian is closed." },
    suggested_action = "Quit Obsidian, then quarantine if you want to reclaim cache space.",
    label = "Cache: " .. name,
  })
end

local function build_profile_store_item()
  if not is_dir(PROFILE_STORE_DIR) then return nil end
  return make_item({
    kind = "profile-store",
    path = PROFILE_STORE_DIR,
    quarantine_path = nil,
    size_bytes = size_bytes(PROFILE_STORE_DIR),
    risk = "keep",
    reasons = { "Settings Profiles global profile store. Usually keep this unless deleting profiles intentionally." },
    suggested_action = "Open and review profile folders before deleting.",
    label = "Settings Profiles store",
  })
end

function M.build_items(opts)
  opts = opts or {}
  local data = read_registry()
  local paths_by_id = registry_paths(data)
  local registered_by_root = {}
  local items = {}

  for id, path in pairs(paths_by_id) do
    registered_by_root[path] = true
    table.insert(items, build_vault_item(id, data.vaults[id], paths_by_id))
  end

  if opts.scan ~= false then
    for _, config_path in ipairs(scan_obsidian_dirs()) do
      local root_path = config_path:gsub("/%.obsidian$", "")
      if not registered_by_root[root_path] then
        table.insert(items, build_orphan_config_item(config_path, paths_by_id))
      end
    end
  end

  for _, name in ipairs(CACHE_DIRS) do
    local path = path_join(APP_SUPPORT_DIR, name)
    if is_dir(path) then table.insert(items, build_cache_item(path)) end
  end

  local profile_item = build_profile_store_item()
  if profile_item then table.insert(items, profile_item) end

  local order = { dead = 1, review = 2, cache = 3, keep = 4 }
  table.sort(items, function(a, b)
    local ar = order[a.risk] or 9
    local br = order[b.risk] or 9
    if ar ~= br then return ar < br end
    return (a.path or "") < (b.path or "")
  end)

  return items
end

function M.item_report(item)
  return item_preview(item)
end

local function confirm(prompt, label, cb)
  vim.ui.select({ label, "Cancel" }, { prompt = prompt }, function(choice)
    if choice == label then cb() end
  end)
end

local function reveal_path(path)
  if path and vim.fn.executable("open") == 1 then
    vim.system({ "open", "-R", path }, { detach = true })
  elseif path then
    vim.ui.open(path)
  end
end

local function vault_path_for_item(item)
  if not item or (item.kind ~= "vault" and item.kind ~= "orphan-config") then return nil end
  local path = normalize_path(item.path)
  if path and is_dir(path) then return path end
  return nil
end

local function refresh_picker(picker, opts)
  local items = M.build_items(opts)
  picker.opts.items = items
  picker.title = "Obsidian Vault Audit (" .. #items .. ")"
  picker:find()
end

function M.remove_registry_entry(item)
  if not item or not item.registry_id then
    vim.notify("No registry entry for selected item", vim.log.levels.WARN)
    return false
  end
  local data = read_registry()
  if not data.vaults[item.registry_id] then
    vim.notify("Registry entry already absent: " .. item.registry_id, vim.log.levels.INFO)
    return true
  end
  local backup = backup_file(REGISTRY_PATH)
  data.vaults[item.registry_id] = nil
  if not write_json(REGISTRY_PATH, data) then
    vim.notify("Failed to write Obsidian registry", vim.log.levels.ERROR)
    return false
  end
  vim.notify("Removed Obsidian registry entry. Backup: " .. tostring(backup), vim.log.levels.INFO)
  return true
end

function M.quarantine_path(path)
  if not is_path(path) then
    vim.notify("Path does not exist: " .. tostring(path), vim.log.levels.WARN)
    return false
  end
  local root, dest = quarantine_dest(path)
  vim.fn.mkdir(root, "p")
  local ok = vim.fn.rename(path, dest) == 0
  if not ok then
    vim.notify("Failed to quarantine: " .. path, vim.log.levels.ERROR)
    return false
  end
  vim.notify("Quarantined to: " .. dest, vim.log.levels.INFO)
  return true
end

function M.pick(opts)
  opts = opts or {}
  local ok, Snacks = pcall(require, "snacks")
  if not ok or not Snacks or not Snacks.picker then
    vim.notify("Snacks picker is not available", vim.log.levels.ERROR)
    return
  end

  local items = M.build_items(opts)
  Snacks.picker.pick({
    source = "obsidian_vault_audit",
    title = "Obsidian Vault Audit (" .. #items .. ")",
    items = items,
    format = function(item)
      local risk_hl = ({
        dead = "DiagnosticError",
        review = "DiagnosticWarn",
        cache = "DiagnosticInfo",
        keep = "DiagnosticOk",
      })[item.risk] or "Normal"
      return {
        { "[" .. item.risk .. "] ", risk_hl },
        { item.kind .. " ", "SnacksPickerLabel" },
        { item.size_display and (item.size_display .. " ") or "", "Comment" },
        { item.path and vim.fn.fnamemodify(item.path, ":~") or item.label, "SnacksPickerFile" },
      }
    end,
    preview = "preview",
    actions = {
      open_vault = function(_, item)
        if not item then return end
        local vault_path = vault_path_for_item(item)
        if vault_path then
          vim.ui.open(obsidian_open_uri(vault_path))
          return
        end
        vim.notify("Selected item is not an existing Obsidian vault; revealing path instead", vim.log.levels.WARN)
        reveal_path(item.config_path or item.path)
      end,
      reveal_item = function(_, item)
        if not item then return end
        reveal_path(item.config_path or item.path)
      end,
      copy_report = function(_, item)
        if not item then return end
        vim.fn.setreg("+", M.item_report(item))
        vim.notify("Copied Obsidian audit item report", vim.log.levels.INFO)
      end,
      refresh_audit = function(picker)
        refresh_picker(picker, opts)
      end,
      quarantine_selected = function(picker, item)
        if not item or not item.quarantine_path then
          vim.notify("Selected item has no quarantine target", vim.log.levels.WARN)
          return
        end
        confirm("Move to ~/.Trash/obsidian-cleanup: " .. item.quarantine_path .. "?", "Quarantine", function()
          if M.quarantine_path(item.quarantine_path) then refresh_picker(picker, opts) end
        end)
      end,
      remove_registry = function(picker, item)
        if not item or not item.registry_id then
          vim.notify("Selected item has no registry entry", vim.log.levels.WARN)
          return
        end
        confirm("Remove Obsidian registry entry for: " .. tostring(item.path) .. "?", "Remove registry", function()
          if M.remove_registry_entry(item) then refresh_picker(picker, opts) end
        end)
      end,
      quarantine_and_remove_registry = function(picker, item)
        if not item then return end
        if not item.quarantine_path or not item.registry_id then
          vim.notify("Selected item needs both a config path and registry entry", vim.log.levels.WARN)
          return
        end
        confirm("Quarantine config and remove registry entry for: " .. tostring(item.path) .. "?", "Quarantine + remove", function()
          local moved = M.quarantine_path(item.quarantine_path)
          local removed = moved and M.remove_registry_entry(item)
          if moved or removed then refresh_picker(picker, opts) end
        end)
      end,
    },
    confirm = "open_vault",
    win = {
      input = {
        footer = "<CR> open vault  <A-o> reveal  <A-y> copy info  <A-q> quarantine  <A-r> rm registry  <A-x> both  <C-r> refresh",
        footer_pos = "left",
        keys = {
          ["<A-o>"] = { "reveal_item", mode = { "i", "n" }, desc = "Reveal selected path" },
          ["<A-y>"] = { "copy_report", mode = { "i", "n" }, desc = "Copy item report" },
          ["<A-q>"] = { "quarantine_selected", mode = { "i", "n" }, desc = "Quarantine selected path" },
          ["<A-r>"] = { "remove_registry", mode = { "i", "n" }, desc = "Remove registry entry" },
          ["<A-x>"] = { "quarantine_and_remove_registry", mode = { "i", "n" }, desc = "Quarantine + remove registry" },
          ["<C-r>"] = { "refresh_audit", mode = { "i", "n" }, desc = "Refresh audit" },
        },
      },
      list = {
        keys = {
          ["<A-o>"] = "reveal_item",
          ["<A-y>"] = "copy_report",
          ["<A-q>"] = "quarantine_selected",
          ["<A-r>"] = "remove_registry",
          ["<A-x>"] = "quarantine_and_remove_registry",
          ["<C-r>"] = "refresh_audit",
        },
      },
    },
  })
end

return M
