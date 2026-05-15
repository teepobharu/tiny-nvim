local prefix = "<leader>'"

return {
  -- fff.nvim - Fast fuzzy file finder with memory built-in
  -- A fast file picker for Neovim with frecency scoring, git integration,
  -- and multiple grep modes (plain, regex, fuzzy)

  -- Register FFF groups in which-key
  {
    "folke/which-key.nvim",
    optional = true,
    opts = {
      spec = {
        { prefix, group = "FFF", mode = { "n", "v" } },
        { "<leader><space>", group = "Find Files", mode = { "n", "v" } },
        { "<leader>/", group = "Grep", mode = { "n", "v" } },
      },
    },
  },

  {
    "dmtrKovalenko/fff.nvim",
    build = function()
      -- Download prebuilt binary or build from source using rustup
      require("fff.download").download_or_build_binary()
    end,
    opts = {
      prompt = "🪿 ",
      title = "FFF",
      max_results = 100,
      max_threads = 4,
      lazy_sync = true, -- Start syncing only when picker is open
      layout = {
        height = 0.8,
        width = 0.8,
        prompt_position = "bottom",
        preview_position = "right",
        preview_size = 0.5,
        flex = {
          size = 130,
          wrap = "top",
        },
        show_scrollbar = true,
        path_shorten_strategy = "middle_number",
      },
      preview = {
        enabled = true,
        max_size = 10 * 1024 * 1024,
        chunk_size = 8192,
        binary_file_threshold = 1024,
        line_numbers = false,
        cursorlineopt = "both",
        wrap_lines = false,
        filetypes = {
          svg = { wrap_lines = true },
          markdown = { wrap_lines = true },
          text = { wrap_lines = true },
        },
      },
      frecency = {
        enabled = true,
      },
      history = {
        enabled = true,
        min_combo_count = 3,
        combo_boost_score_multiplier = 100,
      },
      git = {
        status_text_color = false,
      },
      debug = {
        enabled = false,
        show_scores = false,
      },
      logging = {
        enabled = true,
        log_level = "info",
      },
      grep = {
        max_file_size = 10 * 1024 * 1024,
        max_matches_per_file = 100,
        smart_case = true,
        time_budget_ms = 150,
        modes = { "plain", "regex", "fuzzy" },
      },
    },
    keys = {
      -- FFF prefix group (<leader>')
      {
        prefix .. "f",
        function()
          require("fff").find_files()
        end,
        desc = "FFF find files",
      },
      {
        prefix .. "r",
        function()
          require("mini.extra").pickers.oldfiles()
        end,
        desc = "FFF recent files",
      },
      {
        prefix .. "g",
        function()
          require("fff").live_grep()
        end,
        desc = "FFF live grep",
      },
      {
        prefix .. "z",
        function()
          require("fff").live_grep {
            grep = {
              modes = { "fuzzy", "plain" },
            },
          }
        end,
        desc = "FFF fuzzy grep",
      },
      {
        prefix .. "c",
        function()
          require("fff").live_grep { query = vim.fn.expand "<cword>" }
        end,
        desc = "FFF search current word",
      },

      -- Default file picker keymaps (replaces mini.pick for these)
      {
        "<leader><space>",
        function()
          require("fff").find_files()
        end,
        desc = "Find Files",
      },
      {
        "<leader>fr",
        function()
          require("mini.extra").pickers.oldfiles()
        end,
        desc = "Recent Files",
      },
      {
        "<leader>/",
        function()
          require("fff").live_grep()
        end,
        desc = "Live Grep",
      },
      {
        "<leader>ff",
        function()
          require("fff").find_files()
        end,
        desc = "Find Files",
      },
      {
        "<C-e>",
        function()
          require("fff").find_files()
        end,
        desc = "Find Files (project)",
      },
      {
        "<leader>sw",
        function()
          require("fff").live_grep { query = vim.fn.expand "<cword>" }
        end,
        desc = "Search word under cursor",
      },
      {
        "<leader>fw",
        function()
          require("fff").live_grep { query = vim.fn.expand "<cword>" }
        end,
        desc = "Search word under cursor",
      },
      {
        "<leader>fw",
        function()
          local mode = vim.fn.mode()
          if mode == "v" or mode == "V" or mode == "\22" then
            local lines = vim.fn.getregion(vim.fn.getpos "v", vim.fn.getpos ".", { type = mode })
            vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
            local text = table.concat(lines, "\n")
            if text ~= "" then
              require("fff").live_grep { query = text }
            end
          end
        end,
        desc = "Search visual selection",
        mode = "v",
      },
    },
  },
}
