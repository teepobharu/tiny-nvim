-- Run headlessly with PATCHER_SOURCE pointing at the patched patcher.lua.
-- Tests only disposable clones; never restores or applies a daily plugin.
local config = vim.env.PATCH_TEST_CONFIG or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h")
local source = vim.env.PATCH_TEST_MCPHUB or (vim.fn.stdpath("data") .. "/lazy/mcphub.nvim")
local patcher = dofile(assert(vim.env.PATCHER_SOURCE, "Set PATCHER_SOURCE to the candidate patcher.lua"))
local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
local notices = {}
vim.notify = function(message, level) table.insert(notices, { message = message, level = level }) end
local function command(args)
  local result = vim.system(args, { text = true }):wait()
  assert(result.code == 0, table.concat(args, " ") .. "\n" .. result.stderr)
  return result.stdout
end
local function git(repo, ...)
  return command(vim.list_extend({ "git", "-C", repo }, { ... }))
end
local function read(path)
  local file = assert(io.open(path, "rb")); local text = file:read("*a"); file:close(); return text
end
local function write(path, text)
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
  local file = assert(io.open(path, "wb")); file:write(text); file:close()
end
local function fixture(name)
  local lazy = root .. "/" .. name .. "/lazy"
  vim.fn.mkdir(lazy, "p")
  local repo = lazy .. "/mcphub.nvim"
  command({ "git", "clone", "--shared", "--no-checkout", source, repo })
  git(repo, "checkout", "--detach", "163b3ad0caa3987e04e5b1d89bb89d230686d17b")
  return repo, { lazy_path = lazy, patches_path = root .. "/patches" }
end
local paths = vim.fn.glob(config .. "/patches/mcphub.nvim/*.patch", false, true)
table.sort(paths)
local patches = {}
for _, path in ipairs(paths) do
  local copy = root .. "/patches/mcphub.nvim/" .. vim.fn.fnamemodify(path, ":t")
  write(copy, read(path)); table.insert(patches, copy)
end
local expected = fixture("expected")
for _, path in ipairs(patches) do git(expected, "apply", "--ignore-space-change", path) end
local function manifest(repo)
  local hashes = {}
  for _, path in ipairs(vim.fn.glob(repo .. "/lua/**/*.lua", false, true)) do
    hashes[path:sub(#repo + 2)] = vim.fn.sha256(read(path))
  end
  return hashes
end
local full_tree = manifest(expected)
local function assert_full(repo) assert(vim.deep_equal(full_tree, manifest(repo)), "Lua tree differs from the full patch stack") end
local function assert_clean(repo)
  assert(git(repo, "status", "--porcelain", "--untracked-files=no") == "", "Tracked changes remain after restore/rollback")
  assert(vim.fn.filereadable(repo .. "/lua/mcphub/ui/views/agent_settings.lua") == 0)
  assert(vim.fn.filereadable(repo .. "/lua/mcphub/ui/build_info.lua") == 0)
end
local passed = 0
local function test(name, callback)
  callback(); passed = passed + 1; print("PASS " .. name)
end

test("two LazyCheck restore/apply cycles and an idempotent manual apply", function()
  local repo, opts = fixture("cycles")
  write(repo .. "/keep-unrelated.txt", "user-owned\n")
  assert(patcher.apply_all(opts)); assert_full(repo)
  patcher.create_group_and_cmd(opts)
  for _ = 1, 2 do
    vim.api.nvim_exec_autocmds("User", { pattern = "LazyCheckPre" })
    assert_clean(repo)
    vim.api.nvim_exec_autocmds("User", { pattern = "LazyCheck" })
    assert_full(repo)
  end
  assert(patcher.apply_all(opts)); assert_full(repo)
  assert(read(repo .. "/keep-unrelated.txt") == "user-owned\n")
end)

test("recovers the observed partial stack with exact orphan files", function()
  local repo, opts = fixture("observed")
  for _, path in ipairs(patches) do
    local name = vim.fn.fnamemodify(path, ":t")
    if not name:match("^08%-") and not name:match("^16%-") then git(repo, "apply", "--ignore-space-change", path) end
  end
  for _, relative in ipairs({ "lua/mcphub/ui/views/agent_settings.lua", "lua/mcphub/ui/build_info.lua" }) do
    write(repo .. "/" .. relative, read(expected .. "/" .. relative))
  end
  assert(patcher.apply_all(opts)); assert_full(repo)
end)

test("recovers legacy git-restore leftovers on an otherwise clean baseline", function()
  local repo, opts = fixture("legacy")
  for _, path in ipairs(patches) do git(repo, "apply", "--ignore-space-change", path) end
  git(repo, "restore", "--", "lua") -- deliberately reproduce the old bug, fixture only
  assert(patcher.apply_all(opts)); assert_full(repo)
end)

test("refuses an unknown patch-created file without overwriting it", function()
  local repo, opts = fixture("unknown")
  local relative = "/lua/mcphub/ui/views/agent_settings.lua"
  write(repo .. relative, "-- user-owned content\n")
  local before = manifest(repo)
  assert(not patcher.apply_all(opts))
  assert(read(repo .. relative) == "-- user-owned content\n")
  assert(vim.deep_equal(before, manifest(repo)))
end)

test("stops at patch 08 without modifying the installed repository", function()
  local repo, opts = fixture("forced-failure")
  write(repo .. "/keep-unrelated.txt", "keep me\n")
  local original = patcher.apply_patch
  local visited = {}
  patcher.apply_patch = function(name, ...)
    table.insert(visited, name)
    if name:find("/08%-") then return false end
    return original(name, ...)
  end
  assert(not patcher.apply_all(opts))
  patcher.apply_patch = original
  for _, name in ipairs(visited) do assert(not name:find("/16%-"), "Applied a patch after failure") end
  assert_clean(repo)
  assert(read(repo .. "/keep-unrelated.txt") == "keep me\n")
end)

test("nested LazySync events produce the full stack", function()
  local repo, opts = fixture("nested")
  assert(patcher.apply_all(opts))
  patcher.create_group_and_cmd(opts)
  for _, event in ipairs({ "LazySyncPre", "LazyUpdatePre", "LazyUpdate", "LazySync" }) do
    vim.api.nvim_exec_autocmds("User", { pattern = event })
  end
  assert_full(repo)
end)

test("self-patching lifecycle keeps safety code across two cycles", function()
  local repo, opts = fixture("self-patch")
  local patcher_repo = opts.lazy_path .. "/lazy-local-patcher.nvim"
  command({ "git", "clone", "--shared", "--no-checkout", assert(vim.env.PATCH_TEST_PATCHER), patcher_repo })
  git(patcher_repo, "checkout", "--detach", "cb51ac5cee94c1a5bfef5d55846dc484652f38b9")
  write(root .. "/patches/lazy-local-patcher.nvim/01-reversible-stack-restore_v1.patch",
    read(config .. "/patches/lazy-local-patcher.nvim/01-reversible-stack-restore_v1.patch"))
  assert(patcher.apply_all(opts)); assert_full(repo)
  patcher.create_group_and_cmd(opts)
  for _ = 1, 2 do
    vim.api.nvim_exec_autocmds("User", { pattern = "LazyCheckPre" })
    assert_clean(repo)
    assert(git(patcher_repo, "status", "--porcelain") == "")
    vim.api.nvim_exec_autocmds("User", { pattern = "LazyCheck" })
    assert_full(repo)
    assert(read(patcher_repo .. "/lua/lazy-local-patcher/patcher.lua") == read(vim.env.PATCHER_SOURCE))
  end
end)

vim.fn.delete(root .. "/patches/lazy-local-patcher.nvim", "rf")

test("failed manual apply leaves a fully patched repository byte-for-byte unchanged", function()
  local repo, opts = fixture("conflicting-full-stack")
  assert(patcher.apply_all(opts))
  local generated = repo .. "/lua/mcphub/ui/views/agent_settings.lua"
  write(generated, read(generated) .. "\n-- user edit; keep every other patch too\n")
  local before = manifest(repo)
  assert(not patcher.apply_all(opts), "Expected apply to refuse modified generated file")
  assert(vim.deep_equal(before, manifest(repo)), "Refused restore removed other patches before discovering the conflict")
end)

test("one failed repository does not leave a successfully restored plugin unpatched", function()
  local repo, opts = fixture("mixed-repositories")
  local other = opts.lazy_path .. "/lazy-local-patcher.nvim"
  command({ "git", "clone", "--shared", "--no-checkout", assert(vim.env.PATCH_TEST_PATCHER), other })
  git(other, "checkout", "--detach", "cb51ac5cee94c1a5bfef5d55846dc484652f38b9")
  write(root .. "/patches/lazy-local-patcher.nvim/01-reversible-stack-restore_v1.patch",
    read(config .. "/patches/lazy-local-patcher.nvim/01-reversible-stack-restore_v1.patch"))
  assert(patcher.apply_all(opts))
  local expected_patcher = read(other .. "/lua/lazy-local-patcher/patcher.lua")
  local generated = repo .. "/lua/mcphub/ui/views/agent_settings.lua"
  write(generated, read(generated) .. "\n-- user edit\n")
  patcher.create_group_and_cmd(opts)
  vim.api.nvim_exec_autocmds("User", { pattern = "LazyCheckPre" })
  vim.api.nvim_exec_autocmds("User", { pattern = "LazyCheck" })
  assert(read(other .. "/lua/lazy-local-patcher/patcher.lua") == expected_patcher,
    "A failure in MCPHub left the patcher plugin restored to its unsafe unpatched upstream implementation")
end)
vim.fn.delete(root .. "/patches/lazy-local-patcher.nvim", "rf")

test("orphan recovery never moves a file outside the repository through a symlink", function()
  local repo, opts = fixture("symlink-boundary")
  local outside = root .. "/outside-user-directory"
  vim.fn.mkdir(outside, "p")
  write(outside .. "/file.txt", "known content\n")
  assert(vim.uv.fs_symlink(outside, repo .. "/generated"))
  local own_patches = root .. "/symlink-patches"
  write(own_patches .. "/mcphub.nvim/01-generated.patch", table.concat({
    "diff --git a/generated/file.txt b/generated/file.txt", "new file mode 100644",
    "--- /dev/null", "+++ b/generated/file.txt", "@@ -0,0 +1 @@", "+known content", "",
  }, "\n"))
  opts.patches_path = own_patches
  assert(not patcher.apply_all(opts), "Git should reject applying a patch beyond the symlink")
  assert(vim.fn.filereadable(outside .. "/file.txt") == 1,
    "Orphan recovery moved an external user file through a symlink")
  assert(read(outside .. "/file.txt") == "known content\n")
end)

test("legacy orphan recovery works when git hides untracked files", function()
  local repo, opts = fixture("hidden-untracked")
  for _, path in ipairs(patches) do git(repo, "apply", "--ignore-space-change", path) end
  git(repo, "restore", "--", "lua")
  git(repo, "config", "status.showUntrackedFiles", "no")
  assert(patcher.apply_all(opts), "Hidden untracked orphans bypass recovery and block patch 08")
  assert_full(repo)
end)

test("a failed commit restores the original files and permissions", function()
  local repo, opts = fixture("commit-failure")
  local before = manifest(repo)
  local modes = {}
  for relative in pairs(before) do modes[relative] = vim.uv.fs_stat(repo .. "/" .. relative).mode end
  local rename = vim.uv.fs_rename
  local injected = false
  vim.uv.fs_rename = function(from, to)
    if not injected and to == vim.uv.fs_realpath(repo) .. "/lua/mcphub/hub.lua" then
      injected = true
      return nil, "injected write failure"
    end
    return rename(from, to)
  end
  local ok = patcher.apply_all(opts)
  vim.uv.fs_rename = rename
  assert(injected and not ok, "Commit failure did not reach the transaction boundary")
  assert(vim.deep_equal(before, manifest(repo)), "Commit rollback lost original bytes")
  for relative, mode in pairs(modes) do assert(vim.uv.fs_stat(repo .. "/" .. relative).mode == mode) end
  assert_clean(repo)
end)

test("a concurrent edit during preflight is preserved without applying other files", function()
  local repo, opts = fixture("concurrent-edit")
  local relative = "lua/mcphub/ui/views/main.lua"
  local edited = read(repo .. "/" .. relative) .. "\n-- concurrent user edit\n"
  local before = manifest(repo)
  before[relative] = vim.fn.sha256(edited)
  local apply = patcher.apply_patch
  local injected = false
  patcher.apply_patch = function(...)
    if not injected then write(repo .. "/" .. relative, edited); injected = true end
    return apply(...)
  end
  local ok = patcher.apply_all(opts)
  patcher.apply_patch = apply
  assert(injected and not ok)
  assert(vim.deep_equal(before, manifest(repo)), "Concurrent edit or other original files were overwritten")
end)

test("staged user changes remain untouched", function()
  local repo, opts = fixture("staged-edit")
  local relative = "lua/mcphub/hub.lua"
  write(repo .. "/" .. relative, read(repo .. "/" .. relative) .. "\n-- staged user edit\n")
  git(repo, "add", "--", relative)
  local before = manifest(repo)
  local staged = git(repo, "diff", "--cached", "--binary")
  assert(not patcher.apply_all(opts))
  assert(vim.deep_equal(before, manifest(repo)))
  assert(git(repo, "diff", "--cached", "--binary") == staged)
end)

test("a nested non-repository path never modifies its parent repository", function()
  local repo = fixture("parent-repository")
  local before = manifest(repo)
  vim.fn.mkdir(repo .. "/nested", "p")
  assert(not patcher.restore_repo("nested", repo .. "/nested", patches))
  assert(vim.deep_equal(before, manifest(repo)))
end)

test("first install patches a repository absent during the pre-event", function()
  local repo, opts = fixture("first-install")
  local saved = repo .. "-saved"
  assert(vim.uv.fs_rename(repo, saved))
  patcher.create_group_and_cmd(opts)
  vim.api.nvim_exec_autocmds("User", { pattern = "LazyInstallPre" })
  assert(vim.uv.fs_rename(saved, repo))
  vim.api.nvim_exec_autocmds("User", { pattern = "LazyInstall" })
  assert_full(repo)
end)

test("successful apply preserves private permissions on existing files", function()
  local repo, opts = fixture("permissions")
  local path = repo .. "/lua/mcphub/hub.lua"
  assert(vim.uv.fs_chmod(path, 384)) -- 0600, Git does not track these bits
  assert(patcher.apply_all(opts)); assert_full(repo)
  assert(bit.band(vim.uv.fs_stat(path).mode, 511) == 384, "Apply broadened private file permissions")
end)

test("explicit executable-mode patches respect private access", function()
  local repo, opts = fixture("executable-mode")
  local path = repo .. "/lua/mcphub/hub.lua"
  assert(vim.uv.fs_chmod(path, 384))
  local own_patches = root .. "/mode-patches"
  write(own_patches .. "/mcphub.nvim/01-mode.patch", table.concat({
    "diff --git a/lua/mcphub/hub.lua b/lua/mcphub/hub.lua",
    "old mode 100644", "new mode 100755", "",
  }, "\n"))
  opts.patches_path = own_patches
  assert(patcher.apply_all(opts))
  assert(bit.band(vim.uv.fs_stat(path).mode, 511) == 448, "Executable patch broadened private access") -- 0700
  assert(patcher.restore_all(opts))
  assert(bit.band(vim.uv.fs_stat(path).mode, 511) == 384, "Reverse did not restore private non-executable mode")
end)

print(string.format("%d/%d patch lifecycle tests passed; fixtures: %s", passed, passed, root))
vim.cmd("qa!")
