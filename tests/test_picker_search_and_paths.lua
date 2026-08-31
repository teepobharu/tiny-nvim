vim.notify = function() end

local editor_keymaps = require "utils.editor_keymaps"
local code_ref = require "utils.code_ref"

local function eq(expected, actual, label)
  assert(vim.deep_equal(expected, actual), ("%s: expected %s, got %s"):format(
    label,
    vim.inspect(expected),
    vim.inspect(actual)
  ))
end

local filename_variants = code_ref.generate_path_variants("/tmp/project/lua/example.lua", { filename_only = true })
eq({ { label = "Filename", path = "example.lua", key = "filename" } }, filename_variants, "filename-only variant")

local git_status_keys = editor_keymaps.sources_n_keys.sources.git_status.win.input.keys
for _, key in ipairs { "Yy", "Yg", "Yp", "YP", "YY", "<M-y>" } do
  assert(git_status_keys[key], "git_status missing copy-path key " .. key)
end
eq("gitdiff_toggle_group", git_status_keys["<M-g>"][1], "git_status keeps diff toggle")

local function find_snacks_mapping(lhs)
  for _, mapping in ipairs(editor_keymaps.keymaps.snacks) do
    if mapping[1] == lhs then
      return mapping
    end
  end
  error("missing Snacks mapping " .. lhs)
end

local input = require "utils.input"
local old_visual_mode = input.is_visual_mode
local old_selected_lines = input.getSelectedLines
input.is_visual_mode = function()
  return true
end
input.getSelectedLines = function()
  return "picker_needle"
end

local captured = {}
local captured_buffers = {}
local buffers_closed = true
local old_snacks = rawget(_G, "Snacks")
_G.Snacks = {
  debug = function() end,
  picker = {
    files = function(opts)
      captured[#captured + 1] = opts
      return { closed = false }
    end,
    buffers = function(opts)
      captured_buffers[#captured_buffers + 1] = opts
      return { closed = buffers_closed }
    end,
  },
}

local snacks_actions = require "utils.snacks_actions"
local copied_registers = {}
local original_setreg = vim.fn.setreg
vim.fn.setreg = function(register, value)
  copied_registers[register] = value
end

local path_root = vim.fn.tempname()
local directory_path = path_root .. "/directory"
local file_path = directory_path .. "/note.lua"
vim.fn.mkdir(directory_path, "p")
vim.fn.writefile({ "return true" }, file_path)

snacks_actions.copy_dirpath_absolute(nil, { file = directory_path, dir = true })
eq(vim.fn.fnamemodify(directory_path, ":p"), copied_registers["+"], "directory item copies itself as absolute dirpath")

snacks_actions.copy_dirpath_relative_cwd(nil, { file = directory_path })
assert(
  copied_registers["+"]:match("directory$") ~= nil,
  "filesystem directory copies itself rather than its parent as a relative dirpath"
)

snacks_actions.copy_dirpath_absolute(nil, { file = file_path })
eq(
  vim.fn.fnamemodify(directory_path, ":p"):gsub("/$", ""),
  copied_registers["+"],
  "file item copies its parent as absolute dirpath"
)

vim.fn.setreg = original_setreg

find_snacks_mapping("<leader>ff")[2]()
find_snacks_mapping("<leader>fF")[2]()
local smart_buffer_mapping = find_snacks_mapping "<leader><space>"
assert(vim.tbl_contains(smart_buffer_mapping.mode, "x"), "buffer fallback must be reachable from visual mode")
smart_buffer_mapping[2]()

eq("picker_needle", captured_buffers[1].pattern, "visual smart picker seeds the buffer picker")
eq(3, #captured, "three non-live file picker entry points")
for index, opts in ipairs(captured) do
  eq("picker_needle", opts.pattern, "file picker " .. index .. " carries visible pattern")
  eq(nil, opts.search, "file picker " .. index .. " does not hide selection in search")
end

buffers_closed = false
input.is_visual_mode = function()
  return false
end
smart_buffer_mapping[2]()
eq(nil, captured_buffers[2].pattern, "normal smart picker keeps an empty buffer query")
eq(3, #captured, "normal smart picker does not trigger the files fallback while buffers remain open")

input.is_visual_mode = old_visual_mode
input.getSelectedLines = old_selected_lines
_G.Snacks = old_snacks

print "picker search and path tests: ok"
