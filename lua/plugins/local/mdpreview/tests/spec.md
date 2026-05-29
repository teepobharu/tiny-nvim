# mdpreview — Feature Spec & Manual Test Checklist

Pseudo-test document. Each section is a named scenario with a setup, steps, and
expected outcomes. Run with a live server (`NVIM_APPNAME=nvimwt3a nvim`) so the
browser is open alongside.

---

## Setup

```bash
cd /path/to/mdpreview/tests
NVIM_APPNAME=nvimwt3a nvim fixtures/index.md
:MdPreview
```

All paths below assume the server is running and the browser is open at the
reported URL.

---

## S1 — Server & File Discovery

### S1.1 Single MD buffer → siblings loaded

- Open `fixtures/index.md` in Neovim
- Run `:MdPreview` (no args)
- **Expected**: file toggle shows `index.md`, `code_samples.md`, `images.md`,
  `links.md` (all siblings in `fixtures/`)

### S1.2 Non-MD buffer → CWD glob

- Open any `.lua` file
- Run `:MdPreview` (no args)
- **Expected**: file toggle shows all `*.md` under CWD (capped at 50)

### S1.3 Explicit args

- Run `:MdPreview fixtures/index.md fixtures/links.md`
- **Expected**: only those two files appear in the file toggle

### S1.4 Restart clears old state

- Run `:MdPreview` twice in a row (second call while server is running)
- **Expected**: server restarts cleanly, browser opens at new port, no stale
  files from previous session

### S1.5 No MD files found

- Open Neovim in an empty directory with no `.md` files, run `:MdPreview`
- **Expected**: warning notification "No markdown files found", no browser open

---

## S2 — Markdown Rendering

### S2.1 Default renderer — markdown-it

- Load `fixtures/index.md`
- **Expected**: headings, bold, italic, table, fenced code block, task list all
  render correctly

### S2.2 Renderer toggle

- Click each renderer button: `markdown-it+breaks`, `marked`, `showdown`,
  `commonmark`
- **Expected**: content re-renders without page reload; active button highlighted;
  failed libs show disabled + tooltip

### S2.3 Live reload on save

- Open `fixtures/index.md` in Neovim, make a visible edit, save with `:w`
- **Expected**: browser content updates automatically within ~1 s without manual
  refresh; status shows new timestamp

### S2.4 Dark / light mode toggle

- Click the `☀︎` / `☾` button
- **Expected**: page background, text, borders flip between dark and light
  palette; hljs stylesheet swaps to match

---

## S3 — Code View

### S3.1 Non-MD file defaults to code view

- Click `Program.cs` in the file tab (or navigate via tree)
- **Expected**: code toolbar appears in header; syntax-highlighted C# code
  shown; `Code` button in renderer row is active (lit)

### S3.2 Code view for Lua file

- Navigate to any `.lua` file
- **Expected**: Lua syntax highlighting applied; language tag shows `lua`

### S3.3 Code toggle on MD file

- While viewing `index.md`, click the `Code` button
- **Expected**: raw markdown source shown in code view with syntax highlight;
  `Code` button active; renderer buttons disabled

### S3.4 Toggle back from code to MD

- While in code view on an MD file, click any renderer button
- **Expected**: switches back to rendered MD view; renderer button active;
  `Code` button unlit; code toolbar hidden

### S3.5 Line numbers toggle

- Open any code file; click `#` button
- **Expected**: line numbers appear alongside code; both line numbers and syntax
  highlight visible simultaneously (via hljs-line-numbers plugin)
- Click `#` again → line numbers disappear, highlight stays

### S3.6 Wrap toggle

- Open a file with long lines (e.g., `fixtures/long_lines.txt`); click `↵`
- **Expected**: lines wrap at viewport edge; `↵` button active; toggle off
  restores horizontal scroll

### S3.7 Copy to clipboard

- Open any code file; click `Copy`
- **Expected**: status shows `Success: Copied to clipboard` in green; clipboard
  contains raw file text

### S3.8 Code toolbar persists across files

- Toggle line numbers on; navigate to a different code file via tab
- **Expected**: line numbers still on (state from `localStorage` applied)

---

## S4 — File Tab Bar

### S4.1 Active file highlighted

- Switch files via tab buttons
- **Expected**: clicked button gets `active` class (filled background); others
  deselect

### S4.2 Dynamically added tabs

- Click a relative link to a file not in the initial discovery list
- **Expected**: new tab button appears in the file toggle; it becomes active;
  clicking it later re-opens that file

### S4.3 Tab click resets to default mode

- Open `Program.cs` (code view); switch to `index.md`; switch back to
  `Program.cs` via tab
- **Expected**: `Program.cs` opens in code view (default for `.cs`), not the
  last manually set mode

---

## S5 — Link Navigation

### S5.1 Relative MD link — same dir

- `fixtures/index.md` contains `[links](./links.md)`
- Click link
- **Expected**: `links.md` loads in MD preview; tab button added/activated;
  breadcrumb updates

### S5.2 Relative code link — same dir

- `fixtures/links.md` contains `[sample](./code_samples.md)` and
  `[script](./script.sh)`
- Click each
- **Expected**: `.md` opens as rendered MD; `.sh` opens as code view with bash
  highlight

### S5.3 Git-root-relative link

- MD contains `[myAi.lua](lua/plugins/extra/myAi.lua)` (relative to git root)
- Click link
- **Expected**: file loads in code view; ASSET_ROOTS fallback chain finds it

### S5.4 Absolute filesystem path link

- MD contains `[abs](/abs/path/to/file.lua)` pointing to a real file under an
  allowed root
- Click link
- **Expected**: file loads correctly; not treated as 403

### S5.5 External link — new tab

- MD contains `[GitHub](https://github.com)`
- Click link
- **Expected**: opens in new browser tab; page does not navigate away

### S5.6 Fragment anchor

- MD contains `[section](#s3-code-view)`
- Click link
- **Expected**: in-page scroll to anchor; no fetch; URL gains `#…` fragment

### S5.7 Binary link — new tab via asset

- MD contains `[diagram](./fixtures/sample.png)`
- Click link
- **Expected**: opens image in new tab via `/asset` route

### S5.8 Outside allowed roots — blocked

- Attempt `curl 'http://127.0.0.1:<port>/asset?path=/etc/passwd'`
- **Expected**: `403 Forbidden`

### S5.9 Cmd+click → new tab

- Hold `⌘` (macOS) and click a relative `.md` or code link
- **Expected**: new tab opens at `/?file=<abs>` or `/?file=<abs>&code=1&ext=<ext>`;
  original tab unchanged

---

## S6 — Image Serving

### S6.1 Relative image — MD dir

- `fixtures/images.md` contains `![img](./sample.png)`
- **Expected**: image renders; browser requests `/asset?path=<fixtures_dir>/sample.png`

### S6.2 ASSET_ROOTS fallback

- MD in subdirectory references `![x](assets/logo.png)` that lives at git root
- **Expected**: image loads via fallback chain (primary dir 404 → git root hit)

### S6.3 Absolute image path

- MD contains `![x](/abs/path/to/image.png)` under an allowed root
- **Expected**: image renders via `/asset`

### S6.4 External image — untouched

- MD contains `![x](https://example.com/img.png)`
- **Expected**: image fetched directly by browser; no rewrite

### S6.5 GitLab `/uploads/...` — left as-is

- MD contains `![x](/uploads/abc/img.png)`
- **Expected**: broken image shown (not under allowed roots — by design)

---

## S7 — Breadcrumb

### S7.1 Breadcrumb reflects current file

- Open `fixtures/sub/deep.md`
- **Expected**: breadcrumb shows `/` > `…` > `tests` > `fixtures` > `sub` >
  `deep.md` (last segment non-clickable)

### S7.2 Breadcrumb updates on navigation

- Navigate from `fixtures/index.md` to `fixtures/sub/deep.md` via link
- **Expected**: breadcrumb updates immediately after load

### S7.3 Clickable segment opens tree

- Click any intermediate directory segment in the breadcrumb
- **Expected**: file tree panel opens navigated to that directory

---

## S8 — File Tree Panel

### S8.1 Open via breadcrumb

- Click a directory segment in the breadcrumb
- **Expected**: panel slides in; overlay appears; directory label correct;
  entries listed (dirs first, then files); hidden files excluded

### S8.2 Navigate into subdirectory

- Click a `▶` directory entry
- **Expected**: panel refreshes showing contents of that subdirectory; `..`
  entry at top

### S8.3 Navigate to parent

- Click `..` entry
- **Expected**: panel shows parent directory contents

### S8.4 Open a text file

- Click a `.md` or `.lua` file entry
- **Expected**: panel closes; overlay gone; file loads in appropriate view;
  tab button added

### S8.5 Search filters entries

- Type `spec` in search box
- **Expected**: only entries containing `spec` shown; matching substring
  highlighted in blue

### S8.6 Search clears on directory change

- Search for something; click a directory entry
- **Expected**: search input cleared; full listing of new dir shown

### S8.7 Close panel

- Click `✕` button or click the overlay
- **Expected**: panel hides; overlay gone; content unchanged

### S8.8 Escape closes panel

- While panel is open, press `Escape`
- **Expected**: panel closes

### S8.9 403 on disallowed directory

- Manually fetch `http://127.0.0.1:<port>/ls?path=/etc`
- **Expected**: `{"error":"Forbidden"}`

---

## S9 — Navigation History

### S9.1 Back button

- Open `index.md` → click link to `links.md` → press browser back
- **Expected**: `index.md` renders; breadcrumb reverts; status updates

### S9.2 Forward button

- After pressing back, press browser forward
- **Expected**: `links.md` renders again

### S9.3 Back through code view

- Open `index.md` → navigate to `Program.cs` (code view) → press back
- **Expected**: `index.md` in MD view; `Program.cs` mode preserved as 'code'
  for next forward

---

## S10 — UX / Header

### S10.1 Hide header

- Click `☰` header-toggle button
- **Expected**: header disappears; peek `☰` button appears top-right;
  `localStorage` key `mdpreview.headerCollapsed = true`

### S10.2 Restore header

- Click the peek `☰` button
- **Expected**: header reappears; peek button hidden

### S10.3 Collapse state persists across reload

- Collapse header; reload page
- **Expected**: header still collapsed on load

### S10.4 Ctrl/Cmd+A scoped to content

- Press `⌘A` (macOS)
- **Expected**: only the `#content` area is selected; header buttons not included

### S10.5 Status color — error

- Trigger a 404 (navigate to a nonexistent file link)
- **Expected**: status shows `Error:` in red followed by the message

### S10.6 Status color — success

- Click `Copy` in a code view
- **Expected**: status shows `Success:` in green + "Copied to clipboard"

---

## S11 — Security

### S11.1 Path traversal via /asset

```bash
curl 'http://127.0.0.1:<port>/asset?path=../../../etc/passwd'
```
**Expected**: `403 Forbidden`

### S11.2 Path traversal via /md

```bash
curl 'http://127.0.0.1:<port>/md?path=../../../etc/passwd'
```
**Expected**: `403 Forbidden`

### S11.3 Path traversal via /ls

```bash
curl 'http://127.0.0.1:<port>/ls?path=../../../etc'
```
**Expected**: `{"error":"Forbidden"}`

### S11.4 Absolute path outside roots

```bash
curl 'http://127.0.0.1:<port>/asset?path=/etc/passwd'
```
**Expected**: `403 Forbidden` (path not under any ALLOWED_ROOT)

### S11.5 Server only on localhost

- From another machine on LAN, try `curl http://<host-ip>:<port>/`
- **Expected**: connection refused (server binds `127.0.0.1` only)

---

## Fixture Files

- `fixtures/index.md` — main MD showcase (headings, table, code block, task list, images, links)
- `fixtures/links.md` — various link types (relative MD, code, external, fragment, binary)
- `fixtures/images.md` — image resolution cases (relative, absolute, external, gitlab)
- `fixtures/code_samples.md` — MD file linking to code files
- `fixtures/script.sh` — bash script for code view / syntax hl test
- `fixtures/sample.png` — placeholder image for image tests
- `fixtures/long_lines.txt` — file with long lines for wrap-toggle test
- `fixtures/sub/deep.md` — nested file for breadcrumb depth test
