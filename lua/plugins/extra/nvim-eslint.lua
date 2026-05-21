-- Enable ESLint LSP + eslint_d linter for JavaScript/TypeScript projects.
--
-- Enable by adding "nvim-eslint" to vim.g.enable_extra_plugins in .nvim-config.lua:
--   vim.g.enable_extra_plugins = {
--     "nvim-eslint",
--   }
--
-- Requires:
--   npm i -g vscode-langservers-extracted  (ESLint LSP)
--   npm i -g eslint_d                      (faster linter for nvim-lint)

local js_ts_fts = { "javascript", "typescript", "javascriptreact", "typescriptreact" }

return {
  -- Extend nvim-lint to add eslint_d for JS/TS files
  {
    "mfussenegger/nvim-lint",
    optional = true,
    config = function()
      local lint = require "lint"

      -- Add eslint_d linter config with args
      lint.linters.eslint_d = require("lint.util").wrap(lint.linters.eslint_d, function(diagnostic)
        if diagnostic.message:find "Error: Could not find config file" then
          return nil
        end
        return diagnostic
      end)

      -- Inject eslint_d into JS/TS filetypes
      for _, ft in ipairs(js_ts_fts) do
        local current = lint.linters_by_ft[ft] or {}
        if not vim.tbl_contains(current, "eslint_d") then
          table.insert(current, "eslint_d")
        end
        lint.linters_by_ft[ft] = current
      end
    end,
  },
  -- Enable ESLint LSP server
  {
    "folke/which-key.nvim",
    optional = true,
    init = function()
      vim.lsp.enable "eslint"
    end,
  },
}
