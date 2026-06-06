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

local function build_git_status_map(base_ref, head_ref)
  local file_status_map = {}
  if not base_ref or base_ref == "" then
    return file_status_map
  end
  head_ref = (head_ref and head_ref ~= "") and head_ref or "HEAD"

  local status_output = vim.fn.systemlist {
    "git",
    "diff",
    "--name-status",
    base_ref .. ".." .. head_ref,
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

local function preview_git_diff_with_base(base_ref, head_ref)
  head_ref = (head_ref and head_ref ~= "") and head_ref or "HEAD"
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

    vim.list_extend(cmd, { "diff", base_ref .. ".." .. head_ref, "--", ctx.item.file })
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

--- Session picker using snacks — supports two sources toggled with <M-s>:
---   "startify"   (default): named sessions from vim.g.startify_session_dir
---   "persistence": CWD-based sessions from persistence.nvim
---
--- Common actions (both sources):
---   - confirm (Enter): load selected session
---   - save_session (C-s): save session (startify: SSave! <name>; persistence: save current CWD)
---   - delete_session (C-x): delete with confirmation
---   - toggle_source (M-s): switch between startify / persistence sources
---@param source? "startify"|"persistence"
function M.session_picker(source)
  source = source or "startify"

  -- ── Startify source ──────────────────────────────────────────────────────
  if source == "startify" then
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
          local name, ftype = vim.loop.fs_scandir_next(handle)
          if not name then
            break
          end
          if ftype == "file" and name:match "^[%a%d][%w_]*$" then
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
      title = "Sessions [Startify] (C-s: save, C-x: delete, M-s: persistence)",
      finder = function(_opts, _ctx)
        return scan_sessions()
      end,
      format = "text",
      layout = { preset = "select" },
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
        toggle_source = function(picker, _item)
          picker:close()
          vim.defer_fn(function()
            M.session_picker "persistence"
          end, 50)
        end,
      },
      win = {
        input = {
          keys = {
            ["<C-s>"] = { "save_session", mode = { "n", "i" }, desc = "Save session" },
            ["<C-x>"] = { "delete_session", mode = { "n", "i" }, desc = "Delete session" },
            ["<M-s>"] = { "toggle_source", mode = { "n", "i" }, desc = "Switch to Persistence sessions" },
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

  -- ── Persistence source ───────────────────────────────────────────────────
  -- Decoding mirrors persistence.nvim's own select() logic (init.lua:106-135):
  --   Filename encoding: cwd:gsub("[\\/:]+", "%%") → literal single "%" per separator
  --   Branch separator:  "%%" (two literal percent signs) appended after CWD
  --   vim.split(encoded, "%%", {plain=true}) → { dir_encoded, branch? }
  --   dir_encoded:gsub("%%", "/") → readable path  (gsub pattern "%%" matches literal "%")
  elseif source == "persistence" then
    local ok, persistence = pcall(require, "persistence")
    if not ok then
      vim.notify("persistence.nvim is not available", vim.log.levels.ERROR)
      return
    end

    local home = vim.fn.expand "~"
    local config_dir = require("persistence.config").options.dir
    local uv = vim.uv or vim.loop

    --- Parse a persistence session file path into a display item.
    --- Uses the same decode logic as persistence.nvim's select() (init.lua:112-114).
    ---@param session_file string  absolute path to the .vim session file
    ---@return {text: string, dir: string, branch: string|nil, session: string}|nil
    local function parse_persistence_session(session_file)
      if not uv.fs_stat(session_file) then
        return nil
      end
      -- Strip leading config dir and trailing ".vim"
      local encoded = session_file:sub(#config_dir + 1, -5)
      -- Split on "%%" (two literal percent signs) — separator between CWD and branch
      local dir_encoded, branch = unpack(vim.split(encoded, "%%", { plain = true }))
      -- Replace each literal "%" (path separator) with "/"
      local dir = dir_encoded:gsub("%%", "/")

      local display = vim.fn.fnamemodify(dir, ":p:~")
      -- Trim trailing slash for display
      if display:sub(-1) == "/" then
        display = display:sub(1, -2)
      end

      if branch then
        branch = branch:gsub("%%", "/")
        display = display .. "  [" .. branch .. "]"
      end
      return { text = display, dir = dir, branch = branch, session = session_file }
    end

    --- Build the list of persistence session items (sorted by mtime via persistence.list()).
    local function list_persistence_sessions()
      local items = {}
      for _, session_file in ipairs(persistence.list()) do
        local item = parse_persistence_session(session_file)
        if item then
          table.insert(items, item)
        end
      end
      return items
    end

    local initial = list_persistence_sessions()
    if #initial == 0 then
      vim.notify("No persistence sessions found", vim.log.levels.INFO)
      return
    end

    Snacks.picker.pick {
      source = "sessions_persistence",
      title = "Sessions [Persistence] (C-s: save cwd, C-x: delete, M-s: startify)",
      finder = function(_opts, _ctx)
        return list_persistence_sessions()
      end,
      format = "text",
      layout = { preset = "select" },
      actions = {
        save_session = function(picker, _item)
          persistence.save()
          local display_cwd = vim.fn.fnamemodify(vim.fn.getcwd(), ":p:~")
          vim.notify("Session saved: " .. display_cwd, vim.log.levels.INFO)
          vim.defer_fn(function()
            picker:refresh()
          end, 100)
        end,
        delete_session = function(picker, item)
          if not item then
            vim.notify("No session selected", vim.log.levels.WARN)
            return
          end
          vim.ui.select({ "Yes", "No" }, {
            prompt = "Delete persistence session '" .. item.text .. "'?",
          }, function(choice)
            if choice == "Yes" then
              uv.fs_unlink(item.session, function(err)
                vim.schedule(function()
                  if err then
                    vim.notify("Failed to delete session: " .. err, vim.log.levels.ERROR)
                  else
                    vim.notify("Session Deleted: " .. item.text, vim.log.levels.INFO)
                    picker:refresh()
                  end
                end)
              end)
            end
          end)
        end,
        toggle_source = function(picker, _item)
          picker:close()
          vim.defer_fn(function()
            M.session_picker "startify"
          end, 50)
        end,
      },
      win = {
        input = {
          keys = {
            ["<C-s>"] = { "save_session", mode = { "n", "i" }, desc = "Save current CWD session" },
            ["<C-x>"] = { "delete_session", mode = { "n", "i" }, desc = "Delete session" },
            ["<M-s>"] = { "toggle_source", mode = { "n", "i" }, desc = "Switch to Startify sessions" },
          },
        },
      },
      confirm = function(picker, item)
        picker:close()
        if item then
          vim.fn.chdir(item.dir)
          -- Source the specific session file directly instead of persistence.load()
          -- which would re-derive the session path from CWD (may not match if branch differs)
          vim.cmd("silent! source " .. vim.fn.fnameescape(item.session))
        end
      end,
    }
  end
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

--#region Ref File Picker Factory (unified builder for all ref-based file pickers)

--- Create actions table for a ref-based file picker.
--- All actions dynamically call get_ref() so navigation (C-j/C-k) is respected.
--- @param get_ref fun(): string Function returning the current base ref
--- @return table actions { open_file_diff, open_remote_at_ref, open_remote_at_head }
local function make_ref_file_actions(get_ref)
  return {
    open_file_diff = function(picker, item)
      if not item or not item.file then
        vim.notify("No file selected", vim.log.levels.WARN)
        return
      end
      picker:close()
      git_util.open_file_with_gitsigns_diff(item.file, get_ref())
    end,
    open_remote_at_ref = function(picker, item)
      if not item or not item.file then
        vim.notify("No file selected", vim.log.levels.WARN)
        return
      end
      git_util.open_file_in_remote(item.file, get_ref())
    end,
    open_remote_at_head = function(picker, item)
      if not item or not item.file then
        vim.notify("No file selected", vim.log.levels.WARN)
        return
      end
      git_util.open_file_in_remote(item.file, "HEAD")
    end,
  }
end

--- Create a finder function for a ref-based file picker.
--- @param get_ref fun(): string Function returning the current base ref
--- @param git_root string Git root path
--- @param git_args_fn? fun(ref: string, head_ref: string): table Custom git diff args builder (for staged/workdir modes)
--- @param get_head? fun(): string Function returning the current head ref (defaults to "HEAD")
--- @return fun(opts: table, ctx: table): table finder function
local function make_ref_file_finder(get_ref, git_root, git_args_fn, get_head)
  return function(opts, ctx)
    local show_missing = opts.external == true
    local ref = get_ref()
    local head_ref = (get_head and get_head()) or "HEAD"
    local args = git_args_fn and git_args_fn(ref, head_ref)
      or { "diff", "--name-only", "--diff-filter=d", ref .. ".." .. head_ref }

    local proc_opts = vim.tbl_extend("force", opts, {
      cmd = "git",
      args = args,
      cwd = git_root,
      transform = function(item)
        item.cwd = git_root
        item.file = item.text
        local missing = is_missing_file(item, git_root)
        local keep = should_keep_item(item, git_root, true, show_missing)
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
end

--- Create a format function for a ref-based file picker.
--- @param get_ref fun(): string Function returning the current base ref
--- @param get_head? fun(): string Function returning the current head ref (defaults to "HEAD")
--- @return fun(item: table): table format function
local function make_ref_file_format(get_ref, get_head)
  return function(item)
    local head_ref = (get_head and get_head()) or "HEAD"
    local file_status_map = build_git_status_map(get_ref(), head_ref)
    return git_status_formatter(file_status_map)(item)
  end
end

--- Apply a keytable to both win.input.keys and win.list.keys.
--- Eliminates the common pattern of duplicating keys across both windows.
--- @param base_keys table Key definitions to apply
--- @param extra_keys? table Additional keys to merge on top
--- @return table win { input = { keys = ... }, list = { keys = ... } }
local function apply_keys_to_both_windows(base_keys, extra_keys)
  local merged = extra_keys and vim.tbl_extend("force", base_keys, extra_keys) or base_keys
  return {
    input = { keys = vim.deepcopy(merged) },
    list = { keys = vim.deepcopy(merged) },
  }
end

--- Refresh a picker's title and items after navigation.
--- Common pattern used by all navigable ref-based pickers.
--- @param source string Picker source ID
--- @param get_title fun(): string Function returning the new title
local function refresh_ref_picker(source, get_title)
  local pickers = Snacks.picker.get { source = source }
  local picker = pickers[1]
  if picker then
    vim.schedule(function()
      picker.title = get_title()
      picker:update_titles()
      picker:refresh()
    end)
  end
end

--- Unified factory for ref-based file pickers.
--- All 4 git file pickers (last-commit, upstream, merge-base, change-list sub-picker)
--- use this factory with different ref strategies and optional navigation keys.
---
--- @param config table
---   - source: string - picker source ID
---   - title: string|fun(): string - picker title (or fn returning title)
---   - get_ref: fun(): string - returns current base ref
---   - get_head?: fun(): string - returns current head ref (defaults to "HEAD")
---   - git_root: string - git root path
---   - extra_actions?: table - additional actions to merge
---   - extra_keys?: table - additional keys (applied to both windows)
---   - on_back?: fun() - back navigation callback (adds <C-q> key)
---   - footer?: string - input footer text
---   - git_args_fn?: fun(ref: string, head_ref: string): table - custom git diff args builder
---   - confirm?: fun(picker, item) - custom confirm handler
---   - key_group?: string - which git_file_keys variant: "default"|"upstream"|nil
local function create_ref_file_picker(config)
  local editor_keymaps = require "utils.editor_keymaps"

  -- Resolve title
  local title = type(config.title) == "function" and config.title() or config.title

  -- Build actions
  local actions = make_ref_file_actions(config.get_ref)
  if config.extra_actions then
    actions = vim.tbl_extend("force", actions, config.extra_actions)
  end

  -- Resolve base key group
  local base_git_keys = {}
  if config.key_group == "upstream" then
    local gk = editor_keymaps.snacks_picker_group_keys.git_file_keys_upstream
    base_git_keys = vim.tbl_extend("force", gk.input or {}, gk.list or {})
  elseif config.on_back then
    -- Build back keys inline (use <C-q> to free up <C-h> for HEAD navigation)
    local back_key = {
      function(picker)
        picker:close()
        config.on_back()
      end,
      mode = { "n", "i" },
      desc = "Back to ref selection",
    }
    local gk = editor_keymaps.snacks_picker_group_keys.git_file_keys
    base_git_keys = vim.tbl_extend("force", gk.input or {}, {
      ["<C-q>"] = back_key,
    })
  else
    local gk = editor_keymaps.snacks_picker_group_keys.git_file_keys
    base_git_keys = vim.deepcopy(gk.input or {})
  end

  -- Build window keys
  local win = apply_keys_to_both_windows(base_git_keys, config.extra_keys)
  if config.footer then
    win.input.footer = config.footer
  end

  -- Build picker opts
  local pick_opts = {
    source = config.source,
    title = title,
    external = false,
    finder = make_ref_file_finder(config.get_ref, config.git_root, config.git_args_fn, config.get_head),
    format = make_ref_file_format(config.get_ref, config.get_head),
    preview = function(ctx)
      local head_ref = (config.get_head and config.get_head()) or "HEAD"
      return preview_git_diff_with_base(config.get_ref(), head_ref)(ctx)
    end,
    actions = with_external_actions(actions),
    win = win,
  }

  if config.confirm then
    pick_opts.confirm = config.confirm
  end

  Snacks.picker.pick(pick_opts)
end

--#endregion Ref File Picker Factory

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
  local git_root = Snacks.git.get_root()
  local source = "git_show"

  -- State management for range navigation
  -- Range is HEAD~base_offset..HEAD~head_offset (head_offset < base_offset)
  local state = { base_offset = 1, head_offset = 0, max_offset = 100 }

  local function get_base_ref()
    return "HEAD~" .. state.base_offset
  end

  local function get_head_ref()
    return state.head_offset == 0 and "HEAD" or ("HEAD~" .. state.head_offset)
  end

  local function get_range_display()
    local base_ref = get_base_ref()
    local base_short = git_util.get_short_hash(base_ref)
    local base_branch = git_util.get_ref_branch_name(base_ref)
    local head_short = git_util.get_short_hash(get_head_ref())
    local base_display = base_branch ~= "" and (base_branch .. ":" .. base_short) or base_short
    local head_display = head_short ~= "" and head_short or get_head_ref()
    local range_size = state.base_offset - state.head_offset
    local head_suffix = state.head_offset > 0 and (" @HEAD~" .. state.head_offset) or ""
    return base_display .. ".." .. head_display .. " (" .. range_size .. " commits" .. head_suffix .. ")"
  end

  local function move_range_forward()
    if state.base_offset <= state.head_offset + 1 then
      vim.notify("Already at minimum range (1 commit)", vim.log.levels.WARN)
      return
    end
    state.base_offset = state.base_offset - 1
    refresh_ref_picker(source, get_range_display)
  end

  local function move_range_backward()
    if state.base_offset >= state.max_offset then
      vim.notify("Already at maximum history depth", vim.log.levels.WARN)
      return
    end
    local next_ref = "HEAD~" .. (state.base_offset + 1)
    vim.fn.system("git rev-parse --verify " .. next_ref .. " 2>/dev/null")
    if vim.v.shell_error ~= 0 then
      vim.notify("No more commits in history", vim.log.levels.WARN)
      return
    end
    state.base_offset = state.base_offset + 1
    refresh_ref_picker(source, get_range_display)
  end

  local function move_head_backward()
    -- <C-h>: move HEAD left (older). head_offset grows; must stay < base_offset
    if state.head_offset + 1 >= state.base_offset then
      vim.notify("HEAD cannot cross base ref", vim.log.levels.WARN)
      return
    end
    local next_ref = "HEAD~" .. (state.head_offset + 1)
    vim.fn.system("git rev-parse --verify " .. next_ref .. " 2>/dev/null")
    if vim.v.shell_error ~= 0 then
      vim.notify("No more commits in history", vim.log.levels.WARN)
      return
    end
    state.head_offset = state.head_offset + 1
    refresh_ref_picker(source, get_range_display)
  end

  local function move_head_forward()
    -- <C-l>: move HEAD right (newer, toward actual HEAD). head_offset shrinks toward 0.
    if state.head_offset <= 0 then
      vim.notify("Already at HEAD", vim.log.levels.WARN)
      return
    end
    state.head_offset = state.head_offset - 1
    refresh_ref_picker(source, get_range_display)
  end

  create_ref_file_picker {
    source = source,
    title = get_range_display,
    get_ref = get_base_ref,
    get_head = get_head_ref,
    git_root = git_root,
    footer = "<C-j> base← • <C-k> base→ • <C-h> HEAD← • <C-l> HEAD→",
    extra_keys = {
      ["<C-k>"] = {
        function()
          move_range_forward()
        end,
        mode = { "n", "i" },
        desc = "Base ref → (closer to HEAD)",
      },
      ["<C-j>"] = {
        function()
          move_range_backward()
        end,
        mode = { "n", "i" },
        desc = "Base ref ← (further from HEAD)",
      },
      ["<C-h>"] = {
        function()
          move_head_backward()
        end,
        mode = { "n", "i" },
        desc = "HEAD ref ← (older)",
      },
      ["<C-l>"] = {
        function()
          move_head_forward()
        end,
        mode = { "n", "i" },
        desc = "HEAD ref → (toward actual HEAD)",
      },
    },
  }
end

--- Git diff upstream picker
--- Shows files changed between upstream and HEAD
--- Automatically detects upstream reference
function M.custom_git_pickers.git_diff_upstream()
  local git_root = Snacks.git.get_root()
  local upstream_ref = nil

  -- Step 1: Check if branch has an upstream (HEAD@{u})
  vim.fn.systemlist { "git", "rev-parse", "--verify", "HEAD@{u}" }
  local has_upstream = (vim.v.shell_error == 0)

  if has_upstream then
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

  local ref_metadata = git_util.get_ref_metadata(upstream_ref)
  local base_ref = ref_metadata and ref_metadata.resolved_with_remote or upstream_ref

  create_ref_file_picker {
    source = "git_diff_upstream",
    title = "Git Branch Changed Files (vs " .. base_ref .. ")",
    get_ref = function()
      return base_ref
    end,
    git_root = git_root,
    key_group = "upstream",
  }
end

--- Git diff merge-base picker
--- Shows files changed between merge-base and HEAD
--- Compares current branch with origin default using merge-base as the reference
--- Supports increment/decrement navigation through the merge-base history
--- Falls back to HEAD (staged) when merge-base equals HEAD
--- Supports workdir diff toggle when comparing with HEAD
function M.custom_git_pickers.git_diff_merge_base()
  local git_root = Snacks.git.get_root()
  local source = "git_diff_merge_base"

  -- Determine the target branch for merge-base
  local current_branch = vim.fn.systemlist({ "git", "branch", "--show-current" })[1] or "HEAD"
  local merge_base_target = nil
  local origin_default = vim.fn.systemlist({ "git", "symbolic-ref", "refs/remotes/origin/HEAD", "--short" })[1]

  if origin_default then
    merge_base_target = origin_default
  else
    vim.fn.systemlist { "git", "rev-parse", "--verify", "origin/main" }
    if vim.v.shell_error == 0 then
      merge_base_target = "origin/main"
    else
      vim.fn.systemlist { "git", "rev-parse", "--verify", "origin/master" }
      if vim.v.shell_error == 0 then
        merge_base_target = "origin/master"
      else
        vim.notify("No origin branch found for merge-base comparison", vim.log.levels.WARN)
        return
      end
    end
  end

  -- State management for base ref navigation with merge-base
  local state = {
    base_offset = 0,
    head_offset = 0,
    max_offset = 50,
    merge_base_target = merge_base_target,
    workdir_diff = false,
    fallback_to_head = false,
  }

  local function get_merge_base()
    local merge_base_sha = vim.fn.systemlist({ "git", "merge-base", current_branch, state.merge_base_target })[1]
    if vim.v.shell_error == 0 and merge_base_sha and merge_base_sha ~= "" then
      return merge_base_sha
    end
    return nil
  end

  local function is_base_ref_head(base_ref)
    if not base_ref then
      return false
    end
    local head_sha = vim.fn.systemlist({ "git", "rev-parse", "HEAD" })[1]
    local base_sha = vim.fn.systemlist({ "git", "rev-parse", base_ref })[1]
    return head_sha == base_sha
  end

  local function get_current_base_ref()
    local merge_base = get_merge_base()
    if not merge_base then
      return nil
    end

    local base_ref
    if state.base_offset == 0 then
      base_ref = merge_base
    else
      local ref = merge_base .. "~" .. state.base_offset
      vim.fn.systemlist { "git", "rev-parse", "--verify", ref }
      base_ref = vim.v.shell_error == 0 and ref or merge_base
    end

    if is_base_ref_head(base_ref) then
      state.fallback_to_head = true
      return "HEAD"
    end

    state.fallback_to_head = false
    return base_ref
  end

  local function get_head_ref()
    return state.head_offset == 0 and "HEAD" or ("HEAD~" .. state.head_offset)
  end

  local function get_range_display()
    local base_ref = get_current_base_ref()
    if not base_ref then
      return "merge-base..HEAD"
    end

    if state.fallback_to_head then
      local workdir_label = state.workdir_diff and " + workdir" or " (staged)"
      return "HEAD" .. workdir_label
    end

    local head_ref = get_head_ref()
    local base_short = git_util.get_short_hash(base_ref)
    local head_short = git_util.get_short_hash(head_ref)
    local commit_count = vim.fn.system("git rev-list --count " .. base_ref .. ".." .. head_ref):gsub("\n", "")
    commit_count = tonumber(commit_count) or 0
    local head_suffix = state.head_offset > 0 and (" @HEAD~" .. state.head_offset) or ""
    return "[merge-base]:"
      .. base_short
      .. ".."
      .. (state.head_offset == 0 and "HEAD:" or "")
      .. head_short
      .. " ("
      .. commit_count
      .. " commits"
      .. head_suffix
      .. ")"
  end

  local function get_title()
    return "Changed files (" .. get_range_display() .. ")"
  end

  local function toggle_workdir_diff()
    if not state.fallback_to_head then
      vim.notify("Workdir diff only available when comparing with HEAD", vim.log.levels.WARN)
      return
    end
    state.workdir_diff = not state.workdir_diff
    local status = state.workdir_diff and "enabled (all changes)" or "disabled (staged only)"
    vim.notify("Workdir diff: " .. status, vim.log.levels.INFO)
    refresh_ref_picker(source, get_title)
  end

  local function move_base_ref_forward()
    if state.base_offset <= 0 then
      vim.notify("Already at merge-base", vim.log.levels.WARN)
      return
    end
    state.base_offset = state.base_offset - 1
    refresh_ref_picker(source, get_title)
  end

  local function move_base_ref_backward()
    if state.base_offset >= state.max_offset then
      vim.notify("Already at maximum history depth", vim.log.levels.WARN)
      return
    end
    local next_ref = get_merge_base() .. "~" .. (state.base_offset + 1)
    vim.fn.systemlist { "git", "rev-parse", "--verify", next_ref }
    if vim.v.shell_error ~= 0 then
      vim.notify("No more commits in history", vim.log.levels.WARN)
      return
    end
    state.base_offset = state.base_offset + 1
    refresh_ref_picker(source, get_title)
  end

  local function move_head_backward()
    -- <C-h>: HEAD ref moves older (head_offset increases)
    if state.fallback_to_head then
      vim.notify("HEAD navigation unavailable in HEAD-fallback mode", vim.log.levels.WARN)
      return
    end
    local next_ref = "HEAD~" .. (state.head_offset + 1)
    vim.fn.systemlist { "git", "rev-parse", "--verify", next_ref }
    if vim.v.shell_error ~= 0 then
      vim.notify("No more commits in history", vim.log.levels.WARN)
      return
    end
    state.head_offset = state.head_offset + 1
    refresh_ref_picker(source, get_title)
  end

  local function move_head_forward()
    -- <C-l>: HEAD ref moves newer (head_offset decreases toward 0 = actual HEAD)
    if state.head_offset <= 0 then
      vim.notify("Already at HEAD", vim.log.levels.WARN)
      return
    end
    state.head_offset = state.head_offset - 1
    refresh_ref_picker(source, get_title)
  end

  -- Custom git_args_fn for merge-base's staged/workdir fallback modes
  local function merge_base_git_args(ref, head_ref)
    head_ref = head_ref or "HEAD"
    if state.fallback_to_head then
      if state.workdir_diff then
        return { "diff", "--name-only", "--diff-filter=d", ref }
      else
        return { "diff", "--name-only", "--diff-filter=d", "--cached", ref }
      end
    end
    return { "diff", "--name-only", "--diff-filter=d", ref .. ".." .. head_ref }
  end

  create_ref_file_picker {
    source = source,
    title = get_title,
    get_ref = get_current_base_ref,
    get_head = get_head_ref,
    git_root = git_root,
    git_args_fn = merge_base_git_args,
    footer = "<C-j> base← • <C-k> base→ • <C-h> HEAD← • <C-l> HEAD→ • <C-w> toggle workdir (HEAD only)",
    extra_keys = {
      ["<C-k>"] = {
        function()
          move_base_ref_forward()
        end,
        mode = { "n", "i" },
        desc = "Base ref → (closer to merge-base/HEAD)",
      },
      ["<C-j>"] = {
        function()
          move_base_ref_backward()
        end,
        mode = { "n", "i" },
        desc = "Base ref ← (further from merge-base)",
      },
      ["<C-h>"] = {
        function()
          move_head_backward()
        end,
        mode = { "n", "i" },
        desc = "HEAD ref ← (older)",
      },
      ["<C-l>"] = {
        function()
          move_head_forward()
        end,
        mode = { "n", "i" },
        desc = "HEAD ref → (toward actual HEAD)",
      },
      ["<C-w>"] = {
        function()
          toggle_workdir_diff()
        end,
        mode = { "n", "i" },
        desc = "Toggle workdir diff (HEAD only)",
      },
    },
  }
end

--#endregion Git Pickers

--#region Custom Change List Picker (Two-stage ref comparison)

-- Helper function to get stats for a ref comparison
local function get_ref_stats(refAlias, refActual)
  local ref = refActual or refAlias
  local stats = {
    refAlias = refAlias,
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

  local function add_candidate(refAlias, priority, ref_type, refActual)
    if not seen_refs[refAlias] then
      local stats = get_ref_stats(refAlias, refActual)
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

  -- 3.5 Merge-base between current branch and origin default
  local merge_base_target = origin_default
  if not merge_base_target or merge_base_target == "" then
    vim.fn.systemlist { "git", "rev-parse", "--verify", "origin/main" }
    if vim.v.shell_error == 0 then
      merge_base_target = "origin/main"
    else
      vim.fn.systemlist { "git", "rev-parse", "--verify", "origin/master" }
      if vim.v.shell_error == 0 then
        merge_base_target = "origin/master"
      end
    end
  end

  if merge_base_target and merge_base_target ~= "" then
    local branch_ref = current_branch and current_branch ~= "" and current_branch or "HEAD"
    local merge_base = vim.fn.systemlist({ "git", "merge-base", branch_ref, merge_base_target })[1]
    if vim.v.shell_error == 0 and merge_base and merge_base ~= "" then
      local alias = "merge-base(" .. branch_ref .. "," .. merge_base_target .. ")"
      add_candidate(alias, 3.5, "merge-base", merge_base)
    end
  end

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

  -- 7. Recent tags reachable from HEAD (first 2 with distinct commits)
  local tag_list = vim.fn.systemlist { "git", "tag", "--merged", "HEAD", "--sort=-creatordate" }
  if vim.v.shell_error == 0 and tag_list and #tag_list > 0 then
    local seen_tag_shas = {}
    local added_tags = 0
    for _, tag in ipairs(tag_list) do
      if tag ~= "" then
        local tag_sha = vim.fn.systemlist({ "git", "rev-parse", tag })[1]
        if vim.v.shell_error == 0 and tag_sha and tag_sha ~= "" and not seen_tag_shas[tag_sha] then
          add_candidate(tag, 6.5, "tag")
          seen_tag_shas[tag_sha] = true
          added_tags = added_tags + 1
          if added_tags >= 2 then
            break
          end
        end
      end
    end
  end

  table.sort(candidates, function(a, b)
    return a.priority < b.priority
  end)

  return candidates
end

-- Step 2: File list picker for selected ref with increment/decrement base ref
local function show_file_list_picker(selected_ref_stats, on_back)
  local git_root = Snacks.git.get_root()
  local source = "git_diff_files"
  local ref_metadata = git_util.get_ref_metadata(selected_ref_stats.ref)
  local initial_base_ref = ref_metadata and ref_metadata.resolved_with_remote or selected_ref_stats.ref

  -- State management for SHA-walking navigation
  -- current_head_ref defaults to "HEAD" (index 0 in commits list walked from HEAD back).
  local state = {
    current_base_ref = initial_base_ref,
    current_head_ref = "HEAD",
    initial_base_ref = initial_base_ref,
    commits_history = nil,
  }

  local function update_commits_history()
    state.commits_history = git_util.get_commits_between(state.initial_base_ref, "HEAD")
  end

  -- Find index of a specific ref in the commit history (1 = HEAD, #commits = oldest in range)
  local function find_commit_idx(ref)
    if not state.commits_history then
      update_commits_history()
    end
    local commits = state.commits_history
    if not commits or #commits == 0 then
      return nil, commits
    end

    local sha = vim.fn.system("git rev-parse " .. ref):gsub("\n", "")
    for i, commit in ipairs(commits) do
      if commit:sub(1, #sha) == sha then
        return i, commits
      end
    end
    return nil, commits
  end

  local function find_current_commit_idx()
    return find_commit_idx(state.current_base_ref)
  end

  local function find_current_head_idx()
    return find_commit_idx(state.current_head_ref)
  end

  local function get_range_display()
    local from_ref = state.current_base_ref
    local head_ref = state.current_head_ref
    local from_short = git_util.get_short_hash(from_ref)
    local from_branch = git_util.get_ref_branch_name(from_ref)
    local head_short = git_util.get_short_hash(head_ref)
    local from_display = from_branch ~= "" and ("[" .. from_branch .. "]:" .. from_short) or from_short
    local head_display = head_ref == "HEAD" and ("HEAD:" .. head_short) or head_short
    local commit_count = vim.fn.system("git rev-list --count " .. from_ref .. ".." .. head_ref):gsub("\n", "")
    commit_count = tonumber(commit_count) or 0
    return from_display .. ".." .. head_display .. " (" .. commit_count .. " commits)"
  end

  local function get_title()
    local range_display = get_range_display()
    local ref_type_label = ref_metadata
        and ref_metadata.resolve_ref_type ~= "unknown"
        and " (" .. ref_metadata.resolve_ref_type .. ")"
      or ""
    local ref_alias_label = selected_ref_stats.refAlias ~= selected_ref_stats.ref
        and " [" .. selected_ref_stats.refAlias .. "]"
      or ""
    return "Changed files (" .. range_display .. ")" .. ref_type_label .. ref_alias_label
  end

  -- Base ref walks from index toward 1 (closer to HEAD) or toward #commits (further).
  local function move_base_ref_forward()
    local current_idx, commits = find_current_commit_idx()
    if not commits or #commits == 0 then
      vim.notify("No commits to move forward", vim.log.levels.WARN)
      return
    end
    current_idx = current_idx or #commits
    -- Base ref must stay strictly older than head_ref
    local head_idx = find_current_head_idx() or 1
    if current_idx - 1 <= head_idx then
      vim.notify("Base cannot cross HEAD ref", vim.log.levels.WARN)
      return
    end
    state.current_base_ref = commits[current_idx - 1]
    refresh_ref_picker(source, get_title)
  end

  local function move_base_ref_backward()
    local current_idx, commits = find_current_commit_idx()
    if not commits or #commits == 0 then
      vim.notify("No commits to move backward", vim.log.levels.WARN)
      return
    end
    current_idx = current_idx or 1
    if current_idx < #commits then
      state.current_base_ref = commits[current_idx + 1]
      refresh_ref_picker(source, get_title)
    else
      vim.notify("Already at base ref", vim.log.levels.WARN)
    end
  end

  -- HEAD ref walks similarly: index 1 = HEAD (newest), #commits = oldest.
  local function move_head_backward()
    -- <C-h>: HEAD ref moves older (index grows)
    local current_idx, commits = find_current_head_idx()
    if not commits or #commits == 0 then
      vim.notify("No commits available", vim.log.levels.WARN)
      return
    end
    current_idx = current_idx or 1
    local base_idx = find_current_commit_idx() or #commits
    if current_idx + 1 >= base_idx then
      vim.notify("HEAD cannot cross base ref", vim.log.levels.WARN)
      return
    end
    state.current_head_ref = commits[current_idx + 1]
    refresh_ref_picker(source, get_title)
  end

  local function move_head_forward()
    -- <C-l>: HEAD ref moves newer (index shrinks toward 1 = HEAD)
    local current_idx, commits = find_current_head_idx()
    if not commits or #commits == 0 then
      vim.notify("No commits available", vim.log.levels.WARN)
      return
    end
    current_idx = current_idx or 1
    if current_idx > 1 then
      state.current_head_ref = commits[current_idx - 1]
    else
      state.current_head_ref = "HEAD"
      vim.notify("Already at HEAD", vim.log.levels.WARN)
      return
    end
    refresh_ref_picker(source, get_title)
  end

  create_ref_file_picker {
    source = source,
    title = get_title,
    get_ref = function()
      return state.current_base_ref
    end,
    get_head = function()
      return state.current_head_ref
    end,
    git_root = git_root,
    on_back = on_back,
    footer = "<C-q> back • <C-j> base← • <C-k> base→ • <C-h> HEAD← • <C-l> HEAD→",
    extra_keys = {
      ["<C-j>"] = {
        function()
          move_base_ref_backward()
        end,
        mode = { "n", "i" },
        desc = "Base ref ← (further from HEAD)",
      },
      ["<C-k>"] = {
        function()
          move_base_ref_forward()
        end,
        mode = { "n", "i" },
        desc = "Base ref → (closer to HEAD)",
      },
      ["<C-h>"] = {
        function()
          move_head_backward()
        end,
        mode = { "n", "i" },
        desc = "HEAD ref ← (older)",
      },
      ["<C-l>"] = {
        function()
          move_head_forward()
        end,
        mode = { "n", "i" },
        desc = "HEAD ref → (toward actual HEAD)",
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
    vim.notify("No valid refs found for comparison — opening empty picker", vim.log.levels.INFO)
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
    ["merge-base"] = { label = "merge-base", hl = "DiagnosticHint" },
    ["tag"] = { label = "tag", hl = "DiagnosticInfo" },
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
    show_empty = true,
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

      local ref = item.ref
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
        vim.list_extend(preview_lines, { "No commit changes between " .. item.refAlias .. " and HEAD", "" })
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
        if not item or not item.ref then
          vim.notify("No reference selected", vim.log.levels.WARN)
          return
        end
        picker:close()
        git_util.open_current_buffer_with_gitsigns_diff(item.ref)
      end,
    },
    win = {
      input = {
        keys = {
          ["<C-s>"] = { "open_gitsigns_diff", mode = { "n", "i" }, desc = "Open Gitsigns diff with ref" },
          ["<C-g>"] = { "open_gitsigns_diff", mode = { "n", "i" }, desc = "Open Gitsigns diff with ref" },
        },
      },
      list = {
        keys = {
          ["<C-s>"] = { "open_gitsigns_diff", mode = { "n", "i" }, desc = "Open Gitsigns diff with ref" },
          ["<C-g>"] = { "open_gitsigns_diff", mode = { "n", "i" }, desc = "Open Gitsigns diff with ref" },
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

--- Get initial picker state with persistent cwd and per-source opts
--- @param pickerOpts table Base picker options to merge with
--- @param opts table Options for state initialization
---   - cwd_default: "git"|"current"|"subproject" Default cwd type
---   - use_previous_cwd_state: boolean Whether to use persisted cwd state
---   - source: string Picker source name for per-source opts persistence (e.g. "files", "grep")
--- @return table Merged picker options with cwd state
function M.get_initial_picker_state(pickerOpts, opts)
  pickerOpts = pickerOpts or {}
  opts = opts or {}
  local cwd_default = opts.cwd_default

  local path = require "utils.path"
  local pathUtil = require "utils.mypath"

  local cwd_defaultmap = {
    git = path.get_root_directory() or Snacks.git.get_root(),
    current = vim.fn.getcwd(),
    -- Lazy: only scan for subprojects when cwd_default is "subproject" to avoid
    -- freezing the picker on open (root scan runs git ls-files across 3 pipelines)
    subproject = cwd_default == "subproject"
        and pathUtil.get_sub_project_dirs_from_root(nil, nil, false, false, "nearest")
      or nil,
  }

  local cwd = nil
  local cwd_state = vim.g.picker_cwd_cycle_state_value
  local cwd_fallback = cwd_defaultmap[cwd_default]
  local git_root = path.get_root_directory() or Snacks.git.get_root()

  local result = vim.deepcopy(pickerOpts) or {}

  -- Apply per-source defaults from vim.g first, then persisted overrides
  -- (explicit pickerOpts still take precedence)
  if opts.source then
    local snacks_actions = require "utils.snacks_actions"
    local default_all = vim.g.picker_source_default_opts
    local source_defaults = type(default_all) == "table" and default_all[opts.source] or nil
    local persisted = snacks_actions.get_persisted_source_opts(opts.source)
    snacks_actions.log_picker_persist("get_initial_picker_state:start", {
      source = opts.source,
      picker_opts = pickerOpts,
      defaults = source_defaults,
      persisted = persisted,
    })

    -- 1) Apply source defaults from vim.g (only when not explicitly set)
    if source_defaults then
      for _, key in ipairs { "hidden", "ignored", "follow", "regex" } do
        if source_defaults[key] ~= nil and pickerOpts[key] == nil then
          result[key] = source_defaults[key]
        end
      end
      if source_defaults.case_mode and not pickerOpts.args then
        if source_defaults.case_mode == "ignore" then
          result.args = result.args or {}
          if not vim.tbl_contains(result.args, "--ignore-case") and not vim.tbl_contains(result.args, "-i") then
            table.insert(result.args, "--ignore-case")
          end
          result.case_nonsensitive_custom = true
        elseif source_defaults.case_mode == "sensitive" then
          result.args = result.args or {}
          if not vim.tbl_contains(result.args, "--case-sensitive") and not vim.tbl_contains(result.args, "-s") then
            table.insert(result.args, "--case-sensitive")
          end
          result.case_sensitive_custom = true
        end
      end
    end

    -- 2) Apply persisted per-source opts (override defaults)
    if persisted then
      -- Apply persisted toggle opts only if not explicitly set in pickerOpts
      for _, key in ipairs { "hidden", "ignored", "follow", "regex" } do
        if persisted[key] ~= nil and pickerOpts[key] == nil then
          result[key] = persisted[key]
        end
      end
      -- Apply persisted case mode to args
      if persisted.case_mode and not pickerOpts.args then
        if persisted.case_mode == "ignore" then
          result.args = result.args or {}
          -- Only add if not already present
          if not vim.tbl_contains(result.args, "--ignore-case") and not vim.tbl_contains(result.args, "-i") then
            table.insert(result.args, "--ignore-case")
          end
          result.case_nonsensitive_custom = true
        elseif persisted.case_mode == "sensitive" then
          result.args = result.args or {}
          if not vim.tbl_contains(result.args, "--case-sensitive") and not vim.tbl_contains(result.args, "-s") then
            table.insert(result.args, "--case-sensitive")
          end
          result.case_sensitive_custom = true
        end
        -- "smart" = default, no args needed
      end
    end

    snacks_actions.log_picker_persist("get_initial_picker_state:resolved", {
      source = opts.source,
      resolved = {
        hidden = result.hidden,
        ignored = result.ignored,
        follow = result.follow,
        regex = result.regex,
        args = result.args,
      },
    })
  end

  if cwd_state and opts.use_previous_cwd_state ~= false then
    cwd = cwd_state
  else
    if not cwd and not result.cwd and cwd_fallback then
      cwd = cwd_fallback
    end
  end

  -- is gitroot and (the cwd is root) or initial case (nil and default is root)
  local is_cwd_git_ui = git_root and (cwd and cwd == git_root or (cwd == nil and cwd_defaultmap["current"] == git_root))

  if cwd then
    result.cwd = cwd
  end

  if is_cwd_git_ui then
    result.git_cwd = true
  else
    result.custom_cwd = result.cwd and true or nil
  end

  local args = result.args or {}
  local has_ignore_case = vim.tbl_contains(args, "-i") or vim.tbl_contains(args, "--ignore-case")
  if has_ignore_case then
    result.case_nonsensitive_custom = true
  end

  return result
end

--#endregion Picker State Utilities

--#region Code Ref Picker

--- Picker for current buffer code references (relative/absolute)
--- Uses shared code_ref_picker_builder for unified UI with copy_path_select (<M-y>)
--- Mapped to <localleader>crp
function M.code_ref_picker(opts)
  opts = opts or {}
  local code_ref = require "utils.code_ref"
  local builder = require "utils.code_ref_picker_builder"
  local use_visual = opts.visual or false
  local show_char = vim.g.code_ref_show_char_range or false

  local bufpath = vim.api.nvim_buf_get_name(0)
  if not bufpath or bufpath == "" then
    vim.notify("No code reference available (missing file path)", vim.log.levels.WARN)
    return
  end

  local line, col = unpack(vim.api.nvim_win_get_cursor(0))
  col = col + 1
  local range = code_ref.get_visual_range(use_visual)

  -- Generate unified path variants and code-ref items
  local path_variants = code_ref.generate_path_variants(bufpath)
  local items = code_ref.generate_coderef_items(path_variants, line, col, range, show_char)

  if not items or #items == 0 then
    vim.notify("No code reference available", vim.log.levels.WARN)
    return
  end

  -- Build title with toggle state indicators (line, col, char)
  local hide_col = vim.g.code_ref_hide_col or false
  local hide_line = vim.g.code_ref_hide_line or false
  local state_parts = {}
  if hide_line then
    table.insert(state_parts, "line:hidden")
  end
  if hide_col and not hide_line then
    table.insert(state_parts, "col:hidden")
  end
  if use_visual then
    table.insert(state_parts, show_char and "char:on" or "char:off")
  end
  local state_label = (#state_parts > 0) and (" [" .. table.concat(state_parts, " ") .. "]") or ""
  local title = (opts.title or "Code Reference (Enter: paste)") .. state_label

  -- Footer: actions + toggles (visible in input window)
  local footer = "<CR> paste • <C-y> copy • <C-n> md • <A-c> col/char • <A-l> line"

  builder.build {
    items = items,
    source = "code_ref",
    title = title,
    parent_picker = nil,
    confirm_mode = "paste",
    show_preview = false,
    use_visual = use_visual,
    footer = footer,
    on_refresh = function()
      M.code_ref_picker { visual = use_visual, title = opts.title }
    end,
  }
end

--#endregion Code Ref Picker

--#region Dotfiles Config Picker

--- Picker for dotfiles configuration files
--- Searches ~/dotfiles/ directory with configurable include/exclude patterns
function M.dotfiles_picker()
  -- Configuration table - easily editable for adding/removing patterns
  local CONFIG = {
    base_dir = "~/dotfiles",
    include_patterns = { ".*", "*bash*", "*.lua", "*.vim", "*.json", "*.yaml", "*.yml", "*.toml", "*.conf", "*.config" },
    -- Exclude patterns: can be simple names or relative paths from base_dir
    exclude_dirs = {
      -- Simple directory names
      "fork",
      "nvim*",
      ".git",
      ".config/github-copilot/*/chat*sessions",
      "node_modules",
      ".DS_Store",
      ".continue",
      "backup",
      -- Nested paths (relative to ~/dotfiles/)
      ".config/gcloud",
      ".config/alacritty/themes",
      ".config/glab-cli",
      ".config/raycast/script-commands",
      ".config/raycast/extensions",
      ".config/raycast/exports",
    },
    extra_files = { "~/.bash.local", "~/.zprofile", "~/.gitconfig.local" },
  }

  -- Expand paths
  local base_dir = vim.fn.expand(CONFIG.base_dir)

  -- Check if base directory exists
  if vim.fn.isdirectory(base_dir) == 0 then
    vim.notify("Dotfiles directory does not exist: " .. base_dir, vim.log.levels.WARN)
    return
  end

  -- Helper to check if path matches any pattern
  local function matches_pattern(str, patterns)
    for _, pattern in ipairs(patterns) do
      -- Convert glob pattern to lua pattern
      local lua_pattern = pattern:gsub("%*", ".*"):gsub("%-", "%%-")
      if str:match(lua_pattern) then
        return true
      end
    end
    return false
  end

  -- Helper to check if directory should be excluded
  local function is_excluded_dir(path)
    -- Check both the basename and the relative path
    local dirname = vim.fn.fnamemodify(path, ":t")
    local rel_path = path:sub(#base_dir + 2) -- +2 to remove leading slash

    -- Match against basename patterns
    if matches_pattern(dirname, CONFIG.exclude_dirs) then
      return true
    end

    -- Match against relative path patterns (for nested directories)
    for _, exclude_pattern in ipairs(CONFIG.exclude_dirs) do
      -- Check if the relative path starts with the exclude pattern
      if rel_path:match("^" .. exclude_pattern:gsub("%*", ".*"):gsub("%-", "%%-")) then
        return true
      end
    end

    return false
  end

  -- Helper to scan files recursively
  local function scan_files(dir, files, rel_base)
    files = files or {}
    rel_base = rel_base or base_dir

    local handle = vim.loop.fs_scandir(dir)
    if not handle then
      return files
    end

    while true do
      local name, type = vim.loop.fs_scandir_next(handle)
      if not name then
        break
      end

      local full_path = dir .. "/" .. name

      if type == "directory" then
        -- Recursively scan subdirectories unless excluded
        if not is_excluded_dir(full_path) then
          scan_files(full_path, files, rel_base)
        end
      elseif type == "file" then
        -- Check if file matches include patterns
        if matches_pattern(name, CONFIG.include_patterns) then
          local rel_path = full_path:sub(#rel_base + 2) -- +2 to remove leading slash
          table.insert(files, {
            text = rel_path,
            file = full_path,
          })
        end
      end
    end

    return files
  end

  -- Add extra files if they exist
  local function add_extra_files(files)
    for _, extra_file in ipairs(CONFIG.extra_files) do
      local expanded_path = vim.fn.expand(extra_file)
      if vim.fn.filereadable(expanded_path) == 1 then
        table.insert(files, {
          text = extra_file, -- Keep tilde notation for display
          file = expanded_path,
        })
      end
    end
    return files
  end

  local editor_keymaps = require "utils.editor_keymaps"
  local dotfiles_keys = vim.tbl_extend("force", editor_keymaps.snacks_picker_group_keys.files_keys.input, {
    ["<C-space>"] = { "switch_to_grep", mode = { "n", "i" }, desc = "Switch to Grep Mode" },
  })

  Snacks.picker.pick {
    source = "dotfiles",
    title = "Dotfiles Config",
    cwd = base_dir,
    finder = function(_opts, _ctx)
      local files = add_extra_files {}
      vim.list_extend(files, scan_files(base_dir))
      return files
    end,
    format = "text",
    preview = "file",
    confirm = "edit",
    actions = vim.tbl_extend("force", editor_keymaps.snacks_common_actions, {
      switch_to_grep = function(picker, item)
        picker:close()
        Snacks.picker.grep { cwd = base_dir, hidden = true }
      end,
    }),
    win = {
      input = {
        keys = dotfiles_keys,
      },
      list = {
        keys = {
          ["<c-v>"] = "vsplit",
          ["<c-s>"] = "hsplit",
        },
      },
    },
  }
end

--#endregion Dotfiles Config Picker

-- Export pick_cmd_result for use in other modules
M.pick_cmd_result = pick_cmd_result

--#region LuaSnip Snippets Picker

-- LuaSnip snippets picker source configuration
-- Shows all available snippets (global + filetype-specific) with preview
-- Press <M-g> to toggle between all snippets and filetype-only snippets
M.snippets_source_config = {
  supports_live = false,
  preview = "preview",
  title = "Snippets",
  toggles = {
    show_filetype_only = { icon = "F", value = true },
  },
  format = function(item, picker)
    local name = Snacks.picker.util.align(item.name, picker.align_1 + 5)
    local result = {
      { name, item.ft == "" and "Conceal" or "DiagnosticWarn" },
    }
    -- Show ~trigger alias when it differs from the name
    if item.trigger ~= item.name then
      result[#result + 1] = { " ~" .. item.trigger, "Comment" }
    end
    -- Show [filetype] badge in red when filetype is set
    if item.ft ~= "" then
      result[#result + 1] = { " [" .. item.ft .. "]", "DiagnosticError" }
    end
    -- Add description
    if item.description ~= "" then
      result[#result + 1] = { " " .. item.description }
    end
    return result
  end,
  finder = function(_, ctx)
    local show_filetype_only = ctx.picker.opts.show_filetype_only or false
    local snippets = {}

    -- Capture source buffer's filetype from picker.main (original window)
    -- This prevents reading from the picker input buffer's filetype
    local source_buf = vim.api.nvim_win_get_buf(ctx.picker.main)
    local source_ft = vim.bo[source_buf].filetype

    if show_filetype_only then
      -- Only get filetype-specific snippets from source buffer
      if source_ft ~= "" then
        for _, snip in ipairs(require("luasnip").get_snippets(source_ft)) do
          snip.ft = source_ft
          table.insert(snippets, snip)
        end
      end
    else
      -- Get all snippets (global + filetype-specific)
      for _, snip in ipairs(require("luasnip").get_snippets().all) do
        snip.ft = ""
        table.insert(snippets, snip)
      end
      if source_ft ~= "" then
        for _, snip in ipairs(require("luasnip").get_snippets(source_ft)) do
          snip.ft = source_ft
          table.insert(snippets, snip)
        end
      end
    end

    -- Calculate alignment width
    local align_1 = 0
    for _, snip in pairs(snippets) do
      align_1 = math.max(align_1, #snip.name)
    end
    ctx.picker.align_1 = align_1

    -- Build picker items
    local items = {}
    for _, snip in pairs(snippets) do
      local docstring = snip:get_docstring()
      if type(docstring) == "table" then
        docstring = table.concat(docstring)
      end
      local name = snip.name
      local description = table.concat(snip.description)
      description = name == description and "" or description
      table.insert(items, {
        text = name .. " " .. snip.trigger .. " " .. description, -- search string (name + trigger + description)
        name = name,
        description = description,
        trigger = snip.trigger,
        ft = snip.ft,
        preview = {
          ft = snip.ft,
          text = docstring,
        },
      })
    end
    return items
  end,
  confirm = function(picker, item)
    picker:close()
    local expand = {}
    require("luasnip").available(function(snippet)
      if snippet.trigger == item.trigger then
        table.insert(expand, snippet)
      end
      return snippet
    end)
    if #expand > 0 then
      vim.cmd ":startinsert!"
      vim.defer_fn(function()
        require("luasnip").snip_expand(expand[1])
      end, 50)
    else
      Snacks.notify.warn "No snippet to expand"
    end
  end,
  actions = {
    toggle_filetype_filter = function(picker)
      picker.opts.show_filetype_only = not picker.opts.show_filetype_only
      picker.list:set_target()
      picker:find()
    end,
  },
  win = {
    input = {
      footer = "M-g: toggle ft",
      keys = {
        ["<M-g>"] = { "toggle_filetype_filter", mode = { "n", "i" }, desc = "Toggle all/filetype filter" },
      },
    },
  },
}

--#endregion LuaSnip Snippets Picker

return M
