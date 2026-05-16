# `.features/` &mdash; Agent feature workflow

This folder is where larger pieces of work are planned, tracked, and
handed off between humans and coding agents. The goal is to keep
multi-session work understandable and auditable without dragging the main
documentation around with it.

## When to create a feature folder

Create a folder when a piece of work:

- spans more than one short session;
- touches multiple systems;
- introduces a new system, mechanic, or workflow;
- needs explicit hand-off to another agent or contributor.

Small fixes (a typo, a one-file bug fix, a renamed variable) do **not**
need a feature folder. Use a normal commit.

## Folder layout

Each feature is a folder named `NNN-short-slug` where `NNN` is a zero-padded
number. Each folder contains exactly these files:

```
plan.md         # what we are doing and why
status.md       # current progress, updated as work proceeds
decisions.md    # decisions made during the feature
test-plan.md    # acceptance criteria as checkboxes
handoff.md      # what the next agent / contributor needs to know
```

## Required behavior for agents

- Agents shall **update `status.md`** after meaningful work.
- Agents shall **update `handoff.md`** before ending a session, including
  what is done, what is left, and any new open questions.
- Agents shall **document assumptions** in `decisions.md` whenever they
  pick a path that was not explicitly specified.
- Agents shall **not start large unrelated work** without creating or
  updating a feature folder.
- Agents shall keep documentation under `docs/` in sync when a feature
  changes the architecture, design, or roadmap.

## File templates

### `plan.md`
- Goal of the feature.
- Why it matters (which game pillar / requirement it serves).
- Scope: in / out.
- High-level approach.
- Dependencies and prerequisites.

### `status.md`
- Date-stamped log entries.
- Each entry: what changed, what is next, what is blocking.

### `decisions.md`
- Each decision: context, options considered, chosen option, why.
- Reference ADRs under `docs/decisions/` if relevant.

### `test-plan.md`
- Acceptance criteria as checkboxes.
- Smoke checklist (open project, run main scene, etc.).
- Edge cases worth exercising.

### `handoff.md`
- Current state in 5 lines.
- Files created / changed.
- Known issues and limitations.
- Next recommended steps.
- Open questions.
- How to open / run the project to reproduce current state.

## Numbering

- `000-` is reserved for the bootstrap feature.
- Subsequent features increment: `001-`, `002-`, etc.
- Numbers are assigned at folder creation and never recycled.
