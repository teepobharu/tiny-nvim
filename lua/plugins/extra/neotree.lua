-- editor.lua in Lazy override
-- setup examples
-- https://github.com/LazyVim/LazyVim/blob/0e2eaa3fbad1519e9f4fb29235e13374f297ff00/lua/lazyvim/plugins/editor.lua#L43
-- open spectre search and live grep telescope : https://www.reddit.com/r/neovim/comments/17o6g2n/comment/k7wf2wp/?utm_source=share&utm_medium=web3x&utm_name=web3xcss&utm_term=1&utm_content=share_button
local Util = require("lazy.core.util")
local Path = require("utils.path")
local KeyUtils = require("utils.keyutil")
local key_f = KeyUtils.key_f
local key_g = KeyUtils.key_g

local isSnackEnabled = vim.g.enable_plugins and vim.g.enable_plugins.snacks == "yes"

function openGitRemote(state)
  local node = state.tree:get_node()
  -- __AUTO_GENERATED_PRINT_VAR_START__
  print([==[openGitRemote node:]==], vim.inspect(node)) -- __AUTO_GENERATED_PRINT_VAR_END__
  local path = node:get_id()
  local is_dir = node.type == "directory"
  -- // run git remote url command to get the remote and construct in table_is_empty(table_to_check)he browser ( make sure to support ssh )
  local current_file = path or vim.fn.expand("%:p")

  local urlPath = require("utils.git").get_remote_path()
  local mainBranch = require("utils.git").git_main_branch()
  local gitroot = require("utils.path").get_root_directory()
  local currentBranch = require("lazy.util").git_info(gitroot)
  local branch = ""
  vim.ui.select({
    "1. Main Branch",
    "2. Current Branch",
  }, { prompt = "Choose to open in browser:" }, function(choice)
    if choice then
      local i = tonumber(choice:sub(1, 1))
      if i == 1 then
        branch = mainBranch
      else
        branch = currentBranch
      end
    else
    end
  end)
  local fullUrl = "https://" .. gitDomain .. "/" .. current_file .. "/blob/" .. branch
  require("lazy.util").open(fullUrl)
end
--- Get options for file and grep operations based on the current state and type.

---@param state
---@param type "file" | "directory"
---@return table
function get_opts_for_files_and_grep(state, type)
  local node = state.tree:get_node()
  local filepath = node:get_id()
  local is_dir = node.type == "directory"
  local current_file_dir = vim.fn.fnamemodify(filepath, ":h")
  local cwdPath = is_dir and filepath or current_file_dir
  local extra_opts_list = node.type == "file" and { "-d=1" } or {}
  if type == "file" then
    table.insert(extra_opts_list, "-t=f")
  end
  local extra_opts = table.concat(extra_opts_list, " ") -- works on fzf not in telescope
  -- __AUTO_GENERATED_PRINT_VAR_START__
  print([==[get_opts_for_files_and_grep extra_opts:]==], vim.inspect(extra_opts)) -- __AUTO_GENERATED_PRINT_VAR_END__

  -- # fzf opt: https://github.com/ibhagwan/fzf-lua/wiki/Options
  return {
    current_file_dir = current_file_dir,
    cwdPath = cwdPath,
    extra_opts = extra_opts, -- fzf files
    extra_opts_list = extra_opts_list, -- telescope grep
    filepath = filepath,
  }
end

-- LazyVim : original neotree https://github.com/LazyVim/LazyVim/blob/1f8469a53c9c878d52932818533ce51c27ded5b6/lua/lazyvim/plugins/editor.lua#L23
return {
  -- file explorer
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    -- https://github.com/LazyVim/LazyVim/blob/b601ade71c7f8feacf62a762d4e81cf99c055ea7/lua/lazyvim/plugins/editor.lua
    -- original config: https://github.com/nvim-neo-tree/neo-tree.nvim?tab=readme-ov-file#quickstart
    cmd = "Neotree",
    init = function()
      -- FIX: use `autocmd` for lazy-loading neo-tree instead of directly requiring it,
      -- because `cwd` is not set up properly.
      vim.api.nvim_create_autocmd("BufEnter", {
        group = vim.api.nvim_create_augroup("Neotree_start_directory", { clear = true }),
        desc = "Start Neo-tree with directory",
        once = true,
        callback = function()
          if package.loaded["neo-tree"] then
            return
          else
            local stats = vim.uv.fs_stat(vim.fn.argv(0))
            if stats and stats.type == "directory" then
              require("neo-tree")
            end
          end
        end,
      })
    end,
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons", -- not strictly required, but recommended
      "MunifTanjim/nui.nvim",
      -- "3rd/image.nvim", -- Optional image support in preview window: See `# Preview Mode` for more information
    },
    keys = {
      {
        isSnackEnabled and "<leader>E" or "<leader>e",
        function()
          require("neo-tree.command").execute({ toggle = true, dir = Path.get_root_directory() })
        end,
        desc = "Explorer NeoTree (Root)",
      },
      {
        "<localleader>e",
        function()
          require("neo-tree.command").execute({ toggle = true, dir = Path.get_root_directory_current_buffer() })
        end,
        desc = "Explorer NeoTree (Root)",
      },
      {
        isSnackEnabled and "<localleader>E" or "<leader>E",
        function()
          require("neo-tree.command").execute({ toggle = true, dir = vim.fn.expand("%:p:h") })
        end,
        desc = "Explorer NeoTree (CWD)",
      },
      {
        "<leader>fE",
        function()
          -- %:p:h:h
          require("neo-tree.command").execute({ toggle = true, dir = vim.fn.expand("%:p:h") })
        end,
        desc = "NeoTree (CWD expand)",
      },
      {
        "<leader>fe",
        function()
          local curr_dir = Path.get_root_directory_current_buffer()
          if isSnackEnabled then
            local ok, err = pcall(Snacks.picker.explorer, {
              cwd = curr_dir,
              auto_close = true,
              layout = {
                -- preset = "vertical",
                preset = "sidebar",
                preview = false,
                -- to show the explorer to the right, add the below to
                -- your config under `opts.picker.sources.explorer`
                -- position = "right" ,
              },
              win = {
                list = {
                  keys = {
                    ["-"] = "explorer_up",
                  },
                },
              },
            })

            if not ok then
              vim.notify("Snacks Explorer: " .. err, vim.log.levels.ERROR)
              require("neo-tree.command").execute({ toggle = true, dir = Path.get_root_directory_current_buffer() })
            end
          else
            require("neo-tree.command").execute({ toggle = true, dir = Path.get_root_directory_current_buffer() })
          end
        end,
        desc = (isSnackEnabled and "Snack Explorer" or "NeoTree Explorer") .. "(Root)",
        -- desc = isSnackEnabled and "NeoTree Git root",
      },
      {
        "<leader>" .. key_g .. "e",
        function()
          require("neo-tree.command").execute({ source = "git_status", toggle = true })
        end,
        desc = "Git Explorer",
      },
      {
        "<leader>be",
        function()
          require("neo-tree.command").execute({ source = "buffers", toggle = true })
        end,
        desc = "Buffer Explorer",
      },
      {

        "<leader>" .. key_f .. "e",
        function()
          require("neo-tree.command").execute({ toggle = true, dir = Path.get_root_directory() })
        end,
        desc = "Explorer NeoTree (Root Dir)",
      },
      -- { "<leader>e", "<leader>fe", desc = "Explorer NeoTree (Root Dir)", remap = true },
      -- { "<leader>E", "<leader>fE", desc = "Explorer NeoTree (cwd)", remap = true },
    },
    -- { "<leader>e", "<leader>fe", desc = "Explorer NeoTree (Root Dir)", remap = true },
    -- { "<leader>E", "<leader>fE", desc = "Explorer NeoTree (cwd)", remap = true },
    deactivate = function()
      vim.cmd([[Neotree close]])
    end,
    opts = function(_, opts)
      -- lazyvim.nvim
      opts.open_files_do_not_replace_types = opts.open_files_do_not_replace_types
        or { "terminal", "Trouble", "qf", "Outline", "trouble" }
      table.insert(opts.open_files_do_not_replace_types, "edgy")
      -- use function to merge config (behiovr = force/override  )
      Util.merge(
        opts,
        -- lazy
        {
          sources = { "filesystem", "buffers", "git_status" },
          open_files_do_not_replace_types = { "terminal", "Trouble", "trouble", "qf", "Outline" },
          filesystem = {
            -- bind_to_cwd = false,
            bind_to_cwd = true, -- true creates a 2-way binding between vim's cwd and neo-tree's root
            follow_current_file = { enabled = true },
            use_libuv_file_watcher = true,
          },
          window = {
            mappings = {
              ["l"] = "open",
              ["h"] = "close_node",
              ["<space>"] = "none",
              ["Y"] = {
                function(state)
                  local node = state.tree:get_node()
                  local path = node:get_id()
                  vim.fn.setreg("+", path, "c")
                end,
                desc = "Copy Path to Clipboard",
              },
              ["O"] = {
                function(state)
                  require("lazy.util").open(state.tree:get_node().path, { system = true })
                end,
                desc = "Open with System Application",
              },
              ["P"] = { "toggle_preview", config = { use_float = false } },
            },
          },
          default_component_configs = {
            indent = {
              with_expanders = true, -- if nil and file nesting is enabled, will enable expanders
              expander_collapsed = "",
              expander_expanded = "",
              expander_highlight = "NeoTreeExpander",
            },
            git_status = {
              symbols = {
                unstaged = "󰄱",
                staged = "󰱒",
              },
            },
          },
        },
        ---- my part
        {
          commands = {
            openGitRemote = openGitRemote,
            copy_selector = function(state)
              local node = state.tree:get_node()
              local filepath = node:get_id()
              local filename = node.name
              local modify = vim.fn.fnamemodify

              local results = {
                filepath,
                modify(filepath, ":."),
                modify(filepath, ":~"),
                filename,
                modify(filename, ":r"),
                modify(filename, ":e"),
              }

              local options = {}
              table.insert(options, string.format("1 Path full   : %s", results[1]))
              table.insert(options, string.format("2 Path rel    : %s", results[2]))
              table.insert(options, string.format("3 Path ~      : %s", results[3]))

              if node.type == "file" then
                table.insert(options, string.format("4 File        : %s", results[4]))
                table.insert(options, string.format("5 File no ext : %s", results[5]))
              end

              vim.ui.select(options, { prompt = "Choose to copy to clipboard:" }, function(choice)
                if choice then
                  local i = tonumber(choice:sub(1, 1))
                  if i then
                    local result = results[i]
                    vim.fn.setreg("+", result)
                    vim.notify("Copied: " .. result .. " to vim clipboard")
                  else
                    vim.notify("Invalid selection")
                  end
                else
                  vim.fn.setreg("+", results[4])
                  vim.notify("Copied: " .. results[4] .. " to vim clipbard by default")
                end
              end)
            end,
            copy_file_name_current = function(state)
              local node = state.tree:get_node()
              local filename = node.name
              vim.fn.setreg('"', filename)
              vim.notify("Copied: " .. filename)
            end,
            copy_abs_file = function(state)
              local node = state.tree:get_node()
              local filepath = node:get_id()
              vim.fn.setreg('"', filepath)
              vim.notify("Copied: " .. filepath)
            end,
            telescope_livegrep_cwd = function(state)
              local opts = get_opts_for_files_and_grep(state, "file")
              -- __AUTO_GENERATED_PRINT_VAR_START__
              print([==[function#function opts:]==], vim.inspect(opts)) -- __AUTO_GENERATED_PRINT_VAR_END__
              -- fzf grep not work in live grep : https://www.reddit.com/r/neovim/comments/r74647/comment/hmx7i68/?utm_source=share&utm_medium=web2x&context=3
              require("telescope.builtin").live_grep({ cwd = opts.cwdPath, additional_args = opts.extra_opts })
            end,
            fzf_grep = function(state)
              local opts = get_opts_for_files_and_grep(state, "file")
              -- https://github.com/ibhagwan/fzf-lua/blob/main/lua/fzf-lua/providers/grep.lua
              -- print([==[function#function opts.cwdPath:]==], vim.inspect(opts)) -- __AUTO_GENERATED_PRINT_VAR_END__
              -- local search_paths =
              --   { opts.current_file_dir }, print([==[function#function search_paths:]==], vim.inspect(search_paths)) -- __AUTO_GENERATED_PRINT_VAR_END__
              require("fzf-lua").live_grep({
                cwd = opts.cwdPath,
                -- rg_opts = opts.extra_opts_list,
              })
            end,
            fzf_find_files = function(state)
              local opts = get_opts_for_files_and_grep(state, "file")
              require("fzf-lua").files({ cwd = opts.cwdPath, fd_opts = opts.extra_opts })
            end,
            telescope_find_files = function(state)
              local opts = get_opts_for_files_and_grep(state, "file")
              require("telescope.builtin").find_files({ cwd = opts.cwdPath })
            end,
            cd = function(state)
              local node = state.tree:get_node()
              local filepath = node:get_id()
              local cwdPath = vim.fn.fnamemodify(filepath, ":h")
              vim.notify("Changing directory to: " .. cwdPath)
              vim.cmd("cd " .. cwdPath)
            end,
            fzf_cd = function(state)
              local opts = get_opts_for_files_and_grep(state, "directory")
              require("fzf-lua").files({
                cwd = opts.cwdPath,
                fd_opts = "-t d",
                action = {
                  ["default"] = function(selected)
                    vim.notify("CD: Changing directory to: " .. selected, vim.log.levels.INFO)
                    vim.cmd("cd " .. selected)
                  end,
                  ["ctrl-s"] = function(selected)
                    vim.notify("LCD : Changing directory to: " .. selected, vim.log.levels.INFO)
                    vim.cmd("lcd " .. selected)
                  end,
                },
              })
            end,
          },
          -- https://github.com/nvim-neo-tree/neo-tree.nvim/discussions/370
          filesystem = {
            window = {
              width = 30,
              mappings = {
                ["l"] = "open",
                ["h"] = "close_node",
                ["<space>"] = "none",
                ["<Esc>"] = "clear_filter",
                ["/"] = "none",
                ["f"] = "none",
                ["ff"] = "fuzzy_finder",
                ["fF"] = "filter_on_submit",
                -- ["F"] = "filter_on_submit",
                ["Ff"] = "fzf_find_files",
                ["Fg"] = "fzf_grep",
                ["<tab>"] = "toggle_node",

                ["Y"] = {
                  function(state)
                    local node = state.tree:get_node()
                    local path = node:get_id()
                    vim.fn.setreg("+", path, "c")
                  end,
                  desc = "Copy Path to Clipboard",
                },

                ["O"] = {
                  function(state)
                    require("lazy.util").open(state.tree:get_node().path, { system = true })
                  end,
                  desc = "Open with System Application",
                },
                ["P"] = { "toggle_preview", config = { use_float = false } },
                -- custom binding
                ["YY"] = "copy_selector",
                ["go"] = "openGitRemote",
                ["Yp"] = "copy_file_name_current",
                ["YP"] = "copy_abs_file",
                ["Tg"] = "telescope_livegrep_cwd",
                ["Tf"] = "telescope_find_files",
                -- git copied from git mapping
                -- https://github.com/nvim-neo-tree/neo-tree.nvim/blob/main/README.md#L302
                ["gu"] = "git_unstage_file",
                ["ga"] = "git_add_file",
                ["gr"] = "git_revert_file",
                ["gc"] = "git_commit",
                ["Tc"] = "cd",
                ["TC"] = "fzf_cd",
              },
            },
          },
          buffers = {
            window = {
              mappings = {
                ["X"] = "buffer_delete",
              },
            },
          },
        }
      )
      return opts
    end,
    -- config = function(_, opts)
    --   -- local function on_move(data)
    --   --   LazyVim.lsp.on_rename(data.source, data.destination)
    --   -- end
    --
    --   -- local events = require("neo-tree.events")
    --   -- opts.event_handlers = opts.event_handlers or {}
    --   -- vim.list_extend(opts.event_handlers, {
    --   --   { event = events.FILE_MOVED, handler = on_move },
    --   --   { event = events.FILE_RENAMED, handler = on_move },
    --   -- })
    --   require("neo-tree").setup(opts)
    --   vim.api.nvim_create_autocmd("TermClose", {
    --     pattern = "*lazygit",
    --     callback = function()
    --       if package.loaded["neo-tree.sources.git_status"] then
    --         require("neo-tree.sources.git_status").refresh()
    --       end
    --     end,
    --   })
    -- end,
  },
}
