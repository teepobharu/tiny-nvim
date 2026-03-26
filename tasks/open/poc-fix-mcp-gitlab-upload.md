---
title: "POC: Fix @zereight/mcp-gitlab upload_markdown (local fork)"
status: "open"
assignee: "user"
created: 2026-03-17
priority: "high"
related:
  - tasks/review/investigate-gitlab-upload-issues.md
  - docs/memory/mcphub.md
---

# POC: Fix mcp-gitlab upload_markdown locally

## Overview

Local fork of `@zereight/mcp-gitlab` with the `upload_markdown` 406 fix applied.
MCP config has a new `gitlab_zz_local` server entry pointing to the local build.

See [investigate-gitlab-upload-issues.md](tasks/review/investigate-gitlab-upload-issues.md) for root cause analysis.

## Fix Applied

**File**: `~/worktrees/zereight-mcp-gitlab/index.ts` (line ~6208)

**Root cause**: `form-data` npm package + `fetch` don't interop correctly for multipart uploads — setting `'Content-Type': undefined` stringifies to `"undefined"` instead of deleting the header, causing HTTP 406.

**Fix**: Replace with Node 18+ native globals (`FormData`, `Blob`, `fetch`):

```diff
- const fileBuffer = fs.readFileSync(filePath);
- const FormData = (await import("form-data")).default;
- const form = new FormData();
- form.append("file", fileBuffer, { filename: fileName, contentType: "..." });
- headers: { ...BASE_HEADERS, ...buildAuthHeaders(), "Content-Type": undefined as any }

+ const { readFile } = await import("fs/promises");
+ const fileBuffer = await readFile(filePath);
+ const form = new FormData();    // Node 18+ global
+ const blob = new Blob([fileBuffer], { type: "application/octet-stream" });
+ form.append("file", blob, fileName);
+ headers: { Accept: "application/json", ...buildAuthHeaders() }
```

## Local Fork Location

```
~/worktree/zereight-mcp-gitlab/
├── index.ts          # Fixed source
└── build/index.js    # Compiled output
```

## MCP Config Entry

Added `gitlab_zz_local` to `~/dotfiles/ai/mcp/mcphub.json`:
- **command**: `node`
- **args**: `["/Users/tharutaipree/worktrees/zereight-mcp-gitlab/build/index.js"]`
- Same env vars as `gitlab_upload` (mirrors its config)

## Rebuild Command

If you edit the source again, rebuild with:
```bash
cd ~/worktree/zereight-mcp-gitlab && npm run build
```

## Verification

### How to verify

1. Enable `gitlab_zz_local` in MCPHub (`:MCPHub` → toggle on)
2. Disable `gitlab_upload` to avoid confusion
3. Test `upload_markdown` tool with a file

### Commands

```bash
# Quick smoke test via curl (should still work as reference)
curl --request POST \
  --header "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
  --form "file=@/tmp/test.txt" \
  "https://gitlab.agodadev.io/api/v4/projects/21676/uploads"
```

Via MCPHub:
```
Tool: gitlab_zz_local__upload_markdown
Args: { "project_id": "full-stack/cart/trips-web", "file_path": "/path/to/file.png" }
```

### Checklist

- [ ] `gitlab_zz_local` server starts successfully in MCPHub
- [ ] `upload_markdown` tool returns HTTP 201 (not 406)
- [ ] Response contains `markdown` field with image/file link
- [ ] Other tools (e.g. `get_merge_request`) still work as expected

## Next Steps

- [ ] If verified: upstream a PR to zereight/gitlab-mcp with the fix
- [ ] If verified: update `docs/memory/mcphub.md` to note working upload tool
</content>
</invoke>