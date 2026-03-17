# Snippet authoring notes (LuaSnip + VS Code JSON)

This directory contains **VS Code-style JSON snippet files** (commonly loaded by LuaSnip via VS Code snippet loaders).

## Compatibility targets

- **Neovim (LuaSnip)**: parses _VS Code snippet syntax_ in the JSON `body`.
- **VS Code**: keep snippets compatible with builtin snippet parsing.

## Two parsing layers (the source of most bugs)

When you write a snippet body entry like `"console.log(...)"`, it passes through:

1. **JSON string escaping** (this repo file)
2. **Snippet expansion** (VS Code snippet syntax: `$1`, `${1:default}`, `${VAR}`)
3. **Runtime language parsing** (e.g. JavaScript/TypeScript, including template literals)

You must escape at the correct layer.

## JSON escaping (layer 1)

Inside a JSON string:

- `\"` emits a literal `"`.
- `\\\` emits a literal backslash `\`.
- Prefer multi-line snippets as an array of lines (as done here) so you avoid embedding `\n`.

## VS Code snippet syntax (layer 2)

### Tabstops / placeholders

- `$1`, `$2`, ...: tabstops
- `${1:default}`: tabstop with default
- `$0`: final cursor position

### Literal `$` in output

To output a literal dollar sign, escape it:

- `\\$`

### Variables

VS Code snippets support variables like `${TM_FILENAME}`.

- If you want that variable expanded by the snippet engine, use it unescaped.
- If you want it literally in the output, escape with double backslash `$` as `\\${TM_FILENAME}`.

## JavaScript template literals inside snippets (layer 3 vs layer 2)

JavaScript template literal interpolation is `${...}`.

But snippet engines also treat `$...` as special.

Rules of thumb:

- You want **JS interpolation at runtime** (keep `${...}` for JS): write `\${...}` in the snippet.
- You want **snippet placeholder/variable expansion**: write `${1:...}` or `${VAR}` (do **not** escape).

Example:

- Want to print runtime `caseNo` in JS: `` `Case: ${caseNo}` ``
- In the snippet body, write: `` `Case: \${caseNo}` ``

## Double-quoted JS strings/keys emitted from JSON

If your snippet emits JS like:

```js
{ "case": "basic" }
```

then the JSON line usually needs extra escaping:

```json
"  { \"case\": \"basic\" },"
```

## Important rule: runtime template-literal variables must be escaped

If the emitted code uses a runtime template literal like:

```js
`Value: ${x}`;
```

then inside a VS Code/LuaSnip snippet body you **must** escape the `$` so the snippet engine does not treat it as a tabstop/variable:

- write `` `Value: \\${x}` `` in the snippet body

This rule applies even if the snippet is stored in JSON strings (the JSON layer is separate; you still need the snippet-layer escape).

- Valid JSON snippet but **invalid emitted JS** (often missing commas in object literals).
- Accidentally escaping `$` so JS interpolation does not happen.
- Forgetting to escape `$` when you intended runtime JS interpolation, causing the snippet engine to treat it as a tabstop/variable.

## References

- LuaSnip help (local): `~/.local/share/$NVIM_APPNAME/lazy/LuaSnip/doc/luasnip.txt`
  - `:h luasnip-basics`
  - `:h luasnip-loaders`
  - `:h luasnip-troubleshooting`
- VS Code snippet syntax:
  - https://code.visualstudio.com/docs/editor/userdefinedsnippets#_snippet-syntax
- LuaSnip repository:
  - https://github.com/L3MON4D3/LuaSnip
