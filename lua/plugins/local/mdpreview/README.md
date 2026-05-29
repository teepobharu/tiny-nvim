# mdpreview.nvim

Local Neovim plugin — render `.md` files in browser with multi-renderer toggle,
live reload via SSE, local asset serving, in-app link/code preview, breadcrumb
navigation, and a searchable file tree.

## How It Works

1. `:MdPreview` starts a `vim.uv` TCP server on a random port (`127.0.0.1:<port>`)
2. Browser opens at `http://127.0.0.1:<port>/`
3. Browser fetches raw `.md` from `/md?path=<abs>` — fresh disk read on every fetch
4. After render, JS rewrites relative/absolute `<img src>` → `/asset?path=<abs>`
5. Relative/absolute `<a href>` to local text/code files → intercepted, opened in-app
6. `BufWritePost *.md` autocmd → SSE push `event: reload` → browser auto-refetches
7. `:MdPreviewStop` shuts down server, clears autocmd, closes SSE clients

## Commands

| Command | Description |
|---------|-------------|
| `:MdPreview` | Start server, discover files (current buffer's siblings or CWD glob), open browser |
| `:MdPreview <file...>` | Start server with explicit file list |
| `:MdPreviewStop` | Stop server |
| `<leader>Mh` | Same as bare `:MdPreview` |

## File Discovery (no args)

| Condition | Files loaded |
|-----------|-------------|
| Current buffer is `.md` | All `.md` siblings in same directory |
| Current buffer is non-`.md` | All `**/*.md` under CWD (capped at 50) |
| Args provided | Explicit paths only |

Initial active file = current buffer if in list, else first.

## Routes

| Route | Returns | Notes |
|-------|---------|-------|
| `GET /` | HTML page | Full UI |
| `GET /md?path=<abs>` | Raw `.md` text | Fresh disk read each request |
| `GET /asset?path=<abs>` | Binary/text file w/ MIME | Images, code, etc. |
| `GET /ls?path=<abs>` | JSON `{dirs, files}` | Directory listing for tree panel |
| `GET /events` | SSE stream | Pushes `event: reload` after `BufWritePost` |

## UI Overview

### Header (sticky)

```
[ MD Preview ]  [☰ hide]  [☀︎ dark]
[ code toolbar — visible in code view only             ]
[ File: btn btn btn … ]
[ Renderer: Code  markdown-it  marked  showdown  … ]
[ /path/to/current/file.md  (breadcrumb)             ]
[ status text                                         ]
```

### Renderer row

| Button | Behaviour |
|--------|-----------|
| `Code` | Toggle between code view and MD renderer for any file. Active (lit) when in code view. |
| `markdown-it` … `commonmark` | Select MD renderer. Clicking while in code view switches file to MD with that renderer. |

### Code view toolbar (header, code view only)

| Button | Action |
|--------|--------|
| `#` | Line numbers on/off (hljs + line numbers work simultaneously) |
| `↵` | Wrap long lines |
| `Copy` | Copy raw text to clipboard (`Success:` status in green) |

State persisted in `localStorage` across sessions.

## File View Modes

Every file has a **default mode** derived from its extension:

| File type | Default mode |
|-----------|-------------|
| `.md`, `.markdown`, `.mkd`, `.mmd` | MD renderer |
| All other text/code extensions | Code view |

The `Code` toggle overrides the default for the current file. Clicking the file
tab **resets** back to the default mode.

## Link Click Behavior

| Link target | Behavior |
|-------------|----------|
| `.md`, `.markdown`, `.mkd`, `.mmd` | Opens as MD preview in same tab; adds file toggle button |
| Text/code files (`.lua`, `.py`, `.cs`, `.go`, `.json`, `.sh`, etc.) | Opens in code view with syntax highlight |
| Binary/unknown (`.png`, `.pdf`, `.zip`, etc.) | Opens via `/asset` in new tab |
| External (`https://...`) | Opens in new tab — untouched |
| `#fragment` anchor | In-page jump — untouched |
| Cmd/Ctrl+click any local link | Opens in new tab at `/?file=<abs>[&code=1&ext=<ext>]` |

### Path resolution

Links are resolved in order:
1. MD file's own directory
2. Each directory in `ASSET_ROOTS` (CWD, git root, each MD's dir)

First 200/403 → try next candidate. This handles git-root-relative paths like
`[file](lua/plugins/extra/myAi.lua)` from any subdirectory.

### Absolute filesystem paths

`<img src="/abs/path/to/img.png">` and `<a href="/abs/path/to/file.lua">` are
rewritten if the path is under one of `ASSET_ROOTS`. GitLab `/uploads/...`
paths are **not** rewritten (not under any root — broken image by design).

## Image Resolution

Mirrors previm's `isRelativeUrl` regex: `!/^(?:[a-z][a-z0-9+.-]*:|\/\/|#|\/)/i.test(url)`.

| MD source | Browser request |
|-----------|----------------|
| `![x](./foo.png)` | `/asset?path=<md_dir>/foo.png` ✅ |
| `![x](screenshots/y.png)` | `/asset?path=<md_dir>/screenshots/y.png` ✅ |
| `![x](/abs/path/img.png)` (under root) | `/asset?path=/abs/path/img.png` ✅ |
| `![x](/uploads/abc/z.png)` | left as-is → 404 (GitLab uploads — by design) |
| `![x](https://...)` | fetched directly by browser ✅ |

## Breadcrumb

Shown in the header below the code toolbar slot. Each directory segment is
clickable and opens the **file tree panel** navigated to that directory.
The current filename (last segment) is shown non-clickable.

## File Tree Panel

Opens from breadcrumb segment clicks. Left-side slide-in panel with overlay.

| Element | Behaviour |
|---------|-----------|
| Directory entry (`▶`) | Navigate into it; `..` goes to parent |
| Text/code file (link color) | Close panel, open file in natural view mode |
| Binary file (dim) | Close panel, open via `/asset` |
| Search input | Live filter; matching text highlighted; auto-focused on open |
| `✕` / overlay / `Escape` | Close panel |

Hidden files (`.` prefix) are excluded from listings.

## Navigation History

Every file load (link click, tree selection, breadcrumb navigation) pushes a
history entry via `history.pushState`. Browser back/forward restores the exact
view and mode.

URL scheme:
- MD view: `/?file=<abs>`
- Code view: `/?file=<abs>&code=1&ext=<ext>`

Opening a `/?file=…` URL directly (e.g. via Cmd+click new tab) renders the
correct view on load.

## Security

- Server binds `127.0.0.1` only — not exposed to LAN
- `..` in any path → 403
- All paths must be absolute and start with an allowed root (each MD's dir, CWD, git root)
- `/asset` MIME from extension; unknown ext → `application/octet-stream`
- `/ls` only lists directories under allowed roots

## Architecture

```
lua/plugins/local/mdpreview/
├── README.md              (this file)
├── lua/mdpreview/
│   ├── init.lua           -- M.open(args), M.stop(); file discovery; BufWritePost autocmd
│   ├── server.lua         -- vim.uv TCP server; routes /, /md, /asset, /ls, /events
│   └── template.lua       -- self-contained HTML+JS page
└── plugin/
    └── mdpreview.lua      -- :MdPreview, :MdPreviewStop user commands
tests/
├── spec.md                -- full feature spec & manual test checklist
└── fixtures/
    ├── index.md           -- MD showcase (headings, table, code, task list, links)
    ├── links.md           -- link type tests
    ├── images.md          -- image resolution tests
    ├── code_samples.md    -- code view + fenced block tests
    ├── script.sh          -- bash syntax highlight fixture
    ├── long_lines.txt     -- wrap toggle fixture
    ├── sample.png         -- image fixture
    └── sub/
        └── deep.md        -- breadcrumb depth / tree navigation fixture
```

Lazy spec: `lua/plugins/extra/myMdPreview.lua` — loads via
`dir = stdpath('config') .. '/lua/plugins/local/mdpreview'`, lazy on `cmd` + `keys`.

## Known Gaps

- CDN libs (markdown-it, marked, showdown, commonmark, highlight.js) — needs internet on first browser load; no offline vendor bundle
- `/uploads/...` GitLab images not auto-rewritten — broken image displayed
- No scroll-position memory when switching files
- One server per Neovim instance — restart on every `:MdPreview` call
- No HTML pass-through (renderers escape inline HTML — `<details>` blocks won't render as collapsible)
- `fileMode` per-file override is session-only (not persisted across `:MdPreview` restarts)

## Development

```bash
# Boot server headlessly and print the port
NVIM_APPNAME=nvimwt3a nvim --headless \
  -c "lua require('lazy').load({plugins={'mdpreview'}})" \
  -c "lua local s=require('mdpreview.server'); print(s.start({'/tmp/x.md'},'/tmp/x.md',{'/tmp'}))" \
  -c "qa"

# Security checks
curl 'http://127.0.0.1:<port>/asset?path=../../../etc/passwd'  # → 403
curl 'http://127.0.0.1:<port>/asset?path=/etc/passwd'          # → 403
curl 'http://127.0.0.1:<port>/ls?path=/etc'                    # → {"error":"Forbidden"}

# Run manual spec
NVIM_APPNAME=nvimwt3a nvim tests/fixtures/index.md
# then :MdPreview and follow tests/spec.md
```

## User notes (do not edit / remove)

Core
- ✅ functional Program.cs / absolute path support — absolute fs paths (`/Users/me/repo/file.cs`) now served via `/asset` if under allowed roots
- Note: the original "Not found" path had a `patches/mcphub.nvim/` prefix that doesn't exist on disk — fix the link in the source MD

Extra (later)
- a picker: list active servers, open files, select browser, link with file picker

UX improvement
- ✅ 0 - navigation stack — browser back/forward via `history.pushState`/`popstate`
- ✅ 1 - hidable header — `☰` collapses; peek `☰` fixed top-right; localStorage
- ✅ 2 - ctrl+a scoped to content — Cmd/Ctrl+A selects only `#content`
- ✅ 3 - sticky code toolbar — toolbar in sticky header (always visible in code view)
- ✅ 4 - syntax hl with line numbers — `highlightjs-line-numbers.js`; both work together
- ✅ 5 - cmd+click to open new tab — modifier+click opens `/?file=<abs>` in new tab

- non openable path can consider file://
- menu rightclick open in file://
