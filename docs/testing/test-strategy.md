# Test strategy

> Lightweight, pragmatic testing approach for an indie prototype that must
> stay fast to iterate on. As features stabilize the testing surface
> grows.

## Layers

### 1. Manual smoke testing (always)

- Every spec and ticket in `.scratch/` lists its acceptance criteria as
  checkboxes. Checks that need a person playing go in a `ready-for-human`
  ticket; the standing list is `.scratch/hand-play-backlog/`.
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
spec or ticket in `.scratch/` reproduces those criteria as checkboxes the
tester ticks. A ticket is &ldquo;done&rdquo; only when its checkboxes are
all green and its `Status:` line says `done`. (Features 000&ndash;048 kept
them in `test-plan.md` files, archived in `docs/history/features/`.)

## What exists today

- `tools/check.sh` runs the whole headless suite. Run it before every
  push:
  - `game/tools/validate_project.tscn` is the data validator from
    layer 3. It also fails on any script, scene, or resource that
    doesn't load.
  - `game/tests/automated/smoke_run.tscn` is the integration smoke
    scene from layer 5. It plays every scenario script in
    `game/tests/automated/scenarios/` (one per feature: `chapter_1.gd`
    plays a whole won and a lost Chapter 1 run, `tool_tiers.gd`,
    `endless.gd`, `badges.gd` and so on), sorted by file name, each
    from a clean slate. `-- --scenario <name>` plays just one.
  - The same scene again with `-- --frame-stall 150`, beside the
    plain pass: it blocks 150 ms on every 4th frame, so the frame after
    is long. It adds about 25 s to `tools/check.sh`.
  - With `SMOKE_FRAME_DELAY=40` (as CI runs it), a third pass sleeps
    40 ms every frame.
- `game/tests/sim/balance_sim.tscn` is a tuning aid, not pass/fail.
- `game/tests/sim/screenshots.tscn` captures the key screens under
  Xvfb for visual review.
- Exported builds support `-- --selftest` to prove the PCK loads its
  data.
- CI (`.github/workflows/build.yml`) runs `tools/check.sh` and
  `tools/export_playtest.sh` (including the Linux self-test) on every
  push and pull request.
- Headless tests run as **scenes**, not `-s` scripts, because `-s`
  runs without autoloads.

## Writing smoke and validator checks

- **Seams:** a ticket's smoke and validator checkboxes are its agreed
  seams. Test there; the tdd skill's "confirm the seams with the user"
  is already done when the ticket is `ready-for-agent`.
- **Where a smoke check goes:** in its feature's script under
  `game/tests/automated/scenarios/`. A new feature adds a new script
  and touches nothing shared. The script extends
  `res://tests/automated/smoke_scenario.gd` and defines `run()`, which
  awaits its scenarios in order. The shared helpers live in that base:
  `_start_fresh_run`, `_continue_from`, `_config`, `_wait`,
  `_wait_until`, `_check`, `_spawn_mob` and the rest. Move a helper
  there only once a second script needs it.
- **No script depends on another.** Every script starts from a clean
  slate: no camp, nothing left on the test root, no save, a fresh
  profile and story, Leo with Nela on a 3-night story run. The scripts
  run in file-name order, but nothing relies on that. Steps that need
  the step before go in the same script, as `chapter_1.gd` does for
  the win, the chapter lock it opens, and Continue from its autosave.
- **Wait on a condition, not a duration.** A check that follows
  something in flight (a pebble's tween, a burn's ticks, a fade, a
  windup's hit timer) waits with
  `await _wait_until(func() -> bool: return <condition>, <game seconds>)` and
  asserts on its result. A fixed `_wait()` started beside a tween or a
  timer races it: Godot runs timers before tweens, so one long frame
  lets the wait win. The stalled pass in `tools/check.sh` makes those
  long frames, so such a check goes red locally. A steady frame delay
  (`SMOKE_FRAME_DELAY`) rarely catches it, because it does not make one
  long frame. To check a fix, run
  `godot --headless --path game res://tests/automated/smoke_run.tscn -- --scenario <name> --frame-stall 150`.
- `tools/check.sh` gives every run its own `user://`, so parallel runs
  (one per worktree) never share save or profile files.

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
