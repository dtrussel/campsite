# Test strategy

> Lightweight, pragmatic testing approach for an indie prototype that must
> stay fast to iterate on. As features stabilize the testing surface
> grows.

## Layers

### 1. Manual smoke testing (always)

- Every phase has a smoke checklist under
  `.features/<phase>/test-plan.md`.
- Smoke testing covers: project opens, main scene runs, no errors on
  startup, key controls work, no obvious visual regressions.

### 2. Manual playtest checklists (per feature)

- Each feature folder includes a `test-plan.md` with concrete acceptance
  criteria from the roadmap, expressed as checkboxes a human can run
  through in a few minutes.

### 3. Data validation (as systems land)

- Once `.tres` resources matter (recipes, mob defs, building defs), we
  add a validation tool under `tools/` that loads every `.tres` under
  `game/resources/`, checks required fields, and verifies referenced IDs
  exist.
- Wired into a dev-only menu option or a CLI script.

### 4. Script-level tests (when systems stabilize)

- Optional adoption of [GUT](https://github.com/bitwes/Gut) or an
  equivalent for unit-testing pure-logic GDScript (resource math, XP
  table lookups, recipe satisfaction).
- Not in Phase 0. Introduced no earlier than Phase 6 (combat / XP).

### 5. Integration / smoke scenes (later)

- Dedicated scenes that script-drive a system in isolation (e.g. a
  &ldquo;mob aggro&rdquo; scene that spawns three Shadow Imps and a
  campfire and runs them for 30 seconds while logging events).

## Acceptance criteria pattern

Each roadmap phase ends in &ldquo;Acceptance criteria&rdquo;. The matching
`.features/*/test-plan.md` reproduces those criteria as checkboxes the
tester ticks. A phase is &ldquo;done&rdquo; only when its checkboxes are
all green and `handoff.md` is updated.

## Tools and conventions

- Manual smoke tests are run inside the Godot editor with **F5**.
- Console errors and warnings on startup are bugs.
- If a system depends on a `.tres` file, the data validator must pass
  before the system is considered done.

## What we explicitly do not test (yet)

- Performance under load (waiting for real mob counts).
- Save / load round-trip across version migrations (waiting for save
  format to stabilize).
- Localization.
- Accessibility beyond readable HUD text.
