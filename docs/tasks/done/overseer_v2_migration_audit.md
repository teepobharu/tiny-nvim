# Overseer.nvim v2 Schema Migration Audit

**Date:** 2026-01-24
**Auditor:** Claude Code
**Scope:** All overseer templates and configuration

## Executive Summary

**Current Version:** v1.6.0 (pinned in lua/plugins/runner.lua:14)
**Target Version:** v2.x (latest)
**Templates Audited:** 11
**Templates with Issues:** 10 out of 11
**Critical Breaking Changes:** 3 types

## Critical v2 Breaking Changes Found

### 1. ❌ Condition Callbacks (REMOVED in v2)
**Impact:** 10 templates affected
**Severity:** CRITICAL - Will fail at runtime

According to overseer v2 CHANGELOG line 58:
> "Callback from condition checks removed - conditions no longer support callbacks"

**Affected Templates:**
Checking
- `and_build.lua` (line 51-60)
- `and_pick.lua` (line 82-89)
- `and_test.lua` (line 286-296)
- `grep_async.lua` (line 98-100)
- `vscode_global.lua` (line 25-31)
- `mmb_pick.lua` (line 77-84)
- `mmb_tests.lua` (line 95-102)
- `dotnet_test.lua` (line 313-326)
- `tripviewbff_pick.lua` (line 62-69)

### 2. ❌ Priority Field (REMOVED in v2)
**Impact:** 7 templates affected
**Severity:** HIGH - Will be ignored (no-op)

v2 removed task priority system entirely.

**Affected Templates:**
- `and_pick.lua:79` - `priority = 5`
- `and_test.lua:283` - `priority = 5`
- `mmb_pick.lua:74` - `priority = 5`
- `mmb_tests.lua:92` - `priority = 5`
- `dotnet_test.lua:310` - `priority = 5`
- `tripviewbff_pick.lua:59` - `priority = 5`

### 3. ⚠️ Wrong Field Name: `filetypes` vs `filetype`
**Impact:** 7 templates affected
**Severity:** MEDIUM - May not match correctly

**Affected Templates:**
- `and_build.lua:49` - uses `filetypes` instead of `filetype`
- `and_pick.lua:81` - uses `filetypes` instead of `filetype`
- `and_test.lua:285` - uses `filetypes` instead of `filetype`
- `mmb_pick.lua:76` - uses `filetypes` instead of `filetype`
- `mmb_tests.lua:94` - uses `filetypes` instead of `filetype`
- `dotnet_test.lua:312` - uses `filetypes` instead of `filetype`
- `tripviewbff_pick.lua:61` - uses `filetypes` instead of `filetype`

## Additional Code Quality Issues

### 4. 🐛 Undefined Variables
- `and_test.lua:208` - references undefined `choice` variable
- `mmb_pick.lua:55` - references undefined `html_choices` variable

### 5. ⚠️ Version Pinning
- `lua/plugins/runner.lua:14` - pinned to `version = "v1.6.0"` (should update to v2.x)

## Template-by-Template Analysis

### ✅ COMPLIANT: run_script.lua
- **Status:** Fully v2 compliant
- **Issues:** None

### ⚠️ NEEDS ATTENTION: run_script_deterministic.lua
- **Status:** Mostly compliant
- **Issues:** None critical, but complex logic should be reviewed

### ❌ CRITICAL: grep_async.lua
```lua
-- PROBLEM (line 98-100):
condition = {
  callback = function(task)  -- ❌ REMOVED IN V2
    return true
  end,
}

-- FIX: Remove callback entirely or move logic elsewhere
condition = {
  -- Static matching only in v2
}
```

### ❌ CRITICAL: vscode_global.lua
```lua
-- PROBLEM (line 25-31):
condition = {
  callback = function(opts)  -- ❌ REMOVED IN V2
    if not get_tasks_file(vim.fn.getcwd(), opts.dir) then
      return false, "No .vscode/tasks.json file found"
    end
    return true
  end,
}

-- FIX: Move validation to generator function
generator = function(opts, cb)
  local tasks_file = get_tasks_file(vim.fn.getcwd(), opts.dir)
  if not tasks_file then
    return "No .vscode/tasks.json file found"
  end
  -- ... rest of logic
end,
condition = {} -- Remove callback
```

### ❌ CRITICAL: and_build.lua
**Issues:**
1. Line 49: `filetypes` → should be `filetype`
2. Line 51-60: Condition callback (REMOVED)

```lua
-- CURRENT:
condition = {
  filetypes = { "kt" },  -- ❌ Wrong field name
  callback = function(task)  -- ❌ REMOVED IN V2
    local isInClientAndroidProject = vim.fn.expand("%:p:h"):match("client%-android")
    return isInClientAndroidProject and true or false
  end,
}

-- FIX: Static matching only
condition = {
  filetype = { "kt" },  -- ✅ Correct field name
  dir = vim.fn.getcwd():match("client%-android") and vim.fn.getcwd() or nil,
}
-- NOTE: Complex path matching may need alternative approach (see workarounds below)
```

### ❌ CRITICAL: and_pick.lua
**Issues:**
1. Line 79: `priority = 5` (REMOVED)
2. Line 81: `filetypes` → should be `filetype`
3. Line 82-89: Condition callback (REMOVED)

### ❌ CRITICAL: and_test.lua
**Issues:**
1. Line 283: `priority = 5` (REMOVED)
2. Line 285: `filetypes` → should be `filetype`
3. Line 286-296: Condition callback (REMOVED)
4. Line 208: Undefined global `choice`

### ❌ CRITICAL: mmb_pick.lua
**Issues:**
1. Line 74: `priority = 5` (REMOVED)
2. Line 76: `filetypes` → should be `filetype`
3. Line 77-84: Condition callback (REMOVED)
4. Line 55: Undefined `html_choices`

### ❌ CRITICAL: mmb_tests.lua
**Issues:**
1. Line 92: `priority = 5` (REMOVED)
2. Line 94: `filetypes` → should be `filetype`
3. Line 95-102: Condition callback (REMOVED)

### ❌ CRITICAL: dotnet_test.lua
**Issues:**
1. Line 310: `priority = 5` (REMOVED)
2. Line 312: `filetypes` → should be `filetype`
3. Line 313-326: Condition callback (REMOVED)

### ❌ CRITICAL: tripviewbff_pick.lua
**Issues:**
1. Line 59: `priority = 5` (REMOVED)
2. Line 61: `filetypes` → should be `filetype`
3. Line 62-69: Condition callback (REMOVED)

## Migration Strategy

### Phase 1: Update Plugin Version
1. Update `lua/plugins/runner.lua:14` from `v1.6.0` to latest v2.x
2. Run `:Lazy sync` to update

### Phase 2: Simple Fixes (Safe)
1. Remove all `priority` fields (7 templates)
2. Fix `filetypes` → `filetype` (7 templates)
3. Fix undefined variables

### Phase 3: Condition Callback Removal (Complex)

**Three approaches for handling removed callbacks:**

#### Option A: Static Directory Matching
For simple path checks, use static `dir` field:
```lua
-- Before:
condition = {
  callback = function()
    return vim.fn.expand("%:p:h"):match("specific%-project")
  end
}

-- After:
condition = {
  dir = "/path/to/specific-project"  -- Must be exact path
}
```
**Limitation:** No pattern matching, must be exact directory

#### Option B: Use Generator Function (Recommended)
Move validation logic to generator/builder:
```lua
-- Before:
condition = {
  callback = function()
    return check_something()
  end
}

-- After:
condition = {},  -- Always available
builder = function(params)
  if not check_something() then
    error("Template not available for this context")
  end
  return { cmd = {...} }
end
```
**Benefit:** Full programmatic control, clear error messages

#### Option C: Remove Condition Entirely
Make template always available, rely on user selection:
```lua
-- Before:
condition = {
  callback = function() return is_android_project() end
}

-- After:
-- Just remove condition
-- Template always appears in list
-- User decides if applicable
```
**Benefit:** Simplest change, delegates to user judgment

### Phase 4: Testing
1. Test each template individually with `:OverseerRun`
2. Verify templates appear when appropriate
3. Verify templates work correctly

## Recommended Fixes Summary

```lua
-- PATTERN 1: Remove priority (ALL affected templates)
-  priority = 5,  -- DELETE THIS LINE

-- PATTERN 2: Fix field name (7 templates)
-  filetypes = { "kt" },
+  filetype = { "kotin" },

-- PATTERN 3: Callback removal - Option B (Recommended)
-  condition = {
-    filetype = { "kt" },
-    callback = function(task)
-      return vim.fn.expand("%:p:h"):match("pattern")
-    end,
-  },
+  condition = {
+    filetype = { "kotlin" },
+  },
+  -- Add validation in builder if needed:
   builder = function(params)
+    local current_path = vim.fn.expand("%:p:h")
+    if not current_path:match("pattern") then
+      error("This template only works in 'pattern' projects")
+    end
     -- ... rest of builder
   end,
```

## Implementation Checklist

- [ ] Phase 1: Update plugin version to v2.x
- [ ] Phase 2: Simple fixes
  - [ ] Remove 7 `priority` fields
  - [ ] Fix 7 `filetypes` → `filetype`
  - [ ] Fix undefined variables (and_test.lua:208, mmb_pick.lua:55)
- [ ] Phase 3: Condition callback removal (10 templates)
  - [ ] grep_async.lua
  - [ ] vscode_global.lua
  - [ ] and_build.lua
  - [ ] and_pick.lua
  - [ ] and_test.lua
  - [ ] mmb_pick.lua
  - [ ] mmb_tests.lua
  - [ ] dotnet_test.lua
  - [ ] tripviewbff_pick.lua
- [ ] Phase 4: Testing
  - [ ] Test each template
  - [ ] Verify no runtime errors
  - [ ] Document any behavior changes

## Risk Assessment

**Breaking Changes:** HIGH
**Migration Complexity:** MEDIUM
**Testing Required:** HIGH

**Recommendation:** Implement fixes in phases with thorough testing after each phase.

## References

- Overseer v2 CHANGELOG: `~/.local/share/nvim3_jelly_tinynvim/lazy/overseer.nvim/CHANGELOG.md`
- Template schema docs: Lines 42-53 of `lua/overseer/task.lua`
- Condition validation: Lines 145-192 of `lua/overseer/template.lua`

 

## Some issues to check


