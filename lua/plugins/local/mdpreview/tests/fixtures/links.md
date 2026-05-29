# Link Types — Test Fixture

Tests for S5 (link navigation) and S9 (history).

---

## Relative MD links

- [index.md (same dir)](./index.md)
- [deep.md (subdirectory)](./sub/deep.md)
- [code_samples.md](./code_samples.md)

---

## Relative code / text links

- [script.sh — bash](./script.sh)
- [long_lines.txt — plain text](./long_lines.txt)

---

## Git-root-relative links

These resolve via ASSET_ROOTS fallback (CWD / git root):

- [myMdPreview.lua](lua/plugins/extra/myMdPreview.lua)
- [server.lua](lua/plugins/local/mdpreview/lua/mdpreview/server.lua)

---

## External links (open new tab)

- [GitHub](https://github.com)
- [highlight.js](https://highlightjs.org)

---

## Fragment anchor (in-page jump)

- [Jump to relative MD links](#relative-md-links)

---

## Binary links (open via /asset in new tab)

- [sample image](./sample.png)

---

## Back navigation test

After clicking any link above, use the browser back button to return here.
