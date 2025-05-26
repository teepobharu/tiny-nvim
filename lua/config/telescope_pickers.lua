local M = {}
local gitUtil = require("utils.git")
local pathUtil = require("utils.path")
M.telescope = {}

local get_git_pickers_fn = function()
  -- need here since once open fzf the current buffer will not be avail
  local file_path = vim.fn.expand("%:p")

  ---@param ref : string
  ---@param mode "file" | "commit"
  local open_remote = function(ref, mode)
    local isCommit = ref:match("^[0-9a-fA-F]+$") and (#ref == 7 or #ref == 40)
    local urlF = gitUtil.get_branch_url(ref, "file")
    local urlC = gitUtil.get_branch_url(ref, "commit")
    vim.fn.jobstart({ "open", urlF }, { detach = true })
    if not isCommit then
      vim.fn.setreg("+", urlF)
    else
      vim.fn.jobstart({ "open", urlC }, { detach = true })
    end
  end

  local function diff_ref(branch)
    vim.cmd("tabnew")
    vim.cmd("edit " .. file_path)
    vim.cmd("Gitsigns diffthis " .. branch)
  end

  local function get_branches_n_commits()
    local results = {}
    local local_branches =
      vim.fn.system("git branch | awk '/^*/{print; next} {print | \"sort\"}' | sed -E 's|.* ||' | uniq")
    local remote_branches = vim.fn.system("git branch --remote | sed -E 's|.* ||' | uniq")
    for branch in local_branches:gmatch("[^\r\n]+") do
      table.insert(results, { value = branch })
    end
    for branch in remote_branches:gmatch("[^\r\n]+") do
      table.insert(results, { value = branch })
    end
    -- Adding hash handle error exit skip adding if erorr
    local ok, main_branch = pcall(gitUtil.git_main_branch)
    local ok2, origin_commits = pcall(vim.fn.system, "git log --format='%H' origin/" .. main_branch)
    if ok and ok2 then
      for commit in origin_commits:gmatch("[^\r\n]+") do
        table.insert(results, { value = commit })
      end
    end
    return results
  end
  return {
    get_remote_branches_name = get_branches_n_commits,
    diff_ref = diff_ref,
    open_branch_url = open_remote,
  }
end

M.fzf = {}
M.fzf.pickers = {}
M.fzf.pickers.session_picker = function()
  local fzf = require("fzf-lua")
  local session_dir = vim.g.startify_session_dir or "~/.config/session"
  local results = {}

  for file in
    io.popen(
      "find " .. session_dir .. ' -maxdepth 1 -type f -name "[[:alpha:][:digit:]][[:alnum:]_]*" -exec basename {} +'
    )
      :lines()
  do
    table.insert(results, file)
  end

  fzf.fzf_exec(results, {
    prompt = "Startify Sessions> (c-s to save, c-x to delete) >",
    actions = {
      ["default"] = function(selected)
        local session = selected[1]
        vim.cmd("SLoad " .. session)
      end,
      ["ctrl-s"] = function(selected, opts)
        local session = opts.last_query or selected[1]
        if session == "" then
          session = vim.fn.input("Save Session As: ")
        end

        vim.cmd("SSave! " .. session)
        vim.notify("Session Saved: " .. session, vim.log.levels.INFO)
      end,
      ["ctrl-x"] = function(selected)
        local session = selected[1]
        local user_input = vim.fn.confirm("Confirm Delete Session " .. session, "yesno", 2)
        if user_input == 1 then
          vim.cmd("SDelete! " .. session)
          vim.notify("Session Deleted: " .. session, vim.log.levels.INFO)
        end
      end,
    },
  })
end

M.fzf.pickers.open_git_pickers = function()
  print("FZF PICKERS OPEN GIT PICKERS")
  local fn_list = get_git_pickers_fn()
  local fzf_lua = require("fzf-lua")
  local results = fn_list.get_remote_branches_name()
  -- transform { value = "x.."} => { "x", }
  results = vim.tbl_map(function(v)
    return v.value
  end, results)
  fzf_lua.fzf_exec(results, {
    prompt = "Open Branch URL (c-s to diff, c-y to copy url) >",
    actions = {
      ["default"] = function(selected)
        fn_list.open_branch_url(selected[1])
      end,
      ["ctrl-s"] = function(selected)
        fn_list.diff_ref(selected[1])
      end,
      ["ctrl-y"] = function(selected)
        local file_url = gitUtil.get_branch_url(selected[1], "file")
        vim.fn.setreg("+", file_url)
        vim.fn.setreg("c", gitUtil.get_branch_url(selected[1], "commit"))
        vim.fn.setreg("b", gitUtil.get_branch_url(selected[1], "branch"))
        vim.fn.setreg("f", gitUtil.get_branch_url(file_url))
        vim.notify("Copied and reg c,b,f (commit,file,branch)" .. file_url, vim.log.levels.INFO)
      end,
    },
  })
end

M.telescope.getPickers = function(opts)
  local conf = require("telescope.config").values
  local finders = require("telescope.finders")
  local pickers = require("telescope.pickers")
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local action_utils = require("telescope.actions.utils")

  local session_pickers = function()
    local session_dir = vim.g.startify_session_dir or "~/.config/session"
    -- Logic to handle session previews using the session directory
    -- You can customize this to display session information or previews
    -- Example: Display session files in the specified directory
    local results = {}
    --
    -- for file in io.popen('ls ' .. session_dir):lines() do
    -- find to format output as filename only not the full path
    --p[[:alnum:]_].*find $(pwd) -name '
    --for more format see man re_format
    -- [ ] enhance: add grep cd and "badd" in ~/.config/nvim/session  to see which files and base dir is used

    for file in
      io.popen(
        "find " .. session_dir .. ' -maxdepth 1 -type f -name "[[:alpha:][:digit:]][[:alnum:]_]*" -exec basename {} +'
      )
        :lines()
    do
      -- file that starts with alpahnumerical
      table.insert(results, { value = file })
    end

    -- add key map for loadding with SLoad when press C-enter
    -- actions.select_default:replace(function(prompt_bufnr)
    --  local entry = actions.get_selected_entry(prompt_bufnr)
    --  if entry this_offset_encoding
    --

    -- Return the results for display in Telescope
    return pickers
      .new(opts, {
        prompt_title = "Startify Sessions",
        attach_mappings = function(prompt_bufnr, map)
          actions.select_default:replace(function()
            local selection = action_state.get_selected_entry()

            if selection then
              vim.cmd("SLoad " .. selection.value)
            end
          end)
          map("i", "<C-CR>", function(_prompt_bufnr)
            local entry = action_state.get_selected_entry()
            if entry then
              vim.cmd("SLoad " .. entry.value)
            end
          end)

          local saveSession = function(_prompt_bufnr)
            local picker = action_state.get_current_picker(_prompt_bufnr)
            local firstMultiSelection = picker:get_multi_selection()[1]

            local current_line = action_state.get_current_line()
            -- trim right the current_line
            current_line = current_line:gsub("%s+$", "")

            local session_name = firstMultiselection or current_line

            if firstMultiSelection then
              print("Save session from first multi selected " .. firstMultiSelection.value)
            else
              print("Save session from input prompt .. " .. current_line)
            end

            if current_line ~= "" then
              vim.cmd("SSave! " .. session_name)
            end
          end

          map("i", "<C-s>", function()
            saveSession(prompt_bufnr)
          end)
          map("n", "<C-s>", function()
            saveSession(prompt_bufnr)
          end)
          map("n", "X", function()
            local entry = action_state.get_selected_entry()
            -- confirming

            local user_input = vim.fn.confirm("Confirm Delete Session" .. entry.value, "yesno", 2)
            if user_input == 1 then
              vim.cmd("SDelete! " .. entry.value)
              -- local picker = action_state.get_current_picker(_prompt_bufnr)
              -- picker.refresh()
            end
          end)

          --- end ---
          return true
        end,
        finder = finders.new_table({
          results = results,
          entry_maker = function(entry)
            return {
              display = entry.value,
              value = entry.value,
              ordinal = entry.value,
            }
          end,
        }),
        sorter = conf.generic_sorter(opts),
        -- })
      })
      :find()
    -- return require("telescope").register_extension{
    --   exports = { startify = session_picker }
    -- }
  end

  local git_branch_remote_n_diff_picker = function()
    local fn_list = get_git_pickers_fn()
    local get_remote_branches_name = fn_list.get_remote_branches_name
    local get_branch_url = gitUtil.get_branch_url
    local diff_ref = fn_list.diff_ref
    local open_branch_url = fn_list.open_branch_url
    local current_word = vim.fn.expand("<cword>")
    local hash = current_word
    -- hash should be at leat 7 characters and not more than 40
    local isHash = #hash >= 7 and #hash <= 40 and hash:match("^[0-9a-fA-F]+$")
    if not isHash then
      current_word = "origin/" .. gitUtil.git_main_branch()
    end
    return pickers
      .new(opts, {
        prompt_title = "Open Branch URL (c-s to diff, c-c to copy) >",
        default_text = current_word,
        finder = finders.new_table({
          results = get_remote_branches_name(),
          entry_maker = function(entry)
            return {
              display = entry.value,
              value = entry.value,
              ordinal = entry.value,
            }
          end,
        }),
        -- finder = finders.new_oneshot_job(preview_commands, conf.vimgrep_arguments),

        sorter = conf.generic_sorter(opts),
        attach_mappings = function(prompt_bufnr, map)
          actions.select_default:replace(function()
            local picker = action_state.get_current_picker(prompt_bufnr)
            local firstMultiSelection = picker:get_multi_selection()[1]
            local current_line = action_state.get_current_line()
            current_line = current_line:gsub("%s+$", "")
            local input_or_multi = firstMultiSelection or current_line
            local selection = action_state.get_selected_entry().value or input_or_multi

            if selection then
              open_branch_url(selection)
            end
          end)
          map("i", "<C-s>", function()
            local selection = action_state.get_selected_entry()
            if selection then
              diff_ref(selection.value)
            end
          end)
          map("i", "<CR>", function()
            local selection = action_state.get_selected_entry()
            if selection then
              open_branch_url(selection.value)
            end
          end)
          map("i", "<C-c>", function()
            local selection = action_state.get_selected_entry()
            if selection then
              local file_url = gitUtil.get_branch_url(selection.value, "file")
              vim.fn.setreg("+", file_url)
              vim.fn.setreg("c", gitUtil.get_branch_url(selection.value, "commit"))
              vim.fn.setreg("b", gitUtil.get_branch_url(selection.value, "branch"))
              vim.fn.setreg("f", file_url)
              vim.notify("Copied and reg c,b,f (commit,file,branch)" .. file_url, vim.log.levels.INFO)
            end
          end)
          return true
        end,
      })
      :find()
  end

  local test_pickers = function()
    local results = {
      { value = "test1" },
      { value = "test2" },
      { value = "test3" },
      { value = "start1" },
    }

    return pickers
      .new(opts, {
        prompt_title = "Test Picker",
        finder = finders.new_table({
          results = results,
          entry_maker = function(entry)
            return {
              display = entry.value,
              value = entry.value,
              ordinal = entry.value,
            }
          end,
        }),
        sorter = conf.generic_sorter(opts),
        attach_mappings = function(prompt_bufnr, map)
          actions.select_default:replace(function()
            local selection = action_state.get_selected_entry()

            if selection then
              print("Entered on : " .. selection.value)
            end
          end)
          map("i", "<C-s>", function(_prompt_bufnr)
            print("Saving")
            local entry = action_state.get_selected_entry()
            print("cursor entry = " .. entry.value)
            local picker = action_state.get_current_picker(_prompt_bufnr)
            print("===========DEBUG ===========")
            print("Get multi selection")
            local selections_multi = picker:get_multi_selection()
            local num_selections = table.getn(selections_multi)
            print(num_selections)
            print(vim.inspect(picker:get_multi_selection()))
            local firstMultiSelection = picker:get_multi_selection()[1]
            print(vim.inspect(firstMultiSelection))

            print("current line: " .. action_state.get_current_line())

            local prompt_bufnr2 = vim.api.nvim_get_current_buf()
            print(prompt_bufnr .. " _pbn: " .. _prompt_bufnr .. " pbuf2: " .. prompt_bufnr2)

            local current_line = action_state.get_current_line()
            -- trim right the current_line
            current_line = current_line:gsub("%s+$", "")

            print(" MAP SELECTION ")
            action_utils.map_selections(_prompt_bufnr, function(entry)
              print(entry.value)
            end)

            print(" MAP ENTRIES")
            action_utils.map_entries(prompt_bufnr2, function(entry, index, row)
              print(entry.value .. " idx:" .. index .. " row:" .. row)
            end)
          end)
          return true
        end,
      })
      :find()
  end

  return {
    session_pickers = session_pickers,
    test_pickers = test_pickers,
    git_branch_remote_n_diff_picker = git_branch_remote_n_diff_picker,
  }
end

return M
