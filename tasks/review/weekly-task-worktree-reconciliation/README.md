---
title: "Weekly task and nvim worktree reconciliation — 2026-07-19 review group"

status: review
priority: high
created: 2026-07-12
updated: 2026-08-29
branch: nvim3wt1
profile: nvimwt3a
related:
  - [Task workflow](tasks/AGENTS.md)
  - [Worktree profile guide](docs/memory/nvim-worktree-testing.md)
---

## Objective

Consolidated review index for the batch implemented in the isolated `nvimwt3a` profile. Each task has its own file with implementation details and review feedback. This README is the decision matrix only.

Do not create another weekly ledger for this batch. Update this README with failed checks, decisions, and follow-up work.

## Reconciliation record

- `nvim3wt1` had no unique commits and was three commits behind local `main`.
- The original worktree tip is preserved as `codex/nvim3wt1-pre-task-sync-20260719`.
- `nvim3wt1` was fast-forwarded to local `main` at `8142779`.
- Task definitions and dirty Lua carryover were copied into this worktree.
- Worktree-local `.claude/settings.local.json` and `.mcphub/servers.json` are excluded from this review batch.
- `lazy-lock.json` has no repository diff.
- A user-owned [completed buffer-picker task](tasks/completed/fix-buffer-picker-title-and-grouping.md)
  exists in the working tree. Before committing, stage one deliberate task-state
  transition: the index still contains its `review/` copy while the completed
  copy is currently untracked.

## Automated verification (summary)

Focused tests run on 2026-08-29 pass for buffer grouping, picker pattern
propagation, scratch discovery/filtering, instruction catalog discovery/dedup,
and MCPHub instruction files (53 assertions). Fresh clones of the active
MCPHub and CodeCompanion History revisions accept the local patches; the touched
Lua files parse successfully. The resource-refresh patch pair also passes a
real CodeCompanion open-chat regression test, and the title patch passes a
17-assertion v19 context-filtering regression against the patched upstream
generator. `git diff --check` now passes for the combined worktree and staged
set after normalizing the two patch artifacts.

## Current review — 2026-08-29

### Evidence checklist

- [x] Focused buffer, picker, scratch, instruction-catalog, and MCPHub tests
      pass without loading the daily-driver profile.
- [x] A fresh MCPHub clone at `7cd5db3` accepts patches `01` through `06` in
      order; patched Lua parses and the isolated fixture reports 53 assertions.
- [x] A fresh CodeCompanion History clone at `bc1b4fe` accepts
      `01-title-prompt-v1.patch`; its touched Lua parses.
- [x] The patched CodeCompanion History generator excludes top-level and nested
      v19 context metadata from initial and refresh title prompts (17 assertions,
      adapter stub; no credentials or model request).
- [x] An already-open CodeCompanion chat refreshes its MCP editor-context and
      completion candidates when `resource_list_changed` registers a resource;
      the focused seam and real-chat tests pass.
- [x] Independent re-review found no remaining P1/P2 regressions after the
      disposable-checkout live-chat refresh test passed (10 assertions).
- [x] Current offline patch audit reverse-applied and reapplied the changed
      MCPHub (`06`, `07`), CodeCompanion, and History patches on disposable
      working-tree copies; all eight touched Lua files parse successfully.
- [x] `git diff --check` passes for the final combined worktree and staged set.
      Both normalized patch artifacts also apply cleanly to fresh plugin clones.

### Still needs work

- [ ] **P1 — make the user-selected buffer task transition coherent before a
      commit.** The completed copy is untracked while the staged index still
      retains its review-stage copy; stage the intended `review/` → `completed/`
      transition (or restore the review copy) and stage this updated ledger in
      place of its older staged version before committing.
- [ ] **P3 — complete user-only interactive checks** for C-space switching,
      Neo-tree copy keys, clipboard behavior, the CodeCompanion dynamic AGD
      model picker, the external-app/Codex command, a live MCPHub file-backed
      server, and one actual-model CodeCompanion title smoke chat. Raw `/mcp`
      client parity remains a separate backend design decision.

## Task summary

| Task | Status | Notes |
|------|--------|-------|
| [Buffer picker grouping](tasks/completed/fix-buffer-picker-title-and-grouping.md) | **Completed** | Merged to main via `e72048e`, no feedback |
| [C-space search carry](tasks/review/fix-cspace-search-carry-across-picker-switch.md) | Awaiting user verification | `<leader>ff` fix in main; worktree extends to 3 more entry points — see [task diff note](tasks/review/fix-cspace-search-carry-across-picker-switch.md#main-vs-worktree-diff---2026-07-27) |
| [Buffer path copy](tasks/review/buffer_path_copy_keymaps.md) | Awaiting user verification | See [feedback below](#buffer-path-copy-feedback) and [task file](tasks/review/buffer_path_copy_keymaps.md#review-feedback---2026-07-27) |
| [CodeCompanion chat titles](tasks/review/codecompanion-chat-title-generation-rules.md) | Awaiting user verification | See [feedback below](#codecompanion-chat-titles-feedback) and [task file](tasks/review/codecompanion-chat-title-generation-rules.md#review-feedback---2026-07-27) |
| [Scratch notes picker](tasks/review/scratch_fzf_nvim_integration.md) | Awaiting user verification | See [feedback below](#scratch-notes-picker-feedback) and [task file](tasks/review/scratch_fzf_nvim_integration.md#review-feedback---2026-07-27) |
| [Instruction-file catalog](tasks/review/mcphub-instruction-files-catalog-view.md) | Awaiting user verification | See [feedback below](#instruction-file-catalog-feedback) and [task file](tasks/review/mcphub-instruction-files-catalog-view.md#review-feedback---2026-07-27) |
| [MCPHub instruction files (config)](tasks/review/mcphub-instruction-files-config.md) | Awaiting user verification | Live server-config test only |

## Feedback for next iteration

### Buffer path copy feedback

Task: [buffer_path_copy_keymaps.md](tasks/review/buffer_path_copy_keymaps.md)

- [x] Fix `,crp` error: `code_ref.lua:225: Invalid buffer id: -1` — guard `vim.fn.bufnr "#"` before `nvim_buf_get_name`
- [x] Change `p`-suffixed copy actions to copy **dirpath** instead of filepath — `Yp`/`YP` now copy dirpath; added `Yf`/`YF` for filepath
- [x] `,cp`/`,cP` now copy **dirpath** (was filepath) — `:h:.` and `:h:p` modifier
- [x] Neotree updated to match: `Yp`/`YP` = dirpath, `Yf`/`YF` = filepath, `copy_selector` includes dir options
- [x] Generic picker actions preserve a selected directory itself; `Yp`/`YP`
      retain directory entries and still use the parent directory for files.
      The isolated picker test covers explicit directory metadata, stat fallback,
      and regular-file behavior.

### CodeCompanion chat titles feedback

Task: [codecompanion-chat-title-generation-rules.md](tasks/review/codecompanion-chat-title-generation-rules.md) DONE

- [x] Strengthen title generation prompt to exclude rule/agent/instruction names — still getting titles like "Neovim Config Agent Guide"
- [x] Verify patched v19 context filtering with `<rules>`/`<help>` metadata —
      the adapter-stub test proves the prompt retains the user request and omits
      injected context before title generation.
  - representative injected context covered by the regression:
```
> Context:
> - <rules>AGENTS.md</rules>
> - <rules>CLAUDE.md</rules>
> - <rules>/Users/tharutaipree/.claude/CLAUDE.md</rules>
> - <rules>/Users/tharutaipree/.claude/RTK.md</rules>
```
- [x] Check if `TitleGenerator:relevant_messages()` is leaking tagged content into the prompt
- [ ] User-only actual-model smoke: confirm the returned title itself reflects
      the request rather than a rule label.

### Scratch notes picker feedback

Task: [scratch_fzf_nvim_integration.md](tasks/review/scratch_fzf_nvim_integration.md) DONE

- [x] Change entry key from `<leader>ns` to `<leader>nS`
- [x] Add `<A-e>` to toggle visibility of empty file content
- [x] Remove indent space from labels
- [x] Add source filter for `Snacks.scratch.list()` entries using metadata fields (`item.cwd`, `item.ft`, `item.branch`, `item.stat.size`)


## Imported main-worktree Lua carryover

- [x] [Carryover regression](tests/test_main_worktree_carryover.lua) verifies
      the GPT-5.6 Sol/Terra/Luna Responses choices, GPT-5.5 non-vision fallback,
      `Aa` actions, the dynamic AGD picker at `<leader>ASm`, and direct
      GPT-5.6 Sol shortcuts at `<leader>ASC` / `<leader>ASX` in `nvimwt3a`.
   - [ ] User-only: open the dynamic AGD picker or change-adapter flow and
         confirm the authenticated live model service offers the expected tiers.
- [x] `<leader>CE` resolves to the `gpt-o` ClaudeCode shortcut and is labelled GPT-5.5.
- [x] The carryover regression detects Codex through `ChatGPT.app` or
      `Codex.app` and validates its shell-safe, URI-encoded `codex://new` copy
      command.
   - [ ] User-only: visually confirm the external-app picker shows Codex and
         accepts the copied command in the desktop environment.

### Instruction-file catalog feedback

Task: [mcphub-instruction-files-catalog-view.md](tasks/review/mcphub-instruction-files-catalog-view.md)

TODO
- [x] Add `<A-g>` to toggle global scope filter
  - [ ] Should also support all scope : all/global/local
  - [ ] Type instruction and skills can also be togglable via some key A-t
- [x] Shorten labels: `[g]` (global), `[p]` (project), `[sk]` (skill), `[md]` (instruction)
- [x] Remove indent space from labels
- [ ] All/common instruction and skills can also be togglable via some key A-S-s
- [x] Add `<A-s>` to toggle between each tool/agent

## Final batch signoff

- [ ] I selected one close/keep/return decision for every task above.
- [ ] I confirmed `.claude/settings.local.json` and `.mcphub/servers.json` remain worktree-local and are not part of the accepted code batch.
- [ ] I want the accepted implementation promoted to `main` in a separate change after this review.
- [ ] I, the user, moved only the accepted task files from `review/` to `completed/`; the AI agent did not close them automatically.
