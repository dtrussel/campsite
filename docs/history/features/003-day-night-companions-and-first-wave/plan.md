# Feature 003 — Day/night, companions, and first wave

## Goal

Wire the world's clock to real phase transitions, place a companion at
the campsite from the start of the run, give the player hotkeys to
assign companion tasks during both day and night, and spawn the first
nightly mob wave that attacks the campfire (with any placed fences
absorbing damage on the way). This satisfies **Phase 5 of the roadmap
and brings Phase 4 forward** so companions are part of normal daytime
play, not just a defensive measure.

## Why it matters

Closes the survive-the-night loop: gather by day, build defenses,
assign companions, defend at night, return to day. Exercises every
data-driven system shipped so far (`ResourceManager`, `BuildManager`),
the existing `Building.take_damage` stub from Feature 002, and the
roadmap's signal vocabulary on `TimeManager`.

Pillars served:
- *Survive nightly mob attacks* (primary)
- *Command companions with simple tasks* (primary)
- *Build and improve a campsite base* (validated under fire)
- *Balance cozy camping fantasy with danger and defense* (the day/night
  dichotomy is the core mood beat)

## Scope

### In scope
- `TimeManager` real phase transitions: `day → sunset → night → dawn →
  day` with configurable durations and per-phase signals.
- Sun light + ambient dim during sunset and night.
- HUD: live phase text, countdown until the next phase, base HP from
  the campfire, current companion task, red night-warning during
  sunset.
- `BaseCore` script on `CampfireCore.tscn` with HP, `take_damage`,
  `repair`, `destroyed` signals; `base_core` group.
- `MobDefinition` data class + Shadow Imp `.tres`.
- `ShadowImp.tscn` + `mob_controller.gd` AI: walk toward the
  campfire; attack whatever (fence, watch post, campfire) blocks the
  path; die at zero HP.
- `MobSpawner` node placed in `TestWorld` with four spawn points;
  listens to `TimeManager.night_started`, spawns the wave, emits
  `wave_started` / `wave_ended`.
- `CompanionDefinition` data class + Sibling `.tres`.
- `Sibling.tscn` + `companion_controller.gd` task state machine:
  `IDLE`, `FOLLOW_PLAYER`, `GUARD_BASE`, `GATHER_NEAREST`.
- New input actions: `attack` (mouse left), `assign_idle` (Y),
  `assign_follow` (F), `assign_guard` (G), `assign_gather` (T).
- Minimal **player attack** (LMB outside build mode): nearest mob in
  range, damage 4, cooldown 0.4 s.
- Minimal **companion attack** while in `GUARD_BASE`: nearest mob in
  range, damage 3, cooldown 0.6 s.
- A `Label3D` tag above the companion showing the current task.

### Out of scope
- XP, leveling, level-up effects (Phase 6).
- Companion damage / knockout / recovery (companions invulnerable for
  now).
- Multiple companions or mob types.
- Repair task / Scout task / Support-Combat task.
- Navigation meshes; mobs walk in a straight line and attack what they
  bump into.
- Save / load (Phase 8).
- Lose-state UI: when the campfire is destroyed, the game just stops
  spawning new waves and logs a console message.

## Approach

Bottom-up, mirroring proven patterns:
1. Data classes (`MobDefinition`, `CompanionDefinition`) + `.tres`.
2. `BaseCore` on `CampfireCore`.
3. Mob scene + AI; verify in isolation by force-spawning.
4. Mob spawner wired to `TimeManager.night_started`.
5. `TimeManager` phase machine + lighting.
6. Companion scene + task state machine; hotkeys to assign.
7. Player attack action.
8. HUD wiring for phase, base HP, companion task, night warning.

## Dependencies

- Features 000, 001, 002 (the autoloads, the inventory, the
  buildings).
- Godot 4.x locally for manual playtest.

## Open questions / working assumptions

- **Companion damage:** not in scope; assume companions are
  invulnerable. Revisit before Phase 6.
- **Game over:** when base HP hits zero the wave still finishes, but
  no further waves spawn and the HUD shows a "Camp destroyed"
  message. No reload / retry yet.
- **Mob count tuning:** prototype starts at 4 Shadow Imps in night 1
  over ~30 s. Scaling deferred to a balance pass.
- **Companion deposits:** the companion gathers exactly like the
  player — `ResourceNode.begin_gather` → on `gathered` signal
  `ResourceManager.add` already runs in the node, so no manual deposit
  logic is needed.
