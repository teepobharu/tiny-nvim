-- Blink.cmp icon customisation: AI provider kind_icons, minuet source_icon, source column in menu.
-- Lazy deep-merges this opts table with coding.lua; existing nerd_font_variant etc. survive.
-- kind_icons keys must match provider_options[provider].name (case-sensitive).
-- AGD slot uses name="AGD" — falls back to default glyph; add AGD="󱢆" below if desired.

return {
  "saghen/blink.cmp",
  opts = {
    appearance = {
      kind_icons = {
        Claude = "󰋦",
        OpenAI = "",
        Gemini = "",
        AGD = "",
        Ollama = "󰳆",
        ["llama.cpp"] = "󰳆",
        Openrouter = "󱂇",
        Codestral = "󱎥",
        Deepseek = "",
        Groq = "",
        ["Github Copilot"] = "",
      },
    },
    completion = {
      menu = {
        draw = {
          columns = {
            { "kind_icon", "label", gap = 1 },
            { "kind" },
            { "source_icon" },
          },
          components = {
            source_icon = {
              ellipsis = false,
              text = function(ctx)
                local map = {
                  minuet = "󱗻",
                  nvim_lsp = "",
                  lsp = "",
                  path = "",
                  buffer = "",
                  snippets = "",
                  luasnip = "",
                  async_path = "",
                  emoji = "",
                  git = "",
                  orgmode = "",
                  otter = "󰼁",
                }
                return map[ctx.source_id] or ""
              end,
              highlight = "BlinkCmpSource",
            },
          },
        },
      },
    },
  },
}
