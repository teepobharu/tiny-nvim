---@brief
---
--- YAML Language Server
---
--- Provides YAML validation, completion, and hover support.
--- Works alongside gitlab-ci-ls for GitLab CI files.
---
--- Installation:
--- npm install -g yaml-language-server
---
--- For GitLab CI files (.gitlab-ci.yml), both yamlls and gitlab-ci-ls will attach:
--- - yamlls: General YAML syntax, folding, validation
--- - gitlab-ci-ls: GitLab CI-specific features and validation

-- related: https://github.com/neovim/nvim-lspconfig/blob/master/lsp/yamlls.lua
--
return {
  cmd = { "yaml-language-server", "--stdio" },
  -- filetypes = { "yaml", "yaml.gitlab" },
  filetypes = { "yaml" },
  -- more types
  -- filetypes = { 'yaml', 'yaml.docker-compose', 'yaml.gitlab', 'yaml.helm-values' },

  root_dir = function(bufnr, on_dir)
    local fname = vim.api.nvim_buf_get_name(bufnr)
    local dir =
      vim.fs.dirname(vim.fs.find({ ".git", ".gitlab-ci.yml", ".gitlab-ci.yaml" }, { upward = true, path = fname })[1])
    on_dir(dir)
  end,
  settings = {
    redhat = { telemetry = { enabled = false } },
    yaml = {
      -- schemas = {
      --   -- Add common YAML schemas here if needed
      --   -- For GitLab CI schema, gitlab-ci-ls handles this
      -- },
      format = {
        enable = true, -- default=false
      },
      -- validate = true,
      -- completion = true,
      -- hover = true,
    },
  },
  on_attach = function(client, bufnr)
    --- Disable autoformat on save for YAML files
    --- Uses the same flag as FormatDisable command
    --- Manual formatting still available via :lua vim.lsp.buf.format() or FormatEnable
    vim.b[bufnr].disable_autoformat = true

    -- Also disable the LSP formatting capabilities
    client.server_capabilities.documentFormattingProvider = false
    client.server_capabilities.documentRangeFormattingProvider = false
  end,
}
