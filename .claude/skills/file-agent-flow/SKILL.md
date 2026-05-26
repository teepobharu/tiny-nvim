---
name: file-agent-flow
description: File-based multi-agent handoff workflow. Use when a user asks agents to watch files, coordinate through notes, send requirements to another agent, or report status to a receiver file.
---

# File Agent Flow Skill

Use this skill to coordinate multiple agents through files instead of chat memory. The flow is intentionally generic: every use case has a reusable template, and every run/session gets its own folder.

## Core idea

- **Source files** are the user-facing inputs, such as a rough note or requirement.
- **Agent inbox/outbox/status files** are the contract between agents.
- **Handoff files** are immutable-ish messages from one role to another.
- **Receiver end** is `receiver/status.md` plus `receiver/events.jsonl`; it is the place to report what changed and what state the session is in.
- **Watcher** is optional but useful: `scripts/agent-flow-watch.py` polls session files and updates the receiver end.

## Folder convention

```text
agent-flows/
├── README.md
├── usecases/
│   └── <usecase>/
│       ├── README.md
│       └── session-template/
└── sessions/
    └── <usecase>/
        └── <session-id>/
            ├── README.md
            ├── source-note.md
            ├── tasks.md
            ├── receiver/
            │   ├── status.md
            │   ├── events.jsonl
            │   └── completions.jsonl
            ├── agents/
            │   ├── planner/{inbox.md,outbox.md,status.md}
            │   ├── worker/{inbox.md,outbox.md,status.md}
            │   └── reviewer/{inbox.md,outbox.md,status.md}
            ├── handoffs/
            ├── iterations/
            ├── jobs/
            └── worklog/
```

## Start a session

1. Pick a use case template under `agent-flows/usecases/<usecase>/session-template/`.
2. Copy it to a unique session folder:

```bash
SESSION="$(date +%Y%m%d-%H%M%S)-short-name"
mkdir -p "agent-flows/sessions/note-plan-work-review"
cp -R agent-flows/usecases/note-plan-work-review/session-template \
  "agent-flows/sessions/note-plan-work-review/$SESSION"
```

3. Put the user note/request in `source-note.md`.
4. Start the watcher if the user wants live file-change reporting:

```bash
python3 scripts/agent-flow-watch.py "agent-flows/sessions/note-plan-work-review/$SESSION"
```

## Handoff protocol

Every handoff should use this frontmatter shape:

```yaml
---
flow: note-plan-work-review
session: <session-id>
from: planner
to: worker
status: ready
created: 2026-05-23T00:00:00+07:00
updated: 2026-05-23T00:00:00+07:00
requires_response: true
---
```

Recommended statuses:

- `draft` — being prepared
- `ready` — ready for the target role
- `accepted` — target role has started
- `blocked` — target role cannot proceed without input
- `done` — target role finished its part
- `needs-changes` — reviewer/sender found gaps
- `verified` — reviewer/sender accepted the result

## Role loop for note → plan → work → review

1. **Planner/sender** reads `source-note.md` and writes:
   - `agents/planner/outbox.md`
   - `handoffs/001-planner-to-worker.md`
   - optionally copies the actionable requirements to `agents/worker/inbox.md`
2. **Worker** reads its inbox/handoff, does the work, then writes:
   - `agents/worker/status.md`
   - `agents/worker/outbox.md`
   - `handoffs/002-worker-to-reviewer.md`
3. **Reviewer/sender** reads the worker output and verifies:
   - if incomplete: write `handoffs/003-reviewer-to-worker.md` with `status: needs-changes`
   - if accepted: update `agents/reviewer/status.md` with `status: verified`
4. The watcher updates `receiver/status.md` whenever files change.

## Agent behavior rules

- Keep each session self-contained; do not write one session's status into another session.
- Prefer appending to work logs and creating new handoff files over rewriting old handoffs.
- Do not silently change another role's outbox. Reply via a new handoff instead.
- Always update `updated:` and `status:` in the file you are responsible for.
- Put user-verifiable acceptance criteria in reviewer output.
- If implementing code, follow root `AGENTS.md` and `tasks/AGENTS.md` in addition to this flow.

## Job and iteration tracking

Use these files to track finished work and repeated loops:

- `tasks.md` is the session task board. It has Active, Finished, and Archived sections.
- `jobs/job-###/README.md` is the durable record for one job/task.
- `iterations/###-name.md` records one plan → work → review loop.
- `receiver/completions.jsonl` can be appended to when a job reaches `verified` or `accepted-by-user`.

Close-out states:

1. Worker finishes implementation: job `status: review` or handoff `status: done`.
2. Reviewer accepts: job `status: verified`; move row from Active to Finished in `tasks.md`.
3. User accepts: job `status: accepted-by-user`; optionally move job folder to `archive/completed/`.

Agents can mark `verified`; only the user should mark `accepted-by-user`.
