# Feature 005 — Handoff

## Current project status

The game is **playable end to end** and packaged for a first human
playtest:

- the title screen leads into a 3-night run;
- the run ends in a win or a loss;
- you can restart from the end screen or the pause menu.

Days are for gathering, building and crafting. Nights bring waves of
4 / 7 / 11 Shadow Imps that attack the campfire, fences, the boy and
the Sibling.

Branch: `claude/game-assessment-testing-plan-uv9mw2`.

## How to run

- **Editor:** open `game/project.godot` in Godot **4.3** (standard)
  and press F5.
- **Checks:** `tools/check.sh`. It needs `godot` on PATH or `$GODOT`
  set.
- **Tester package:** `tools/export_playtest.sh` writes
  `build/Campsite-0.1.0-playtest1-windows.zip`. It needs the 4.3
  export templates.
- **Visual check** (Linux, no display):
  `xvfb-run -a godot --path game --rendering-driver opengl3 res://tests/sim/screenshots.tscn -- /some/dir`
- **Balance sim:**
  `godot --headless --path game res://tests/sim/balance_sim.tscn -- <companion_task 0-3> <fight|idle>`

## Files created

- `.features/005-first-playtest-build/*`
- **Core:**
  - `game/scripts/core/{crafting_manager,playtest_log}.gd`;
  - `game/scripts/crafting/crafting_recipe.gd`.
- **Utilities:** `game/scripts/utilities/{definition_loader,fx}.gd`.
- **UI:**
  - `game/scripts/ui/{ui_kit,title_screen,pause_menu,controls_overlay,end_screen,crafting_panel}.gd`;
  - `game/scenes/ui/{TitleScreen,PauseMenu,ControlsOverlay,EndScreen,CraftingPanel}.tscn`.
- **Torch:**
  - `game/scripts/buildings/torch.gd`;
  - `game/scenes/buildings/Torch.tscn`;
  - `game/resources/items/torch.tres`;
  - `game/resources/recipes/torch.tres`.
- **World:** `game/scenes/resources/PineTree.tscn`.
- **Tools and tests:**
  - `game/tools/validate_project.{gd,tscn}`;
  - `game/tests/automated/smoke_run.{gd,tscn}`;
  - `game/tests/sim/{balance_sim,screenshots}.{gd,tscn}`.
- **Export:** `game/export_presets.cfg`.
- **Repo tools:** `tools/{check.sh,export_playtest.sh,godot_version.txt}`.
- **Docs:** `docs/testing/{playtest-001.md,PLAYTEST-README.txt}`.

## Public APIs introduced or changed

- **`GameManager`:**
  - `RunState`, `run_state`, `nights_to_win`, `stats`, `record()`;
  - `start_run()`, `go_to_title()`, `on_game_scene_ready()`,
    `is_playing()`;
  - signals `run_started` and `run_ended(won, reason)`.
- **`TimeManager`:** `reset()`, `start_run()`, `stop()`,
  `skip_phase()`, `is_running`.
- **Reset hooks:** `ResourceManager.reset()`,
  `ProgressionManager.reset()`.
- **`CraftingManager`:** `get_recipes()`, `can_craft()`,
  `craft(recipe, crafter)`, `crafted` signal, `is_crafting`.
- **Player and Companion:**
  - `take_damage(amount, source)`, `current_hp`, `max_hp`,
    `is_knocked_out`;
  - signals `health_changed`, and `knocked_out` (player) or
    `knocked_out_changed` (companion).
- **`Building` and `BaseCore`:** `take_damage(amount, source = null)`.
  `Building` also gets optional `auto_attack_*` exports.
- **`MobDefinition`:** new `aggro_radius`; `scene` is replaced by
  `scene_path` and `get_scene()`. The same `scene` → `scene_path`
  change applies to `CompanionDefinition` and `BuildingDefinition`.
- **`MobSpawner`:** `wave_sizes`, `get_wave_size(night)`;
  `wave_started(night, mob_count)`.
- **`ResourceNode`:** `bonus_definition`, `bonus_amount`.
- **Input actions:**
  - `pause` replaces `quit_game`;
  - new: `toggle_help`, `open_crafting`, `place_torch`, `eat_berries`,
    `skip_to_night`, `rotate_building`;
  - `attack` also accepts Space.

## Tuning knobs (first balance pass)

| What | Where | Value |
|------|-------|-------|
| Day / sunset / night length | `time_manager.gd` | 120 / 10 / 75 s |
| Wave sizes | `MobSpawner.wave_sizes` | 4, 7, 11 (+2 per extra night) |
| Imp HP / damage / speed / aggro | `shadow_imp.tres` | 12 / 4 / 2.4 / 4 m |
| Campfire HP | `CampfireCore.tscn` | 150 |
| Boy HP / regen | `player_stats.tres`, `player_controller.gd` | 50 / 1.5 per s (not at night) |
| Torch | `Torch.tscn` / `torch.gd` | 3.5 m, 45 % speed, 1 dmg/s |
| Watch Post | `WatchPost.tscn` | 2 dmg every 1.2 s within 5 m |
| Nights to win | `GameManager.nights_to_win` | 3 |

In the sim, with the Sibling guarding and the boy fighting beside the
fire, the bot wins with the campfire at about 80 % HP. With the boy
idle, he is knocked out on night 3. The sim skips daytime regen and
building, so real players have more tools than the bot.

## Known limitations

- There is no audio. SFX hooks to add later: gather complete, hit,
  mob death, level up, sunset, night start, craft, and win/lose.
- Placeholder art only. The boy has no facing indicator (torches are
  planted in the last movement direction).
- Imps walk in straight lines (no navmesh), which is fine on the flat
  map.
- Attack targets the nearest imp within 2.2 m; there is no aiming.
- The Windows build is unsigned, so SmartScreen warns on first launch.
- Headless runs print dummy-renderer and "leaked at exit" noise. These
  are harmless; `check.sh` only fails on script or load errors.
- Unused items (Clay, Mushrooms, Glow Shards, Scrap) exist in data but
  have no source or use yet.

## Next recommended feature

1. **Run playtest 001** (`docs/testing/playtest-001.md`) with 2–3
   people. Triage the feedback into a `006-playtest-1-fixes` feature.
2. **`007-save-load`** (roadmap Phase 8), once the loop is confirmed
   fun.

## Unresolved questions

- Should the boy being knocked out end the run, or cost something
  (drop resources, lose the night)? Decide after the playtest.
- Is 3 nights the right run length for a first session?
- Should the Sibling's guard AI chase imps that target the boy?
