# Feature Planning Workflow

This directory tracks feature-level work across development sessions and coding agents.

---

## Why This Exists

Game development involves many sessions, multiple agents, and frequent context switches. Without a shared handoff structure, agents lose track of:
- What was decided and why
- What is implemented vs. stubbed
- What is broken or incomplete
- Where the next agent should start

This workflow solves that by giving every significant feature its own folder with persistent state.

---

## Folder Structure

Each feature gets a folder named `NNN-feature-name/` where `NNN` is a zero-padded sequence number.

```
.features/
├── README.md                       ← this file
├── 000-project-bootstrap/
│   ├── plan.md                     ← what we intend to build
│   ├── status.md                   ← current completion state
│   ├── decisions.md                ← decisions made during this feature
│   ├── test-plan.md                ← how to verify the feature is done
│   └── handoff.md                  ← what the next agent needs to know
├── 001-playable-movement/
│   └── ...
└── ...
```

---

## File Responsibilities

### `plan.md`
- Written before work begins.
- Describes the goal, scope, deliverables, and approach.
- Should be stable; major changes to the plan create a note in `decisions.md`.

### `status.md`
- Updated **after every work session**.
- Tracks which deliverables are done, in-progress, or blocked.
- Includes the last known working state.
- Uses checkboxes: `- [x] done`, `- [ ] not started`, `- [~] in progress`.

### `decisions.md`
- Records every decision made that affects this feature.
- Includes: what was decided, why, and what alternatives were considered.
- Decisions here are scoped to this feature; cross-cutting decisions go in `docs/decisions/ADR-####.md`.

### `test-plan.md`
- Lists acceptance criteria for the feature.
- Includes step-by-step manual test procedures.
- A feature is **not done** until all criteria here pass.

### `handoff.md`
- Written at the **end of every session** by the working agent.
- Includes: current state, files changed, known issues, next steps, open questions.
- The next agent reads this file first.

---

## Agent Rules

1. **Before starting a session:** Read the `handoff.md` of the current active feature.
2. **Before starting a new feature:** Create a new `NNN-feature-name/` folder with all five files.
3. **During the session:** Update `status.md` as items are completed.
4. **At the end of every session:** Update `handoff.md` with the current state, next steps, and any unresolved questions.
5. **Never start large unrelated work** without creating or updating a feature folder first.
6. **Never mark a feature done** in `status.md` without passing the acceptance criteria in `test-plan.md`.

---

## Feature Status Values

| Status | Meaning |
|--------|---------|
| `PLANNED` | Feature is defined but no work has started |
| `IN PROGRESS` | Active work is happening |
| `BLOCKED` | Cannot proceed — reason documented in status.md |
| `REVIEW` | Implementation done; awaiting acceptance criteria verification |
| `DONE` | All acceptance criteria passed |
| `ABANDONED` | Decided not to implement — reason documented |

---

## Current Features

| # | Name | Status |
|---|------|--------|
| 000 | Project Bootstrap | IN PROGRESS |
