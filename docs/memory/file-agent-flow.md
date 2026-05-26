# File Agent Flow

Local file-based coordination pattern for multi-agent work. Use it when chat context is not enough and you want persistent handoffs between roles.

## What it solves

- Write a rough note in a file.
- Let a planner/sender agent convert the note into requirements.
- Let a worker agent execute those requirements.
- Let the sender/reviewer verify and either request changes or mark the result verified.
- Keep a receiver-end status file that reports file changes and current role status.

## Project locations

| Purpose | Path |
| --- | --- |
| Skill instructions | `.claude/skills/file-agent-flow/SKILL.md` |
| Planner agent | `.claude/agents/flow-planner.md` |
| Worker agent | `.claude/agents/flow-worker.md` |
| Reviewer agent | `.claude/agents/flow-reviewer.md` |
| New session helper prompt | `.claude/commands/flow-new-session.md` |
| Status helper prompt | `.claude/commands/flow-status.md` |
| Flow docs/templates | `agent-flows/` |
| Watcher | `scripts/agent-flow-watch.py` |

## Folder model

```text
agent-flows/
├── usecases/
│   └── note-plan-work-review/
│       ├── README.md
│       └── session-template/
└── sessions/
    └── note-plan-work-review/
        └── <session-id>/
            ├── source-note.md
            ├── receiver/{status.md,events.jsonl}
            ├── agents/{planner,worker,reviewer}/{inbox.md,outbox.md,status.md}
            ├── handoffs/
            └── worklog/
```

## Create a session

```bash
SESSION="$(date +%Y%m%d-%H%M%S)-demo"
mkdir -p agent-flows/sessions/note-plan-work-review
cp -R agent-flows/usecases/note-plan-work-review/session-template \
  "agent-flows/sessions/note-plan-work-review/$SESSION"
```

Edit:

```bash
$EDITOR "agent-flows/sessions/note-plan-work-review/$SESSION/source-note.md"
```

Run one receiver update:

```bash
python3 scripts/agent-flow-watch.py "agent-flows/sessions/note-plan-work-review/$SESSION" --once
```

Run live watcher:

```bash
python3 scripts/agent-flow-watch.py "agent-flows/sessions/note-plan-work-review/$SESSION"
```

## Handoff statuses

| Status | Meaning |
| --- | --- |
| `draft` | Being prepared |
| `ready` | Ready for the target role |
| `accepted` | Target role has started |
| `blocked` | Cannot proceed without input |
| `done` | Role finished its part |
| `needs-changes` | Reviewer found gaps |
| `verified` | Reviewer accepted the result |

## Watcher notes

- Dependency-free Python polling; no fswatch/watchman required.
- Tracks SHA-256 content changes to detect modifications.
- Writes `receiver/events.jsonl` as JSONL.
- Regenerates `receiver/status.md` as a readable dashboard.
- Excludes receiver output and watcher state by default to avoid feedback loops.

## Recommended prompts

Planner:

```text
Use the file-agent-flow skill as flow-planner. Session path: agent-flows/sessions/note-plan-work-review/<session-id>. Read source-note.md and create the worker handoff.
```

Worker:

```text
Use the file-agent-flow skill as flow-worker. Session path: agent-flows/sessions/note-plan-work-review/<session-id>. Execute the latest handoff addressed to worker and report back in files.
```

Reviewer:

```text
Use the file-agent-flow skill as flow-reviewer. Session path: agent-flows/sessions/note-plan-work-review/<session-id>. Verify worker output against the source note and planner handoff.
```


## Finished jobs and iteration history

Added files in each session template:

- `tasks.md` — quick board with Active, Finished / verified, and Archived sections.
- `jobs/job-000-template/README.md` — durable per-job completion record.
- `iterations/000-template.md` — template for each plan → work → review loop.
- `receiver/completions.jsonl` — optional append-only completion events.

Close-out convention:

| State | Who can set | Meaning |
| --- | --- | --- |
| `review` | worker | Work is ready to check |
| `needs-changes` | reviewer | Another iteration is required |
| `verified` | reviewer/agent | Work satisfies the plan |
| `accepted-by-user` | user | User accepted/closed it |

This separation avoids agents hiding unfinished work as completed. It matches the repo rule where agents can move task work to review, but only the user moves it to completed.
