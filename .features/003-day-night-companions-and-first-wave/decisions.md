# Feature 003 — Decisions

## D-003-1 — Companions present from start, assignable during the day

- **Decision:** A Sibling companion spawns in `TestWorld` from the
  start of the run. Task hotkeys work during day and night. This
  pulls Phase 4 of the roadmap forward into the Phase 5 feature.
- **Rationale:** Explicit user request and stronger feel — the boy is
  not alone, and the day has more to do (assign gathering /
  following) than just waiting for night. The integration cost is
  small because the gather pipeline (`ResourceNode.begin_gather`) is
  actor-agnostic from Feature 001.

## D-003-2 — Mob targeting via collision, not navigation mesh

- **Decision:** Mobs walk in a straight line toward the campfire's
  position. When `CharacterBody3D.move_and_slide` reports a slide
  collision with a `Building` (or `BaseCore`), the mob enters
  `ATTACKING` and damages that target on a cooldown. When the target
  is destroyed (`take_damage` returns to `current_hp == 0`), the mob
  resumes walking.
- **Rationale:** A full navigation mesh is overkill for a prototype
  with a flat ground and small object count. Straight-line + bump
  delivers the intended "fences absorb attention" gameplay almost
  exactly. We can introduce `NavigationAgent3D` in a later feature
  without changing the mob's public API.

## D-003-3 — Combat is minimal, no XP yet

- **Decision:** The player and a guarding companion can both attack
  the nearest mob in range with simple cooldown-based melee. No
  combo, no charge, no XP, no level-up.
- **Rationale:** Without any combat the wave can never be cleared;
  with full combat the feature triples in size and overlaps Phase 6.
  Minimal combat solves the immediate need without precluding Phase 6.

## D-003-4 — Companions are invulnerable

- **Decision:** Companions take no damage. Mobs ignore companions
  entirely and target buildings or the base core. The companion's
  `Sibling.tscn` has no HP field exposed to the world.
- **Rationale:** Companion damage opens questions (knockout vs
  death, recovery rules, panic AI) that deserve their own pass.
  Cutting it now keeps the focus on the day/night loop.

## D-003-5 — Wave logic owned by a scene-level node, not an autoload

- **Decision:** `MobSpawner` is a `Node3D` instance inside
  `TestWorld.tscn` with four `Marker3D` children at the map edges.
  It listens to `TimeManager.night_started`. Different maps can use
  different spawners later.
- **Rationale:** Spawn behaviour is map-specific (positions, counts,
  mob mix), so it belongs in the scene. Autoload would force
  global-by-default and complicate later level swaps.

## D-003-6 — Companion task hotkeys apply to the lone companion

- **Decision:** With one companion in the prototype, **F / G / T / Y**
  always target it directly — no selection step. The companion's
  current task is shown in the HUD and above its head.
- **Rationale:** Selection UI is its own feature. When a second
  companion lands, this rule expands to "apply to last-selected
  companion, default to closest", with no migration of inputs.

## D-003-7 — `TimeManager` resets the clock at phase transitions

- **Decision:** Instead of computing the phase from a single
  normalized time-of-day, the manager owns `current_phase` and a
  `remaining_seconds` countdown. When the countdown hits zero it
  transitions to the next phase, resets the countdown to the new
  phase's duration, and emits the matching signal.
- **Rationale:** Phase changes are first-class events the game cares
  about. The previous "normalized time" was fine for the bootstrap
  but invites floating-point drift when each phase has a different
  duration.

## D-003-8 — Game over is silent for now

- **Decision:** When `BaseCore.destroyed` fires, the spawner stops
  spawning and the HUD shows "Camp destroyed". The game does not
  reload, retry, or show a screen.
- **Rationale:** A proper lose flow needs UI and intent (retry / quit
  / new game). Out of scope; document the gap and move on.

## D-003-9 — LMB action overload (build vs. attack)

- **Decision:** Two distinct input actions share LMB: `confirm_build`
  and `attack`. `BuildManager` reacts to `confirm_build` only when in
  build mode and calls `set_input_as_handled()`; the player reacts to
  `attack` only when **not** in build mode.
- **Rationale:** Cleanest mapping that does not introduce a third
  modifier key. Each handler gates itself so input-propagation order
  is irrelevant.
