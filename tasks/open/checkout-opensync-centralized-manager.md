---
title: "Checkout centralized manager for CLI agents (opensync)"
status: "open"
assignee: "ai"
created: 2026-02-10
priority: "high"
---

Evaluate the `opensync` centralized manager (https://github.com/waynesutton/opensync) as a possible upstream for orchestrating our CLI agents (MCPHub / CodeCompanion integrations).

Goals
- Clone and build `opensync` locally and confirm it runs.
- Map its components and API surface to our existing MCPHub/agent architecture.
- Produce a short integration plan (options: adapter, fork, or embed) with migration risks and required changes.

Acceptance criteria
- `opensync` repo is cloned and a local run/smoke-test is documented.
- A one-page mapping is produced showing where our agents would attach (endpoints, protocols, auth).
- A recommended integration approach with estimated effort (low/medium/high) and any blocking issues.

Suggested steps
1. Clone the repository and list supported runtimes and dependencies.
   - `git clone https://github.com/waynesutton/opensync.git`
2. Follow the project's README to build/run the manager and run any included examples or tests.
3. Create notes: required ports, config formats, plugin hooks, and how agents register with the manager.
4. Compare with MCPHub's features (porting, workspace mode, fixed port requirement) and identify mismatches.
5. Draft an integration plan with 3 options: (1) adapter layer, (2) lightweight fork, (3) replace MCPHub — include pros/cons and estimate.
6. Add follow-up tasks (implementation, docs, CI) based on the chosen option.

References
- https://github.com/waynesutton/opensync

Notes
- I will start working on this task; when complete I will move it to `tasks/wip/` and attach the notes and mapping as additional files under `tasks/`.
