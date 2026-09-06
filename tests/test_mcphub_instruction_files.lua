local script_path = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p")
local repo_root = vim.fs.dirname(vim.fs.dirname(script_path))
local plugin_root = vim.env.MCPHUB_PLUGIN_ROOT

assert(plugin_root and plugin_root ~= "", "MCPHUB_PLUGIN_ROOT must point to a patched mcphub.nvim checkout")
vim.opt.runtimepath:prepend(plugin_root)

local assertions = 0
local function check(condition, message)
  assertions = assertions + 1
  assert(condition, message)
end

local function check_equal(actual, expected, message)
  assertions = assertions + 1
  assert(actual == expected, string.format("%s\nexpected: %q\nactual:   %q", message, expected, actual))
end

local function is_valid_utf8(value)
  local index = 1
  while index <= #value do
    local lead = value:byte(index)
    local sequence_length
    if lead < 0x80 then
      sequence_length = 1
    elseif lead >= 0xC2 and lead <= 0xDF then
      sequence_length = 2
    elseif lead >= 0xE0 and lead <= 0xEF then
      sequence_length = 3
    elseif lead >= 0xF0 and lead <= 0xF4 then
      sequence_length = 4
    else
      return false
    end
    if index + sequence_length - 1 > #value then
      return false
    end
    for offset = 1, sequence_length - 1 do
      local continuation = value:byte(index + offset)
      if continuation < 0x80 or continuation > 0xBF then
        return false
      end
    end
    index = index + sequence_length
  end
  return true
end

local warnings = {}
local current_config = {}
local current_source
local config_manager = {
  get_server_config = function()
    return current_config
  end,
  get_config_source = function()
    return current_source
  end,
  get_active_config_files = function()
    return { current_source }
  end,
}
local utils = {
  pretty_json = function(value)
    return value
  end,
  calculate_tokens = function(value)
    return math.ceil(#value / 4)
  end,
  format_token_count = tostring,
  format_relative_time = tostring,
  iso_to_relative_time = tostring,
  ms_to_relative_time = tostring,
}

package.loaded["mcphub.state"] = { config = { ui = { token_counts = {} } } }
package.loaded["mcphub.utils.config_manager"] = config_manager
package.loaded["mcphub.utils.log"] = {
  warn = function(message)
    table.insert(warnings, message)
  end,
  error = function(message)
    error(message)
  end,
}
package.loaded["mcphub.native"] = {}
package.loaded["mcphub.utils"] = utils
package.loaded["mcphub.utils.validation"] = {
  validate_inputSchema = function()
    return { ok = true }
  end,
}

local prompt = require("mcphub.utils.prompt")
local fixture_root = vim.fs.joinpath(repo_root, "tests", "fixtures", "mcphub-instructions")
local fixture_config = vim.fs.joinpath(fixture_root, "config", "mcphub.json")
local home = vim.fn.expand("~")
local tilde_file = vim.fs.joinpath(fixture_root, "home", "tilde.md")
check(tilde_file:sub(1, #home) == home, "tilde fixture must live below the current home directory")
local tilde_reference = "~" .. tilde_file:sub(#home + 1)
local default_header = "\n\n#### Instructions for `fixture` server\n\n"

local function body_for(config, source)
  current_config = { custom_instructions = config }
  current_source = source or fixture_config
  local rendered = prompt.format_custom_instructions("fixture")
  check(rendered:sub(1, #default_header) == default_header, "rendered instructions should use the server header")
  return rendered:sub(#default_header + 1)
end

check_equal(body_for({ text = "100% inline" }), "100% inline", "inline-only instructions stay compatible")
local legacy_inline = string.rep("i", 9000)
check_equal(
  body_for({ text = legacy_inline }),
  legacy_inline,
  "inline-only instructions should not inherit the new default file budget"
)

local merged = body_for({
  text = "INLINE_INSTRUCTION",
  files = { "relative.md", tilde_reference },
  max_bytes = 1024,
})
local inline_pos = assert(merged:find("INLINE_INSTRUCTION", 1, true))
local relative_pos = assert(merged:find("RELATIVE_FILE_INSTRUCTION", 1, true))
local tilde_pos = assert(merged:find("TILDE_FILE_INSTRUCTION", 1, true))
check(inline_pos < relative_pos and relative_pos < tilde_pos, "merge order should be inline, relative file, tilde file")

warnings = {}
prompt.clear_instruction_file_cache()
current_config = {
  custom_instructions = {
    files = { "relative.md", "missing.md" },
  },
}
current_source = fixture_config
local missing_ok, missing_rendered = pcall(prompt.format_custom_instructions, "fixture")
check(missing_ok, "missing instruction files must not crash prompt generation")
check(missing_rendered:find("RELATIVE_FILE_INSTRUCTION", 1, true) ~= nil, "readable files survive a missing sibling")
local second_server_ok = pcall(prompt.format_custom_instructions, "fixture-two")
local repeated_first_server_ok = pcall(prompt.format_custom_instructions, "fixture")
check(second_server_ok and repeated_first_server_ok, "shared missing paths must stay non-fatal across servers")
local warned_fixture = false
local warned_fixture_two = false
for _, warning in ipairs(warnings) do
  warned_fixture = warned_fixture or warning:find("for 'fixture'", 1, true) ~= nil
  warned_fixture_two = warned_fixture_two or warning:find("for 'fixture-two'", 1, true) ~= nil
end
check(
  #warnings == 2 and warned_fixture and warned_fixture_two,
  "each server should warn once for a shared missing path without A/B/A warning oscillation"
)

warnings = {}
prompt.clear_instruction_file_cache()
local capped = body_for({ text = "INLINE", files = { "relative.md" }, max_bytes = 12 })
check_equal(capped, "INLINE\n\nRELA", "the per-server cap includes separators and preserves inline-first priority")
check(#warnings == 1 and warnings[1]:find("truncated", 1, true) ~= nil, "custom caps should warn on truncation")

local temp_root = vim.fn.tempname()
vim.fn.mkdir(temp_root, "p")
local temp_config = vim.fs.joinpath(temp_root, "mcphub.json")
local large_file = vim.fs.joinpath(temp_root, "large.md")
vim.fn.writefile({ "{}" }, temp_config)
vim.fn.writefile({ string.rep("x", 9000) }, large_file, "b")
warnings = {}
prompt.clear_instruction_file_cache()
local original_io_open = io.open
local observed_read_sizes = {}
io.open = function(path, mode)
  local file, open_error = original_io_open(path, mode)
  if not file or path ~= large_file then
    return file, open_error
  end
  return {
    read = function(_, amount)
      table.insert(observed_read_sizes, amount)
      return file:read(amount)
    end,
    close = function()
      return file:close()
    end,
  }
end
local default_capped = body_for({ files = { "large.md" } }, temp_config)
check_equal(#default_capped, 8192, "the default combined instruction cap should be 8 KiB")
check(#warnings == 1 and warnings[1]:find("8192 bytes", 1, true) ~= nil, "default-cap truncation should warn")
warnings = {}
local smaller_cached = body_for({ files = { "large.md" }, max_bytes = 12 }, temp_config)
local larger_reread = body_for({ files = { "large.md" }, max_bytes = 8500 }, temp_config)
io.open = original_io_open
check_equal(smaller_cached, string.rep("x", 12), "a smaller request must not leak a larger cached prefix")
check_equal(#larger_reread, 8500, "a larger request should replace an overflowing smaller cache entry")
check_equal(#observed_read_sizes, 2, "a smaller request should reuse the bounded larger cache entry")
check_equal(observed_read_sizes[1], 8193, "default rendering should read only the needed prefix plus one byte")
check_equal(observed_read_sizes[2], 8501, "an expanded budget should reread only its prefix plus one byte")

local utf8_file = vim.fs.joinpath(temp_root, "utf8.md")
vim.fn.writefile({ "A😀B" }, utf8_file, "b")
warnings = {}
prompt.clear_instruction_file_cache()
local utf8_cut = body_for({ files = { "utf8.md" }, max_bytes = 4 }, temp_config)
local utf8_exact = body_for({ files = { "utf8.md" }, max_bytes = 5 }, temp_config)
check_equal(utf8_cut, "A", "file truncation should drop a partial multibyte codepoint")
check_equal(utf8_exact, "A😀", "a complete multibyte codepoint should fit at its byte boundary")
check(#utf8_cut <= 4 and #utf8_exact <= 5, "UTF-8-safe prefixes must stay within their byte budgets")
check(is_valid_utf8(utf8_cut) and is_valid_utf8(utf8_exact), "file-backed truncation must emit valid UTF-8")

local inline_unicode = "A😀B"
check_equal(body_for({ text = inline_unicode }), inline_unicode, "legacy inline-only Unicode should remain unchanged")
local inline_utf8_cut = body_for({ text = inline_unicode, max_bytes = 4 })
check_equal(inline_utf8_cut, "A", "explicit inline caps should also drop partial multibyte codepoints")
check(is_valid_utf8(inline_utf8_cut), "inline truncation must emit valid UTF-8")

local changing_file = vim.fs.joinpath(temp_root, "changing.md")
vim.fn.writefile({ "CACHE_OLD" }, changing_file, "b")
prompt.clear_instruction_file_cache()
local old_content = body_for({ files = { "changing.md" } }, temp_config)
vim.fn.writefile({ "CACHE_NEW_LONGER" }, changing_file, "b")
local new_content = body_for({ files = { "changing.md" } }, temp_config)
check(old_content:find("CACHE_OLD", 1, true) ~= nil, "initial cached content should render")
check(new_content:find("CACHE_NEW_LONGER", 1, true) ~= nil, "file metadata changes should invalidate cached content")

warnings = {}
prompt.clear_instruction_file_cache()
current_config = { custom_instructions = { disabled = true, files = { "missing.md" } } }
current_source = fixture_config
check_equal(prompt.format_custom_instructions("fixture"), "", "disabled instructions should render nothing")
check_equal(#warnings, 0, "disabled instructions should not read or warn about files")

current_config = { custom_instructions = { text = "INLINE", files = { "relative.md" }, max_bytes = 1024 } }
current_source = fixture_config
local server = {
  name = "fixture",
  status = "connected",
  description = "fixture server",
  capabilities = {
    resources = { { uri = "fixture://one", name = "fixture" } },
  },
}
local server_text = prompt.server_to_text(server)
check(server_text:find("RELATIVE_FILE_INSTRUCTION", 1, true) ~= nil, "server prompts should include file instructions")

package.loaded["mcphub.utils.nuiline"] = {}
package.loaded["mcphub.utils.text"] = { highlights = { muted = "" } }
package.loaded["mcphub.utils.constants"] = {}
package.loaded["mcphub.utils.prompt"] = prompt
local renderer = require("mcphub.utils.renderer")
check(renderer.has_custom_instructions({ text = "INLINE" }), "renderer should recognize inline instructions")
check(renderer.has_custom_instructions({ files = { "relative.md" } }), "renderer should recognize file-only instructions")
check(not renderer.has_custom_instructions({ files = {} }), "renderer should treat an empty file list as empty")
check(not renderer.has_custom_instructions(nil), "renderer should safely handle absent instructions")
current_config = { custom_instructions = { text = "INLINE" } }
local inline_tokens = renderer.estimate_server_tokens(server, current_config)
current_config = { custom_instructions = { text = "INLINE", files = { "relative.md" } } }
local file_tokens = renderer.estimate_server_tokens(server, current_config)
check(file_tokens > inline_tokens, "server token estimates should include loaded instruction files")

local validation = assert(loadfile(vim.fs.joinpath(plugin_root, "lua", "mcphub", "utils", "validation.lua")))()
local function validate(custom_instructions)
  return validation.validate_server_config("fixture", {
    command = "fixture-command",
    custom_instructions = custom_instructions,
  })
end
check(validate({ text = "inline", files = { "one.md" }, max_bytes = 1024 }).ok, "valid instruction config should pass")
check(not validate("invalid").ok, "custom_instructions must be an object")
check(not validate({ text = 42 }).ok, "custom_instructions.text must be a string")
check(not validate({ files = { named = "one.md" } }).ok, "custom_instructions.files must be an array")
check(not validate({ files = { "" } }).ok, "instruction file paths must be non-empty strings")
check(not validate({ max_bytes = 1.5 }).ok, "custom_instructions.max_bytes must be a positive integer")

vim.fn.delete(temp_root, "rf")
print(string.format("ok - mcphub instruction files (%d assertions)", assertions))
