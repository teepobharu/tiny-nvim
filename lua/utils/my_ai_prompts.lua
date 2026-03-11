-- AI Prompts for CodeCompanion and other AI tools
-- Centralized location for reusable prompt templates

local M = {}

--- Empty prompt template for CodeCompanion actions
--- Useful when you want the action to start with no initial prompt
M.EMPTY_PROMPT_CODECOMPANION = {
  {
    role = "user",
    content = "",
  },
}

--- Code review instructions template
--- Used for reviewing git changes with structured feedback
--- Prioritizes bugs & logic errors as the most critical category
---
--- @param change_type string The type of changes ("staged", "unstaged", "all")
--- @param scope string The scope of review ("current buffer" or "selected lines")
--- @param filepath string The relative file path being reviewed
--- @param diff string The git diff content to review
--- @return string Formatted review prompt
M.CODE_REVIEW_INSTRUCTIONS = function(change_type, scope, filepath, diff)
  return string.format(
    [[You have the full file content available in context. Review the following %s changes in %s for:

**File being reviewed:** `%s`

**Review Categories (in priority order):**

1. **🐛 Bugs & Logic Errors** (HIGHEST PRIORITY)
   - Null/undefined pointer dereferences
   - Off-by-one errors in loops/arrays
   - Race conditions and concurrency issues
   - Edge case handling (empty inputs, boundary values)
   - Incorrect algorithm implementations
   - Type mismatches and coercion issues

2. **🔒 Security Issues**
   - SQL injection, XSS, CSRF vulnerabilities
   - Authentication/authorization bypasses
   - Hardcoded secrets (API keys, passwords, tokens)
   - Insecure dependencies or outdated libraries
   - Input validation failures

3. **⚡ Performance**
   - O(n²) or worse algorithmic complexity
   - Memory leaks or excessive allocations
   - Unnecessary loops or redundant operations
   - Database N+1 query problems
   - Blocking operations in async code

4. **✨ Best Practices**
   - Code style and formatting
   - Naming conventions
   - Error handling patterns
   - Test coverage gaps
   - Documentation quality

**Format your feedback as:**
## [Category Name]
- Line X: [Issue description] → [Suggested fix]

**Guidelines:**
- **PRIORITIZE BUGS**: Focus most on category 1 (bugs & logic errors) as these cause immediate failures
- Use the full file context to understand code structure and dependencies
- Only report actual issues found (be selective, not exhaustive)
- Provide specific line numbers from the diff
- Suggest concrete, actionable fixes with context from the full file
- If no issues found: "✅ No issues found - changes look good!"

**Changes to review:**
```diff
%s
```
]],
    change_type,
    scope,
    filepath,
    diff
  )
end

return M
