# Feature 003 — Status

## 2026-05-16 — Implementation session

**Completed**

- Feature folder with all five workflow docs.
- `TimeManager` upgraded to a real phase machine
  (`DAY → SUNSET → NIGHT → DAWN`) with per-phase durations, signals,
  and remaining-time queries.
- `WorldLighting` node + script: snaps sun/ambient between day and
  night palettes on phase transitions.
- `BaseCore` script attached to `CampfireCore.tscn`; HP, damage,
  repair, destroyed signal; `base_core` group.
- `MobDefinition` + `shadow_imp.tres`.
- `ShadowImp.tscn` + `mob_controller.gd` (target campfire, attack what
  blocks, die at 0 HP).
- `MobSpawner` node placed in `TestWorld` with four edge spawn
  points; listens to `night_started`.
- `CompanionDefinition` + `sibling.tres`.
- `Sibling.tscn` + `companion_controller.gd` with `IDLE`,
  `FOLLOW_PLAYER`, `GUARD_BASE`, `GATHER_NEAREST` and a Label3D task
  tag.
- Hotkeys for companion task assignment (F/G/T/Y).
- Player LMB attack outside build mode (damage 4, range 1.8, cooldown
  0.4 s).
- HUD shows live time-of-day with remaining seconds, real base HP,
  current companion task, and a red sunset warning.

**Next**

- Manual playtest of `test-plan.md`.
- Feature 004 candidates: combat polish + XP / leveling (Phase 6 of
  the roadmap), or crafting (Phase 7), or save/load (Phase 8).

**Blocking**

- None.
