---
title: "Setup GitLab Knowledge Graph (gkg) for codebase indexing"
status: "review"
assignee: "user"
created: 2026-02-24
priority: "medium"
---

# GitLab Knowledge Graph (gkg) - Setup & Investigation

**Docs**: https://gitlab-org.gitlab.io/rust/knowledge-graph/
**Source**: https://gitlab.com/gitlab-org/rust/knowledge-graph
**Status**: Public Beta

---

## Investigation Findings

### 1. Git Project Support (Remote vs Local)

**Works with: LOCAL git repositories only (any origin)**

- `gkg index` operates on **local filesystem paths** - it scans directories for git repos
- It is **git-host agnostic** - works with GitHub, GitLab, Bitbucket, or any origin
- The tool discovers git repos by looking for `.git` directories, not by querying any remote API
- You point it at a local directory (workspace or single repo), and it parses the files on disk
- No remote cloning or fetching is done by gkg itself - you clone first, then index

```bash
# Index a single repo (any git host origin)
cd ~/AgodaGit/trips-web && gkg index

# Index an entire workspace (discovers all git repos inside)
gkg index ~/AgodaGit/
```

**Verdict**: Works with any git project regardless of remote host. It only reads local files.

---

### 2. Auto Index Update Feature

**Available via `--enable-reindexing` flag (experimental)**

- `gkg server start --enable-reindexing` enables file watching on registered workspaces
- Automatically queues re-indexing jobs when files change
- **Caveat**: Currently in active development
  - Ruby cross-file references cause undefined behavior with reindexing
  - All other languages work but marked "use at your own risk" until GA
- Without this flag, re-indexing is **manual** (`gkg index` or via MCP `index_project` tool)
- The MCP tool `index_project` can also trigger re-indexing programmatically

**Verdict**: Auto-update exists but is experimental. Manual re-index is the stable path.

---

### 3. AI Agent Requirements During Index/Setup

**No AI agent connection required - fully local/offline**

- Indexing is done via `tree-sitter` and native Rust parsers (AST-based)
- No calls to OpenAI, Copilot, Claude, or any LLM during indexing
- No API keys needed for setup or indexing
- The tool produces a **structured graph database** that AI agents can then consume via MCP
- The AI integration is on the **consumer side** (agents query gkg), not the producer side

**Verdict**: Zero AI dependencies. Pure static code analysis using tree-sitter.

---

### 4. MCP Tools & MCPHub.nvim Integration

#### Available MCP Tools (7 tools)

| Tool                          | Description                                            |
| ----------------------------- | ------------------------------------------------------ |
| `list_projects`               | List all indexed projects with absolute paths          |
| `search_codebase_definitions` | Search functions, classes, methods by name (paginated) |
| `index_project`               | Trigger re-indexing of a project                       |
| `get_references`              | Find all call sites / usages of a definition           |
| `read_definitions`            | Read full definition bodies for multiple symbols       |
| `get_definition`              | Go-to-definition for a symbol on a specific line       |
| `repo_map`                    | Generate token-efficient ASCII tree + definitions map  |

#### MCP Transport

- **HTTP**: `http://localhost:27495/mcp` (streamable HTTP)
- **SSE**: `http://localhost:27495/mcp/sse` (Server-Sent Events)
- Server runs on port `27495` by default

#### MCPHub.nvim Integration Path

gkg exposes a standard MCP server over HTTP/SSE. To integrate with MCPHub.nvim:

**Option A: SSE endpoint in mcphub.json**

```json
{
  "mcpServers": {
    "gkg": {
      "url": "http://localhost:27495/mcp/sse"
    }
  }
}
```

**Option B: Direct LadybugDB access via KuzuDB MCP**
For direct database queries (Cypher-like), use the KuzuDB MCP server:

```json
{
  "mcpServers": {
    "kuzu-gkg": {
      "command": "docker",
      "args": [
        "run",
        "-v",
        "~/.gkg/gkg_workspace_folders/<hash>/<hash>:/database",
        "-e",
        "KUZU_DB_FILE=database.kz",
        "--rm",
        "-i",
        "kuzudb/mcp-server"
      ]
    }
  }
}
```

**Note**: Only one process can open the database at a time. If using KuzuDB MCP directly, `gkg server` must be stopped.

---

## Supported Languages

| Language   | Definitions & Imports | Intra-file Refs | Cross-file Refs |
| ---------- | --------------------- | --------------- | --------------- |
| Ruby       | yes                   | yes             | yes             |
| Java       | yes                   | yes             | yes             |
| Kotlin     | yes                   | yes             | yes             |
| TypeScript | yes                   | yes             | wip             |
| JavaScript | yes                   | yes             | wip             |
| Python     | yes                   | yes             | wip             |

---

## Setup Steps

### Step 1: Install gkg

```bash
curl -fsSL https://gitlab.com/gitlab-org/rust/knowledge-graph/-/raw/main/install.sh | bash
```

Ensure `~/.local/bin` is in PATH:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Verify:

```bash
gkg -V
```

### Step 2: Index a project

```bash
# Single repo
cd ~/your-project && gkg index --stats

# Or specify path
gkg index ~/AgodaGit/trips-web --stats
```

### Step 3: Start the server

```bash
# Foreground (for testing)
gkg server start

# With auto-reindexing (experimental)
gkg server start --enable-reindexing

# Background/detached
gkg server start --detached
```

Web UI available at: http://localhost:27495

Extension on intellij and VSCODE available

### Step 4: Configure MCP for MCPHub.nvim

Add to mcphub.json (e.g. `~/dotfiles/ai/mcp/mcphub.json`):

```json
{
  "mcpServers": {
    "gkg": {
      "url": "http://localhost:27495/mcp/sse"
    }
  }
}
```

Then in Neovim: `:MCPHub` to verify the server appears.

### Step 5: Test MCP tools

Via CodeCompanion/Avante/CopilotChat, the AI agents can now use:

- "Search for function X in the codebase" -> `search_codebase_definitions`
- "Find all references to Y" -> `get_references`
- "Show me the repo structure" -> `repo_map`
- "Go to definition of Z" -> `get_definition`

### Step 6: (Optional) Re-index after code changes

```bash
# Manual re-index
gkg index ~/your-project

# Or via MCP tool (AI agent can call index_project)
```

---

## MCP Configuration File

gkg has its own MCP settings at `~/.gkg/mcp.settings.json`:

```json
{
  "disabled_tools": []
}
```

You can disable specific tools by adding their names to the array.

---

## Data Storage

All indexed data stored under `~/.gkg/`:

- `gkg_manifest.json` - workspace registry
- `gkg_workspace_folders/<hash>/<hash>/database.kz` - LadybugDB graph database
- `gkg_workspace_folders/<hash>/<hash>/parquet_files/` - Parquet data files

To clean up: `gkg clean` or `gkg remove --workspace /path`

---

## Indexing Results (opencode project)

**Project**: `/Users/tharutaipree/AgodaGit/tools/opencode`
**Index time**: 4.15 seconds
**Stats**: 692 files, 3503 definitions, 4006 imported symbols, 1706 relationships
**Languages**: 682 TypeScript (3319 defs), 10 Rust (184 defs)
**Data**: `~/.gkg/gkg_workspace_folders/9b428a4a09ada084/`

## MCP Server Verification

- Server: `gkg server start --detached` (port 27495)
- Web UI: http://localhost:27495 (Vue.js dashboard)
- MCP HTTP: `http://localhost:27495/mcp` (streamable HTTP, requires `Accept: application/json, text/event-stream`)
- MCP SSE: `http://localhost:27495/mcp/sse`
- Server info: rmcp v0.8.1, protocol 2024-11-05
- **8 tools confirmed**: list_projects, search_codebase_definitions, get_references, read_definitions, get_definition, repo_map, import_usage, index_project

## MCPHub.nvim Config

Added to `~/dotfiles/ai/mcp/mcphub.json`:

```json
"gkg": {
  "autoApprove": ["list_projects", "search_codebase_definitions", "get_references", "read_definitions", "get_definition", "repo_map", "import_usage"],
  "disabled": false,
  "type": "sse",
  "url": "http://localhost:27495/mcp/sse"
}
```

---

## Sample projects index Creation

option 1: index+reindex with UI web
option 2: reindex (index not work project_absolute_path only) with MCP

> caveat: once run gkg server cmd; gkg index CLI cmd not work need to stop or use 2 option above ?
> what about refreshing

For Nvim:

prompts

@{gkg}
re/index these projects:
/Users/tharutaipree/.local/share/nvim3_jelly_tinynvim/lazy/avante.nvim
/Users/tharutaipree/.local/share/nvim3_jelly_tinynvim/lazy/codecompanion.nvim
/Users/tharutaipree/.local/share/nvim3_jelly_tinynvim/lazy/snacks.nvim

--- 
/Users/tharutaipree/AgodaGit/fe/trips-web/apps/trip-view-bff/
/Users/tharutaipree/AgodaGit/fe/trips-web/apps/clientside/Agoda.Cronos.Cart.ClientSide/
/Users/tharutaipree/AgodaGit/fe/trips-web/libs/saved
/Users/tharutaipree/AgodaGit/fe/trips-web/libs/cart

## Checklist

- [x] Install gkg and verify on macOS (v0.24.0 at ~/.local/bin/gkg)
- [x] Index a test project and evaluate speed/quality (opencode: 4.15s, 3503 defs)
- [x] Start gkg server and verify MCP endpoint (8 tools, rmcp v0.8.1)
- [x] Add gkg to mcphub.json config (SSE endpoint)
- [ ] Verify gkg appears in MCPHub.nvim UI (`:MCPHub`)
- [ ] Evaluate usefulness of `repo_map` tool for AI context
- [ ] Test `--enable-reindexing` with TypeScript projects
- [ ] Consider adding gkg server start to shell startup / launchd
- [ ] Index additional projects (trips-web, etc.)
