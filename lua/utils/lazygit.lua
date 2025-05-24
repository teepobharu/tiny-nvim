local LazyVimUi = require("utils.ui")
local LazyVimRoot = require("utils.root")
local LazyUtil = require("lazy.util")

---@class lazyvim.util.lazygit
---@field config_dir? string
---@overload fun(cmd: string|string[], opts: LazyTermOpts): LazyFloat
local M = setmetatable({}, {
  __call = function(m, ...)
    return m.open(...)
  end,
})

---@alias LazyGitColor {fg?:string, bg?:string, bold?:boolean}

---@class LazyGitTheme: table<number, LazyGitColor>
---@field activeBorderColor LazyGitColor
---@field cherryPickedCommitBgColor LazyGitColor
---@field cherryPickedCommitFgColor LazyGitColor
---@field defaultFgColor LazyGitColor
---@field inactiveBorderColor LazyGitColor
---@field optionsTextColor LazyGitColor
---@field searchingActiveBorderColor LazyGitColor
---@field selectedLineBgColor LazyGitColor
---@field unstagedChangesColor LazyGitColor
M.theme = {
  [241] = { fg = "Special" },
  activeBorderColor = { fg = "MatchParen", bold = true },
  cherryPickedCommitBgColor = { fg = "Identifier" },
  cherryPickedCommitFgColor = { fg = "Function" },
  defaultFgColor = { fg = "Normal" },
  inactiveBorderColor = { fg = "FloatBorder" },
  optionsTextColor = { fg = "Function" },
  searchingActiveBorderColor = { fg = "MatchParen", bold = true },
  selectedLineBgColor = { bg = "Visual" }, -- set to `default` to have no background colour
  unstagedChangesColor = { fg = "DiagnosticError" },
}

M.theme_path = LazyUtil.norm(vim.fn.stdpath("cache") .. "/lazygit-theme.yml")

-- re-create config file on startup
M.dirty = true

-- re-create theme file on ColorScheme change
vim.api.nvim_create_autocmd("ColorScheme", {
  callback = function()
    M.dirty = true
  end,
})

-- Opens lazygit
---@param opts? LazyTermOpts | {args?: string[]}
function M.open(opts)
  if vim.g.lazygit_theme ~= nil then
    vim.notify("Deprecated ~ vim.g.lazygit_theme", "vim.g.lazygit_config", { severity = "warning" })
  end

  opts = vim.tbl_deep_extend("force", {}, {
    esc_esc = false,
    ctrl_hjkl = false,
  }, opts or {})

  local cmd = { "lazygit" }
  vim.list_extend(cmd, opts.args or {})

  print([==[M.open#if vim.g.lazygit_config:]==], vim.inspect(vim.g.lazygit_config)) -- __AUTO_GENERATED_PRINT_VAR_END__
  if vim.g.lazygit_config then
    -- __AUTO_GENERATED_PRINT_VAR_START__

    print([==[M.open#if#if M.dirty:]==], vim.inspect(M.dirty)) -- __AUTO_GENERATED_PRINT_VAR_END__
    if M.dirty then
      -- __AUTO_GENERATED_PRINT_VAR_START__
      M.update_config()
    end

    print([==[M.open#if#if M.config_dir:]==], vim.inspect(M.config_dir)) -- __AUTO_GENERATED_PRINT_VAR_END__
    if not M.config_dir then
      -- __AUTO_GENERATED_PRINT_VAR_START__
      local Process = require("lazy.manage.process")
      local ok, lines = pcall(Process.exec, { "lazygit", "-cd" })
      if ok then
        M.config_dir = lines[1]
        vim.env.LG_CONFIG_FILE = LazyUtil.norm(M.config_dir .. "/config.yml" .. "," .. M.theme_path)
      else
        ---@diagnostic disable-next-line: cast-type-mismatch
        ---@cast lines string
        LazyUtil.error(
          { "Failed to get **lazygit** config directory.", "Will not apply **lazygit** config.", "", "# Error:", lines },
          { title = "lazygit" }
        )
      end
    end
  end

  vim.notify(
    "Opening lazygit" .. vim.inspect(cmd) .. (vim.env.LG_CONFIG_FILE or "LG_CONFIG nil"),
    { severity = "info" }
  )
  -- join the command with space
  return table.concat(cmd, " ")
  -- return cmd -- open in toggle term instead
  -- return LazyUtil.terminal(cmd, opts)
end

function M.set_ansi_color(idx, color)
  io.write(("\27]4;%d;%s\7"):format(idx, color))
end

---@param v LazyGitColor
---@return string[]
function M.get_color(v)
  ---@type string[]
  local color = {}
  if v.fg then
    color[1] = LazyVimUi.color(v.fg)
  elseif v.bg then
    color[1] = LazyVimUi.color(v.bg, true)
  end
  if v.bold then
    table.insert(color, "bold")
  end
  return color
end

function M.update_config()
  ---@type table<string, string[]>
  local theme = {}

  for k, v in pairs(M.theme) do
    if type(k) == "number" then
      local color = M.get_color(v)
      -- LazyGit uses color 241 a lot, so also set it to a nice color
      -- pcall, since some terminals don't like this
      pcall(M.set_ansi_color, k, color[1])
    else
      theme[k] = M.get_color(v)
    end
  end
  -- original lazy from: https://github.com/LazyVim/LazyVim/blob/12818a6cb499456f4903c5d8e68af43753ebc869/lua/lazyvim/util/lazygit.lua#L124
  -- preset info: https://github.com/jesseduffield/lazygit/blob/8a8490d97d13b55d232f8a7c69a40668dc3cd5af/pkg/config/editor_presets.go#L4
  local config = [[
os:
  editPreset: "nvim-remote"
  openDirInEditor: "code -- {{dir}}"
gui:
  nerdFontsVersion: 3
  theme: 
]]

  ---@type string[]
  local lines = {}
  for k, v in pairs(theme) do
    lines[#lines + 1] = ("   %s:"):format(k)
    for _, c in ipairs(v) do
      lines[#lines + 1] = ("     - %q"):format(c)
    end
  end
  config = config .. table.concat(lines, "\n")
  LazyUtil.write_file(M.theme_path, config)
  M.dirty = false
end

---@param opts? {count?: number}|LazyCmdOptions
function M.blame_line(opts)
  opts = vim.tbl_deep_extend("force", {
    count = 3,
    filetype = "git",
    size = {
      width = 0.6,
      height = 0.6,
    },
    border = "rounded",
  }, opts or {})
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1]
  local file = vim.api.nvim_buf_get_name(0)
  local root = LazyVimRoot.detectors.pattern(0, { ".git" })[1] or "."
  local cmd = { "git", "-C", root, "log", "-n", opts.count, "-u", "-L", line .. ",+1:" .. file }
  return LazyUtil.float_cmd(cmd, opts)
end

-- stylua: ignore
M.remote_patterns = {
  { "^(https?://.*)%.git$"              , "%1" },
  { "^git@(.+):(.+)%.git$"              , "https://%1/%2" },
  { "^git@(.+):(.+)$"                   , "https://%1/%2" },
  { "^git@(.+)/(.+)$"                   , "https://%1/%2" },
  { "^ssh://git@(.*)$"                  , "https://%1" },
  { "ssh%.dev%.azure%.com/v3/(.*)/(.*)$", "dev.azure.com/%1/_git/%2" },
  { "^https://%w*@(.*)"                 , "https://%1" },
  { "^git@(.*)"                         , "https://%1" },
  { ":%d+"                              , "" },
  { "%.git$"                            , "" },
}

---@param remote string
function M.get_url(remote)
  local ret = remote
  for _, pattern in ipairs(M.remote_patterns) do
    ret = ret:gsub(pattern[1], pattern[2])
  end
  return ret:find("https://") == 1 and ret or ("https://%s"):format(ret)
end

function M.browse()
  local lines = require("lazy.manage.process").exec({ "git", "remote", "-v" })
  local remotes = {} ---@type {name:string, url:string}[]

  for _, line in ipairs(lines) do
    local name, remote = line:match("(%S+)%s+(%S+)%s+%(fetch%)")
    if name and remote then
      local url = M.get_url(remote)
      if url then
        table.insert(remotes, {
          name = name,
          url = url,
        })
      end
    end
  end

  local function open(remote)
    if remote then
      if vim.fn.has("nvim-0.10") == 0 then
        LazyUtil.open(remote.url, { system = true })
        return
      end
      vim.ui.open(remote.url)
    end
  end

  if #remotes == 0 then
  elseif #remotes == 1 then
    return open(remotes[1])
  end

  vim.ui.select(remotes, {
    prompt = "Select remote to browse",
    format_item = function(item)
      return item.name .. (" "):rep(8 - #item.name) .. " 🔗 " .. item.url
    end,
  }, open)
end

return M
