local M = {}

--- Generate the self-contained HTML page.
--- @param port number  server port
--- @param files string[]  list of absolute paths to serve
--- @param initial string  initial active file path
--- @param roots string[]  allowed root directories for asset resolution fallback
function M.html(port, files, initial, roots)
  local file_buttons = {}
  for _, f in ipairs(files) do
    local label = vim.fn.fnamemodify(f, ":t")
    local active = f == initial and "active" or ""
    table.insert(
      file_buttons,
      string.format('<button type="button" data-file="%s" class="%s">%s</button>', f, active, label)
    )
  end
  local file_buttons_html = table.concat(file_buttons, "\n            ")

  -- JSON array of roots for JS fallback resolution
  local roots_parts = {}
  for _, r in ipairs(roots or {}) do
    table.insert(roots_parts, string.format('%q', r))
  end
  local roots_json = "[" .. table.concat(roots_parts, ",") .. "]"

  return string.format(
    [[<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width,initial-scale=1"/>
  <title>MD Preview</title>
  <style>
    :root{--page-bg:#f7f8fa;--panel-bg:#ffffff;--text:#172b4d;--heading:#091e42;--muted:#5e6c84;--border:#dfe1e6;--soft-bg:#f4f5f7;--link:#0052cc;--active-bg:#0052cc;--active-text:#ffffff}
    body.dark{--page-bg:#0d1117;--panel-bg:#161b22;--text:#c9d1d9;--heading:#f0f6fc;--muted:#8b949e;--border:#30363d;--soft-bg:#21262d;--link:#58a6ff;--active-bg:#1f6feb;--active-text:#ffffff}
    body{margin:0;color:var(--text);background:var(--page-bg);font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}
    header{position:sticky;top:0;z-index:2;padding:12px 20px;border-bottom:1px solid var(--border);background:var(--panel-bg);display:flex;flex-direction:column;gap:8px}
    .header-row{display:flex;align-items:center;gap:8px;flex-wrap:wrap}
    .header-row h1{margin:0;font-size:16px;color:var(--heading)}
    main{max-width:1600px;margin:0 auto;padding:24px}
    #content{padding:24px;overflow-x:auto;border:1px solid var(--border);border-radius:8px;background:var(--panel-bg)}
    #content.code-view{padding:0}
    h1,h2,h3{color:var(--heading)}
    a{color:var(--link)}
    code{padding:2px 4px;border-radius:3px;background:var(--soft-bg);font-family:ui-monospace,SFMono-Regular,Menlo,Monaco,Consolas,monospace}
    table{width:max-content;max-width:none;border-collapse:collapse;margin:16px 0 32px;font-size:13px}
    th,td{max-width:520px;padding:8px 10px;vertical-align:top;border:1px solid var(--border)}
    th{background:var(--soft-bg);color:var(--heading)}
    img{display:block;max-width:320px;max-height:240px;border:1px solid var(--border);border-radius:4px;cursor:zoom-in}
    .viewer-container{z-index:10000}
    select.mode-toggle{width:auto;padding:0 4px;font-size:12px;height:30px;cursor:pointer}
    .toggle-row{display:flex;flex-wrap:wrap;gap:6px;align-items:center}
    .toggle-row span{color:var(--muted);font-size:12px;min-width:60px}
    .toggle-row button{padding:4px 8px;border:1px solid #c1c7d0;border-radius:4px;background:var(--panel-bg);color:var(--text);cursor:pointer;font-size:12px}
    .toggle-row button.active{border-color:var(--active-bg);background:var(--active-bg);color:var(--active-text);font-weight:600}
    .toggle-row button:disabled{opacity:.45;cursor:not-allowed}
    body.dark .toggle-row button{border-color:var(--border)}
    .mode-toggle{display:inline-flex;align-items:center;justify-content:center;width:30px;height:30px;border:1px solid var(--border);border-radius:6px;background:var(--panel-bg);color:var(--text);cursor:pointer;font-size:14px}
    .mode-toggle:hover{border-color:var(--active-bg)}
    #status{font-size:11px;color:var(--muted);padding:2px 0}
    #status .s-error{color:#cf222e;font-weight:600}
    #status .s-success{color:#1a7f37;font-weight:600}
    #code-toolbar-slot{display:none;gap:8px;align-items:center;flex-wrap:wrap;padding:4px 0;border-top:1px solid var(--border)}
    .code-name{font-weight:600;font-size:13px}
    .code-lang{color:var(--muted);font-size:11px;padding:2px 6px;border:1px solid var(--border);border-radius:3px}
    .code-btn{padding:3px 8px;border:1px solid var(--border);border-radius:4px;background:var(--panel-bg);color:var(--text);cursor:pointer;font-size:12px}
    .code-btn.active{background:var(--active-bg);color:var(--active-text);border-color:var(--active-bg)}
    #content pre{margin:0;padding:12px;overflow:auto;background:var(--panel-bg)}
    #content pre.wrap{white-space:pre-wrap;word-break:break-word}
    body.header-collapsed header{display:none}
    body.header-collapsed #peek{display:flex}
    #peek{display:none;position:fixed;top:4px;right:4px;z-index:3;align-items:center;justify-content:center;width:30px;height:30px;border:1px solid var(--border);border-radius:6px;background:var(--panel-bg);color:var(--text);cursor:pointer;font-size:14px}
    #peek:hover{border-color:var(--active-bg)}
    #breadcrumb{display:flex;align-items:center;flex-wrap:wrap;gap:2px;font-size:12px;color:var(--muted);padding:2px 0}
    .bc-copy{flex-shrink:0;width:22px;height:22px;display:inline-flex;align-items:center;justify-content:center;border:1px solid var(--border);border-radius:4px;background:var(--panel-bg);color:var(--text);cursor:pointer;font-size:12px;padding:0}
    .bc-copy:hover{border-color:var(--active-bg)}
    .bc-sep{color:var(--border);padding:0 2px;user-select:none}
    .bc-seg{cursor:pointer;padding:1px 4px;border-radius:3px;color:var(--link)}
    .bc-seg:hover{background:var(--soft-bg)}
    .bc-seg.bc-current{color:var(--muted);cursor:default;font-weight:600}
    .bc-seg.bc-current:hover{background:transparent}
    #tree-panel{display:none;position:fixed;top:0;left:0;bottom:0;width:320px;z-index:10;background:var(--panel-bg);border-right:1px solid var(--border);flex-direction:column;box-shadow:4px 0 16px rgba(0,0,0,.18)}
    #tree-panel.open{display:flex}
    #tree-header{display:flex;align-items:center;gap:8px;padding:10px 12px;border-bottom:1px solid var(--border);flex-shrink:0}
    #tree-header .tree-dir{font-weight:600;font-size:13px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;flex:1}
    #tree-close{border:none;background:none;color:var(--muted);cursor:pointer;font-size:18px;padding:0 4px;line-height:1}
    #tree-close:hover{color:var(--text)}
    #tree-search{margin:8px 12px;padding:5px 8px;border:1px solid var(--border);border-radius:4px;background:var(--soft-bg);color:var(--text);font-size:12px;outline:none;flex-shrink:0}
    #tree-search:focus{border-color:var(--active-bg)}
    #tree-list{overflow-y:auto;flex:1;padding:4px 0}
    .tree-item{display:flex;align-items:center;gap:6px;padding:4px 12px;cursor:pointer;font-size:13px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;user-select:none}
    .tree-item:hover{background:var(--soft-bg)}
    .tree-item.tree-dir-item{color:var(--heading)}
    .tree-item.tree-file-item{color:var(--text)}
    .tree-item.tree-file-item.text-file{color:var(--link)}
    .tree-item .ti-icon{font-size:12px;flex-shrink:0;color:var(--muted)}
    .tree-item.match-hl{background:var(--soft-bg)}
    #tree-openers a{color:var(--link);text-decoration:none;padding:1px 5px;border:1px solid var(--border);border-radius:3px;font-size:11px;white-space:nowrap}
    #tree-openers a:hover{border-color:var(--active-bg);background:var(--soft-bg)}
    #tree-overlay{display:none;position:fixed;inset:0;z-index:9;background:rgba(0,0,0,.3)}
    #tree-overlay.open{display:block}
    table.hljs-ln{margin:0;border:none;width:100%%;font-size:inherit;border-collapse:collapse}
    table.hljs-ln td{border:none;padding:0;vertical-align:top}
    .hljs-ln-numbers{user-select:none;text-align:right;color:var(--muted);border-right:1px solid var(--border);padding:0 8px !important;min-width:3ch}
    .hljs-ln-code{padding-left:8px !important}
    #help-popover{position:fixed;top:48px;right:12px;z-index:9999;background:var(--panel-bg);border:1px solid var(--border);border-radius:8px;box-shadow:0 8px 24px rgba(0,0,0,.35);padding:14px 16px;min-width:340px;max-width:420px;font-size:13px;color:var(--text);display:none}
    #help-popover.open{display:block}
    #help-popover h3{margin:0 0 8px;font-size:13px;color:var(--heading);border-bottom:1px solid var(--border);padding-bottom:6px}
    #help-popover dl{margin:0;display:grid;grid-template-columns:auto 1fr;gap:4px 12px;align-items:baseline}
    #help-popover dt{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:11px;color:var(--link);white-space:nowrap}
    #help-popover dd{margin:0;color:var(--text)}
    #help-popover .help-section{margin-top:10px}
    #ctx-menu{position:fixed;z-index:9999;background:var(--panel-bg);border:1px solid var(--border);border-radius:6px;box-shadow:0 4px 16px rgba(0,0,0,.3);padding:4px 0;min-width:220px;font-size:13px}
    #ctx-menu button{display:block;width:100%%;text-align:left;background:none;border:0;color:var(--text);padding:6px 12px;cursor:pointer;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
    #ctx-menu button:hover{background:var(--soft-bg)}
    :root{--split-width:480px}
    #split-divider{display:none;width:6px;cursor:col-resize;background:var(--border);flex-shrink:0;align-self:stretch}
    #split-divider:hover{background:var(--active-bg)}
    #split-pane{display:none;width:var(--split-width);flex-shrink:0;flex-direction:column;border:1px solid var(--border);border-radius:8px;background:var(--panel-bg);overflow:hidden;align-self:stretch;min-height:480px}
    body.split-open main{display:flex;gap:0;align-items:stretch}
    body.split-open #content{flex:1;min-width:0}
    body.split-open #split-divider,body.split-open #split-pane{display:flex}
    #split-header{display:flex;align-items:center;gap:6px;padding:6px 10px;border-bottom:1px solid var(--border);font-size:12px;background:var(--soft-bg);flex-shrink:0}
    #split-name{flex:1;color:var(--heading);font-weight:600;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;cursor:default}
    .split-chrome{border:1px solid transparent;background:none;color:var(--muted);cursor:pointer;font-size:12px;line-height:1;padding:2px 6px;border-radius:3px}
    .split-chrome:hover{border-color:var(--border);color:var(--text)}
    .split-chrome.active{border-color:var(--active-bg);background:var(--active-bg);color:var(--active-text)}
    #split-content{flex:1;overflow:auto;padding:16px}
    #split-content.code-view{padding:0}
    #split-content pre{margin:0;padding:12px;overflow:auto;background:var(--panel-bg)}
    #split-content pre.wrap{white-space:pre-wrap;word-break:break-word}
    body.split-min #split-divider{display:none}
    body.split-min #split-pane{width:32px;cursor:pointer;min-height:0}
    body.split-min #split-content,body.split-min .split-chrome{display:none}
    body.split-min #split-header{flex-direction:column;border-bottom:none;padding:8px 4px;background:var(--panel-bg)}
    body.split-min #split-name{writing-mode:vertical-rl;transform:rotate(180deg);text-align:center;font-size:11px}
  </style>
  <link rel="stylesheet" id="hljs-css-dark" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github-dark.min.css">
  <link rel="stylesheet" id="hljs-css-light" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github.min.css" disabled>
</head>
<body class="dark">
  <header>
    <div class="header-row">
      <h1>MD Preview</h1>
      <span style="flex:1"></span>
      <button type="button" id="font-dec"   class="mode-toggle" title="Decrease text size (A-)">A-</button>
      <button type="button" id="font-inc"   class="mode-toggle" title="Increase text size (A+)">A+</button>
      <button type="button" id="font-reset" class="mode-toggle" title="Reset text size">A0</button>
      <select id="zoom-provider" class="mode-toggle" title="Image zoom provider">
        <option value="none">Zoom: off</option>
        <option value="medium-zoom">Zoom: medium</option>
        <option value="viewer">Zoom: viewer</option>
      </select>
      <button type="button" id="help-toggle" class="mode-toggle" title="Help / keyboard shortcuts">?</button>
      <button type="button" id="header-toggle" class="mode-toggle" title="Hide header (Cmd/Ctrl+B)">☰</button>
      <button type="button" id="dark-mode-toggle" class="mode-toggle" title="Toggle dark mode">☀︎</button>
    </div>
    <div id="code-toolbar-slot"></div>
    <div class="toggle-row" id="file-toggle">
      <span>File:</span>
      %s
    </div>
    <div class="toggle-row" id="renderer-row" aria-label="Markdown renderer">
      <span>Renderer:</span>
      <button type="button" id="code-mode-toggle" title="Toggle code / MD view">Code</button>
      <button type="button" data-provider="markdown-it" class="active">markdown-it</button>
      <button type="button" data-provider="markdown-it-breaks">markdown-it+breaks</button>
      <button type="button" data-provider="marked">marked</button>
      <button type="button" data-provider="showdown">showdown</button>
      <button type="button" data-provider="commonmark">commonmark</button>
    </div>
    <div class="bc-row" style="display:flex;align-items:center;gap:6px;flex-wrap:wrap">
      <button type="button" id="copy-path" class="bc-copy" title="Copy file path">&#x1F4C1;</button>
      <div id="breadcrumb"></div>
      <button type="button" id="copy-content" class="bc-copy" title="Copy file contents">&#x1F4CB;</button>
    </div>
    <div id="status"></div>
  </header>
  <button id="peek" title="Show header">☰</button>
  <div id="help-popover" role="dialog" aria-label="Keybindings and help">
    <h3>Keybindings</h3>
    <dl>
      <dt>Cmd/Ctrl+A</dt><dd>Select all content</dd>
      <dt>Cmd/Ctrl+B</dt><dd>Toggle header</dd>
      <dt>Cmd/Ctrl+E</dt><dd>Open file explorer at current dir</dd>
      <dt>Cmd/Ctrl+Click</dt><dd>Open link in new tab</dd>
      <dt>Opt/Alt+Cmd+Click</dt><dd>Open link / file tab in split panel</dd>
      <dt>Alt+1</dt><dd>Maximize left (main) panel</dd>
      <dt>Alt+2</dt><dd>Maximize right (split) panel</dd>
      <dt>Alt+Right-Click</dt><dd>Search selection on Sourcegraph / Glean</dd>
      <dt>Esc</dt><dd>Close popovers / file tree</dd>
    </dl>
    <div class="help-section">
      <h3>Split panel</h3>
      <dl>
        <dt>Opt/Alt+Cmd+Click</dt><dd>Open link or file tab in split panel alongside current file</dd>
        <dt>Drag divider</dt><dd>Resize split panel width (240–1200px)</dd>
        <dt>Double-click divider</dt><dd>50 / 50 split</dd>
        <dt>Alt+1 / Alt+2</dt><dd>Maximize left / right panel</dd>
        <dt>&#x2013; (minimize)</dt><dd>Collapse panel to narrow strip; click strip to restore</dd>
        <dt>&#x2715; (close)</dt><dd>Close split panel</dd>
      </dl>
    </div>
    <div class="help-section">
      <h3>Header buttons</h3>
      <dl>
        <dt>A- A+ A0</dt><dd>Decrease / increase / reset font size</dd>
        <dt>&#x1F4C1;</dt><dd>Copy file path (before breadcrumb)</dd>
        <dt>&#x1F4CB;</dt><dd>Copy file contents (after filename)</dd>
        <dt>Zoom: ▾</dt><dd>Select image zoom provider (off / medium / viewer)</dd>
        <dt>?</dt><dd>Toggle this help</dd>
        <dt>☰</dt><dd>Hide header</dd>
        <dt>☀︎ / ☾</dt><dd>Toggle dark mode</dd>
      </dl>
    </div>
    <div class="help-section">
      <h3>Breadcrumb</h3>
      <dl>
        <dt>Click dir</dt><dd>Open inline file tree at that directory</dd>
        <dt>Non-text link</dt><dd>Opens via file:// in new tab (browser may prompt)</dd>
      </dl>
    </div>
  </div>
  <div id="tree-overlay"></div>
  <div id="tree-panel" role="dialog" aria-label="File tree">
    <div id="tree-header">
      <span class="tree-dir" id="tree-dir-label"></span>
      <button id="tree-close" title="Close">✕</button>
    </div>
    <div id="tree-openers" style="display:none;padding:4px 10px 6px;border-bottom:1px solid var(--border);flex-shrink:0;font-size:11px;color:var(--muted);gap:4px;flex-wrap:wrap;align-items:center"></div>
    <input id="tree-search" type="search" placeholder="Search…" autocomplete="off" spellcheck="false"/>
    <div id="tree-list"></div>
  </div>
  <main>
    <section id="content">Loading…</section>
    <div id="split-divider" title="Drag to resize"></div>
    <aside id="split-pane">
      <div id="split-header">
        <span id="split-name" title=""></span>
        <button type="button" id="split-code-btn" class="split-chrome" title="Toggle code / MD view">Code</button>
        <button type="button" id="split-max-btn" class="split-chrome" title="Maximize split panel (Alt+2)">&#x2922;</button>
        <button type="button" id="split-min-btn" class="split-chrome" title="Minimize">&#x2013;</button>
        <button type="button" id="split-close-btn" class="split-chrome" title="Close">&#x2715;</button>
      </div>
      <section id="split-content"></section>
    </aside>
  </main>
  <script src="https://cdn.jsdelivr.net/npm/markdown-it@14.1.0/dist/markdown-it.min.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/marked@12.0.2/marked.min.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/showdown@2.1.0/dist/showdown.min.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/commonmark@0.31.2/dist/commonmark.min.js"></script>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/highlightjs-line-numbers.js@2.8.0/dist/highlightjs-line-numbers.min.js"></script>
  <script>
    const PORT = %d;
    const ASSET_ROOTS = %s;
    const content = document.getElementById('content');
    const status  = document.getElementById('status');
    const darkBtn = document.getElementById('dark-mode-toggle');
    const codeToolbarSlot = document.getElementById('code-toolbar-slot');
    const codeModeToggleBtn = document.getElementById('code-mode-toggle');
    const rendererBtns = Array.from(document.querySelectorAll('[data-provider]'));
    const fileBtns     = Array.from(document.querySelectorAll('[data-file]'));

    let currentFile = %q;
    let currentProvider = 'markdown-it';
    let lastMd = '';
    let lastCodeText = '';
    // per-file view mode: 'md' | 'code' — persists across tab switches within session
    const fileMode = {};

    const showdown = window.showdown ? new window.showdown.Converter({tables:true,strikethrough:true,tasklists:true,ghCompatibleHeaderId:true}) : null;
    const cmReader = window.commonmark ? new window.commonmark.Parser() : null;
    const cmWriter = window.commonmark ? new window.commonmark.HtmlRenderer({safe:true}) : null;

    const renderers = {
      'markdown-it':        md => window.markdownit({html:false,linkify:true,typographer:true}).render(md),
      'markdown-it-breaks': md => window.markdownit({html:false,linkify:true,typographer:true,breaks:true}).render(md),
      'marked':             md => window.marked.parse(md,{gfm:true,breaks:false}),
      'showdown':           md => showdown ? showdown.makeHtml(md) : '<p>showdown failed</p>',
      'commonmark':         md => cmWriter ? cmWriter.render(cmReader.parse(md)) : '<p>commonmark failed</p>',
    };

    // hljs language aliases — maps file extensions to hljs language names
    const HLJS_LANG_ALIAS = {
      cs: 'csharp', c: 'c', cpp: 'cpp', h: 'cpp', hpp: 'cpp',
      jsx: 'javascript', tsx: 'typescript', mjs: 'javascript',
      sh: 'bash', zsh: 'bash', fish: 'bash',
      yml: 'yaml', htm: 'html',
      mkd: 'markdown', mmd: 'markdown',
      conf: 'ini', rb: 'ruby', kt: 'kotlin',
    };

    // --- status helpers ---
    function setStatus(msg, type) {
      if (type === 'error') {
        status.innerHTML = '<span class="s-error">Error:</span> ' + escapeHtml(msg.replace(/^Error:\s*/i, ''));
      } else if (type === 'success') {
        status.innerHTML = '<span class="s-success">Success:</span> ' + escapeHtml(msg);
      } else {
        status.textContent = msg;
      }
    }

    // --- view mode helpers ---
    function getDefaultMode(path) {
      const ext = extOf(path);
      // non-MD text files default to code view; MD files default to rendered MD
      return (TEXT_EXTS.has(ext) && !MD_EXTS.has(ext)) ? 'code' : 'md';
    }
    function getCurrentMode(path) {
      return fileMode[path] !== undefined ? fileMode[path] : getDefaultMode(path);
    }

    // Update Code toggle button + renderer button disabled state to match current file's mode
    function updateViewToggle() {
      const isCode = getCurrentMode(currentFile) === 'code';
      codeModeToggleBtn.classList.toggle('active', isCode);
      rendererBtns.forEach(b => { b.disabled = isCode || !renderers[b.dataset.provider]; });
      // code toolbar slot visibility
      if (!isCode) {
        codeToolbarSlot.style.display = 'none';
        codeToolbarSlot.innerHTML = '';
        content.classList.remove('code-view');
      }
    }

    // Unified file open — respects per-file mode
    function openFile(path, push) {
      const ext = extOf(path);
      if (getCurrentMode(path) === 'code') {
        loadCodeFile(path, ext || 'txt', '', push);
      } else {
        fetchAndRender(path, push);
      }
    }

    function setDark(dark) {
      document.body.classList.toggle('dark', dark);
      darkBtn.textContent = dark ? '☀︎' : '☾';
      const cssD = document.getElementById('hljs-css-dark');
      const cssL = document.getElementById('hljs-css-light');
      if (cssD) cssD.disabled = !dark;
      if (cssL) cssL.disabled = dark;
    }

    // --- URL state (history API + cmd+click new tab) ---
    function urlForState(state) {
      const q = new URLSearchParams();
      q.set('file', state.path);
      if (state.type === 'code') { q.set('code', '1'); q.set('ext', state.ext || ''); }
      return '/?' + q.toString();
    }
    function readUrlState() {
      const q = new URLSearchParams(location.search);
      const file = q.get('file');
      if (!file) return null;
      if (q.get('code') === '1') return { type: 'code', path: file, ext: q.get('ext') || extOf(file) };
      return { type: 'md', path: file };
    }
    function pushView(state) {
      history.pushState(state, '', urlForState(state));
    }

    // --- path helpers ---
    function isRelativeUrl(url) {
      return !/^(?:[a-z][a-z0-9+.-]*:|\/\/|#|\/)/i.test(url);
    }
    function isAbsoluteFsPath(p) {
      if (!p || p[0] !== '/') return false;
      return ASSET_ROOTS.some(r => p === r || p.startsWith(r + '/'));
    }
    function resolveRelative(src, baseDir) {
      try {
        return new URL(src, 'file://' + baseDir + '/').pathname;
      } catch (_e) { return null; }
    }

    const TEXT_EXTS = new Set([
      'md','markdown','mkd','mmd',
      'lua','js','ts','tsx','jsx','json','yaml','yml','toml','sh','bash','zsh','fish',
      'py','rb','go','rs','c','cs','cpp','h','hpp','java','kt','swift','php','sql',
      'html','htm','xml','css','scss','sass',
      'txt','log','env','conf','ini',
    ]);
    const MD_EXTS = new Set(['md','markdown','mkd','mmd']);

    function extOf(p) {
      const m = p.match(/\.([a-z0-9]+)$/i);
      return m ? m[1].toLowerCase() : '';
    }
    function escapeHtml(s) {
      return s.replace(/[&<>]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;'}[c]));
    }

    const codeViewOpts = {
      lineNumbers: localStorage.getItem('mdpreview.lineNumbers') !== 'false',
      wrap:        localStorage.getItem('mdpreview.wrap') === 'true',
    };

    // --- image zoom ---
    const IMG_EXTS = new Set(['png','jpg','jpeg','gif','svg','webp','bmp','ico','avif']);

    const _scriptCache = {};
    function loadScript(url) {
      if (_scriptCache[url]) return _scriptCache[url];
      _scriptCache[url] = new Promise((res, rej) => {
        const s = document.createElement('script');
        s.src = url; s.onload = res; s.onerror = rej;
        document.head.appendChild(s);
      });
      return _scriptCache[url];
    }
    function loadLink(href) {
      if (document.querySelector('link[href="' + href + '"]')) return Promise.resolve();
      return new Promise((res, rej) => {
        const l = document.createElement('link');
        l.rel = 'stylesheet'; l.href = href; l.onload = res; l.onerror = rej;
        document.head.appendChild(l);
      });
    }

    let _activeZoomInstance = null;
    let currentZoomProvider = localStorage.getItem('mdpreview.zoomProvider') || 'viewer';

    const ZOOM_PROVIDERS = {
      'medium-zoom': {
        scripts: ['https://cdn.jsdelivr.net/npm/medium-zoom@1.1.0/dist/medium-zoom.min.js'],
        css: [],
        attach(root) {
          _activeZoomInstance = window.mediumZoom(Array.from(root.querySelectorAll('img')), {
            margin: 24, background: 'rgba(0,0,0,.85)'
          });
        },
        detach() { if (_activeZoomInstance) { _activeZoomInstance.detach(); _activeZoomInstance = null; } },
      },
      viewer: {
        scripts: ['https://cdn.jsdelivr.net/npm/viewerjs@1.11.6/dist/viewer.min.js'],
        css:     ['https://cdn.jsdelivr.net/npm/viewerjs@1.11.6/dist/viewer.min.css'],
        attach(root) {
          _activeZoomInstance = new window.Viewer(root, { toolbar: true, navbar: false, title: true });
        },
        detach() { if (_activeZoomInstance) { _activeZoomInstance.destroy(); _activeZoomInstance = null; } },
      },
    };

    function openLinkInZoom(href) {
      if (currentZoomProvider === 'medium-zoom' && window.mediumZoom) {
        const tmp = document.createElement('img');
        tmp.src = href; tmp.style.cssText = 'position:absolute;opacity:0;pointer-events:none;width:1px;height:1px';
        document.body.appendChild(tmp);
        const mz = window.mediumZoom(tmp, { background: 'rgba(0,0,0,.85)', margin: 24 });
        mz.open();
        tmp.addEventListener('medium-zoom:closed', () => { mz.detach(); tmp.remove(); });
      } else if (currentZoomProvider === 'viewer' && window.Viewer) {
        const tmp = document.createElement('img');
        tmp.src = href; tmp.style.cssText = 'position:absolute;opacity:0;pointer-events:none;width:1px;height:1px';
        document.body.appendChild(tmp);
        const v = new window.Viewer(tmp, {
          inline: false, navbar: false,
          hidden() { v.destroy(); tmp.remove(); },
        });
        v.show();
      }
    }

    function applyZoom(root) {
      if (_activeZoomInstance && ZOOM_PROVIDERS[currentZoomProvider]) {
        ZOOM_PROVIDERS[currentZoomProvider].detach();
      }
      if (currentZoomProvider === 'none') return;
      const p = ZOOM_PROVIDERS[currentZoomProvider];
      if (!p) return;
      Promise.all([...p.scripts.map(loadScript), ...p.css.map(loadLink)])
        .then(() => {
          p.attach(root);
          root.querySelectorAll('a[href]').forEach(a => {
            try {
              const pathname = new URL(a.href, location.href).pathname;
              if (!IMG_EXTS.has(extOf(pathname))) return;
            } catch (_) { return; }
            if (a.dataset.zoomBound) return;
            a.dataset.zoomBound = '1';
            a.addEventListener('click', e => {
              e.preventDefault();
              openLinkInZoom(a.href);
            });
          });
        })
        .catch(e => setStatus('Zoom load failed: ' + e, 'error'));
    }

    const zoomSelect = document.getElementById('zoom-provider');
    zoomSelect.value = currentZoomProvider;
    zoomSelect.addEventListener('change', () => {
      if (_activeZoomInstance && ZOOM_PROVIDERS[currentZoomProvider]) {
        ZOOM_PROVIDERS[currentZoomProvider].detach();
      }
      currentZoomProvider = zoomSelect.value;
      localStorage.setItem('mdpreview.zoomProvider', currentZoomProvider);
      applyZoom(content);
    });

    // --- font size ---
    const FONT_MIN = 10, FONT_MAX = 28, FONT_DEFAULT = 14;
    let fontSize = parseInt(localStorage.getItem('mdpreview.fontSize') || FONT_DEFAULT, 10);
    function applyFontSize() {
      content.style.fontSize = fontSize + 'px';
      localStorage.setItem('mdpreview.fontSize', String(fontSize));
    }
    function bumpFont(delta) {
      fontSize = Math.max(FONT_MIN, Math.min(FONT_MAX, fontSize + delta));
      applyFontSize();
    }
    applyFontSize();
    document.getElementById('font-inc').addEventListener('click',   () => bumpFont(1));
    document.getElementById('font-dec').addEventListener('click',   () => bumpFont(-1));
    document.getElementById('font-reset').addEventListener('click', () => { fontSize = FONT_DEFAULT; applyFontSize(); });

    // --- copy path / copy content ---
    document.getElementById('copy-path').addEventListener('click', async () => {
      try {
        await navigator.clipboard.writeText(currentFile);
        setStatus('Copied path: ' + currentFile, 'success');
      } catch (e) {
        setStatus('Copy failed: ' + e.message, 'error');
      }
    });
    // --- help popover ---
    const helpPopoverEl = document.getElementById('help-popover');
    const helpToggleBtn = document.getElementById('help-toggle');
    function setHelpOpen(open) { helpPopoverEl.classList.toggle('open', open); }
    helpToggleBtn.addEventListener('click', e => {
      e.stopPropagation();
      setHelpOpen(!helpPopoverEl.classList.contains('open'));
    });
    helpPopoverEl.addEventListener('click', e => e.stopPropagation());
    document.addEventListener('click', () => setHelpOpen(false));
    document.addEventListener('keydown', e => { if (e.key === 'Escape') setHelpOpen(false); });

    document.getElementById('copy-content').addEventListener('click', async () => {
      const text = getCurrentMode(currentFile) === 'code' ? lastCodeText : lastMd;
      if (!text) { setStatus('Nothing to copy yet', 'error'); return; }
      try {
        await navigator.clipboard.writeText(text);
        setStatus('Copied contents (' + text.length + ' chars)', 'success');
      } catch (e) {
        setStatus('Copy failed: ' + e.message, 'error');
      }
    });

    function ensureFileButton(path) {
      if (fileBtns.find(b => b.dataset.file === path)) return;
      const btn = document.createElement('button');
      btn.type = 'button'; btn.dataset.file = path;
      btn.textContent = path.split('/').pop();
      btn.addEventListener('click', e => {
        if ((e.metaKey || e.ctrlKey) && e.altKey) { e.preventDefault(); openInSplit(path); return; }
        delete fileMode[path]; openFile(path);
      });
      document.getElementById('file-toggle').appendChild(btn);
      fileBtns.push(btn);
    }

    function candidatePaths(relPath, baseDir) {
      const seen = new Set();
      const out = [];
      const push = p => { if (p && !seen.has(p)) { seen.add(p); out.push(p); } };
      if (baseDir) push(resolveRelative(relPath, baseDir));
      for (const r of ASSET_ROOTS) push(resolveRelative(relPath, r));
      return out;
    }

    function tryMdCandidates(candidates, idx, push) {
      if (idx >= candidates.length) {
        setStatus('file not found in any allowed root', 'error');
        return;
      }
      const path = candidates[idx];
      setStatus('Loading…');
      fetch('/md?path=' + encodeURIComponent(path))
        .then(r => {
          if (r.status === 404 || r.status === 403) { tryMdCandidates(candidates, idx + 1, push); return; }
          if (!r.ok) throw new Error('HTTP ' + r.status);
          return r.text().then(md => {
            if (push !== false) pushView({type:'md', path:path});
            fileMode[path] = 'md';
            currentFile = path;
            ensureFileButton(path);
            fileBtns.forEach(b => b.classList.toggle('active', b.dataset.file === path));
            buildBreadcrumb(path);
            renderMd(md);
            setStatus('Loaded: ' + path.split('/').pop() + '  (' + new Date().toLocaleTimeString() + ')');
          });
        })
        .catch(e => { setStatus(e.message || e, 'error'); });
    }

    function loadMdFile(relPath, baseDir, push) {
      tryMdCandidates(candidatePaths(relPath, baseDir), 0, push);
    }

    function renderCodeView(path, ext, text) {
      const name = path.split('/').pop();
      const hljsLang = HLJS_LANG_ALIAS[ext] || ext;

      // populate code toolbar in header slot
      codeToolbarSlot.style.display = 'flex';
      codeToolbarSlot.innerHTML =
        '<span class="code-name">' + escapeHtml(name) + '</span>' +
        '<span class="code-lang">' + escapeHtml(ext) + '</span>' +
        '<span style="flex:1"></span>' +
        '<button class="code-btn' + (codeViewOpts.lineNumbers?' active':'') + '" data-toggle="lineNumbers" title="Line numbers">#</button>' +
        '<button class="code-btn' + (codeViewOpts.wrap?' active':'') + '" data-toggle="wrap" title="Wrap">↵</button>';

      content.classList.add('code-view');
      content.innerHTML =
        '<pre class="' + (codeViewOpts.wrap?'wrap':'') + '">' +
        '<code class="language-' + hljsLang + '">' + escapeHtml(text) + '</code></pre>';

      if (window.hljs) {
        content.querySelectorAll('pre code').forEach(el => {
          window.hljs.highlightElement(el);
          if (codeViewOpts.lineNumbers && window.hljs.lineNumbersBlock) {
            window.hljs.lineNumbersBlock(el);
          }
        });
      }

      lastCodeText = text;
      codeToolbarSlot.querySelectorAll('[data-toggle]').forEach(b => {
        b.addEventListener('click', () => {
          const k = b.dataset.toggle;
          codeViewOpts[k] = !codeViewOpts[k];
          localStorage.setItem('mdpreview.' + k, String(codeViewOpts[k]));
          renderCodeView(path, ext, text);
        });
      });

      updateViewToggle();
    }

    function tryCodeCandidates(candidates, ext, idx, push) {
      if (idx >= candidates.length) {
        setStatus('file not found in any allowed root', 'error');
        return;
      }
      const path = candidates[idx];
      setStatus('Loading…');
      fetch('/asset?path=' + encodeURIComponent(path))
        .then(r => {
          if (r.status === 404 || r.status === 403) { tryCodeCandidates(candidates, ext, idx + 1, push); return; }
          if (!r.ok) throw new Error('HTTP ' + r.status);
          return r.text().then(text => {
            if (push !== false) pushView({type:'code', path:path, ext:ext});
            fileMode[path] = 'code';
            currentFile = path;
            ensureFileButton(path);
            fileBtns.forEach(b => b.classList.toggle('active', b.dataset.file === path));
            buildBreadcrumb(path);
            renderCodeView(path, ext, text);
            setStatus('Loaded: ' + path.split('/').pop() + '  (code, ' + ext + ')  (' + new Date().toLocaleTimeString() + ')');
          });
        })
        .catch(e => { setStatus(e.message || e, 'error'); });
    }

    function loadCodeFile(relPath, ext, baseDir, push) {
      tryCodeCandidates(candidatePaths(relPath, baseDir), ext, 0, push);
    }

    // targetSplit=true → plain click navigates within split panel; false → main view
    function rewriteLinks(container, baseFile, targetSplit) {
      const ref = baseFile || currentFile;
      const baseDir = ref.substring(0, ref.lastIndexOf('/'));
      container.querySelectorAll('a[href]').forEach(a => {
        const href = a.getAttribute('href');
        if (!href) return;
        const hashIdx = href.indexOf('#');
        const pathPart = hashIdx >= 0 ? href.substring(0, hashIdx) : href;
        const frag    = hashIdx >= 0 ? href.substring(hashIdx) : '';
        const cleanPath = pathPart.split('?')[0];
        if (!cleanPath) return;
        const ext = extOf(cleanPath);
        if (isAbsoluteFsPath(cleanPath)) {
          if (!TEXT_EXTS.has(ext)) {
            a.href = '/asset?path=' + encodeURIComponent(cleanPath) + frag;
            a.target = '_blank';
            a.rel = 'noopener noreferrer';
            a.title = 'Open: ' + cleanPath;
          } else {
            a.removeAttribute('target');
            a.removeAttribute('rel');
            a.addEventListener('click', e => {
              if ((e.metaKey || e.ctrlKey) && e.altKey) {
                e.preventDefault();
                openInSplit(cleanPath, ext);
                return;
              }
              if (e.metaKey || e.ctrlKey || e.shiftKey) {
                e.preventDefault();
                window.open(urlForState({type: getCurrentMode(cleanPath), path: cleanPath, ext: ext}), '_blank', 'noopener');
                return;
              }
              e.preventDefault();
              if (targetSplit) openInSplit(cleanPath, ext);
              else             openFile(cleanPath);
            });
          }
          return;
        }
        if (cleanPath[0] === '/' && !isRelativeUrl(href)) {
          a.href = '/open?path=' + encodeURIComponent(cleanPath);
          a.target = '_blank';
          a.rel = 'noopener noreferrer';
          a.title = 'Open externally: ' + cleanPath;
          return;
        }
        if (!isRelativeUrl(href)) return;
        if (!TEXT_EXTS.has(ext)) {
          const cands = candidatePaths(cleanPath, baseDir);
          if (cands.length === 0) return;
          a.href = '/asset?path=' + encodeURIComponent(cands[0]) + frag;
          a.target = '_blank';
          a.rel = 'noopener noreferrer';
          a.title = 'Open: ' + cands[0];
          return;
        }
        a.removeAttribute('target');
        a.removeAttribute('rel');
        a.addEventListener('click', e => {
          if ((e.metaKey || e.ctrlKey) && e.altKey) {
            e.preventDefault();
            loadInSplit(cleanPath, baseDir, ext);
            return;
          }
          if (e.metaKey || e.ctrlKey || e.shiftKey) {
            e.preventDefault();
            const cands = candidatePaths(cleanPath, baseDir);
            if (!cands.length) return;
            window.open(urlForState({type: MD_EXTS.has(ext) ? 'md' : 'code', path: cands[0], ext: ext}), '_blank', 'noopener');
            return;
          }
          e.preventDefault();
          if (targetSplit) {
            loadInSplit(cleanPath, baseDir, ext);
          } else {
            if (MD_EXTS.has(ext)) loadMdFile(cleanPath, baseDir);
            else                  loadCodeFile(cleanPath, ext, baseDir);
          }
        });
      });
    }

    function rewriteImgSrcs(container, baseFile) {
      const ref = baseFile || currentFile;
      const baseDir = ref.substring(0, ref.lastIndexOf('/'));
      container.querySelectorAll('img[src]').forEach(img => {
        const src = img.getAttribute('src');
        if (!src) return;
        if (isAbsoluteFsPath(src)) {
          img.setAttribute('src', '/asset?path=' + encodeURIComponent(src));
          return;
        }
        if (!isRelativeUrl(src)) return;
        const primary = baseDir ? resolveRelative(src, baseDir) : null;
        if (primary) {
          img.setAttribute('src', '/asset?path=' + encodeURIComponent(primary));
        }
        const fallbacks = ASSET_ROOTS
          .filter(r => !baseDir || r !== baseDir)
          .map(r => resolveRelative(src, r))
          .filter(Boolean);
        if (fallbacks.length > 0) {
          let idx = 0;
          img.onerror = function () {
            if (idx < fallbacks.length) {
              img.src = '/asset?path=' + encodeURIComponent(fallbacks[idx++]);
            } else {
              img.onerror = null;
            }
          };
        }
      });
    }

    function renderMd(md) {
      lastMd = md;
      content.classList.remove('code-view');
      content.innerHTML = renderers[currentProvider](md);
      content.querySelectorAll('a').forEach(a => { a.target='_blank'; a.rel='noopener noreferrer'; });
      rewriteImgSrcs(content);
      rewriteLinks(content);
      updateViewToggle(); // hides code toolbar slot + syncs Code button
      applyZoom(content);
    }

    function fetchAndRender(file, push) {
      if (push !== false) {
        pushView({type:'md', path:file});
      } else {
        history.replaceState({type:'md', path:file}, '', urlForState({type:'md', path:file}));
      }
      currentFile = file;
      fileBtns.forEach(b => b.classList.toggle('active', b.dataset.file === file));
      setStatus('Loading…');
      fetch('/md?path=' + encodeURIComponent(file))
        .then(r => {
          if (!r.ok) throw new Error('HTTP ' + r.status);
          return r.text();
        })
        .then(md => {
          buildBreadcrumb(file);
          renderMd(md);
          setStatus('Loaded: ' + file.split('/').pop() + '  (' + new Date().toLocaleTimeString() + ')');
        })
        .catch(e => { setStatus(e.message, 'error'); });
    }

    // --- breadcrumb ---
    const breadcrumbEl = document.getElementById('breadcrumb');

    function buildBreadcrumb(filePath) {
      // split into segments, last is filename
      const parts = filePath.split('/').filter(Boolean);
      // build cumulative dir paths: parts[0..i] = dir, parts[0..n-1] = file
      breadcrumbEl.innerHTML = '';
      const addSep = () => {
        const s = document.createElement('span');
        s.className = 'bc-sep'; s.textContent = '/';
        breadcrumbEl.appendChild(s);
      };
      // leading slash segment — directory: open file tree
      const root = document.createElement('span');
      root.className = 'bc-seg'; root.textContent = '/';
      root.title = '/';
      root.addEventListener('click', () => openTreeAt('/'));
      breadcrumbEl.appendChild(root);

      parts.forEach((seg, i) => {
        addSep();
        const absPath = '/' + parts.slice(0, i + 1).join('/');
        const isLast = i === parts.length - 1;
        const span = document.createElement('span');
        span.textContent = seg;
        if (isLast) {
          // current file — non-clickable label
          span.className = 'bc-seg bc-current';
          span.title = absPath;
        } else {
          // intermediate dir segment — open file tree at this dir
          span.className = 'bc-seg';
          span.title = absPath;
          span.addEventListener('click', () => openTreeAt(absPath));
        }
        breadcrumbEl.appendChild(span);
      });
    }

    // --- file tree panel ---
    const treePanel    = document.getElementById('tree-panel');
    const treeOverlay  = document.getElementById('tree-overlay');
    const treeDirLabel = document.getElementById('tree-dir-label');
    const treeList     = document.getElementById('tree-list');
    const treeSearch   = document.getElementById('tree-search');
    const treeCloseBtn = document.getElementById('tree-close');

    let treeCurrentDir = '';
    let treeEntries    = []; // [{name, isDir, absPath}]

    const treeOpenersEl = document.getElementById('tree-openers');

    function buildOpenerLinks(path) {
      const enc = encodeURIComponent(path);
      const openers = [
        { label: 'Finder',   href: '/open?path=' + enc },
        { label: 'VSCode',   href: 'vscode://file' + path },
        { label: 'Cursor',   href: 'cursor://file' + path },
        { label: 'Obsidian', href: 'obsidian://open?path=' + enc },
      ];
      treeOpenersEl.style.display = 'flex';
      treeOpenersEl.innerHTML = '<span style="margin-right:4px">Open:</span>' +
        openers.map(o =>
          '<a href="' + escapeHtml(o.href) + '" target="_blank" rel="noopener noreferrer">' +
          escapeHtml(o.label) + '</a>'
        ).join(' ');
    }

    function openTreeAt(dirPath) {
      treeCurrentDir = dirPath;
      treeDirLabel.textContent = dirPath;
      treeDirLabel.title = dirPath;
      treeSearch.value = '';
      treeList.innerHTML = '<span style="padding:8px 12px;color:var(--muted);font-size:12px">Loading…</span>';
      treePanel.classList.add('open');
      treeOverlay.classList.add('open');
      buildOpenerLinks(dirPath);
      treeSearch.focus();

      fetch('/ls?path=' + encodeURIComponent(dirPath))
        .then(r => r.ok ? r.json() : Promise.reject('HTTP ' + r.status))
        .then(data => {
          treeEntries = [];
          // parent dir entry (unless at root)
          if (dirPath !== '/') {
            const parent = dirPath.substring(0, dirPath.lastIndexOf('/')) || '/';
            treeEntries.push({name: '..', isDir: true, absPath: parent});
          }
          data.dirs.forEach(n  => treeEntries.push({name: n,  isDir: true,  absPath: dirPath.replace(/\/$/, '') + '/' + n}));
          data.files.forEach(n => treeEntries.push({name: n,  isDir: false, absPath: dirPath.replace(/\/$/, '') + '/' + n}));
          renderTreeList('');
        })
        .catch(e => {
          treeList.innerHTML =
            '<div style="padding:10px 12px;font-size:12px;color:#cf222e">Error: ' +
            escapeHtml(String(e)) + '</div>';
        });
    }

    function renderTreeList(query) {
      const q = query.toLowerCase().trim();
      treeList.innerHTML = '';
      const filtered = q
        ? treeEntries.filter(e => e.name.toLowerCase().includes(q))
        : treeEntries;
      if (filtered.length === 0) {
        treeList.innerHTML = '<span style="padding:8px 12px;color:var(--muted);font-size:12px">No results</span>';
        return;
      }
      filtered.forEach(entry => {
        const row = document.createElement('div');
        const isTxt = TEXT_EXTS.has(extOf(entry.name));
        if (entry.isDir) {
          row.className = 'tree-item tree-dir-item';
        } else {
          row.className = 'tree-item tree-file-item' + (isTxt ? ' text-file' : '');
        }
        if (q && entry.name.toLowerCase().includes(q)) row.classList.add('match-hl');

        const icon = document.createElement('span');
        icon.className = 'ti-icon';
        icon.textContent = entry.isDir ? '▶' : (isTxt ? '◦' : '·');
        row.appendChild(icon);

        const label = document.createElement('span');
        label.style.overflow = 'hidden';
        label.style.textOverflow = 'ellipsis';
        // highlight matching fragment
        if (q) {
          const idx = entry.name.toLowerCase().indexOf(q);
          if (idx >= 0) {
            label.innerHTML =
              escapeHtml(entry.name.slice(0, idx)) +
              '<mark style="background:var(--active-bg);color:var(--active-text);border-radius:2px">' +
              escapeHtml(entry.name.slice(idx, idx + q.length)) + '</mark>' +
              escapeHtml(entry.name.slice(idx + q.length));
          } else {
            label.textContent = entry.name;
          }
        } else {
          label.textContent = entry.name;
        }
        row.appendChild(label);
        row.title = entry.absPath;

        row.addEventListener('click', () => {
          if (entry.isDir) {
            openTreeAt(entry.absPath);
          } else {
            closeTree();
            // open via unified openFile — reset mode so defaults apply
            delete fileMode[entry.absPath];
            ensureFileButton(entry.absPath);
            openFile(entry.absPath);
          }
        });

        treeList.appendChild(row);
      });
    }

    function closeTree() {
      treePanel.classList.remove('open');
      treeOverlay.classList.remove('open');
      treeOpenersEl.style.display = 'none';
    }

    treeCloseBtn.addEventListener('click', closeTree);
    treeOverlay.addEventListener('click', closeTree);
    treeSearch.addEventListener('input', () => renderTreeList(treeSearch.value));
    treeSearch.addEventListener('keydown', e => {
      if (e.key === 'Escape') closeTree();
    });

    // --- event listeners ---

    // file tab buttons — reset to natural default mode so code files always open in code view
    fileBtns.forEach(b => b.addEventListener('click', e => {
      if ((e.metaKey || e.ctrlKey) && e.altKey) {
        e.preventDefault();
        openInSplit(b.dataset.file);
        return;
      }
      delete fileMode[b.dataset.file];
      openFile(b.dataset.file);
    }));

    // renderer buttons — when in code mode, clicking a renderer switches file to MD
    rendererBtns.forEach(b => {
      if (!renderers[b.dataset.provider]) { b.disabled = true; b.title = 'Library failed to load'; }
      b.addEventListener('click', () => {
        currentProvider = b.dataset.provider;
        rendererBtns.forEach(x => x.classList.toggle('active', x.dataset.provider === currentProvider));
        if (getCurrentMode(currentFile) === 'code') {
          // user picked a renderer while in code view → switch to MD
          fileMode[currentFile] = 'md';
          fetchAndRender(currentFile, false);
        } else {
          renderMd(lastMd);
        }
      });
    });

    // Code toggle button — flips current file between code and MD view
    codeModeToggleBtn.addEventListener('click', () => {
      const newMode = getCurrentMode(currentFile) === 'code' ? 'md' : 'code';
      fileMode[currentFile] = newMode;
      openFile(currentFile, false); // replaceState, don't push
    });

    darkBtn.addEventListener('click', () => setDark(!document.body.classList.contains('dark')));

    // browser back/forward — restore mode from history state
    window.addEventListener('popstate', e => {
      if (!e.state) return;
      const s = e.state;
      fileMode[s.path] = s.type; // 'md' or 'code'
      if (s.type === 'md') fetchAndRender(s.path, false);
      else loadCodeFile(s.path, s.ext || extOf(s.path), '', false);
    });

    // header collapse
    const headerEl = document.querySelector('header');
    const peekBtn  = document.getElementById('peek');
    const headerToggleBtn = document.getElementById('header-toggle');
    function setHeaderCollapsed(v) {
      document.body.classList.toggle('header-collapsed', v);
      localStorage.setItem('mdpreview.headerCollapsed', String(v));
    }
    headerToggleBtn.addEventListener('click', () => setHeaderCollapsed(true));
    peekBtn.addEventListener('click', () => setHeaderCollapsed(false));
    if (localStorage.getItem('mdpreview.headerCollapsed') === 'true') {
      document.body.classList.add('header-collapsed');
    }

    // Ctrl/Cmd+A scoped to #content only
    document.addEventListener('keydown', e => {
      const tag = (document.activeElement && document.activeElement.tagName) || '';
      const inInput = tag === 'INPUT' || tag === 'TEXTAREA';
      // Cmd/Ctrl+A → select all content
      if ((e.metaKey || e.ctrlKey) && e.key === 'a' && !e.shiftKey && !e.altKey) {
        if (inInput) return;
        e.preventDefault();
        const sel = window.getSelection();
        const range = document.createRange();
        range.selectNodeContents(content);
        sel.removeAllRanges();
        sel.addRange(range);
        return;
      }
      // Cmd/Ctrl+B → toggle header
      if ((e.metaKey || e.ctrlKey) && e.key === 'b' && !e.shiftKey && !e.altKey) {
        if (inInput) return;
        e.preventDefault();
        setHeaderCollapsed(!document.body.classList.contains('header-collapsed'));
        return;
      }
      // Cmd/Ctrl+E → open file explorer at current file's dir
      if ((e.metaKey || e.ctrlKey) && e.key === 'e' && !e.shiftKey && !e.altKey) {
        if (inInput) return;
        e.preventDefault();
        const dir = currentFile.substring(0, currentFile.lastIndexOf('/')) || '/';
        openTreeAt(dir);
        return;
      }
      // Alt+1 → maximize left (main) pane; Alt+2 → maximize right (split) pane
      if (e.altKey && !e.metaKey && !e.ctrlKey && !e.shiftKey) {
        if (e.key === '1') {
          if (inInput || !splitOpen || splitMin) return;
          e.preventDefault();
          if (splitMaximized) { setSplitMaximized(false); } else { setSplitWidth(240); }
          return;
        }
        if (e.key === '2') {
          if (inInput || !splitOpen) return;
          e.preventDefault();
          if (splitMin) setSplitMin(false);
          setSplitMaximized(!splitMaximized);
          return;
        }
      }
    });

    // --- alt+right-click context menu ---
    const SG_URL = 'https://agoda.sourcegraphcloud.com/search?patternType=keyword&df=%%5B%%22type%%22%%2C%%22Code%%22%%2C%%22type%%3Afile%%22%%5D&__cc=1&q=context%%3Ano-fork+highlighttext';
    const GLEAN_URL = 'https://agoda.glean.com/search?q=';
    let ctxMenuEl = null;
    function closeCtxMenu() { if (ctxMenuEl) { ctxMenuEl.remove(); ctxMenuEl = null; } }
    function openCtxMenu(x, y, sel) {
      closeCtxMenu();
      const enc = encodeURIComponent(sel);
      const sgHref    = SG_URL.replace('highlighttext', enc);
      const gleanHref = GLEAN_URL + enc;
      const preview   = escapeHtml(sel.slice(0, 40)) + (sel.length > 40 ? '&hellip;' : '');
      ctxMenuEl = document.createElement('div');
      ctxMenuEl.id = 'ctx-menu';
      ctxMenuEl.innerHTML =
        '<button data-act="sg">&#x1F50D; Sourcegraph: &ldquo;' + preview + '&rdquo;</button>' +
        '<button data-act="glean">&#x1F50D; Glean: &ldquo;' + preview + '&rdquo;</button>';
      ctxMenuEl.style.left = x + 'px';
      ctxMenuEl.style.top  = y + 'px';
      ctxMenuEl.addEventListener('click', ev => {
        const act = ev.target.dataset && ev.target.dataset.act;
        if (act === 'sg')    window.open(sgHref,    '_blank', 'noopener');
        if (act === 'glean') window.open(gleanHref, '_blank', 'noopener');
        closeCtxMenu();
      });
      document.body.appendChild(ctxMenuEl);
    }
    content.addEventListener('contextmenu', e => {
      if (!e.altKey) return;
      const sel = (window.getSelection() || '').toString().trim();
      if (!sel) return;
      e.preventDefault();
      openCtxMenu(e.clientX, e.clientY, sel);
    });
    document.addEventListener('click',   closeCtxMenu);
    document.addEventListener('keydown', e => { if (e.key === 'Escape') closeCtxMenu(); });

    // --- split pane (Alt+Cmd+click target) ---
    const splitPane     = document.getElementById('split-pane');
    const splitDivider  = document.getElementById('split-divider');
    const splitContent  = document.getElementById('split-content');
    const splitNameEl   = document.getElementById('split-name');
    const splitMinBtn   = document.getElementById('split-min-btn');
    const splitCloseBtn = document.getElementById('split-close-btn');

    let splitFile  = '';
    let splitOpen  = false;
    let splitMin   = false;
    let splitWidth = parseInt(localStorage.getItem('mdpreview.splitWidth') || '480', 10);
    splitWidth = Math.max(240, Math.min(1200, isNaN(splitWidth) ? 480 : splitWidth));
    document.documentElement.style.setProperty('--split-width', splitWidth + 'px');

    function persistSplit() {
      localStorage.setItem('mdpreview.splitOpen',  String(splitOpen));
      localStorage.setItem('mdpreview.splitMin',   String(splitMin));
      localStorage.setItem('mdpreview.splitWidth', String(splitWidth));
      localStorage.setItem('mdpreview.splitFile',  splitFile || '');
    }
    function setSplitOpen(v) {
      splitOpen = !!v;
      document.body.classList.toggle('split-open', splitOpen);
      if (!splitOpen) { splitMin = false; document.body.classList.remove('split-min'); }
      persistSplit();
    }
    function setSplitMin(v) {
      splitMin = !!v;
      document.body.classList.toggle('split-min', splitMin);
      persistSplit();
    }

    function renderMdInSplit(md, sourcePath) {
      splitContent.classList.remove('code-view');
      splitContent.innerHTML = renderers[currentProvider](md);
      rewriteImgSrcs(splitContent, sourcePath);
      rewriteLinks(splitContent, sourcePath, true); // targetSplit=true → plain click navigates in split
    }
    function renderCodeInSplit(path, ext, text) {
      const hljsLang = HLJS_LANG_ALIAS[ext] || ext;
      splitContent.classList.add('code-view');
      splitContent.innerHTML =
        '<pre class="' + (codeViewOpts.wrap ? 'wrap' : '') + '">' +
        '<code class="language-' + hljsLang + '">' + escapeHtml(text) + '</code></pre>';
      if (window.hljs) {
        splitContent.querySelectorAll('pre code').forEach(el => {
          window.hljs.highlightElement(el);
          if (codeViewOpts.lineNumbers && window.hljs.lineNumbersBlock) {
            window.hljs.lineNumbersBlock(el);
          }
        });
      }
    }

    // Try each resolved candidate in turn — mirrors tryMdCandidates / tryCodeCandidates for split
    function loadInSplit(relPath, baseDir, ext) {
      const cands = candidatePaths(relPath, baseDir);
      if (!cands.length) { openInSplit(relPath, ext); return; } // let openInSplit show the error
      const isMd = MD_EXTS.has(ext || extOf(relPath));
      const endpoint = isMd ? '/md' : '/asset';
      function tryNext(idx) {
        if (idx >= cands.length) { openInSplit(cands[0], ext); return; } // show error on first candidate
        fetch(endpoint + '?path=' + encodeURIComponent(cands[idx]))
          .then(r => {
            if (r.status === 404 || r.status === 403) { tryNext(idx + 1); return; }
            if (!r.ok) { openInSplit(cands[0], ext); return; }
            openInSplit(cands[idx], ext); // resolved — hand off to openInSplit with known-good absolute path
          })
          .catch(() => tryNext(idx + 1));
      }
      tryNext(0);
    }

    function splitError(msg) {
      splitContent.classList.remove('code-view');
      splitContent.innerHTML =
        '<div style="padding:16px;font-size:12px">' +
        '<p style="color:#cf222e;font-weight:600;margin:0 0 6px">Not found</p>' +
        '<p style="color:var(--muted);margin:0">' + escapeHtml(msg) + '</p>' +
        '<p style="margin:8px 0 0"><button class="split-open-tree" style="font-size:12px;padding:3px 8px;border:1px solid var(--border);border-radius:4px;background:var(--panel-bg);color:var(--link);cursor:pointer">Browse files…</button></p>' +
        '</div>';
      splitContent.querySelector('.split-open-tree') &&
        splitContent.querySelector('.split-open-tree').addEventListener('click', () => {
          const dir = (splitFile || currentFile).substring(0, (splitFile || currentFile).lastIndexOf('/')) || '/';
          openTreeAt(dir);
        });
    }

    function openInSplit(path, ext) {
      if (!path) return;
      // resolve relative path against current file's directory
      if (!path.startsWith('/')) {
        const baseDir = currentFile.substring(0, currentFile.lastIndexOf('/'));
        const cands = candidatePaths(path, baseDir);
        if (!cands.length) { setSplitOpen(true); splitFile = path; splitNameEl.textContent = path; splitNameEl.title = path; splitError(path); return; }
        path = cands[0];
      }
      splitFile = path;
      setSplitOpen(true);
      setSplitMin(false);
      const fname = path.split('/').pop();
      splitNameEl.textContent = fname;
      splitNameEl.title = path;
      const ext2 = ext || extOf(path);
      const isText = TEXT_EXTS.has(ext2);
      const isMd   = MD_EXTS.has(ext2);
      // disable code-mode toggle for non-MD text (already in code view) and non-text (image etc.)
      splitCodeBtn.style.display = isMd ? '' : 'none';
      if (!splitFileMode[path]) splitFileMode[path] = isMd ? 'md' : 'code';
      updateSplitCodeBtn();
      splitContent.innerHTML = '<p style="padding:16px;color:var(--muted);font-size:12px">Loading…</p>';
      if (isMd && splitFileMode[path] !== 'code') {
        fetch('/md?path=' + encodeURIComponent(path))
          .then(r => { if (r.status === 404 || r.status === 403) throw new Error('Not found: ' + path); if (!r.ok) throw new Error('HTTP ' + r.status); return r.text(); })
          .then(md => renderMdInSplit(md, path))
          .catch(err => splitError(err.message || String(err)));
      } else if (isText) {
        fetch('/asset?path=' + encodeURIComponent(path))
          .then(r => { if (r.status === 404 || r.status === 403) throw new Error('Not found: ' + path); if (!r.ok) throw new Error('HTTP ' + r.status); return r.text(); })
          .then(text => renderCodeInSplit(path, ext2, text))
          .catch(err => splitError(err.message || String(err)));
      } else {
        // binary asset (image, pdf) — embed via /asset
        splitContent.classList.remove('code-view');
        splitContent.innerHTML = '<img src="/asset?path=' + encodeURIComponent(path) + '" alt="' + escapeHtml(path) + '" style="max-width:100%%;height:auto"/>';
      }
      persistSplit();
      setStatus('Split: ' + fname, 'success');
    }

    const splitMaxBtn  = document.getElementById('split-max-btn');
    const splitCodeBtn = document.getElementById('split-code-btn');

    // split view mode: 'md' or 'code' — persists per splitFile
    const splitFileMode = {};
    let splitMaximized = false;
    let splitPrevWidth = 480; // remembers width before maximizing

    function setSplitMaximized(v) {
      splitMaximized = !!v;
      if (splitMaximized) {
        splitPrevWidth = splitWidth;
        const mainW = document.querySelector('main').getBoundingClientRect().width;
        setSplitWidth(Math.max(240, mainW - 260));
      } else {
        setSplitWidth(splitPrevWidth);
      }
      splitMaxBtn.title = splitMaximized ? 'Restore split panel (Alt+2)' : 'Maximize split panel (Alt+2)';
      splitMaxBtn.innerHTML = splitMaximized ? '&#x2923;' : '&#x2922;';
    }

    function updateSplitCodeBtn() {
      const isCode = splitFileMode[splitFile] === 'code';
      splitCodeBtn.classList.toggle('active', isCode);
      splitCodeBtn.title = isCode ? 'Switch to rendered view' : 'Toggle code / MD view';
    }

    function reloadSplitWithMode() {
      if (!splitFile) return;
      const ext2 = extOf(splitFile);
      const isCode = splitFileMode[splitFile] === 'code';
      if (isCode || (TEXT_EXTS.has(ext2) && !MD_EXTS.has(ext2))) {
        fetch('/asset?path=' + encodeURIComponent(splitFile))
          .then(r => { if (!r.ok) throw new Error('HTTP ' + r.status); return r.text(); })
          .then(text => renderCodeInSplit(splitFile, ext2, text))
          .catch(err => splitError(err.message || String(err)));
      } else {
        fetch('/md?path=' + encodeURIComponent(splitFile))
          .then(r => { if (!r.ok) throw new Error('HTTP ' + r.status); return r.text(); })
          .then(md => renderMdInSplit(md, splitFile))
          .catch(err => splitError(err.message || String(err)));
      }
      updateSplitCodeBtn();
    }

    splitCodeBtn.addEventListener('click', e => {
      e.stopPropagation();
      const ext2 = extOf(splitFile);
      const isMd = MD_EXTS.has(ext2);
      const isCurrentlyCode = splitFileMode[splitFile] === 'code';
      // MD files toggle between md and code; code-only files stay in code
      if (!isMd) return;
      splitFileMode[splitFile] = isCurrentlyCode ? 'md' : 'code';
      reloadSplitWithMode();
    });

    splitMaxBtn.addEventListener('click',  e => { e.stopPropagation(); setSplitMaximized(!splitMaximized); });
    splitCloseBtn.addEventListener('click', e => { e.stopPropagation(); splitFile = ''; splitContent.innerHTML = ''; splitMaximized = false; setSplitOpen(false); });
    splitMinBtn.addEventListener('click',   e => { e.stopPropagation(); setSplitMin(true); });

    // double-click on free space in header bar → toggle maximize
    document.getElementById('split-header').addEventListener('dblclick', e => {
      if (e.target.closest('button')) return; // ignore dblclick on buttons
      setSplitMaximized(!splitMaximized);
    });

    splitPane.addEventListener('click', () => {
      // when minimized, clicking anywhere on the strip restores
      if (splitMin) setSplitMin(false);
    });

    function setSplitWidth(w) {
      splitWidth = Math.max(240, Math.min(1200, w));
      document.documentElement.style.setProperty('--split-width', splitWidth + 'px');
      persistSplit();
    }
    // double-click divider → 50/50 split
    splitDivider.addEventListener('dblclick', () => {
      const mainW = document.querySelector('main').getBoundingClientRect().width;
      setSplitWidth(Math.round((mainW - 6) / 2));
    });
    splitDivider.addEventListener('mousedown', e => {
      if (e.detail > 1) return; // skip on double-click
      e.preventDefault();
      const startX = e.clientX, startW = splitWidth;
      document.body.style.cursor = 'col-resize';
      document.body.style.userSelect = 'none';
      function onMove(ev) {
        const delta = startX - ev.clientX;
        splitWidth = Math.max(240, Math.min(1200, startW + delta));
        document.documentElement.style.setProperty('--split-width', splitWidth + 'px');
      }
      function onUp() {
        document.removeEventListener('mousemove', onMove);
        document.removeEventListener('mouseup', onUp);
        document.body.style.cursor = '';
        document.body.style.userSelect = '';
        persistSplit();
      }
      document.addEventListener('mousemove', onMove);
      document.addEventListener('mouseup', onUp);
    });

    // restore split state on load
    if (localStorage.getItem('mdpreview.splitOpen') === 'true') {
      const savedFile = localStorage.getItem('mdpreview.splitFile') || '';
      const wantMin   = localStorage.getItem('mdpreview.splitMin') === 'true';
      if (savedFile) {
        openInSplit(savedFile);
        if (wantMin) setSplitMin(true);
      }
    }

    // SSE live reload
    const evtSrc = new EventSource('/events');
    evtSrc.addEventListener('reload', () => {
      openFile(currentFile, false);
      if (splitOpen && splitFile) openInSplit(splitFile);
    });

    setDark(true);

    // init: respect URL state (cmd+click new tab) or load default
    const initState = readUrlState();
    if (initState) {
      fileMode[initState.path] = initState.type;
      if (initState.type === 'md') fetchAndRender(initState.path, false);
      else loadCodeFile(initState.path, initState.ext || extOf(initState.path), '', false);
    } else {
      openFile(currentFile, false);
    }
  </script>
</body>
</html>]],
    file_buttons_html,
    port,
    roots_json,
    initial
  )
end

return M
