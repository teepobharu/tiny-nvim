--#region common pickers 1 TODO: moved down to same region
function SnacksUtils()
  Snacks.debug "asdasd"
  Snacks.notify.warn "Notification from SnacksUtils"

  -- useful utils setup from main
  function snacks_setup_utils()
    _G.dd = function(...)
      Snacks.debug.inspect(...)
    end
    _G.bt = function()
      Snacks.debug.backtrace()
    end
    vim.print = _G.dd -- Override print to use snacks for `:=` command
  end
end
function snacks_preview()
  -- snacks preview
  -- require("snacks.picker").preview({ source = "asd.zxc" })
  ---@type snacks.picker
  -- @type snacks.picker.core.picker -- https://github.com/folke/snacks.nvim/blob/main/docs/picker.md#-snackspickercorepicker
  function test1()
    local B = Snacks.picker.buffers()
    print(vim.inspect(B.init_opts.source))
    print(vim.inspect(B.init_opts.source.asd and B.init_opts.source.asd.zxc)) -- stop
    print(123)
    print(vim.inspect(B.init_opts.source.asd.zxc)) -- stop
    print(321)
  end

  ---@class snacks.picker.input
  local p1 = Snacks.picker.files {
    -- search = "test"
    -- why refresh null ?
    pattern = "test", -- intial query
    win = {
      input = {
        keys = {
          ["<C-s>"] = {
            function(picker, item)
              -- __AUTO_GENERATED_PRINT_VAR_START__
              print([==[snacks_preview#(anon) item:]==], vim.inspect(item)) -- __AUTO_GENERATED_PRINT_VAR_END__
              print([==[snacks_preview#(anon) picker:refresh:]==], vim.inspect(picker.refresh))
              print([==[snacks_preview#(anon) picker:]==], vim.inspect(picker)) -- __AUTO_GENERATED_PRINT_VAR_END__
              picker:refresh()
              -- __AUTO_GENERATED_PRINT_VAR_START__
              picker:find()
            end,
            mode = { "n", "i" },
            desc = "test refresh",
          },
        },
      },
    },
  }
  p1:refresh()
  vim.defer_fn(function()
    vim.notify("waiting", vim.log.levels.INFO)
    print "waiting . . ."
  end, 2000)
  local p2 = Snacks.picker.buffers {
    -- search = "test"
    pattern = "testp2", -- intial query
  }
  -- wait 3s
  print([==[snacks_preview#(anon) p1:active1]==], vim.inspect(p1:is_active()))
  vim.defer_fn(function()
    p1:toggle()
    print([==[snacks_toggle#(anon) p1:active2]==], vim.inspect(p1:is_active()))
  end, 3000)
  vim.defer_fn(function()
    p2:toggle()
    print([==[snacks_preview#(anon) p1:]==], vim.inspect(p1:isfcused()))
    print([==[snacks_preview#(anon) p2:]==], vim.inspect(p2:is_active()))
  end, 3000)
  -- lua Snacks.picker.get()
  -- test1()
end
function snacks_qffiles()
  -- get list of quickfix items files
  -- do rg on these files
  local items = vim.fn.getqflist({
    items = 0,
  }).items

  if not items or #items == 0 then
    vim.notify("Quickfix list is empty", vim.log.levels.WARN)
    return
  end

  local files = {}
  for _, item in ipairs(items) do
    if item.filename then
      table.insert(files, item.filename)
    end
  end
  ---@type snacks.picker.Config
  --- require("snacks.picker").files
  local snacks_picker_files
  Snacks.picker.files {
    input = {
      initial_value = "",
      keys = {
        J = {
          function()
            vim.cmd "colder"
          end,
          mode = { "n", "i" },
          desc = "Navigate to older list",
        },
        K = {
          function()
            vim.cmd "cnewer"
          end,
          mode = { "n", "i" },
          desc = "Navigate to newer list",
        },
      },
    },
    preview = {
      minimal = true,
    },
    values = files,
  }
end
--#endregion
--
-- Configuration structure for Snacks picker keymaps
local SnacksFilesTest = function()
  Snacks.picker.files {
    matcher = {
      -- smartcase = false, -- this will make ignorecase work
    },
    args = {
      -- "-h" ,
      "--hidden",
      "--no-ignore",
      "--ignore-case",
    },
  }
end
local SNACKS_GLOBAL_OPTS = {
  win = {
    input = {
      keys = {
        ["<S-t>"] = { "trouble_open", mode = { "n" }, desc = "Smart open Touble" },
        ["<C-t>"] = { "terminal", mode = { "n", "i" }, desc = "Open terminal from picker" },
        ["<C-p>"] = {
          "debug_print_actions_and_options",
          mode = { "n", "i" },
          desc = "Debug: Print actions and options",
        },
        ["<M-g>"] = {
          -- WORKS in real mapping
          "gitdiff_toggle_group",
          mode = { "n", "i" },
          desc = "Toggle git_diff group/source",
        },
      },
    },
  },
  actions = {
    delete_file = function(picker)
      local paths = vim.tbl_map(function(item)
        return item.file
      end, picker:selected { fallback = true })

      if #paths == 0 then
        return
      end

      Snacks.picker.util.confirm("Delete " .. #paths .. " file(s)?", function()
        for _, path in ipairs(paths) do
          -- Use the same trash logic as explorer
          local ok, err = require("snacks.explorer.actions").trash(path)
          if not ok then
            Snacks.notify.error("Failed to delete: " .. err)
          end
        end
        picker:refresh()
      end)
    end,
    gitdiff_toggle_group = function(picker, item)
      -- Toggle between git_diff and git_files sources
      if picker.opts.source == "git_diff" and not picker.opts.group then
        picker.opts.group = true
        Snacks.debug "Switched to git_diff group"
      elseif picker.opts.source == "git_diff" then
        picker.opts.group = false
        -- picker.opts.source = "git_status"
        -- picker.opts.source = "files" -- not work like this
        Snacks.debug "Switched to status source"
        -- Snacks.picker.git_status {}
        picker = Snacks.picker.git_status {}
        -- picker:close() -- will blink but will make resume work
        -- Snacks.picker.git_status {}
        return
      elseif picker.opts.source == "git_status" then
        Snacks.debug "Switched to git_diff source"
        picker = Snacks.picker.git_diff {}
        -- picker:close() -- will blink but will make resume work
        -- Snacks.picker.git_diff {}
        return
      else
        Snacks.debug "Unknown status"
      end
      picker:refresh()
    end,
    -- debug_print_actions_and_options = function(picker, item)
    -- Print available actions
    debug_print_actions_and_options = function(picker, item)
      -- Collect actions and print as a comma-separated list
      local action_names = {}
      if picker and picker.opts and picker.opts.actions then
        for name, _ in pairs(picker.opts.actions) do
          table.insert(action_names, name)
        end
      end
      print("Actions:", table.concat(action_names, ", "))

      -- Initial options (concise)
      if picker and picker.init_opts then
        local init = vim.deepcopy(picker.init_opts)
        init.actions = nil
        init.win = nil
        print("Init:", vim.inspect(init))
      end

      -- Input / pattern / matcher / search
      local current_args = vim.deepcopy((picker and picker.opts and picker.opts.args) or {}) or {}
      local current_pattern = picker and picker.input and picker.input.filter and picker.input.filter.pattern
      local currentmatchpattern = picker and picker.matcher and picker.matcher.pattern
      local current_search = picker and picker.input and picker.input.filter and picker.input.filter.search or ""
      print("Args:", vim.inspect(current_args))
      print("Pattern:", vim.inspect(current_pattern))
      print("MatcherPattern:", vim.inspect(currentmatchpattern))
      print("Search:", vim.inspect(current_search))
      print("SearchHasUpper:", tostring((current_search or ""):match "%u" and true or false))

      -- Live mode and matcher opts (concise)
      print("Live:", vim.inspect(picker and picker.opts and picker.opts.live))
      if picker and picker.matcher then
        print("MatcherOpts:", vim.inspect(picker.matcher.opts))
      end

      -- Refresh the picker
      picker:refresh()
    end,
  },
}
--#region Utilities map
local testingmap_snacks = {
  buffers = {
    key = "<localleader>z<space>",
    modes = { "n", "x" },
    default_opts = {
      -- Default options for buffers picker
      --
    },
  },
  files = {
    key = "<localleader>zf",
    modes = { "n", "x" },
    default_opts = {
      -- Default options for files picker
    },
  },
  grep = {
    key = "<localleader>zg",
    modes = { "n", "x" },
    default_opts = {
      -- Default options for grep picker
    },
  },
  grep_word = {
    key = "<localleader>zG",
    modes = { "n", "x" },
    default_opts = {
      -- Default options for grep_word picker
    },
  },
  explorer = {
    key = "<localleader>ze",
    modes = { "n" },
    default_opts = {
      -- Default options for explorer
    },
  },
  git_diff = {
    key = "<localleader>zd",
    modes = { "n", "x" },
  },
  -- https://deepwiki.com/search/does-gitlog-picker-accept-base_0e1ec813-cda2-41f2-8e09-e57e16f2ab2d?mode=fast
  -- TODO: feature choose branches files in that ref (if not remote manual checkout and track), check with current files / select files and diff with remote
  git_log = {
    key = "<localleader>zgB",
    modes = { "n", "x" },
    default_opts = {
      current_file = true,
    },
  },
  git_grep = {
    key = "<localleader>zr",
    modes = { "n", "x" },
  },
  git_status = {
    key = "<localleader>zs",
    modes = { "n", "x" },
  },
  git_files = {
    key = "<localleader>zF",
    modes = { "n", "x" },
    default_opts = {
      -- Default options for git_files picker
    },
  },
  smart = {
    key = "<localleader>zs",
    modes = { "n", "x" },
    default_opts = {
      -- Default options for smart picker
    },
  },
  snippets = {
    key = "<localleader>zS",
    modes = { "n", "x" },
    default_opts = {
      -- Default options for smart picker
    },
  },
}
-- Auto-mapper function that applies opts and creates keymaps
-- @param mapConfig table: Configuration with picker names, keys, and default_opts
-- @param optsConfig table: Options to merge (_all applies to all pickers, picker_name for specific)
-- @param useDefaultOpts boolean: Whether to include default_opts from mapConfig (default: true)
function autoMapSnacksKeys(mapConfig, optsConfig, useDefaultOpts, useGlobalOpts)
  optsConfig = optsConfig or {}
  useDefaultOpts = useDefaultOpts == nil and true or useDefaultOpts
  useGlobalOpts = useGlobalOpts and SNACKS_GLOBAL_OPTS or {}
  local all_opts = optsConfig._all or {}

  for picker_name, map_info in pairs(mapConfig) do
    -- Build the options in order: default_opts -> _all opts -> picker-specific opts
    local final_opts = {}
    if useGlobalOpts then
      final_opts = vim.tbl_deep_extend("force", final_opts, useGlobalOpts)
    end

    if useDefaultOpts and map_info.default_opts then
      final_opts = vim.tbl_deep_extend("force", final_opts, map_info.default_opts)
    end

    final_opts = vim.tbl_deep_extend("force", final_opts, all_opts)

    if optsConfig[picker_name] then
      final_opts = vim.tbl_deep_extend("force", final_opts, optsConfig[picker_name])
    end

    -- Create the keymap
    vim.keymap.set(map_info.modes or { "n" }, map_info.key, function()
      -- Call the appropriate Snacks picker with merged opts
      if Snacks.picker[picker_name] then
        Snacks.picker[picker_name](final_opts)
      else
        -- set new picker with source name as picker_name and final_opts as opts
        vim.notify("Snacks picker '" .. picker_name .. "' does not exist", vim.log.levels.ERROR)
        Snacks.picker(picker_name, final_opts)
      end
    end, {
      desc = "Snacks: " .. picker_name,
      noremap = true,
      silent = true,
    })
  end
end
--#endregion

--#region Utils fns
local function is_in_project_dir_snacks(item)
  return require("utils.snacks_terminal").is_in_project_dir_snacks(item)
end
function filter_buffers_external(items, shouldFilterNonExist)
  local filter_ok, filtered = pcall(function()
    local filtered = {}
    if not shouldFilterNonExist then
      return items
    end
    for _, item in ipairs(items) do
      if not is_in_project_dir_snacks(item) then
        table.insert(filtered, item)
      end
    end
    return filtered
  end)

  -- If filter fails, return original items
  if not filter_ok then
    vim.notify("External filter failed, showing all buffers", vim.log.levels.WARN)
    return items
  end

  return filtered
end

--#endregion
--
--#region Map region test
function snacks_opt_tgg()
  -- Define options to apply
  local optsToTest = {
    _all2 = {
      toggles = {
        -- Existing toggles...
        case_sensitive = {
          icon = "C", -- Icon to show in title
          value = true, -- Show when case_sensitive is true
        },
      },
      -- Your existing actions...
      actions = {
        toggle_case_sensitive = function(picker, item)
          local source = picker.opts.source or "files"

          if source == "files" or source == "buffers" or source == "smart" then
            -- Toggle matcher smartcase for file sources
            local current = picker.opts.matcher.smartcase
            picker.opts.matcher.smartcase = not current
            picker.opts.matcher.ignorecase = current
            -- Recreate matcher with new options
            picker.matcher = require("snacks.picker.core.matcher").new(picker.opts.matcher)
          else
            -- Toggle command args for grep sources
            local current_args = picker.deepcopy(picker.opts.args) or {}
            local has_ignore = vim.tbl_contains(current_args, "-i") or vim.tbl_contains(current_args, "--ignore-case")

            if has_ignore then
              picker.opts.args = vim.tbl_filter(function(arg)
                return arg ~= "-i" and arg ~= "--ignore-case"
              end, current_args)
            else
              table.insert(current_args, "--ignore-case")
              picker.opts.args = current_args
            end
          end

          -- Update the toggle state and refresh
          picker.opts.case_sensitive = not picker.opts.case_sensitive
          picker:refresh()
        end,
      },
      win = {
        input = {
          keys = {
            ["<C-s>"] = { "toggle_case_sensitive", mode = { "n", "i" }, desc = "Toggle case sensitivity" },
          },
        },
      },
    },
    _all = {
      -- Common options applied to all pickers
      matcher = {
        fuzzy = true, -- fuzzy matching
        -- smartcase = false,   -- always case-insensitive (set at initialization)
        smartcase = true, -- always case-insensitive (set at initialization)
        -- default = true ?
        filename_bonus = true, -- bonus for matching filename
        file_pos = true, -- support file:line:col patterns
        cwd_bonus = false, -- bonus for files in cwd
        frecency = false, -- frecency scoring
        history_bonus = false, -- chronological boost
      },
      toggles = {
        -- Existing toggles...
        git_cwd = {
          icon = "",
          value = true, -- Show when case_sensitive is true
        },
        case_sensitive_custom = {
          icon = "C", -- Icon to show in title
          value = true, -- Show when case_sensitive is true
        },
        case_nonsensitive_custom = {
          icon = "-C", -- Icon to show in title
          value = true, -- Show when case_sensitive is true
        },
      },
      -- Move inline key functions into actions so keys can reference them by name
      actions = {
        -- not work
        toggle_smartcase = function(picker, item)
          -- Matcher config cannot be changed on the fly
          -- We need to use toggles or refresh with new opts
          print [==[Toggle matcher settings:]==]
          -- print([==[Current picker.matcher:]==], vim.inspect(picker.matcher))
          print([==[Current picker.matcher.opts:]==], vim.inspect(picker.matcher.opts))

          Snacks.debug "Toggled smartcase"
          -- this work but need auto search trigger to refresh the result (also need turn smarcase off)
          picker.matcher.opts.ignorecase = not picker.matcher.opts.ignorecase
          if picker.matcher.opts.ignorecase then
            picker.matcher.opts.smartcase = true
          else
            -- turn of smartcase
            picker.matcher.opts.smartcase = false
          end
          -- Snacks.debug("Toggled smartcase to " .. tostring(picker.matcher.opts.smartcase), "info")
          Snacks.debug("Toggled ignorecase to " .. tostring(picker.matcher.opts.ignorecase), "info")

          -- Need to recreate the matcher with nef config
          -- picker.matcher = require("snacks.picker.core.matcher")(picker, picker.opts.matcher)
          picker:find()
          picker:refresh()
        end,

        -- https://deepwiki.com/search/is-there-action-for-toggle-cas_3d6a4dac-3a3f-41d1-acc7-4f8dffee3d77?mode=fast
        toggle_case_sensitivity = function(picker, item)
          local current_args = vim.deepcopy(picker.opts.args) or {}
          local has_ignore_case = vim.tbl_contains(current_args, "-i")
            or vim.tbl_contains(current_args, "--ignore-case")
          local has_casesens = vim.tbl_contains(current_args, "-s")
            or vim.tbl_contains(current_args, "--case-sensitive")
          -- local current_search = picker.input.filter and picker.input.filter.search
          local current_pattern = picker.input.filter and picker.input.filter.pattern
          local currentmatchpattern = picker.matcher and picker.matcher.pattern
          -- exists in file same as matcher
          local current_search = picker.input.filter and picker.input.filter.search
          local search_query_has_upper = current_search:match "%u"

          -- Determine source type (fd for files, rg for grep)
          local source = picker.opts.source

          function remove_exist_flags(args, flags)
            return vim.tbl_filter(function(arg)
              return not vim.tbl_contains(flags, arg)
            end, args)
          end

          local is_case_sensitive_perceived = has_casesens or (not has_ignore_case and search_query_has_upper)

          local is_next_sensitive = nil
          print([==[Toggle before args:]==], vim.inspect(picker.opts.args))
          if has_ignore_case then
            current_args = remove_exist_flags(current_args, { "-i", "--ignore-case" })
            current_args = remove_exist_flags(current_args, { "-s", "--case-sensitive" })

            Snacks.debug "Default (smartcase)"
          elseif is_case_sensitive_perceived then
            -- Add ignore case flag
            current_args = remove_exist_flags(current_args, { "-i", "--ignore-case" })
            current_args = remove_exist_flags(current_args, { "-s", "--case-sensitive" })
            table.insert(current_args, "--ignore-case")
            is_next_sensitive = false
            Snacks.debug "Ignore case"
          else -- (search_query_has_both_case and not has_casesens and not has_ignore_case)
            -- Remove ignore case flag
            current_args = remove_exist_flags(current_args, { "-i", "--ignore-case" })
            current_args = remove_exist_flags(current_args, { "-s", "--case-sensitive" })
            table.insert(current_args, "--case-sensitive")
            Snacks.debug "Case sensitive"
            is_next_sensitive = true
          end
          picker.opts.args = current_args
          if source == "files" or source == "buffers" or source == "smart" then
            local smartcase = picker.opts.matcher.smartcase
            local ignorecase = picker.opts.matcher.ignorecase
            local init_smartcase = picker.init_opts.matcher and picker.init_opts.matcher.smartcase
            local init_ignorecase = picker.init_opts.matcher and picker.init_opts.matcher.ignorecase
            -- print all smart,init , ignore in table
            print(
              [==[snacks_opt_tgg#picker.opts.matcher:]==],
              vim.inspect {
                smartcase = smartcase,
                ignorecase = ignorecase,
                init_smartcase = init_smartcase,
                init_ignorecase = init_ignorecase,
              }
            )
            if is_next_sensitive then
              picker.opts.matcher.ignorecase = false
              picker.opts.matcher.smartcase = false
            elseif is_next_sensitive == false then
              picker.opts.matcher.ignorecase = true
              picker.opts.matcher.smartcase = false
            else
              picker.opts.matcher.ignorecase = false
              picker.opts.matcher.smartcase = false
            end
            picker.matcher = require("snacks.picker.core.matcher").new(picker.opts.matcher)
          end

          picker.opts.case_sensitive_custom = is_next_sensitive
          picker.opts.case_nonsensitive_custom = is_next_sensitive == false
          print([==[Toggle after args:]==], vim.inspect(picker.opts.args))
          -- picker:find()
          picker:find()
        end,
        -- toggle_case_sensitivity= function(picker, item)
        toggle_case_sensitivity_debug = function(picker, item)
          -- GREP : work on both if intial opts has smart case on / of
          --  initial : match all regardless smartcase
          -- Files / FD ? : not work on both if intial opts has smart case on / of
          -- smartcase: if false sensitivecase
          -- Toggle case sensitivity by modifying command args
          local current_args = vim.deepcopy(picker.opts.args) or {}
          local has_ignore_case = vim.tbl_contains(current_args, "-i")
            or vim.tbl_contains(current_args, "--ignore-case")
          local has_casesens = vim.tbl_contains(current_args, "-s")
            or vim.tbl_contains(current_args, "--case-sensitive")
          -- local current_search = picker.input.filter and picker.input.filter.search
          local current_pattern = picker.input.filter and picker.input.filter.pattern
          local currentmatchpattern = picker.matcher and picker.matcher.pattern
          -- exists in file same as matcher
          -- __AUTO_GENERATED_PRINT_VAR_START__
          print([==[snacks_opt_tgg#toggle_case_sensitivity current_pattern:]==], vim.inspect(current_pattern)) -- __AUTO_GENERATED_PRINT_VAR_END__
          local current_search = picker.input.filter and picker.input.filter.search
          -- __AUTO_GENERATED_PRINT_VAR_START__
          print([==[snacks_opt_tgg#toggle_case_sensitivity currentmatchpattern:]==], vim.inspect(currentmatchpattern)) -- __AUTO_GENERATED_PRINT_VAR_END__
          -- __AUTO_GENERATED_PRINT_VAR_START__
          print([==[snacks_opt_tgg#toggle_case_sensitivity current_search:]==], vim.inspect(current_search)) -- __AUTO_GENERATED_PRINT_VAR_END__
          local search_query_has_upper = current_search:match "%u"
          print(
            [==[snacks_opt_tgg#toggle_case_sensitivity search_query_has_both_case:]==],
            vim.inspect(search_query_has_upper)
          )

          -- Determine source type (fd for files, rg for grep)
          local source = picker.opts.source

          -- __AUTO_GENERATED_PRINT_VAR_START__

          function remove_exist_flags(args, flags)
            return vim.tbl_filter(function(arg)
              return not vim.tbl_contains(flags, arg)
            end, args)
          end

          local is_case_sensitive_perceived = has_casesens or (not has_ignore_case and search_query_has_upper)
          -- __AUTO_GENERATED_PRINT_VAR_START__
          print(
            [==[snacks_opt_tgg#toggle_case_sensitivity is_case_sensitive_perceived:]==],
            vim.inspect(is_case_sensitive_perceived)
          ) -- __AUTO_GENERATED_PRINT_VAR_END__

          local is_next_sensitive = false
          print([==[Toggle before args:]==], vim.inspect(picker.opts.args))
          if has_ignore_case then
            current_args = remove_exist_flags(current_args, { "-i", "--ignore-case" })
            current_args = remove_exist_flags(current_args, { "-s", "--case-sensitive" })

            Snacks.debug "Default (smartcase)"
          elseif is_case_sensitive_perceived then
            -- Add ignore case flag
            current_args = remove_exist_flags(current_args, { "-i", "--ignore-case" })
            current_args = remove_exist_flags(current_args, { "-s", "--case-sensitive" })
            table.insert(current_args, "--ignore-case")
            Snacks.debug "Ignore case"
          else -- (search_query_has_both_case and not has_casesens and not has_ignore_case)
            -- Remove ignore case flag
            current_args = remove_exist_flags(current_args, { "-i", "--ignore-case" })
            current_args = remove_exist_flags(current_args, { "-s", "--case-sensitive" })
            table.insert(current_args, "--case-sensitive")
            Snacks.debug "Case sensitive"
            is_next_sensitive = true
          end
          picker.opts.args = current_args
          -- __AUTO_GENERATED_PRINT_VAR_START__

          if source == "files" or source == "buffers" or source == "smart" then
            function workbutnotrefreshed()
              local smartcase = picker.matcher.opts.smartcase
              local ignorecase = picker.matcher.opts.ignorecase
              local init_smartcase = picker.init_opts.matcher and picker.init_opts.matcher.smartcase
              -- __AUTO_GENERATED_PRINT_VAR_START__
              local init_ignorecase = picker.init_opts.matcher and picker.init_opts.matcher.ignorecase
              -- print all smart,init , ignore in table
              print(
                [==[snacks_opt_tgg#picker.matcher.opts:]==],
                vim.inspect {
                  smartcase = smartcase,
                  ignorecase = ignorecase,
                  init_smartcase = init_smartcase,
                  init_ignorecase = init_ignorecase,
                }
              )
              -- __AUTO_GENERATED_PRINT_VAR_START__
              if is_next_sensitive then
                picker.matcher.opts.ignorecase = false
                picker.matcher.opts.smartcase = false
              else
                picker.matcher.opts.ignorecase = false
                picker.matcher.opts.smartcase = true
                -- picker.matcher.opts.smartcase = init_smartcase
              end
            end
            function work()
              local smartcase = picker.opts.matcher.smartcase
              local ignorecase = picker.opts.matcher.ignorecase
              local init_smartcase = picker.init_opts.matcher and picker.init_opts.matcher.smartcase
              -- __AUTO_GENERATED_PRINT_VAR_START__
              local init_ignorecase = picker.init_opts.matcher and picker.init_opts.matcher.ignorecase
              -- print all smart,init , ignore in table
              print(
                [==[snacks_opt_tgg#picker.opts.matcher:]==],
                vim.inspect {
                  smartcase = smartcase,
                  ignorecase = ignorecase,
                  init_smartcase = init_smartcase,
                  init_ignorecase = init_ignorecase,
                }
              )
              -- __AUTO_GENERATED_PRINT_VAR_START__
              if is_next_sensitive then
                picker.opts.matcher.ignorecase = false
                picker.opts.matcher.smartcase = false
              else
                picker.opts.matcher.ignorecase = false
                picker.opts.matcher.smartcase = true
                -- picker.opts.matcher.smartcase = init_smartcase
              end
              -- this line maje the result change
              picker.matcher = require("snacks.picker.core.matcher").new(picker.opts.matcher)
              print(
                [==[snacks_opt_tgg#toggle_case_sensitivity#if picker.opts.matcher:]==],
                vim.inspect(picker.opts.matcher)
              ) -- __AUTO_GENERATED_PRINT_VAR_END__
            end
            -- matcherLoc()
            work()
            picker.opts.case_sensitive_custom = is_next_sensitive

            -- __AUTO_GENERATED_PRINT_VAR_START__

            -- table.insert(current_args, "-h")
            -- table.insert(current_args, "-s")
            -- picker.opts.args = current_args
            -- __AUTO_GENERATED_PRINT_VAR_START__
            -- print([==[snacks_opt_tgg#picker.opts.args:]==], vim.inspect(picker.opts.args)) -- __AUTO_GENERATED_PRINT_VAR_END__
            -- __AUTO_GENERATED_PRINT_VAR_START__
            -- picker:refresh()
            -- picker.opts.actions.toggle_smartcase(picker, item)
          end
          print([==[Toggle after args:]==], vim.inspect(picker.opts.args))
          -- picker:find()
          picker:find()
        end,
        toggle_cwd_files_grep = function(picker, item)
          -- require does not really updated on the fly
          -- require("utils.snacks_terminal").toggle_cwd_files_grep(picker, item)
          local path = require "utils.path"
          local pathUtil = require "utils.mypath"

          -- Get available cwd options
          local current_dir = vim.fn.getcwd()
          local git_root = path.get_root_directory()
          local sub_project_dir = pathUtil.get_sub_project_dirs_from_root(nil, nil, false, false, "nearest")
          local prev_buf = vim.api.nvim_buf_get_name(vim.fn.bufnr "#")
          local prev_buffer_dir = prev_buf ~= "" and vim.fn.fnamemodify(prev_buf, ":p:h") or nil

          -- Initialize cwd cycle state if not exists
          if not vim.g.picker_cwd_cycle_state then
            vim.g.picker_cwd_cycle_state = "current"
          end

          -- Define the initial cycle order (will be filtered for duplicates/invalid)
          local cycle_order = { "current", "gitroot", "subproject", "prevbuffer", "current_d1" }

          -- Map states to actual directories
          local cwd_map = {
            current = current_dir,
            current_d1 = current_dir, -- Same as current, but with depth-1 search for grep
            gitroot = git_root,
            subproject = sub_project_dir,
            prevbuffer = prev_buffer_dir,
          }

          -- Remove duplicates from cwd_map
          -- Keep track of seen directories and remove duplicate entries
          -- Note: current_d1 is kept separate from current even if same dir (different behavior for grep)
          local seen_dirs = {}
          local unique_cycle_order = {}

          for _, state in ipairs(cycle_order) do
            local dir = cwd_map[state]
            -- Only add if directory is valid and not seen before
            if dir and dir ~= "" and vim.fn.isdirectory(dir) == 1 then
              -- Treat current_d1 as distinct from current (different grep behavior)
              local dir_key = (state == "current_d1") and "current_d1" or dir

              if not seen_dirs[dir_key] then
                seen_dirs[dir_key] = true
                table.insert(unique_cycle_order, state)
              else
                -- Remove duplicate from cwd_map
                print(string.format("Removing duplicate cwd state '%s' for directory '%s'", state, dir))
                cwd_map[state] = nil
              end
            else
              -- Remove invalid directories
              cwd_map[state] = nil
            end
          end

          -- Update cycle_order to only include unique, valid directories
          cycle_order = unique_cycle_order

          -- If all directories are the same or invalid, keep at least current
          if #cycle_order == 0 then
            cycle_order = { "current" }
            cwd_map = { current = current_dir }
          end

          -- If only one unique directory, notify user and don't cycle
          if #cycle_order == 1 then
            vim.notify("Only one unique directory available - no other scopes to cycle to", vim.log.levels.INFO)
            return
          end

          -- Find next valid state in the new cycle_order
          local current_state_idx = nil
          for i, state in ipairs(cycle_order) do
            if state == vim.g.picker_cwd_cycle_state then
              current_state_idx = i
              break
            end
          end

          -- If current state is not in cycle (was removed as duplicate), start from beginning
          if not current_state_idx then
            current_state_idx = 0
          end

          -- Move to next state
          local next_idx = (current_state_idx % #cycle_order) + 1
          vim.g.picker_cwd_cycle_state = cycle_order[next_idx]
          local new_cwd = cwd_map[vim.g.picker_cwd_cycle_state]

          -- Get current picker source and pattern
          local source = picker.init_opts and picker.init_opts.source
          -- search = for grep pickers
          local filter_pattern = picker.input.filter
            and (picker.input.filter.pattern ~= "" and picker.input.filter.pattern)
          local filter_search = picker.input.filter
            and (picker.input.filter.search ~= "" and picker.input.filter.search)

          -- State labels
          local state_labels = {
            current = cwd_map.current == cwd_map.gitroot and "Default/Git" or "Default/current",
            current_d1 = (cwd_map.current == cwd_map.gitroot and "Default/Git" or "Default/current") .. "(D=1)",
            gitroot = "Git Root",
            subproject = "Sub-Project Directory",
            prevbuffer = "Previous Buffer Directory",
          }

          -- Notify user about the change
          vim.notify(
            string.format("CWD: %s\n%s", state_labels[vim.g.picker_cwd_cycle_state], new_cwd),
            vim.log.levels.INFO
          )

          -- -- Close current picker
          -- picker:close()

          -- Build picker params with scope label in title
          local scope_label = state_labels[vim.g.picker_cwd_cycle_state]
          local picker_params = {
            cwd = new_cwd,
            pattern = filter_pattern or "",
            search = filter_search or "",
            live = picker.opts.supports_live and picker.opts.live,
            show_empty = true,
            title = string.format("%s [%s]", source or "Picker", scope_label),
          }
          local hidden_state = picker.opts.hidden
          local ignored_state = picker.opts.ignored

          -- Fallback to init_opts if opts don't have the values
          if hidden_state == nil and picker.init_opts then
            hidden_state = picker.init_opts.hidden
          end
          if ignored_state == nil and picker.init_opts then
            ignored_state = picker.init_opts.ignored
          end

          if hidden_state ~= nil then
            picker_params.hidden = hidden_state
          end
          if ignored_state ~= nil then
            picker_params.ignored = ignored_state
          end

          -- Add git_cwd=true when current cwd is equal to git root
          if new_cwd == git_root and git_root and git_root ~= "" then
            picker_params.git_cwd = true
          end

          -- Handle different picker types and preserve their state
          if
            vim.g.picker_cwd_cycle_state == "current_d1"
            and type(source) == "string"
            and (source:match "grep" or source:match "files")
            and not source:match "^git"
          then
            picker_params.args = { "--max-depth", "1" }
          end
          -- clone picker_params in to picker.opts
          picker.opts.cwd = picker_params.cwd
          picker.opts.args = picker_params.args
          picker.opts.pattern = picker_params.pattern
          picker.opts.search = picker_params.search
          picker.opts.live = picker_params.live
          picker.opts.show_empty = true
          picker.title = picker_params.title
          picker.opts.git_cwd = true
          -- __AUTO_GENERATED_PRINT_VAR_START__
          print([==[M.toggle_cwd_files_grep picker.opts:]==], vim.inspect(picker.opts)) -- __AUTO_GENERATED_PRINT_VAR_END__
          picker:refresh()

          local backupmanual_whenneed = function()
            if source == "files" then
              -- Add max-depth for current_d1 mode (depth 1 search) - fd supports --max-depth
              Snacks.picker.files(picker_params)
            elseif source == "grep" then
              -- Add max-depth for current_d1 mode (depth 1 search) - ripgrep supports --max-depth
              Snacks.picker.grep(picker_params)
            elseif source == "buffers" then
              -- Buffers picker - preserve any relevant state
              Snacks.picker.buffers(picker_params)
              -- elseif source == "git_files" then
              --   -- Git files picker
              --   Snacks.picker.git_files(picker_params)
            else
              Snacks.notify.warn("picker source" .. tostring(source) .. "Not configured to use change cwd")
              -- check for Snacks.picker[source]
              if Snacks.picker[source] and type(Snacks.picker[source]) == "function" then
                Snacks.picker[source](picker_params)
              else
                Snacks.notify.warn("Unknown picker source: " .. tostring(source) .. ". Falling back to smart picker.")
                -- Fallback to smart picker for unknown sources
                Snacks.picker.smart(picker_params)
              end
            end

            -- Re-enter insert mode after picker opens (Snacks default behavior)
            vim.defer_fn(function()
              if vim.api.nvim_get_mode().mode == "n" then
                vim.cmd "startinsert"
              end
            end, 50)
          end
        end,
      },

      win = {
        input = {
          -- ERR: title/footer must be string or array
          -- footer = function(picker)
          --   return "CWD: " .. (picker.opts.cwd or vim.fn.getcwd())
          -- end,
          footer = "footer text",
          footer_pos = "center", -- not required
          keys = {
            ["<M-b>"] = { "delete_file", mode = { "n", "i" }, desc = "Delete selected file" },
            ["<M-s>"] = { "toggle_cwd_files_grep", mode = { "n", "i" }, desc = "Toggle files cwd" },
            ["<C-t>"] = { "toggle_smartcase", mode = { "n", "i" }, desc = "Toggle smartcase (requires refresh)" },
            ["<M-c>"] = { "toggle_case_sensitivity", mode = { "n", "i" }, desc = "Toggle case sensitivity" },
          },
        },
      },
    },
    --
    buffers = {
      toggles = {
        external = { icon = "X", value = true },
      },
      transform = function(item, ctx)
        if not ctx.picker.opts.external then
          return item
        else
          return not is_in_project_dir_snacks(item)
        end
        return false
      end,
      actions = {
        toggle_external = function(picker)
          Snacks.debug "Toggling external buffers filter"
          picker.opts.external = not picker.opts.external
          print([==[snacks_opt_tgg#toggle_external picker.opts.external:]==], vim.inspect(picker.opts.external)) -- __AUTO_GENERATED_PRINT_VAR_END__
          -- picker.list:set_target()
          picker:find()
          -- picker:refresh()
        end,
      },
      win = {
        input = {
          footer = "External toggle via <M-e> or <C-p>",
          keys = {
            ["<M-e>"] = { "toggle_external", mode = { "n", "i" }, desc = "Toggle external buffers" },
            ["<C-p>"] = { "toggle_external", mode = { "n", "i" }, desc = "Toggle external buffers" },
          },
        },
      },
    },

    files = {
      -- Specific options only for files picker
      source = "files",
    },
    grep = {
      -- Specific options for grep picker
      source = "grep",
    },
    -- Add more picker-specific options as needed
  }

  -- Apply the configuration with default opts enabled
  autoMapSnacksKeys(testingmap_snacks, optsToTest, true, true)
  Snacks.debug "default test toggles Snacks keymaps configured!"
  print "Note: Matcher settings are initialized at creation time."
  print "To change matcher behavior, recreate the picker or use toggles."
end
function DOCS()
  local DOCSDESC = [[
    BASIC item: https://deepwiki.com/folke/snacks.nvim/2.8-creating-custom-pickers#item-field-requirements
    CUSTOM preview: https://deepwiki.com/search/suggest-way-to-achieve-the-act_13b29d19-06dc-4383-bc2b-5871786b2b2e
      -- if not format by default will use file key
      preview = "preview",
      format = function(item, picker)
        return {
          { item.value or item.text, "Normal" },
        }
      end,
      items = {
        -- below will show echo 123 in preview with correct hl
        { value = "Active Item 1", preview = { text = "echo 123", ft = "sh" } }, 
  ]]

  local test = ""
end
function map_layout()
  local optsLayout = {
    all = {
      layout = {
        strategy = "horizontal",
        preview = "main",
        preview_width = 0.6,
      },
    },
    buffers = {
      layout = {
        strategy = "horizontal",
        preview = "main",
        preview_width = 0.6,
      },
    },
    files = {
      layout = {
        strategy = "horizontal",
        preview = "main",
        preview_width = 0.6,
      },
    },
    grep = {
      layout = {
        strategy = "horizontal",
        preview = "main",
        preview_width = 0.6,
      },
    },
  }
  autoMapSnacksKeys(testingmap_snacks, optsLayout, true, true)
end
function map_new_luasnippets()
  local optsLayout = {
    _all = {
      layout = {
        strategy = "horizontal",
        preview = "main",
        preview_width = 0.6,
      },
    },
    --- @class snacks.Picker
    --- @field [string] unknown
    snippets = {
      supports_live = false,
      preview = "preview",
      format = function(item, picker)
        local name = Snacks.picker.util.align(item.name, picker.align_1 + 5)
        return {
          { name, item.ft == "" and "Conceal" or "DiagnosticWarn" },
          { item.description },
        }
      end,
      finder = function(_, ctx)
        local snippets = {}
        for _, snip in ipairs(require("luasnip").get_snippets().all) do
          snip.ft = ""
          table.insert(snippets, snip)
        end
        for _, snip in ipairs(require("luasnip").get_snippets(vim.bo.ft)) do
          snip.ft = vim.bo.ft
          table.insert(snippets, snip)
        end
        local align_1 = 0
        for _, snip in pairs(snippets) do
          align_1 = math.max(align_1, #snip.name)
        end
        ctx.picker.align_1 = align_1
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
            text = name .. " " .. description, -- search string
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
        --
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
    },
  }
  autoMapSnacksKeys(testingmap_snacks, optsLayout, true, true)
end

function mapGitOpts()
  local gitMapOpts = {
    -- TODO: use this in git custom picker
    git_diff = {
      base = "HEAD~2", -- alias/commit works
      -- Use args for global git options like -c core.quotepath=false
      -- -- fail with path filter error - cmd: `git -c core.quotepath=false --no-pager -- tests diff --no-color --no-ext-diff --diff-filter=u --merge-base HEAD~2`
      -- args = {
      --   "--", "tests"
      -- },
      cmd_args = { "--", "tests/" },
      -- pathspec = "tests", -- not work
    },
    git_grep = {
      pathspec = "tests", -- works
      search = "TODO",
    },
  }
  -- Snacks.picker.git_diff(vim.tbl_extend("force",{}, gitMapOpts.git_diff))
  autoMapSnacksKeys(testingmap_snacks, gitMapOpts, true, true)
end
--#endregion
-- git()
--#region built in pickers test
function snacks_grep()
  -- https://deepwiki.com/search/how-does-this-picker-populate_0d5cf5fe-0523-490e-b51c-799e8f6dd16d?mode=fast
  -- Toggle CWD scope for pickers (files/grep/etc)
  -- Cycles through: current dir → git root → sub-project dir → previous buffer dir
  -- cd ./assets -- expect no grep , cwd should overrite grep search
  Snacks.picker.grep_word {
    show_empty = true,
    cwd = Snacks.git.get_root(),
  }

  Snacks.picker.grep_word {
    show_empty = true,

    smartcase = false,
    ignorecase = true,
    hidden = true,
    cwd = Snacks.git.get_root(),
    live = true,
    -- opts = {
    --   hidden = true,
    -- },
    args = { "--ignore-case" },
  }
end
function snacks_git_browse()
  -- https://deepwiki.com/search/can-gitbrowse-be-configure-and_45650fa5-dddd-460a-8101-f405f8843dec?mode=fast
  Snacks.gitbrowse {
    branch = require("utils.git").git_main_branch(),
    what = "file",
  }
end
function git()
  -- Snacks.picker.git_log_file { current_file = false } -- no specific files / dir available
  -- Snacks.picker.git_diff {}
  -- Want to do buffer_lines style in git diff

  --
  --
  -- Try to do git diff in line like grep lines
  -- https://deepwiki.com/search/how-does-this-picker-populate_0d5cf5fe-0523-490e-b51c-799e8f6dd16d?mode=fast
  Snacks.picker.git_diff {
    -- Snacks.picker.files {
    -- Snacks.picker.grep {
    -- finder = "lines", -- might need this but preview show empty
    -- base = "HEAD~1",
    group = true, --  else showq multiple pathces in multiple result
    layout = {
      preset = "ivy", -- Horizontal layout at bottom
      preview = "main", -- Show preview in main window
    },
    -- preview = "file",
    preview = "file",
    main = { current = true }, -- Use current window as main
    on_show = function(picker)
      -- local cursor = vim.api.nvim_win_get_cursor(picker.main)
      -- local info = vim.api.nvim_win_call(picker.main, vim.fn.winsaveview)
      -- picker.list:view(cursor[1], info.topline)
      -- picker:show_preview()
    end,
  }
end
-- git()
function gitdiff_custom()
  function c1()
    Snacks.picker.git_diff {
      layout = {
        -- preset = "ivy",    -- Horizontal layout at bottom
        backdrop = false, -- No backdrop
        -- Keep diff preview in picker, not in main window
      },
      main = { current = true },
      -- base = "main",
      group = true,
      -- Open file in main window when showing picker
      -- on_show = function(picker)
      -- --   picker.list:view(cursor[1], info.topline)
      -- end,
      -- Update main window when selection changes
      on_change = function(picker, item)
        -- __AUTO_GENERATED_PRINT_VAR_START__
        -- print([==[gitdiff_custom#on_change item:]==], vim.inspect(item)) -- __AUTO_GENERATED_PRINT_VAR_END__
        -- if item and item.file then
        --   -- Check if buffer is already loaded
        --   local buf = vim.fn.bufexists(item.file)
        --   if buf == 0 then
        --     vim.cmd("edit " .. item.file)
        --   else
        --     vim.api.nvim_set_current_buf(buf)
        --   end
        --
        --   if item.line then
        --     vim.api.nvim_win_set_cursor(0, { item.line, 0 })
        --     vim.cmd("norm! zz")
        --   end
        --
        --   -- Refresh gitsigns
        --   if vim.fn.exists(":Gitsigns") > 0 then
        --     vim.cmd("Gitsigns refresh")
        --   end
        -- end
      end,
    }
  end
  -- TOFIX: after hovering to 2-3 list seems like the file content is in the search box then all the snacks key cannot be used / stuck
  -- https://deepwiki.com/search/how-does-this-picker-populate_0d5cf5fe-0523-490e-b51c-799e8f6dd16d?mode=fast
  function c2()
    Snacks.picker.git_diff {
      layout = {
        preset = "ivy", -- Horizontal layout at bottom
        backdrop = false, -- No backdrop - single layout config
      },
      main = { current = true },
      base = "main",
      group = true,
      -- Use on_change to update main window when selection changes
      on_change = function(picker, item)
        if not item or not item.file then
          return
        end

        -- Safely get the main window
        local main_win = picker.main
        if not main_win or not vim.api.nvim_win_is_valid(main_win) then
          Snacks.debug("Invalid main window in git_diff on_change", "error")
          return
        end

        -- Load the file if not already loaded
        local buf = vim.fn.bufnr(item.file, false)
        if buf == -1 then
          print([==[gitdiff_custom#c2#on_change buf:]==], vim.inspect(buf, item.file)) -- __AUTO_GENERATED_PRINT_VAR_END__
          vim.cmd("edit " .. item.file)
          buf = vim.fn.bufnr(item.file, false)
        end
        vim.api.nvim_win_set_buf(main_win, buf)

        -- Set the buffer in main window

        -- Jump to the line if specified
        if item.line then
          print([==[gitdiff_custom#c2#on_change#if item.line:]==], vim.inspect(item.line)) -- __AUTO_GENERATED_PRINT_VAR_END__
          vim.api.nvim_win_set_cursor(main_win, { item.line, 0 })
          vim.cmd "norm! zz"
        end

        -- Optional: refresh gitsigns if available
        -- pcall(vim.cmd, "Gitsigns refresh")
      end,
    }
  end
  c2()
end
-- gitdiff_custom()
--#region

--#region custom pickers
function custom_git()
  -- Custom picker to select branch then show diff
  function git_diff_branch()
    -- Step 1: Pick a branch/ref
    Snacks.picker.git_branches {
      title = "Select Branch to Diff Against HEAD",
      confirm = function(picker, item)
        if not item.branch then
          return
        end

        -- Step 2: Show diff between chosen branch and HEAD
        Snacks.picker.git_diff {
          title = "Git Diff (HEAD vs " .. item.branch .. ")",
          -- base = item.branch, -- Use chosen branch as base
          -- hash works
          -- base = "351108d8b6a7cedd264b364a76ee958ba552087f", -- Use chosen branch as base
          -- Optional: customize actions or keys
        }
      end,
    }
  end
  git_diff_branch()
end
-- custom_git()

function custom_test_withaction_moditem()
  local mycustom_source_config = {
    -- Custom option that will be toggled
    show_archived = false,
    -- Define the finder function that returns items based on the option
    finder = function(opts, ctx)
      local items = {}
      -- Return different items based on the custom option
      if opts.show_archived then
        table.insert(items, { text = "Archived Item 1" })
        table.insert(items, { text = "Archived Item 2" })
      else
        table.insert(items, { text = "Active Item 1" })
        table.insert(items, { text = "Active Item 2" })
        table.insert(items, { text = "Active Item 3" })
      end
      return items
    end,
    preview = function(item, picker) -- or user preview default then set item.preview.text + .ft
      return {
        { "Preview of " .. (item.text or "No Text"), "Normal" },
      }
    end,
    -- Define custom toggle action
    actions = {
      toggle_archived = function(picker)
        picker.opts.show_archived = not picker.opts.show_archived
        picker:find()
      end,
    },

    -- Bind the toggle action to a key
    win = {
      input = {
        keys = {
          ["<C-a>"] = { "toggle_archived", mode = { "n", "i" }, desc = "Toggle Archived" },
        },
      },
    },
  }
  --   require("snacks.picker.config.sources").my_custom_source = {
  --   finder = function(opts, ctx)
  --     return {
  --       { text = "Custom Item 1" },
  --       { text = "Custom Item 2" },
  --     }
  --   end,
  --   -- other configuration...
  -- }
  --
  -- -- The source is now available as:
  -- require("snacks").picker.my_custom_source()

  require("snacks.picker.config.sources").my_custom_source = mycustom_source_config
  -- Snacks.picker.my_custom_source()
  Snacks.picker.pick {
    -- source = "my_custom_source",
    -- Define toggle - action is auto-generated
    toggles = {
      archived = { icon = "📁", enabled = false },
    },
    preview = "preview",
    format = function(item, picker)
      return {
        { item.value or item.text, "Normal" },
      }
    end,
    -- items = {
    --   -- { text = "Item 1", file = "/path/to/file1.txt" },
    --   -- { text = "Item 2", file = "/path/to/file2.txt" },
    --   { value = "Active Item 2" },
    --   { value = "Active Item 3" },
    -- },
    finder = function(opts, ctx)
      -- Use opts.archived instead of opts.show_archived
      local archived_items = {
        { value = "BIN Item 1", preview = { text = "echo 123", ft = "sh" } },
        { text = "BIN Item 2" },
      }
      local active_items = {
        { value = "Active Item 1", preview = { text = "echo 123", ft = "sh" } },
        { text = "Active Item 2" },
        { text = "Active Item 3" },
      }
      local items = opts.archived and archived_items or active_items
      return items
    end,

    -- Key binding for auto-generated action
    win = {
      input = {
        keys = {
          ["<C-a>"] = { "toggle_archived", mode = { "n", "i" } },
        },
      },
    },
  }
end
-- custom_test_withaction_moditem()

function custom_test()
  -- https://deepwiki.com/folke/snacks.nvim/2.8-creating-custom-pickers
  -- https://deepwiki.com/search/how-does-confirm-jump-works-an_3bac984b-318e-4216-9ef0-20a9fe35f125?mode=fast
  --
  -- batch return function(cb) support
  -- custom hard code list
  Snacks.picker.pick {
    supports_live = true,
    finder = function(picker, opts)
      -- This is correct - finders can return tables directly
      return {
        { text = "First line", value = 1 },
        { text = "Second line", value = 2 },
        -- lines does not work
        {
          text = "Third line fLine",
          value = 3,
          file = "/Users/tharutaipree/dotfiles/.config/nvim3_jelly_tinynvim/tests/myTestSnacks.lua",
          line = 1133,
        },
        {
          text = "Forth line helper.lua",
          value = "[ai-tools/]",
          file = "/Users/tharutaipree/dotfiles/.config/nvim3_jelly_tinynvim/lua/utils/prompts_helper.lua",
          line = 1133,
        },
      }
    end,
    format = function(item, picker)
      -- virtual = not allow to fzf match in grep modPThird
      return {
        -- Use item.text instead of item.name
        { item.text, "Normal" },
        { " ", "Normal" },
        -- { "(" .. item.value .. ")", "Comment", virtual = true },
        { "(" .. item.value .. ")", "Comment" },
        -- Handle case where file might be nil
        { item.file and " [" .. item.file .. "]" or "", "NonText", virtual = true },
      }
    end,
    preview = "preview",
    confirm = "jump",
    -- layout = {
    --   preset = "file"
    -- },
  }
end
-- custom_test()

function inline_custom_prev_follow()
  Snacks.picker {
    source = "lines", -- or your custom source
    layout = {
      preview = "main", -- Show preview in main window
      preset = "ivy", -- Horizontal layout at bottom
    },
    main = { current = true }, -- Use current window as main
    -- Optional: customize the on_show behavior like lines source
    on_show = function(picker)
      local cursor = vim.api.nvim_win_get_cursor(picker.main)
      local info = vim.api.nvim_win_call(picker.main, vim.fn.winsaveview)
      picker.list:view(cursor[1], info.topline)
      picker:show_preview()
    end,
  }
end
--#endregion

function main()
  -- snacks_opt_tgg()
  map_new_luasnippets()
  -- mapGitOpts()
  -- map_layout()
end

main()
