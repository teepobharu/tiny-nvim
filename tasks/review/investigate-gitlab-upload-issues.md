---
title: "Investigate GitLab upload_markdown and glab API upload failures"
status: "review"
assignee: "user"
created: 2026-02-20
priority: "high"
---

# Investigate GitLab Upload Issues

## Overview

Two related issues with GitLab file uploads need investigation:
1. MCPHub `upload_markdown` tool not working
2. `glab api` upload endpoint failing

## Test Case

**File**: `/Users/tharutaipree/Downloads/Screenshot/Screen Recording 2026-02-20 at 13.29.24.mov`
**Project**: `full-stack/cart/trips-web`

## Issues to Investigate

### 1. MCPHub upload_markdown Tool Failure

**Tool**: `mcphub_gitlab_z__upload_markdown`
**Symptoms**: Tool not working (exact error unknown)
**Expected**: Upload file and return markdown link

**Test Parameters**:
```json
{
  "project_id": "full-stack/cart/trips-web",
  "file_path": "/Users/tharutaipree/Downloads/Screenshot/Screen Recording 2026-02-20 at 13.29.24.mov"
}
```

### 2. glab API Upload Endpoint Failure

**Commands Tested** (both failing):

```bash
# glab CLI approach
glab api --method POST "projects/$project_id/uploads" -F "file=@./screenshot.png"

# Direct curl approach
curl -s --request POST \
  --form "file=@./screenshot.png" \
  "https://gitlab.agodadev.io/api/v4/projects/$project_id/uploads"
```

**Endpoint**: `/projects/{id}/uploads`
**Method**: POST with multipart/form-data

## Investigation Results ✅

### Root Cause Identified

The **406 Not Acceptable** error from the MCPHub `upload_markdown` tool is a known issue with the `@zereight/mcp-gitlab` package when sending multipart/form-data uploads. The exact same issue was reported in [GitHub Issue #330](https://github.com/zereight/gitlab-mcp/issues/330).

### Key Findings

1. **Direct curl upload works perfectly**:
   ```bash
   curl --request POST \
     --header "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
     --form "file=@/path/to/file.mov" \
     "https://gitlab.agodadev.io/api/v4/projects/21676/uploads"
   # Returns: {"id":533931,"alt":"...","url":"...","markdown":"![...](...)"} ✅
   ```

2. **glab CLI also fails** (different error):
   ```bash
   glab api --method POST "projects/21676/uploads" -F "file=@file.txt"
   # Returns: {"error":"file is invalid"} glab: HTTP 400 ❌
   ```
   - Note: `glab` uses `-F` for form data but appears to have a bug with file uploads
   - `glab` does NOT support `--jq` flag (produces error)

3. **MCPHub upload_markdown tool fails**:
   ```
   MCP error -32603: GitLab API error: 406 Not Acceptable
   {"status":406,"error":"Not Acceptable"}
   ```
   - This is identical to the reported issue in zereight/gitlab-mcp#330
   - The tool is not properly formatting the multipart/form-data request
   - GitLab server logs show no additional details beyond 406 response

4. **Project ID encoding works**:
   - URL-encoded path: `full-stack%2Fcart%2Ftrips-web` ✅
   - Numeric ID: `21676` ✅
   - Both formats are accepted by GitLab API

5. **Authentication is valid**:
   - `glab auth status` confirms authentication works
   - Token has proper permissions (uploads work via curl)

### Root Cause Analysis - CONFIRMED ✅

The MCP server uses incompatible libraries for FormData upload:

**Problem**: The `@zereight/mcp-gitlab` package uses:
- `formdata-node` package for creating FormData
- `undici` fetch for HTTP requests
- These two don't properly integrate for multipart uploads

**Proof**: Testing script reproduced the exact 406 error:
```javascript
// From MCP server source (BROKEN):
import { FormData } from 'formdata-node';
import { fileFromPath } from 'formdata-node/file-from-path';
import { fetch } from 'undici';

headers: {
  ...BASE_HEADERS,          // Contains 'Content-Type': 'application/json'
  ...buildAuthHeaders(),
  'Content-Type': undefined, // BROKEN: Sets header to string "undefined"
}
```

Result: HTTP 406 Not Acceptable

**Solution**: Use Node.js native globals (Node 18+):
```javascript
// WORKING approach:
import { readFile } from 'fs/promises';
// Use global FormData, Blob, fetch (no imports needed)

const fileBuffer = await readFile(filePath);
const form = new FormData();
const blob = new Blob([fileBuffer], { type: 'application/octet-stream' });
form.append('file', blob, fileName);

const response = await fetch(url, {
  method: 'POST',
  headers: {
    Accept: 'application/json',
    Authorization: `Bearer ${token}`,
    // NO Content-Type - let fetch set it automatically with boundary
  },
  body: form,
});
```

Result: HTTP 201 Created ✅

### Technical Details

- **Working endpoint**: `POST /api/v4/projects/{id}/uploads`
- **Required header**: `Content-Type: multipart/form-data`
- **Form field**: `file=@/path/to/file`
- **Response format**: JSON with `id`, `url`, `markdown` fields

## Investigation Tasks

- [x] Test `upload_markdown` tool with test file and capture exact error
- [x] Verify project ID encoding (URL-encoded path vs numeric ID)
- [x] Check `glab` version and authentication status (`glab auth status`)
- [x] Test with smaller file (screenshot.png vs .mov video)
- [x] Verify GitLab API endpoint availability and permissions
- [x] Check if API token has required scopes (`api`, `write_repository`)
- [x] Test direct curl with proper authentication headers
- [x] Review MCPHub GitLab server implementation for upload logic
- [x] Check GitLab instance version compatibility (Agoda's GitLab)
- [x] Test with different project paths to isolate permissions issue
- [x] **Reproduced the exact 406 error with test script**
- [x] **Identified incompatible FormData libraries (formdata-node + undici)**
- [x] **Confirmed working solution with Node native globals**
- [ ] Report findings to zereight/gitlab-mcp GitHub issue
- [ ] Create workaround documentation for users

## Expected Outputs

1. ✅ Root cause identification for both failures - COMPLETED
2. ⚠️ Working command/tool configuration - **Workaround needed** (use curl directly)
3. 📝 Documentation updates for:
   - [~/dotfilesai/AI-docs.md](../../../dotfilesai/AI-docs.md)
   - [~/dotfiles/ai/agents/docs/tools/gitlab/glab-cli.md](../../../../ai/agents/docs/tools/gitlab/glab-cli.md)

## Cleanup

- [x] Removed test file `/tmp/test-upload.txt`
- [x] Note: GitLab uploads cannot be deleted via API (no DELETE endpoint exists)
- [x] Successfully uploaded test files remain in project uploads directory

## Documentation Updates Needed

### AI-docs.md
- ⚠️ **MCPHub `upload_markdown` tool is broken** (406 error)
- **Root cause**: Uses `formdata-node` + `undici` which don't integrate properly
- **Fix required**: Replace with Node.js native FormData/Blob globals (Node 18+)
- Document workaround: Use bash tool with curl for uploads
- Known issue: https://github.com/zereight/gitlab-mcp/issues/330
- Working curl command template:
  ```bash
  curl --request POST \
    --header "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
    --form "file=@/path/to/file" \
    "https://gitlab.agodadev.io/api/v4/projects/{project_id}/uploads"
  ```
- Note: Both URL-encoded path and numeric project ID work

### glab-cli.md
- ⚠️ **glab upload endpoint is also broken** (400 error)
- Document that `-F` flag exists but file uploads don't work
- `glab` does NOT support `--jq` flag (common mistake)
- Recommend using curl for file uploads instead
- Add note about glab limitations vs curl for complex operations

### Test Scripts (for reference)
Created test scripts in [tests/glab-markdown](../../../../tests/glab-markdown):
- `test-gitlab-upload.js` - Comprehensive test that reproduces the 406 error and demonstrates working solution
- `test-working-approach.js` - Simplified test focusing on the working Node.js native approach
- `package.json` - ES module configuration with dependencies
- `README.md` - Complete usage instructions and troubleshooting guide

**Usage**:
```bash
cd tests/glab-markdown
export GITLAB_TOKEN="your_token_here"
npm install
npm test  # Run comprehensive test
npm run test:working  # Run working solution only
```

## References

- GitLab API Docs: https://docs.gitlab.com/ee/api/projects.html#upload-a-file
- glab CLI Docs: https://gitlab.com/gitlab-org/cli/-/blob/main/docs/source/api/index.md
- MCPHub GitLab Server: `@zereight/mcp-gitlab` npm package
- **Known Issue**: https://github.com/zereight/gitlab-mcp/issues/330
- GitLab API Status Codes: https://docs.gitlab.com/ee/api/rest/index.html#status-codes

## Notes & Conclusions

- ✅ Video file (.mov) uploads work fine with curl (no size limitations found)
- ✅ Project path URL encoding works correctly (`%2F` for `/`)
- ✅ Agoda's GitLab API is standard-compliant
- ❌ MCPHub `upload_markdown` tool has a bug in multipart/form-data handling
  - **Root cause**: `formdata-node` + `undici` incompatibility
  - **Setting `'Content-Type': undefined` doesn't delete the header, it sets it to the string "undefined"**
- ❌ `glab api` also cannot upload files (different implementation issue)
- ✅ **Solution confirmed**: Use Node.js native globals (FormData, Blob, fetch)
- 💡 **Recommended workaround**: Use bash tool with curl for file uploads
- 📌 File uploads return markdown link format in response
- 🔍 HTTP 406 typically means incorrect `Content-Type` or `Accept` headers
- 🐛 This is a known upstream issue, not specific to Agoda's GitLab
- 🎯 **Fix is simple**: Replace imports in MCP server source code:
  ```diff
  - import { FormData } from 'formdata-node';
  - import { fileFromPath } from 'formdata-node/file-from-path';
  - import { fetch } from 'undici';
  + import { readFile } from 'fs/promises';
  + // Use global FormData, Blob, fetch (Node 18+)
  ```
