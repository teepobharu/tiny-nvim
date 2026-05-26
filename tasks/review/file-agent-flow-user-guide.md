---
title: "File Agent Flow - User Guide and Review Checklist"
status: review
priority: medium
created: 2026-05-23
updated: 2026-05-23
category: ai-tooling
related:
  - [Agent flow overview](agent-flows/README.md)
  - [Note plan work review use case](agent-flows/usecases/note-plan-work-review/README.md)
  - [Session template](agent-flows/usecases/note-plan-work-review/session-template/README.md)
  - [File agent flow skill](.claude/skills/file-agent-flow/SKILL.md)
  - [Planner agent](.claude/agents/flow-planner.md)
  - [Worker agent](.claude/agents/flow-worker.md)
  - [Reviewer agent](.claude/agents/flow-reviewer.md)
  - [Watcher script](scripts/agent-flow-watch.py)
  - [Memory doc](docs/memory/file-agent-flow.md)
---

## Objective

Provide a user-facing guide and review checklist for the local file-based agent flow system.

This task is in `review/` so the user can follow the guide, test the flow, and decide whether the design is accepted or needs changes.

## What was added

A generic local file-agent-flow structure for multi-agent handoff sessions:

```text
agent-flows/
├── README.md
├── usecases/
│   └── note-plan-work-review/
│       ├── README.md
│       └── session-template/
└── sessions/
```

Local Claude helpers:

```text
.claude/skills/file-agent-flow/SKILL.md
.claude/agents/flow-planner.md
.claude/agents/flow-worker.md
.claude/agents/flow-reviewer.md
.claude/commands/flow-new-session.md
.claude/commands/flow-status.md
```

Watcher:

```text
scripts/agent-flow-watch.py
```

Permanent reference:

```text
docs/memory/file-agent-flow.md
```

## User Guide

### 1. Create a new session

From the repo root:

```bash
SESSION="$(date +%Y%m%d-%H%M%S)-demo"
mkdir -p agent-flows/sessions/note-plan-work-review
cp -R agent-flows/usecases/note-plan-work-review/session-template \
  "agent-flows/sessions/note-plan-work-review/$SESSION"
```

Your session will be here:

```text
agent-flows/sessions/note-plan-work-review/<session-id>/
```

### 2. Write the source note

Edit:

```bash
$EDITOR "agent-flows/sessions/note-plan-work-review/$SESSION/source-note.md"
```

Fill in:

```markdown
## Context

## Desired outcome

## Constraints

## Acceptance criteria
```

Example source note:

```markdown
# Source Note

## Context

I want a command that summarizes my current Neovim picker state.

## Desired outcome

Add a helper that prints current picker source, cwd, and selected item.

## Constraints

- Keep it local to my config.
- Do not modify upstream plugin files.

## Acceptance criteria

- [ ] A command or Lua function exists.
- [ ] It works from Snacks picker.
- [ ] Reviewer can verify with a command.
```

### 3. Start the watcher

Run once:

```bash
python3 scripts/agent-flow-watch.py \
  "agent-flows/sessions/note-plan-work-review/$SESSION" \
  --once
```

Or keep watching:

```bash
python3 scripts/agent-flow-watch.py \
  "agent-flows/sessions/note-plan-work-review/$SESSION"
```

The receiver dashboard is:

```text
agent-flows/sessions/note-plan-work-review/<session-id>/receiver/status.md
```

The append-only event log is:

```text
agent-flows/sessions/note-plan-work-review/<session-id>/receiver/events.jsonl
```

Completion events can be appended to:

```text
agent-flows/sessions/note-plan-work-review/<session-id>/receiver/completions.jsonl
```

### 4. Ask planner agent to create the plan

Prompt:

```text
Use the file-agent-flow skill as flow-planner.
Session path: agent-flows/sessions/note-plan-work-review/<session-id>.
Read source-note.md and create the worker handoff.
```

Expected planner outputs:

```text
agents/planner/status.md
agents/planner/outbox.md
agents/worker/inbox.md
handoffs/001-planner-to-worker.md
tasks.md
jobs/job-001/README.md
iterations/001-initial.md
```

### 5. Ask worker agent to execute

Prompt:

```text
Use the file-agent-flow skill as flow-worker.
Session path: agent-flows/sessions/note-plan-work-review/<session-id>.
Execute the latest handoff addressed to worker and report back in files.
```

Expected worker outputs:

```text
agents/worker/status.md
agents/worker/outbox.md
handoffs/002-worker-to-reviewer.md
jobs/job-001/README.md
iterations/001-initial.md
```

Worker should set the job to `review` or `blocked`, not final accepted.

### 6. Ask reviewer agent to verify

Prompt:

```text
Use the file-agent-flow skill as flow-reviewer.
Session path: agent-flows/sessions/note-plan-work-review/<session-id>.
Verify worker output against the source note and planner handoff.
```

Reviewer outcomes:

- If work needs more changes:

```text
handoffs/003-reviewer-to-worker.md
iterations/002-review-fixes.md
jobs/job-001/README.md status: needs-changes
tasks.md keeps job active
```

- If work passes review:

```text
jobs/job-001/README.md status: verified
tasks.md row moves to Finished / verified by reviewer
receiver/completions.jsonl gets a completion event
receiver/status.md summarizes verified state
```

### 7. User accepts or requests changes

After reviewer marks a job `verified`, the user decides:

- Accept it:

```yaml
status: accepted-by-user
final_verdict: accepted-by-user
```

- Or request another iteration by adding a new note/handoff and setting:

```yaml
status: needs-changes
final_verdict: needs-changes
```

Important rule:

> Agents can mark `verified`; only the user should mark `accepted-by-user`.

This mirrors the repo's existing task rule: agents can move work to review, but only the user completes it.

## Finished job tracking

Use these files:

| File | Purpose |
| --- | --- |
| `tasks.md` | Session-level board: Active, Finished, Archived |
| `jobs/job-###/README.md` | Durable record for one job |
| `iterations/###-name.md` | One plan → work → review loop |
| `receiver/completions.jsonl` | Append-only completion events |

Recommended lifecycle:

```text
planned
  ↓
in-progress
  ↓
review
  ↓
needs-changes ──→ next iteration
  ↓
verified
  ↓
accepted-by-user
```

## Iteration example

```text
iterations/001-initial.md
iterations/002-review-fixes.md
iterations/003-final-polish.md
```

Each iteration should answer:

- Why did this iteration start?
- What requirements were in scope?
- What did the worker change?
- What did reviewer decide?
- Who owns the next action?

## Verification

### How to verify

Use the template to create a throwaway session, edit `source-note.md`, run the watcher, and inspect generated receiver status. Then optionally run the planner/worker/reviewer prompts in separate agent turns.

### Commands

Create a test session:

```bash
SESSION="$(date +%Y%m%d-%H%M%S)-test-flow"
mkdir -p agent-flows/sessions/note-plan-work-review
cp -R agent-flows/usecases/note-plan-work-review/session-template \
  "agent-flows/sessions/note-plan-work-review/$SESSION"
```

Write a simple source note:

```bash
cat > "agent-flows/sessions/note-plan-work-review/$SESSION/source-note.md" <<'NOTE'
---
role: user-source
status: ready
updated: 2026-05-23T00:00:00+07:00
---

# Source Note

## Context

Test the file agent flow.

## Desired outcome

Planner should create a small handoff for a worker.

## Constraints

- Do not change real repo code for this test.

## Acceptance criteria

- [ ] Watcher updates receiver/status.md.
- [ ] Session has tasks.md, jobs/, and iterations/.
NOTE
```

Run watcher once:

```bash
python3 scripts/agent-flow-watch.py \
  "agent-flows/sessions/note-plan-work-review/$SESSION" \
  --once
```

Inspect status:

```bash
sed -n '1,220p' \
  "agent-flows/sessions/note-plan-work-review/$SESSION/receiver/status.md"
```

Confirm expected files exist:

```bash
find "agent-flows/sessions/note-plan-work-review/$SESSION" \
  -maxdepth 3 \
  -type f \
  | sort
```

Optional cleanup after review:

```bash
rm -rf "agent-flows/sessions/note-plan-work-review/$SESSION"
```

### Checklist

- [ ] A copied session contains `source-note.md`, `tasks.md`, `receiver/`, `agents/`, `handoffs/`, `iterations/`, `jobs/`, and `worklog/`.
- [ ] Running `scripts/agent-flow-watch.py --once` updates `receiver/status.md`.
- [ ] `receiver/events.jsonl` records file events as JSONL.
- [ ] `tasks.md` clearly separates Active, Finished / verified, and Archived jobs.
- [ ] `jobs/job-000-template/README.md` explains the job lifecycle.
- [ ] `iterations/000-template.md` explains how to track each plan → work → review loop.
- [ ] The planner/worker/reviewer agent files make role ownership clear.
- [ ] The user can tell the difference between `verified` and `accepted-by-user`.
- [ ] The flow feels generic enough to reuse for future use cases/sessions.

## Review questions for user

- [ ] Is `agent-flows/usecases/<usecase>/session-template/` the right place for reusable templates?
- [ ] Is `agent-flows/sessions/<usecase>/<session-id>/` the right place for concrete runs?
- [ ] Is `tasks.md` enough as the session board, or do you want a Kanban-style folder layout too?
- [ ] Should `accepted-by-user` jobs stay in `jobs/`, or be moved to `archive/completed/`?
- [ ] Should the watcher append completion events automatically when it sees `status: verified`, or should reviewer do it manually?
- [ ] Do you want a Neovim command/keymap to create sessions and open `source-note.md`?

## Notes

Current implementation is intentionally file-first and dependency-free. The watcher uses polling and SHA-256 checks so it works without `fswatch` or `watchman`.
