return {
  {
    "lewis6991/gitsigns.nvim",
    keys = {
      {
        "<leader>ghx",
        ":Gitsigns refresh<CR>",
        desc = "Gitsign Refresh All",
      },
      {
        "<leader>ghe",
        ":Gitsigns diffthis ",
        desc = "Gtisign Diff ..",
      },
      {
        "<leader>ghX",
        ":Gitsigns detach<CR>",
        desc = "Detach",
      },
      {
        "<leader>ghA",
        ":Gitsigns attach",
        desc = "Gitsigns Attach",
      },
      {
        "<leader>ghS",
        "<cmd>!git add %<CR>:Gitsigns detach<CR>:Gitsigns attach<CR>",
        desc = "$Git stage current",
      },
      {
        "<leader>ghM",
        function()
          -- WARNING: LSP  cwd can cause error pwd (example .ts in lua git project)= ~/ of project git root: /Users/tharutaipree/dotfiles/.config/nvim3_jelly_tinynvim
          local simpleCmdResult
          local function doStageSimple()
            -- Stage the current file using git
            local file = vim.fn.expand "%:p"
            local cmd = { "git", "add", file }
            simpleCmdResult = vim.fn.system(cmd)
            if vim.v.shell_error ~= 0 then
              return false
            end
            return true
          end
          if not doStageSimple() then
            -- __AUTO_GENERATED_PRINT_VAR_START__
            local dbg = require("utils.user_debug").dbg
            -- __AUTO_GENERATED_PRINT_VAR_START__
            local current_file = vim.fn.expand "%:p"
            local current_file_dir = vim.fn.fnamemodify(current_file, ":h")
            local git_root_buff = require("utils.mypath").get_root_directory_current_buffer()
            local pwdres = vim.fn.system({ "pwd" }):gsub("\n", "")

            dbg("pwd", pwdres)
            dbg([==[(anon) current_file:]==], vim.inspect(current_file)) -- __AUTO_GENERATED_PRINT_VAR_END__
            dbg("currfile", current_file)
            -- Check if current working directory is outside git root
            local extramsg
            if not git_root_buff or not vim.startswith(pwdres, git_root_buff) then
              vim.notify(
                "[WARN] Current directory is outside the git root: " .. (git_root_buff or "unknown"),
                vim.log.levels.WARN
              )
              return
            end
            -- approach =  -C to dir and add file this works
            -- works (most simple use current dir + current file (full))
            local cmd = { "git", "-C", current_file_dir, "add", current_file }
            dbg([==[#if cmd:]==], vim.inspect(cmd)) -- __AUTO_GENERATED_PRINT_VAR_END__
            -- TESTING here
            -- local cmd = {
            --   "git",
            --   "-C",
            --   "/Users/tharutaipree/dotfiles/.config/nvim3_jelly_tinynvim/lua",
            --   "add",
            --   "/Users/tharutaipree/dotfiles/.config/nvim3_jelly_tinynvim/test.ts",
            -- }
            local cmdresult = vim.fn.system(cmd)
            if vim.v.shell_error ~= 0 then
              vim.notify(
                "[ERROR] git add cmd " .. table.concat(cmd, " ") .. "also failed: " .. cmdresult,
                vim.log.levels.ERROR
              )
            else
              require("gitsigns").attach()
              Snacks.debug "git add : fallback succeeded"
            end
          end
        end,
        desc = "$GitFN stage current",
      },
      -- normally do not needed if staged it wil has gitsign
      -- {
      --   "<leader>ghU",
      --   "<cmd>!git restore --staged %<CR>:Gitsigns detach<CR>:Gitsigns attach<CR>",
      --   desc = "$Git unstage current",
      -- },
    },
  },
}
