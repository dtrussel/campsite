# Feature 003 — Handoff

## Current project status

The game now has its first real day/night loop. The boy starts in day
1 with the Sibling companion already at the camp. The clock advances
through `Day → Sunset → Night → Dawn`; sunset turns the HUD label red;
night dims the sun. Shadow Imps emerge from the map edges at night,
walk toward the campfire, and attack anything that blocks them (fences
absorb attention before the campfire does). The boy can attack mobs
with LMB; a guarding companion attacks mobs in range. The campfire has
real HP and a "Camp destroyed" lose state.

Companions are present from start and can be assigned tasks during the
day or night: **F** follow, **G** guard, **T** gather, **Y** idle.

Branch: `claude/bootstrap-godot-game-TEdp5`.

## Files created in this feature

- `.features/003-day-night-companions-and-first-wave/{plan,status,decisions,test-plan,handoff}.md`
- `game/scripts/base/base_core.gd`
- `game/scripts/mobs/mob_definition.gd`
- `game/scripts/mobs/mob_controller.gd`
- `game/scripts/mobs/mob_spawner.gd`
- `game/scripts/companions/companion_definition.gd`
- `game/scripts/companions/companion_controller.gd`
- `game/scripts/world/world_lighting.gd`
- `game/resources/mobs/shadow_imp.tres`
- `game/resources/companions/sibling.tres`
- `game/scenes/mobs/ShadowImp.tscn`
- `game/scenes/companions/Sibling.tscn`

## Files modified

- `game/scripts/core/time_manager.gd` — real phase machine with per-
  phase durations, countdown, and signals.
- `game/scripts/player/player_controller.gd` — LMB attack outside
  build mode.
- `game/scripts/ui/hud.gd` — live phase + countdown, real base HP,
  companion task tag, sunset warning color, camp-destroyed banner.
- `game/scenes/world/TestWorld.tscn` — added `WorldLighting`,
  `MobSpawner` (with four `Marker3D` spawn points), `Sibling`
  instance; campfire-core is now in the `base_core` group.
- `game/scenes/base/CampfireCore.tscn` — script attached, group
  added.
- `game/scenes/ui/HUD.tscn` — added `CompanionTaskLabel` and reuses
  the existing time and base-HP labels for live data.
- `game/project.godot` — five new input actions
  (`attack` = LMB, `assign_idle` = Y, `assign_follow` = F,
  `assign_guard` = G, `assign_gather` = T).

## Public APIs introduced

- `BaseCore` (StaticBody3D): `damaged`, `repaired`, `destroyed`,
  `take_damage`, `repair`, `current_hp`, `max_hp`.
- `MobDefinition` (Resource): `id`, `display_name`, `scene`,
  `max_hp`, `move_speed`, `attack_damage`, `attack_cooldown_seconds`,
  `attack_range`, `xp_reward`.
- `Mob` (CharacterBody3D, in `mob_controller.gd`): `state`,
  `take_damage(amount)`, `defeated` signal.
- `CompanionDefinition` (Resource): `id`, `display_name`, `scene`,
  `move_speed`, `attack_damage`, `attack_range`,
  `attack_cooldown_seconds`, `ui_color`.
- `Companion` (CharacterBody3D, in `companion_controller.gd`):
  `set_task(task: int)`, `current_task`, `task_changed` signal, plus
  `Task` enum (`IDLE`, `FOLLOW_PLAYER`, `GUARD_BASE`, `GATHER_NEAREST`).
- `TimeManager` (autoload): `Phase` enum, `current_phase`,
  `remaining_seconds`, `get_phase_name() -> String`, signals
  `day_started`, `sunset_warning`, `night_started`, `dawn_started`,
  `phase_changed`.
- `MobSpawner` (Node3D, scene-level): `wave_started(int)`,
  `wave_ended` signals; configurable `spawn_count`,
  `spawn_interval_seconds`, `mob_definition`.

## Known limitations

- Only one companion type (Sibling) and one mob type (Shadow Imp).
- Companions take no damage; mobs ignore them entirely.
- No XP, no level-up, no skill effects (Phase 6).
- No navigation mesh: mobs walk in a straight line and rely on
  collision to find what to attack. Works for the flat prototype map;
  will need real navigation when terrain gets interesting.
- No save / load (Phase 8).
- "Camp destroyed" is a HUD banner with no retry / menu; the game
  keeps running but no new mobs spawn.

## How to open / run

1. Install **Godot 4.x (standard, not .NET)**.
2. Open `game/project.godot`.
3. Press **F5**.

A suggested first run:

- Day 1: gather 4 Wood + 2 Fiber. Press **B**, place two Wooden Fences
  between the campfire and the spawn corner.
- Press **G** to send the Sibling to guard the campfire.
- Wait for sunset (HUD label turns red), then night.
- Watch Shadow Imps walk in, attack the fences, fall to the
  companion's swings.
- Click mobs with LMB to help.

## Next recommended feature

- **`004-combat-and-xp`** (Phase 6 of the roadmap). With combat live
  but unscored, the natural next step is XP for kills / building /
  crafting and a level-up on a simple threshold table.
- Alternative: **`004-crafting`** (Phase 7). Recipes consuming
  resources, producing items/buildings, granting XP.
- Alternative: **`004-save-load`** (Phase 8). Persist day, time,
  inventory, base HP, placed buildings, companion task.

Recommendation: **combat-and-xp**. The current combat works but is
cosmetic; once XP and level-up land we have a first complete prototype
loop end-to-end.

## Unresolved questions

- Wave scaling: night-to-night difficulty curve not designed yet.
- Companion knockout / recovery rules (still deferred).
- Should fences regenerate / be repairable during the day? Phase 4
  said yes (Repair task), out of scope here.
- Should mobs award resources on death (e.g. Scrap)? Phase 5 says yes
  but it's not wired; tied to Feature 004 (XP) anyway.

## Manual steps the human contributor still needs to perform

- Open the project in Godot once after pulling so the new `.tres` and
  `.tscn` files are imported.
- Walk through `test-plan.md` and tick the acceptance checkboxes.
