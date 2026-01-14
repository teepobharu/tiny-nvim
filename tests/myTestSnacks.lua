
function SnacksUtils()
  Snacks.debug("asdasd")
  Snacks.notify.warn("Notification from SnacksUtils")

  print(12312321)
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
    print(vim.inspect(B.init_opts.source.asd.zxc))                            -- stop
    print(321)
  end

  ---@class snacks.picker.input
  local p1 = Snacks.picker.files({
    -- search = "test"
    -- why refresh null ?
    pattern = "test" -- intial query
    ,win = {
      input = {
        keys = {
          ["<C-s>"] = { 
            function (picker, item)
            -- __AUTO_GENERATED_PRINT_VAR_START__
            print([==[snacks_preview#(anon) item:]==], vim.inspect(item)) -- __AUTO_GENERATED_PRINT_VAR_END__
            print([==[snacks_preview#(anon) picker:refresh:]==], vim.inspect(picker.refresh))
            print([==[snacks_preview#(anon) picker:]==], vim.inspect(picker)) -- __AUTO_GENERATED_PRINT_VAR_END__
            picker:refresh()
            -- __AUTO_GENERATED_PRINT_VAR_START__
            picker:find()
          end, mode = { "n", "i"}, desc = "test refresh"
          }
        }
      }
    }
  })
  p1:refresh()
  vim.defer_fn(function()
    vim.notify("waiting", vim.log.levels.INFO)
    print("waiting . . .")
  end, 2000)
  local p2 = Snacks.picker.buffers {
    -- search = "test"
    pattern = "testp2" -- intial query
  }
  -- wait 3s
  print([==[snacks_preview#(anon) p1:active1]==], vim.inspect(p1:is_active()))
  vim.defer_fn(function()
    p1:toggle()
    print([==[snacks_toggle#(anon) p1:active2]==], vim.inspect(p1:is_active()))
  end, 3000)
  vim.defer_fn(function()
    p2:toggle()
    print([==[snacks_preview#(anon) p1:]==], vim.inspect(p1:is_focused()))
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

-- Configuration structure for Snacks picker keymaps
local SnacksFilesTest = function()

  Snacks.picker.files({
    matcher = {
      -- smartcase = false, -- this will make ignorecase work
    },
    args = { 
      -- "-h" ,
      "--hidden", "--no-ignore", "--ignore-case" 
    },
  })

end
local SNACKS_GLOBAL_OPTS =  {
  win = {
      input = {
        keys = {
            ["<C-p>"] = { "debug_print_actions_and_options", mode = { "n", "i" }, desc = "Debug: Print actions and options" },
      }
    }
  },
  actions = {
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
        print("SearchHasUpper:", tostring((current_search or ""):match("%u") and true or false))

        -- Live mode and matcher opts (concise)
        print("Live:", vim.inspect(picker and picker.opts and picker.opts.live))
        if picker and picker.matcher then
          print("MatcherOpts:", vim.inspect(picker.matcher.opts))
        end

        -- Refresh the picker
        picker:refresh()
      end,
  }
}

local testingmap_snacks = {
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
 sgit_files = {
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
      Snacks.picker[picker_name](final_opts)
    end, {
      desc = "Snacks: " .. picker_name,
      noremap = true,
      silent = true,
    })
  end
end

function snacks_opt_tgg()
  -- Define options to apply
  local optsToTest = {
  _all2 = {
  toggles = {  
    -- Existing toggles...  
    case_sensitive = {   
      icon = "C",  -- Icon to show in title  
      value = true -- Show when case_sensitive is true  
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
      }  
    }  
  }  
    },
  _all = {
    -- Common options applied to all pickers
    matcher = {
      fuzzy = true,        -- fuzzy matching
      -- smartcase = false,   -- always case-insensitive (set at initialization)
      smartcase = true,   -- always case-insensitive (set at initialization)
        -- default = true ?
      filename_bonus = true, -- bonus for matching filename
      file_pos = true,     -- support file:line:col patterns
      cwd_bonus = false,   -- bonus for files in cwd
      frecency = false,    -- frecency scoring
      history_bonus = false, -- chronological boost
    },
      toggles = {  
        -- Existing toggles...  
        case_sensitive_custom = {   
          icon = "C",  -- Icon to show in title  
          value = true -- Show when case_sensitive is true  
        },
        case_nonsensitive_custom = {   
          icon = "-C",  -- Icon to show in title  
          value = true -- Show when case_sensitive is true  
        },
      },  
    -- Move inline key functions into actions so keys can reference them by name
    actions = {
        -- not work
      toggle_smartcase = function(picker, item)
        -- Matcher config cannot be changed on the fly
        -- We need to use toggles or refresh with new opts
        print([==[Toggle matcher settings:]==])
        -- print([==[Current picker.matcher:]==], vim.inspect(picker.matcher))
        print([==[Current picker.matcher.opts:]==], vim.inspect(picker.matcher.opts))

        Snacks.debug("Toggled smartcase")
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
          local has_ignore_case = vim.tbl_contains(current_args, "-i") or vim.tbl_contains(current_args, "--ignore-case")
          local has_casesens = vim.tbl_contains(current_args, "-s") or vim.tbl_contains(current_args, "--case-sensitive")
          -- local current_search = picker.input.filter and picker.input.filter.search
          local current_pattern = picker.input.filter and picker.input.filter.pattern
          local currentmatchpattern = picker.matcher and picker.matcher.pattern
          -- exists in file same as matcher
          local current_search = picker.input.filter and picker.input.filter.search
          local search_query_has_upper = current_search:match("%u")

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
            current_args = remove_exist_flags(current_args, {"-i", "--ignore-case"})
            current_args = remove_exist_flags(current_args, {"-s", "--case-sensitive"})

            Snacks.debug("Default (smartcase)")
          elseif is_case_sensitive_perceived then
            -- Add ignore case flag
            current_args = remove_exist_flags(current_args, {"-i", "--ignore-case"})
            current_args = remove_exist_flags(current_args, {"-s", "--case-sensitive"})
            table.insert(current_args, "--ignore-case")
            is_next_sensitive = false
            Snacks.debug("Ignore case")
          else -- (search_query_has_both_case and not has_casesens and not has_ignore_case)
            -- Remove ignore case flag
            current_args = remove_exist_flags(current_args, {"-i", "--ignore-case"})
            current_args = remove_exist_flags(current_args, {"-s", "--case-sensitive"})
            table.insert(current_args, "--case-sensitive")
            Snacks.debug("Case sensitive")
            is_next_sensitive = true
          end
          picker.opts.args = current_args
          if source == "files" or source == "buffers" or source == "smart" then
              local smartcase = picker.opts.matcher.smartcase
              local ignorecase = picker.opts.matcher.ignorecase
              local init_smartcase = picker.init_opts.matcher and picker.init_opts.matcher.smartcase
              local init_ignorecase = picker.init_opts.matcher and picker.init_opts.matcher.ignorecase
              -- print all smart,init , ignore in table
              print([==[snacks_opt_tgg#picker.opts.matcher:]==], vim.inspect({ 
                smartcase = smartcase, ignorecase = ignorecase, init_smartcase = init_smartcase, init_ignorecase = init_ignorecase,
              }))
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
          local has_ignore_case = vim.tbl_contains(current_args, "-i") or vim.tbl_contains(current_args, "--ignore-case")
          local has_casesens = vim.tbl_contains(current_args, "-s") or vim.tbl_contains(current_args, "--case-sensitive")
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
          local search_query_has_upper = current_search:match("%u")
          print([==[snacks_opt_tgg#toggle_case_sensitivity search_query_has_both_case:]==], vim.inspect(search_query_has_upper))

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
          print([==[snacks_opt_tgg#toggle_case_sensitivity is_case_sensitive_perceived:]==], vim.inspect(is_case_sensitive_perceived)) -- __AUTO_GENERATED_PRINT_VAR_END__



          local is_next_sensitive = false
          print([==[Toggle before args:]==], vim.inspect(picker.opts.args))
          if has_ignore_case then
            current_args = remove_exist_flags(current_args, {"-i", "--ignore-case"})
            current_args = remove_exist_flags(current_args, {"-s", "--case-sensitive"})

            Snacks.debug("Default (smartcase)")
          elseif is_case_sensitive_perceived then
            -- Add ignore case flag
            current_args = remove_exist_flags(current_args, {"-i", "--ignore-case"})
            current_args = remove_exist_flags(current_args, {"-s", "--case-sensitive"})
            table.insert(current_args, "--ignore-case")
            Snacks.debug("Ignore case")
          else -- (search_query_has_both_case and not has_casesens and not has_ignore_case)
            -- Remove ignore case flag
            current_args = remove_exist_flags(current_args, {"-i", "--ignore-case"})
            current_args = remove_exist_flags(current_args, {"-s", "--case-sensitive"})
            table.insert(current_args, "--case-sensitive")
            Snacks.debug("Case sensitive")
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
              print([==[snacks_opt_tgg#picker.matcher.opts:]==], vim.inspect({ 
                smartcase = smartcase, ignorecase = ignorecase, init_smartcase = init_smartcase, init_ignorecase = init_ignorecase,
              }))
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
              print([==[snacks_opt_tgg#picker.opts.matcher:]==], vim.inspect({ 
                smartcase = smartcase, ignorecase = ignorecase, init_smartcase = init_smartcase, init_ignorecase = init_ignorecase,
              }))
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
              print([==[snacks_opt_tgg#toggle_case_sensitivity#if picker.opts.matcher:]==], vim.inspect(picker.opts.matcher)) -- __AUTO_GENERATED_PRINT_VAR_END__
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
          local path = require("utils.path")
          local pathUtil = require("utils.mypath")

          -- Get available cwd options
          local current_dir = vim.fn.getcwd()
          local git_root = path.get_root_directory()
          local sub_project_dir = pathUtil.get_sub_project_dir()
          local prev_buf = vim.api.nvim_buf_get_name(vim.fn.bufnr("#"))
          local prev_buffer_dir = prev_buf ~= "" and vim.fn.fnamemodify(prev_buf, ":p:h") or nil

          -- Initialize cwd cycle state if not exists
          if not vim.g.picker_cwd_cycle_state then
            vim.g.picker_cwd_cycle_state = "current"
          end

          -- Define the initial cycle order (will be filtered for duplicates/invalid)
          local cycle_order = {"current", "gitroot", "subproject", "prevbuffer", "current_d1"}

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
            cycle_order = {"current"}
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
          local filter_pattern = picker.input.filter and (picker.input.filter.pattern ~= "" and picker.input.filter.pattern)
          local filter_search = picker.input.filter and (picker.input.filter.search ~= "" and picker.input.filter.search)

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
          if vim.g.picker_cwd_cycle_state == "current_d1" and type(source) == "string" and (source:match("grep") or source:match("files")) and not source:match("^git") then
            picker_params.args = { "--max-depth", "1" }
          end
          -- clone picker_params in to picker.opts
          picker.opts.cwd =picker_params.cwd
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
                vim.cmd("startinsert")
              end
            end, 50)
          end
        end,
    }          
,

    win = {
      input = {
          footer = function(picker)  
            return "CWD: " .. (picker.opts.cwd or vim.fn.getcwd())  
          end,  
          footer_pos = "center",
        keys = {
          ["<M-s>"] = { "toggle_cwd_files_grep", mode = { "n", "i" }, desc = "Toggle files cwd" },
          ["<C-t>"] = { "toggle_smartcase", mode = { "n", "i" }, desc = "Toggle smartcase (requires refresh)" },
          ["<M-c>"] = { "toggle_case_sensitivity", mode = { "n", "i" }, desc = "Toggle case sensitivity" },
        }

      }
    }
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
  
  Snacks.debug("Snacks keymaps configured!")
  print("Note: Matcher settings are initialized at creation time.")
  print("To change matcher behavior, recreate the picker or use toggles.")
end

function snacks_grep()
-- Toggle CWD scope for pickers (files/grep/etc)
-- Cycles through: current dir → git root → sub-project dir → previous buffer dir
Snacks.picker.grep{
  smartcase = false,
  ignorecase = true,
  hidden = true,
  -- opts = {
  --   hidden = true,
  -- },
  args = { "--ignore-case"}
}
end

function snacks_git_browse()
  -- https://deepwiki.com/search/can-gitbrowse-be-configure-and_45650fa5-dddd-460a-8101-f405f8843dec?mode=fast
  Snacks.gitbrowse({   
    branch = require("utils.git").git_main_branch(),
    what = "file",
  })
end

function main()
  snacks_opt_tgg()
end

main()
