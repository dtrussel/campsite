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

### 4. Script-level tests (the unit pass)

- Unit tests of pure-logic GDScript (the run config's rules, the
  profile's verbs and unlocks, the badge rule) through a module's
  public interface, in a small runner of our own (no add-on). See
  "Writing unit tests" below.

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
  - `game/tests/unit/unit_run.tscn` is the unit-test pass from layer 4,
    a small runner of our own (no add-on). It plays every
    `game/tests/unit/test_*.gd` script (extending `unit_test.gd`, with
    `check` and `check_eq`) and each `test_*` method in it, on a fresh
    instance, then its `after_each()`, with the autoloads up but no
    gameplay scene. A new module adds its own test script.
    `-- --unit <name>` plays just one script. See "Writing unit tests".
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
- **Hero clip checks** (in the validator, `game/tools/clip_checks.gd`).
  For every hero, each mapped state must have its clip in the model
  (always enforced). Then, measured as data with no scene or Blender:
  - **loop:** idle, walk and run's last pose against their first (the
    largest joint jump and bone turn at the wrap; limits 1 cm, 3°);
  - **slide:** how far a foot slides per stride, at the speed the game
    moves the hero (walk at `CharacterVisual.walk_speed`, the clip at
    1x; run at the hero's `move_speed`, the clip at the run scale). A
    foot counts as down within 2 cm of its lowest point (limit 4 cm);
  - **duration:** each action's length at its gameplay play speed
    (`PLAY_SPEEDS`) against its gameplay length (`ACTION_SECONDS`, the
    stock lengths; ±0.05 s).
  - **contact time:** a hero's `attack_contact_time` must come within
    the wind-up cap at play speed, inside the attack clip, and, for a
    hand-made clip, equal the clip script's: `art/characters/hero_clips.py`
    records each clip it keys in `<kid>_clips.json` beside the model
    (`_validate_hero_clip_records`). Always enforced.

  Each check reports until `ENFORCED` (hero, state, checks) switches
  it to failing the validator. `tools/check.sh` shows one summary line;
  `godot --headless --path game res://tools/validate_project.tscn -- --clips`
  prints every number. The pure measures have unit tests
  (`test_clip_checks.gd`).
- **Hero captures** (review, not pass/fail): `game/tools/hero_capture.tscn`
  records a hero playing states in the game, as the player and as the
  companion, and writes PNG strips (or every frame, for a GIF). It also
  stacks an old capture over a new one. Usage is in its header:
  `xvfb-run -a godot --path game --resolution 320x180 --fixed-fps 30 res://tools/hero_capture.tscn -- <out_dir> leo walk attack`.
  The clay contact sheets come from Blender (`art/review/clip_sheet.py`,
  see `art/README.md`).
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

## Writing unit tests

- **Where:** a new `game/tests/unit/test_<module>.gd` per module (for
  example `test_run_config.gd`, `test_profile.gd`, `test_badges.gd`).
  It touches nothing shared: the runner finds every `test_*.gd` itself.
- **Shape:** the script extends `"res://tests/unit/unit_test.gd"` and
  defines `test_*` methods, each a few checks on one rule. The runner
  calls them in the order they are written, each on a fresh instance,
  synchronously (no `await`). The autoloads are up, but there is no
  gameplay scene or camp.
- **Checks:** `check(condition, what)` and
  `check_eq(actual, expected, what)`. `check_eq` compares types too, so
  a number read back from JSON is a float, not an int.
- **Setup and teardown:** build what a test needs in `_init()` or the
  test itself, and override `after_each()`, which the runner calls after
  every test method, to free it. For the profile, preload
  `res://scripts/core/profile.gd`, make a fresh one and call
  `use_memory()` (see `test_profile.gd`). A test of a module that reads
  the `Profile` autoload itself calls `Profile.use_memory()` first, and
  again in `after_each()`, so it never touches the player's file
  (`test_run_session.gd`). A test that needs a file keeps
  its own under `user://` and removes it in `after_each()`
  (`test_profile_file.gd`).
- **Run one script:**
  `godot --headless --path game res://tests/unit/unit_run.tscn -- --unit <name>`
  (`<name>` without `.gd`). Not `--test`, which Godot itself takes. On
  a fresh worktree, run `godot --headless --path game --import` first,
  or class names fail to load.
- **Read the output, not just the last line.** A test that calls a
  missing method (or hits any other script error) stops there but still
  ends with `unit: PASSED`. `tools/check.sh` fails the pass on any
  `SCRIPT ERROR` in its log; when you run the scene by hand, look for
  one yourself.

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
