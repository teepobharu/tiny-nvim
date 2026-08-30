local plugin_root = vim.env.CODECOMPANION_HISTORY_PLUGIN_ROOT
assert(plugin_root and plugin_root ~= "", "CODECOMPANION_HISTORY_PLUGIN_ROOT must point to a patched checkout")
vim.opt.runtimepath:prepend(plugin_root)

package.loaded["codecompanion.http"] = {}
package.loaded["codecompanion.config"] = {
  constants = {
    USER_ROLE = "user",
    LLM_ROLE = "llm",
  },
  interactions = {
    chat = {
      tools = {
        opts = { tool_replacement_message = "the ${tool} tool" },
        groups = {
          files = {
            prompt = "I'm giving you access to ${tools} to help you perform file operations",
            tools = { "create_file", "read_file", "grep_search" },
          },
        },
        read_file = { description = "Read a file" },
        grep_search = { description = "Search files" },
      },
    },
  },
}
package.loaded["codecompanion._extensions.history.log"] = {
  trace = function() end,
  error = function() end,
}
package.loaded["codecompanion.schema"] = {}

local TitleGenerator = require "codecompanion._extensions.history.title_generator"
local assertions = 0

local function check(condition, message)
  assertions = assertions + 1
  assert(condition, message)
end

local function check_contains(value, expected, message)
  check(value:find(expected, 1, true) ~= nil, message)
end

local function check_not_contains(value, unexpected, message)
  check(value:find(unexpected, 1, true) == nil, message)
end

local function new_generator(opts)
  local generator = TitleGenerator.new(vim.tbl_deep_extend("force", {
    auto_generate_title = true,
    title_generation_opts = {},
  }, opts or {}))
  generator._make_adapter_request = function(self, _, prompt, callback)
    self.captured_prompt = prompt
    callback("Mock Title")
  end
  return generator
end

local function generate(generator, chat, is_refresh)
  local callbacks = {}
  generator:generate(chat, function(title)
    callbacks[#callbacks + 1] = title
  end, is_refresh)
  return generator.captured_prompt or "", callbacks
end

local chat = {
  opts = {},
  messages = {
    {
      role = "user",
      content = "<rules>AGENTS.md</rules>",
      _meta = { tag = "rules" },
    },
    {
      role = "user",
      content = "<help>codecompanion-configuration-prompt-library</help>",
      context = { id = "help" },
    },
    {
      role = "user",
      content = "<buf>BUTLER-mem.md</buf>",
      opts = { _meta = { reference = "buffer" } },
    },
    {
      role = "user",
      content = "<rules>CLAUDE.md</rules>",
      opts = { context = { context_id = "nested-context" } },
    },
    {
      role = "user",
      content = "Make scratch picker labels compact",
      opts = { visible = true },
    },
    {
      role = "user",
      content = "<diag>untagged diagnostic dump</diag>",
      opts = { visible = false },
    },
  },
}

local initial = new_generator()
local initial_prompt, initial_callbacks = generate(initial, chat)
check(initial_callbacks[1] == "Deciding title...", "initial generation reports deciding state")
check(initial_callbacks[2] == "Mock Title", "initial generation reaches the adapter seam")
check_contains(initial_prompt, "Make scratch picker labels compact", "initial prompt keeps the user request")
check_not_contains(initial_prompt, "AGENTS.md", "top-level _meta context is excluded")
check_not_contains(initial_prompt, "codecompanion-configuration-prompt-library", "top-level context is excluded")
check_not_contains(initial_prompt, "BUTLER-mem.md", "nested opts._meta context is excluded")
check_not_contains(initial_prompt, "CLAUDE.md", "nested opts.context context is excluded")
check_not_contains(
  initial_prompt,
  "untagged diagnostic dump",
  "hidden (visible=false) line without tag or context id is excluded"
)

local refresh = new_generator {
  title_generation_opts = {
    refresh_every_n_prompts = 2,
    max_refreshes = 1,
  },
}
chat.opts = { title = "Old Title", title_refresh_count = 0 }
local should_refresh = refresh:should_generate(chat)
check(not should_refresh, "context rows do not count as user prompts for refresh scheduling")
chat.messages[#chat.messages + 1] = { role = "llm", content = "I will update the picker." }
chat.messages[#chat.messages + 1] = {
  role = "user",
  content = "Also show empty scratch files.",
  opts = { visible = true },
}
local should_generate, is_refresh = refresh:should_generate(chat)
check(should_generate and is_refresh, "two real user messages enable the configured refresh")
local refresh_prompt = generate(refresh, chat, true)
check_contains(refresh_prompt, "Make scratch picker labels compact", "refresh prompt keeps first real request")
check_contains(refresh_prompt, "Also show empty scratch files.", "refresh prompt keeps later real request")
check_not_contains(refresh_prompt, "AGENTS.md", "refresh prompt excludes rule context")
check_not_contains(refresh_prompt, "BUTLER-mem.md", "refresh prompt excludes buffer context")
check_not_contains(refresh_prompt, "untagged diagnostic dump", "refresh prompt excludes hidden context lines")

local string_prompt = new_generator {
  title_generation_opts = {
    prompt = "Use only the user's requested outcome.",
  },
}
chat.opts = {}
local custom_prompt = generate(string_prompt, chat)
check_contains(custom_prompt, "Use only the user's requested outcome.", "string title rules replace the default prompt")
check_contains(
  custom_prompt,
  "Conversation:\nUser: Make scratch picker labels compact",
  "string title rules receive filtered context"
)

local function_context
local function_prompt = new_generator {
  title_generation_opts = {
    prompt = function(context)
      function_context = context
      return "Function prompt: " .. context.conversation_context
    end,
  },
}
local generated_function_prompt = generate(function_prompt, chat)
check_contains(
  generated_function_prompt,
  "Function prompt: User: Make scratch picker labels compact",
  "function title rules control the final prompt"
)
check(
  function_context and not function_context.conversation_context:find("AGENTS.md", 1, true),
  "function title rules receive filtered context"
)

-- Picker annotations are inlined into genuine user message text ("the X tool",
-- "I'm giving you access to ...", "file `path` (with buffer number: N)"). When
-- the remainder is trivial (a greeting), the annotations are stripped so they
-- cannot dominate the title prompt.
local annotated_chat = {
  opts = {},
  messages = {
    {
      role = "user",
      content = "the read_file tool I'm giving you access to create_file, read_file, grep_search tools to help you perform file operations file `/x/y.lua` (with buffer number: 32)\nhi",
      opts = { visible = true },
    },
  },
}
local annotated_prompt = generate(new_generator(), annotated_chat)
check_contains(annotated_prompt, "User: hi", "trivial remainder keeps the greeting after stripping")
check_not_contains(
  annotated_prompt,
  "to help you perform file operations",
  "tool group prompt annotation is stripped for trivial messages"
)
check_not_contains(annotated_prompt, "the read_file tool", "tool replacement annotation is stripped")
check_not_contains(annotated_prompt, "with buffer number", "buffer note annotation is stripped")

-- A real request that mentions tools keeps its full text (strip guard).
local request_chat = {
  opts = {},
  messages = {
    {
      role = "user",
      content = "the read_file tool I'm giving you access to create_file, read_file, grep_search tools to help you perform file operations\nWhy does the grep_search tool return stale results after renaming files?",
      opts = { visible = true },
    },
  },
}
local request_prompt = generate(new_generator(), request_chat)
check_contains(
  request_prompt,
  "Why does the grep_search tool return stale results after renaming files?",
  "real request mentioning tools is kept unchanged"
)
check_contains(
  request_prompt,
  "to help you perform file operations",
  "non-trivial remainder keeps the original content intact"
)

print(("ok - CodeCompanion title prompt filtering (%d assertions)"):format(assertions))
