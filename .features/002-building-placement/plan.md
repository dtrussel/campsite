# Feature 002 — Building placement

## Goal

Add the second gameplay verb: **build**. The player presses **B** to
enter build mode, a translucent ghost of the chosen building follows the
mouse cursor, turns green or red based on placement validity, and on
left-click consumes resources via `ResourceManager.spend_costs(...)` and
spawns the real building in the world. This satisfies Phase 3 of the
roadmap end-to-end.

## Why it matters

Closes the gather → spend → reshape-the-world loop and gives Phase 5
(mob waves) something to attack and Phase 4 (companions) something to
repair. Pillars served: *Build and improve a campsite base* (primary),
*Survive nightly mob attacks* (sets up Phase 5), *Maintain strong visual
clarity* (clear green/red feedback).

## Scope

### In scope
- `BuildingDefinition` data class.
- Two `BuildingDefinition` `.tres` files (Wooden Fence, Watch Post).
- `Building` shared script (root behaviour for placed buildings; HP API
  is stubbed for Phase 5).
- `WoodenFence` and `WatchPost` scenes.
- `BuildManager` autoload owning build mode + the active ghost.
- New input actions: `toggle_build_mode`, `select_building_1`,
  `select_building_2`, `confirm_build`, `cancel_build`.
- Ground group on `TestWorld.tscn` so the ghost footprint can filter the
  ground out of overlap checks.
- HUD `BuildModeLabel` surfaced when build mode is active.

### Out of scope
- Building rotation (`R` key).
- Multi-building selection UI / hotbar.
- Damage / repair gameplay (HP API exists, but nothing damages or
  repairs in this feature).
- Snap-to-grid.
- Save / load of placed buildings (Phase 8).

## Approach

Mirror the data-driven pattern Feature 001 proved:
- `BuildingDefinition` (`Resource`) parallels `ResourceDefinition`.
- `Building` (`StaticBody3D`) parallels `ResourceNode`.
- `BuildManager` (autoload) parallels `ResourceManager` with the same
  `DirAccess` loading idiom.

Build bottom-up: data class → `.tres` files → building script and
scenes → autoload → input wiring → HUD wiring → ground group.

## Dependencies

- Feature 001 (ships `ResourceManager.spend_costs` and the data-driven
  patterns this feature reuses).
- Godot 4.x installed locally for the manual acceptance checks.
