local picker = require "utils.scratch_notes_picker"

local function eq(expected, actual, label)
  assert(vim.deep_equal(expected, actual), ("%s: expected %s, got %s"):format(
    label,
    vim.inspect(expected),
    vim.inspect(actual)
  ))
end

local function write(path, lines)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  assert(vim.fn.writefile(lines or { path }, path) == 0, "failed to write " .. path)
end

local function find_by_file(items, path)
  for _, item in ipairs(items) do
    if item.file == path then
      return item
    end
  end
  error("missing item for " .. path)
end

local test_root = vim.fn.tempname()
vim.fn.mkdir(test_root, "p")

local roots = {
  ["daily-work"] = vim.fs.joinpath(test_root, "work"),
  ["daily-personal"] = vim.fs.joinpath(test_root, "personal"),
  ["raw-notes"] = vim.fs.joinpath(test_root, "raw"),
  ["scratch-files"] = vim.fs.joinpath(test_root, "scratch"),
}
local opts = {
  roots = roots,
  date_ymd = "20260719",
  home = test_root,
  env = {},
}

local ok, err = pcall(function()
  eq("daily-work", picker.next_source "all", "all cycles to work")
  eq("daily-personal", picker.next_source "daily-work", "work cycles to personal")
  eq("raw-notes", picker.next_source "daily-personal", "personal cycles to raw")
  eq("scratch-files", picker.next_source "raw-notes", "raw cycles to scratch")
  eq("all", picker.next_source "scratch-files", "scratch cycles to all")
  eq("raw-notes", picker.normalize_source "raw", "source alias")

  local sources = picker.resolve_sources(opts)
  eq(vim.fs.joinpath(roots["daily-work"], "20260719", "user.md"), sources["daily-work"].today, "work today")
  eq(vim.fs.joinpath(roots["daily-personal"], "2026-07-19.md"), sources["daily-personal"].today, "personal today")
  eq(vim.fs.joinpath(roots["raw-notes"], "20260719_raw.md"), sources["raw-notes"].today, "raw today")

  local blank_override_sources = picker.resolve_sources {
    home = "   ",
    dotfiles_dir = "\t",
    roots = {
      ["daily-work"] = "",
      ["daily-personal"] = " ",
      ["raw-notes"] = "\t",
      ["scratch-files"] = "  ",
    },
    date_ymd = "20260719",
    env = {
      HOME = test_root,
      DOTFILES_DIR = "",
      SCRATCH_FZF_DAILY_WORK_ROOT = "",
      SCRATCH_FZF_DAILY_PERSONAL_ROOT = " ",
      SCRATCH_FZF_RAW_NOTES_ROOT = "\t",
      SCRATCH_FZF_SCRATCH_ROOT = "",
    },
  }
  eq(
    vim.fs.joinpath(test_root, "Documents", "daily"),
    blank_override_sources["daily-work"].root,
    "blank work overrides fall back below HOME"
  )
  eq(
    vim.fs.joinpath(test_root, "dotfiles", ".config", "myscripts", "scratch"),
    blank_override_sources["scratch-files"].root,
    "blank scratch overrides fall back below dotfiles"
  )
  assert(
    blank_override_sources["daily-work"].today:sub(1, #test_root) == test_root,
    "blank overrides must never produce a root-level daily target"
  )

  write(vim.fs.joinpath(roots["daily-work"], "20260718", "user.md"), { "work note" })
  write(vim.fs.joinpath(roots["daily-work"], "20260718", "ignore.txt"), { "ignored" })
  write(vim.fs.joinpath(roots["daily-work"], "too", "deep", "note.md"), { "too deep" })
  write(vim.fs.joinpath(roots["daily-personal"], "2026-07-18.md"), { "personal note" })
  write(vim.fs.joinpath(roots["raw-notes"], "20260718_raw.md"), { "raw note" })
  write(vim.fs.joinpath(roots["scratch-files"], "scratch.lua"), { "return true" })
  write(vim.fs.joinpath(roots["scratch-files"], "nested", "scratch.py"), { "print('ok')" })
  write(vim.fs.joinpath(roots["scratch-files"], "too", "deep", "scratch.sh"), { "echo no" })

  local work_items = picker.collect("daily-work", opts)
  eq(2, #work_items, "work includes today's target and one prior markdown note")
  eq(true, work_items[1].is_today, "today sorts first")
  eq(true, work_items[1].missing, "missing today target remains creatable")
  eq("20260718/user.md", work_items[2].relative, "work relative path")

  local scratch_items = picker.collect("scratch-files", opts)
  eq(2, #scratch_items, "scratch scan honors max depth")
  eq("scratch-files", scratch_items[1].scratch_source, "scratch source metadata")

  local all_items = picker.collect("all", opts)
  eq(8, #all_items, "all aggregates three today targets and five existing files")
  eq(true, all_items[1].is_today, "aggregate keeps daily targets first")
  eq(
    { roots["daily-work"], roots["daily-personal"], roots["raw-notes"], roots["scratch-files"] },
    picker.grep_dirs("all", opts),
    "all grep roots"
  )
  eq("*.md", picker.grep_glob("raw-notes", opts), "daily grep glob")
  eq(nil, picker.grep_glob("scratch-files", opts), "scratch grep accepts all files")

  local empty_root_scratch = vim.fs.joinpath(roots["scratch-files"], "empty.txt")
  local native_file = vim.fs.joinpath(test_root, "native", "scratch.lua")
  local native_empty = vim.fs.joinpath(test_root, "native", "empty.json")
  local native_cwd = vim.fs.joinpath(test_root, "project", "lua")
  write(empty_root_scratch, {})
  write(native_file, { "return 'native'" })
  write(native_empty, {})
  local native_opts = {
    roots = roots,
    date_ymd = "20260719",
    home = test_root,
    env = {},
    scratch_items = {
      {
        file = native_file,
        name = "Native Scratch",
        ft = "lua",
        branch = "feature/native",
        cwd = native_cwd,
        stat = vim.uv.fs_stat(native_file),
      },
      {
        file = native_empty,
        name = "Empty Scratch",
        ft = "json",
        stat = vim.uv.fs_stat(native_empty),
      },
      {
        file = native_file,
        name = "Duplicate Native Scratch",
        ft = "lua",
        stat = vim.uv.fs_stat(native_file),
      },
    },
  }
  local native_items = picker.collect("scratch-files", native_opts)
  eq(5, #native_items, "scratch source combines and deduplicates native entries with filesystem entries")
  eq(
    { roots["scratch-files"], vim.fs.dirname(native_file) },
    picker.grep_dirs("scratch-files", native_opts),
    "scratch grep includes the runtime-native scratch directory"
  )
  local native_item = find_by_file(native_items, native_file)
  eq(true, native_item.scratch_native, "native scratch keeps its metadata marker")
  eq("lua", native_item.scratch_ft, "native scratch keeps its filetype")
  eq("feature/native", native_item.scratch_branch, "native scratch keeps its branch")
  eq(native_cwd, native_item.scratch_cwd, "native scratch keeps its cwd")
  eq(
    "[scratch] [lua] [feature/native] [cwd:" .. vim.fn.fnamemodify(native_cwd, ":~") .. "]",
    picker.format_label(native_item),
    "native scratch labels stay compact while distinguishing metadata"
  )
  local filtered_native_items = picker.collect("scratch-files", vim.tbl_extend("force", native_opts, {
    show_empty_scratch = false,
  }))
  eq(3, #filtered_native_items, "empty filesystem and native scratch files hide together")
  assert(
    not pcall(find_by_file, filtered_native_items, native_empty),
    "empty native scratch file should be hidden when empty files are disabled"
  )
  assert(
    not pcall(find_by_file, filtered_native_items, empty_root_scratch),
    "empty filesystem scratch file should be hidden when empty files are disabled"
  )

  local raw_today, created = picker.create_today("raw-notes", opts)
  eq(sources["raw-notes"].today, raw_today, "raw create path")
  eq(true, created, "raw target created")
  assert(vim.fn.filereadable(raw_today) == 1, "raw target should exist")
  local _, created_again = picker.create_today("raw-notes", opts)
  eq(false, created_again, "existing daily target is not recreated")

  local no_path, create_error = picker.create_today("scratch-files", opts)
  eq(nil, no_path, "scratch source has no daily target")
  assert(type(create_error) == "string" and create_error:find("no daily note target", 1, true), "missing target error")

  local missing_opts = {
    roots = {
      ["daily-work"] = vim.fs.joinpath(test_root, "missing-work"),
      ["daily-personal"] = vim.fs.joinpath(test_root, "missing-personal"),
      ["raw-notes"] = vim.fs.joinpath(test_root, "missing-raw"),
      ["scratch-files"] = vim.fs.joinpath(test_root, "missing-scratch"),
    },
    date_ymd = "20260719",
    home = test_root,
    env = {},
  }
  eq(0, #picker.collect("scratch-files", missing_opts), "missing scratch root is empty")
  eq(3, #picker.collect("all", missing_opts), "missing daily roots still expose today's targets")
end)

vim.fn.delete(test_root, "rf")
assert(ok, err)
print "scratch_notes_picker tests: ok"
