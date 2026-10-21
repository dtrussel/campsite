# Feature 004 — Handoff

## Current project status

Combat is now scored. Each character (player and Sibling) earns XP
for the things they already do and levels up on a cumulative
threshold table. Level-ups bump `attack_damage` so kills resolve
faster. The HUD has two new rows showing `Player: Lv N - X / Y XP`
and `Sibling: Lv N - X / Y XP`, with a green flash on level-up.

Branch: `claude/bootstrap-godot-game-TEdp5`.

## Files created in this feature

- `.features/004-xp-and-leveling/{plan,status,decisions,test-plan,handoff}.md`
- `game/scripts/progression/character_stats.gd`
- `game/scripts/core/progression_manager.gd`
- `game/resources/progression/player_stats.tres`
- `game/resources/progression/sibling_stats.tres`

## Files modified

- `game/project.godot` — registered `ProgressionManager` autoload.
- `game/scripts/mobs/mob_controller.gd` —
  `take_damage(amount, source = null)` with last-damager
  attribution; awards `xp_reward` on death.
- `game/scripts/player/player_controller.gd` — `@export stats`,
  registers on `_ready`, bumps `attack_damage` on `level_up`,
  passes `self` as source to `mob.take_damage`.
- `game/scripts/companions/companion_controller.gd` — same pattern;
  runtime `_current_attack_damage` so the shared `.tres` is not
  mutated.
- `game/scripts/core/build_manager.gd` — awards 5 XP to the player
  after a successful placement.
- `game/scripts/resources/resource_node.gd` — awards 1 XP to the
  actor in `_on_gather_complete`.
- `game/scripts/ui/hud.gd` + `game/scenes/ui/HUD.tscn` — two
  progress rows; subscribes to `xp_gained` and `level_up`; flashes
  on level-up.
- `game/scenes/player/PlayerBoy.tscn` — `stats =
  ExtResource(player_stats.tres)`.
- `game/scenes/companions/Sibling.tscn` — `stats =
  ExtResource(sibling_stats.tres)`.

## Public APIs introduced

- `CharacterStatsDefinition` (Resource): `base_max_health`,
  `base_attack_damage`, `max_health_per_level`,
  `attack_damage_per_level`, `xp_table: PackedInt32Array`,
  `display_name`, `ui_color`.
- `ProgressionManager` (autoload): `xp_gained(character, amount,
  source)`, `level_up(character, new_level)`,
  `register_character`, `unregister_character`, `award_xp`,
  `get_level`, `get_xp`, `get_xp_to_next_level`, `get_stats`.
- `Mob.take_damage(amount, source = null)` — backward-compatible
  signature widening.

## Known limitations

- HP fields on the stats `.tres` exist but are unused (nothing
  damages the player or the companion yet).
- No visible XP bar — text only.
- No "ding" sound on level-up.
- XP table is hard-coded in the `.tres`; no in-editor tuning UI.
- XP resets on every run (Phase 8).
- Damage attribution is last-damager only; no assist credit.

## How to open / run

1. Install **Godot 4.x (standard, not .NET)**.
2. Open `game/project.godot`.
3. Press **F5**.
4. Gather and build during day 1, defeat the night-1 wave with
   LMB and / or a guarding companion. The HUD shows XP earned in
   real time; you should hit Lv 2 mid-fight.

## Next recommended feature

- **`005-crafting`** (Phase 7 of the roadmap). One recipe end-to-
  end (Torch suggested: 1 Wood + 1 Resin + 1 Leaves). Crafting
  grants XP via the same `ProgressionManager.award_xp(...)` call.
- Alternative: **`005-save-load`** (Phase 8). Persist day, time,
  inventory, base HP, placed buildings, XP, and levels. Save format
  must be versioned from day one per ADR-0001 risks.

Recommendation: **crafting**. It is the last gameplay verb the
vertical slice still needs; save/load is best built once the full
state is in place.

## Unresolved questions

- Should there be a level cap, or is the table indefinitely
  extendable? Currently the `.tres` lists thresholds up to level
  9; past that, level stays.
- Should max-stack / over-stack of XP be possible (e.g. one mob
  kill skipping multiple levels at once)? Currently the manager
  loops and emits `level_up` once per crossed threshold.
- Should there be a death penalty on the player's XP if the camp
  is destroyed? Not yet — the game just stops.

## Manual steps the human contributor still needs to perform

- Open the project in Godot once after pulling so the new `.tres`
  files are imported.
- Walk through `test-plan.md` and tick the acceptance checkboxes.
