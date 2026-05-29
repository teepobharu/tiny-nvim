# mdpreview — Fixture Index

Main showcase file. Open with `:MdPreview` from this directory.

---

## Headings

# H1
## H2
### H3
#### H4

---

## Text Formatting

**Bold**, _italic_, ~~strikethrough~~, `inline code`, and a [link](#links).

---

## Table

| Name      | Type    | Notes            |
|-----------|---------|------------------|
| index.md  | fixture | this file        |
| links.md  | fixture | link types       |
| images.md | fixture | image resolution |
| script.sh | code    | bash syntax hl   |

---

## Task List

- [x] Server starts on random port
- [x] SSE live reload on save
- [ ] Offline CDN vendor bundle

---

## Fenced Code Block

```lua
local function greet(name)
  return "Hello, " .. name .. "!"
end
print(greet("world"))
```

```json
{ "key": "value", "num": 42 }
```

---

## Links

See [links.md](./links.md) for all link-type tests.

---

## Images

See [images.md](./images.md) for image resolution tests.

---

## Nested file

See [deep](./sub/deep.md) for breadcrumb depth test.
