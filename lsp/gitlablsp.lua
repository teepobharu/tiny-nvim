-- vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
-- 	pattern = "*.gitlab-ci*.{yml,yaml}",
-- 	callback = function()
-- 		vim.bo.filetype = "yaml.gitlab"
-- 	end,
-- })


vim.filetype.add({
  pattern = {
    -- Pattern matches filenames containing ".gitlab-ci.yml" or ".gitlab-ci.yaml"
    -- Examples: ".gitlab-ci.yml", ".gitlab-ci.yaml", "project.gitlab-ci.yml"
    -- Lua pattern breakdown:
    --   '.*': literal dot
    --   '%.': literal dot
    --   'gitlab': literal text
    --   '%-': literal hyphen
    --   'ci': literal text
    --   '%.': literal dot
    --   'ya?ml': matches "yaml" or "yml" (the 'a' is optional)
    ['.*%.gitlab%-ci%.ya?ml'] = 'yaml.gitlab',
  },
})

local cache_dir = vim.uv.os_homedir() .. '/.cache/gitlab-ci-ls/'

---@brief
---
--- https://github.com/alesbrelih/gitlab-ci-ls
--
-- Language Server for Gitlab CI
--
-- `gitlab-ci-ls` can be installed via cargo:
-- cargo install gitlab-ci-ls
return {
  cmd = { 'gitlab-ci-ls' },
  filetypes = { 'yaml.gitlab' },
  root_dir = function(bufnr, on_dir)
    local fdir = vim.api.nvim_buf_get_name(bufnr)
    -- return
    local dirpath = vim.fs.dirname(
      vim.fs.find(
        { ".gitlab-ci.yml", ".gitlab-ci.yaml", "*.gitlab-ci*.yml", "*.gitlab-ci*.yaml" },
        { upward = true, path = fdir }
      )[1])

    on_dir(dirpath)

    --   below is from lspconfig but requires util
    --   local fname = vim.api.nvim_buf_get_name(bufnr)
    -- on_dir(util.root_pattern('.gitlab*', '.git')(fname))
  end,
  init_options = {
    cache_path = cache_dir,
    log_path = cache_dir .. '/log/gitlab-ci-ls.log',
  },
}


-- local install
-- https://github.com/huyhoang8398/gitlab-lsp
-- return {
-- cmd = { "node", "/path/to/gitlab-lsp/dist/server.js", "--stdio" },
-- filetypes = { "yaml.gitlab" },
-- name = "gitlab_ci_lss",
-- root_dir = function(bufnr)
--   local fdir = vim.api.nvim_buf_get_name(bufnr)
--
--
--   return vim.fs.dirname(
--     vim.fs.find(
--       { ".gitlab-ci.yml", ".gitlab-ci.yaml", "*.gitlab-ci*.yml", "*.gitlab-ci*.yaml" },
--       { upward = true, path = fdir }
--     )[1])
-- end,

-- }
--
-- vim.api.nvim_create_autocmd("FileType", {
--   pattern = "yaml.gitlab",
--   callback = function()
--     vim.lsp.start({
--       name = "gitlab_ci_ls",
--       cmd = { "node", "/path/to/gitlab-lsp/dist/server.js", "--stdio" },
--       root_dir = vim.fs.dirname(
--         vim.fs.find(
--           { ".gitlab-ci.yml", ".gitlab-ci.yaml", "*.gitlab-ci*.yml", "*.gitlab-ci*.yaml" },
--           { upward = true }
--         )[1]
--       ),
--     })
--   end,
-- })
