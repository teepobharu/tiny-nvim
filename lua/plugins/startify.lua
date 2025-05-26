local map = vim.keymap.set

return {
	"mhinz/vim-startify",
	lazy = false,
	config = function()
		-- more settings example: https://github.com/mhinz/vim-startify/wiki/Example-configurations#show-modified-and-untracked-git-files

		local function gitModified()
      local files = vim.fn.systemlist("git ls-files -m 2>/dev/null")
      return vim.tbl_map(function(val) return { line = val, path = val } end, files)
    end

		local function gitUntracked()
			local files = vim.fn.systemlist("git ls-files -o --exclude-standard 2>/dev/null")
			return vim.tbl_map(function(val)
				return { line = val, path = val }
			end, files)
		end

		vim.g.startify_custom_header = {
			[[                                                                       ]],
			[[  ██████   █████                   █████   █████  ███                  ]],
			[[ ░░██████ ░░███                   ░░███   ░░███  ░░░                   ]],
			[[  ░███░███ ░███   ██████   ██████  ░███    ░███  ████  █████████████   ]],
			[[  ░███░░███░███  ███░░███ ███░░███ ░███    ░███ ░░███ ░░███░░███░░███  ]],
			[[  ░███ ░░██████ ░███████ ░███ ░███ ░░███   ███   ░███  ░███ ░███ ░███  ]],
			[[  ░███  ░░█████ ░███░░░  ░███ ░███  ░░░█████░    ░███  ░███ ░███ ░███  ]],
			[[  █████  ░░█████░░██████ ░░██████     ░░███      █████ █████░███ █████ ]],
			[[ ░░░░░    ░░░░░  ░░░░░░   ░░░░░░       ░░░      ░░░░░ ░░░░░ ░░░ ░░░░░  ]],
			[[                                                                       ]],
			[[                     λ it be like that sometimes λ                     ]],
		}

		vim.g.startify_session_dir = "~/.config/nvim/session"
		vim.g.startify_lists = {
			{ type = "sessions", header = { "   Sessions" } },
			{ type = "files", header = { "   Files" } },
			{ type = "dir", header = { "   Current Directory " .. vim.fn.getcwd() } },
			{ type = "bookmarks", header = { "   Bookmarks" } },
			{ type = gitModified, header = { "   Git ~ modified" } },
			{ type = gitUntracked, header = { "   Git ~ untracked" } },
			{ type = "commands", header = { "   Commands" } },
		}

		vim.g.startify_session_autoload = 1
		vim.g.startify_session_delete_buffers = 1
		vim.g.startify_change_to_vcs_root = 1
		vim.g.startify_fortune_use_unicode = 1
		vim.g.startify_session_persistence = 1

		vim.g.webdevicons_enable_startify = 1

		function StartifyEntryFormat()
			return vim.fn.WebDevIconsGetFileTypeSymbol(vim.fn.absolute_path()) .. " " .. vim.fn.entry_path()
		end

		vim.g.startify_bookmarks = {
			{ c = "~/.config" },
			{ i = "~/.config/nvimChad/nvim/init.lua" },
			{ z = "~/.zshrc" },
			{ t = "~/.tmux.conf" },
			{ b = "~/.bash_profile" },
			{ a = "~/.bash_aliases" },
			{ K = "~/.config/karabiner/karabiner.json" },
			-- { r = '~/.config/karabiner/assets/complex_modifications/capslock.json' },
			{ ["."] = "~/.config/nvimChad/nvim/plug-config/start-screen.vim" },
			{ p = "~/.config/nvimChad/nvim/vim-plug/plugins.vim" },
			{ w = "~/.config/nvim/keys/which-key.vim" },
			{ G = "~/AgodaGit" },
			{ ms = "~/AgodaGit/fe/mspa/Agoda.Mobile.Client/package.json" },
		}

		vim.g.startify_enable_special = 0

		local key_opts = { noremap = true, silent = true, desc = "Startify" }
		map("n", "<localleader>,", "<cmd>Startify<cr>", key_opts)
	end,
}
