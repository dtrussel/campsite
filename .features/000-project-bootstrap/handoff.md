# Feature 000: Handoff

**Feature:** Project Bootstrap
**Completed By:** Bootstrap Agent
**Date:** 2026-05-16
**Next Feature:** `001-playable-movement` (Phase 1)

---

## Current Project Status

Phase 0 documentation and Godot project skeleton are complete. The repository is ready for Phase 1 development.

**Documentation:** All documents are written and in place.
**Godot skeleton:** All scene and script files are created. The project should open and run in Godot 4.2+, showing a test world with a player placeholder, campfire, placeholder trees, and a HUD with all 10 resource slots.

**Not yet validated in the Godot editor** (this environment has no Godot runtime). The file structure and syntax are correct to the best of the agent's knowledge, but the following should be verified manually.

---

## How to Open and Run the Project

1. Install Godot 4.2 or later from https://godotengine.org/download
2. Launch Godot and click **Import**
3. Navigate to `game/project.godot` and click **Open**
4. Allow Godot to reimport assets on first open
5. Press **F5** to run, or use **Project → Run Project**

The main scene is `scenes/main/Main.tscn`.

---

## Files Created in This Session

### Root
- `.editorconfig`
- `.gitignore`
- `README.md`

### Documentation
- `docs/decisions/ADR-0001-engine-and-language-selection.md`
- `docs/requirements/requirements.md`
- `docs/design/game-design-spec.md`
- `docs/architecture/software-architecture.md`
- `docs/architecture/coding-standards.md`
- `docs/roadmap/roadmap.md`
- `docs/testing/test-strategy.md`

### Feature Workflow
- `.features/README.md`
- `.features/000-project-bootstrap/plan.md`
- `.features/000-project-bootstrap/status.md`
- `.features/000-project-bootstrap/decisions.md`
- `.features/000-project-bootstrap/test-plan.md`
- `.features/000-project-bootstrap/handoff.md` (this file)

### Godot Project
- `game/project.godot`
- `game/icon.svg`
- `game/scenes/main/Main.tscn`
- `game/scenes/world/TestWorld.tscn`
- `game/scenes/player/PlayerBoy.tscn`
- `game/scenes/base/CampfireCore.tscn`
- `game/scenes/ui/HUD.tscn`

### Scripts
- `game/scripts/core/game_manager.gd`
- `game/scripts/core/resource_manager.gd`
- `game/scripts/core/progression_manager.gd`
- `game/scripts/core/resource_definition.gd`
- `game/scripts/game_loop/time_manager.gd`
- `game/scripts/game_loop/wave_manager.gd`
- `game/scripts/player/player_controller.gd`
- `game/scripts/companions/companion_controller.gd`
- `game/scripts/base/base_core.gd`
- `game/scripts/buildings/building.gd`
- `game/scripts/buildings/building_definition.gd`
- `game/scripts/crafting/crafting_recipe.gd`
- `game/scripts/mobs/mob_definition.gd`
- `game/scripts/progression/character_stats_definition.gd`
- `game/scripts/resources/resource_node.gd`
- `game/scripts/save/save_manager.gd`
- `game/scripts/ui/hud_controller.gd`

---

## Chosen Technology

**Engine:** Godot 4.x
**Language:** GDScript (typed)
**Rendering:** Forward+ (default)
**Target:** Windows desktop first

Full rationale: `docs/decisions/ADR-0001-engine-and-language-selection.md`

---

## What Is Implemented

- Full project directory structure
- All documentation (requirements, design spec, architecture, coding standards, roadmap, test strategy, ADR)
- `project.godot` with autoloads registered: `GameManager`, `TimeManager`, `ResourceManager`, `ProgressionManager`
- Input map: `move_forward/back/left/right`, `sprint`, `interact`, `build_mode`
- `Main.tscn`: entry point with world, player, isometric camera, HUD
- `TestWorld.tscn`: flat ground, campfire, 5 tree placeholders, 4 spawn point markers
- `PlayerBoy.tscn`: CharacterBody3D with capsule mesh (blue), collision, interact area
- `CampfireCore.tscn`: orange glowing cylinder with OmniLight
- `HUD.tscn`: right-side panel with Day, Phase, Base HP, 10 resource labels, warning label
- Full `ResourceManager` with add/remove/spend/signal API
- Full `ProgressionManager` with XP tracking and level-up logic
- `TimeManager` with day/sunset/night/dawn cycle and configurable durations
- `GameManager` coordinating phase transitions and day counting
- `player_controller.gd`: WASD movement, sprint, interact (E), face-direction rotation
- `companion_controller.gd`: Follow and Guard task states (stub)
- `resource_node.gd`: gatherable node with depletion and respawn
- `wave_manager.gd`: stub for Phase 5
- `save_manager.gd`: stub save/load with versioning
- All data Resource class definitions: `ResourceDefinition`, `BuildingDefinition`, `CraftingRecipe`, `MobDefinition`, `CharacterStatsDefinition`

---

## What Is Intentionally Not Implemented

- Real 3D art assets (all meshes are CSG/primitive placeholders)
- NavigationServer3D / NavigationMesh (needed for Phase 4-5)
- Actual mob spawning and combat (Phase 5-6)
- Crafting UI (Phase 7)
- BuildManager autoload and build mode (Phase 3)
- Resource node scenes in TestWorld (Phase 2 places them)
- Companion scenes placed in world (Phase 4)
- Full save/load (Phase 8)

---

## Known Limitations and Issues

1. **No `BuildManager` autoload yet.** It is documented in the architecture but not implemented as a script or registered in `project.godot`. Phase 3 adds it.

2. **HUD base health connection.** The HUD connects to the base core via a signal emitted through the group `"base_core"` and wired in `Main.tscn`'s script. If the campfire node is not in the scene tree when `Main._ready()` runs, the connection may miss. Phase 1 should verify this in the editor.

3. **Camera is static.** The camera in `Main.tscn` is a fixed isometric transform. It does not follow the player. Phase 1 adds a camera controller with player tracking.

4. **No NavigationMesh.** Companion guard state uses a simple angle-based patrol loop, not actual navigation. This is intentional for Phase 0.

5. **Sprint action uses Left Shift keycode.** The physical keycode `4194325` is `KEY_SHIFT`. Verify in the Godot Input Map editor that this resolves correctly.

6. **HUD script references `$Panel/VBox/...` node paths.** If the HUD scene tree is changed, these paths must be updated in `hud_controller.gd`.

7. **`SaveManager` is not registered as an autoload.** It is a script ready to be added. To enable save/load, add it to the `[autoload]` section in `project.godot` as `SaveManager="*res://scripts/save/save_manager.gd"`.

---

## Recommended Next Feature

**Feature 001: Playable Movement and Camp Scene**

The Phase 1 goal (see `docs/roadmap/roadmap.md`):
- Add a real 3D test world (expand `TestWorld.tscn`)
- Add a camera controller that follows the player
- Verify WASD movement works correctly
- Verify HUD renders and updates
- Add day/night visual transition (sky color, ambient light change)

**Start by:**
1. Opening the project in Godot and running the smoke tests from `.features/000-project-bootstrap/test-plan.md`
2. Fixing any errors found
3. Creating `.features/001-playable-movement/` with all five workflow files
4. Implementing the camera follow controller

---

## Open Questions (From Requirements)

| OQ | Question |
|----|----------|
| OQ-01 | Is the tone primarily cozy, spooky, funny, or heroic? |
| OQ-02 | Does the boy fight directly, command companions, or both? |
| OQ-03 | Can companions be defeated permanently or only temporarily? |
| OQ-04 | Base health → 0: instant game over or last-stand recovery? |
| OQ-05 | Do pets fight, gather, scout, or provide passive buffs only? |
| OQ-06 | Handcrafted world, procedural, or hybrid? |
| OQ-07 | Real-time only or pausable during planning? |
| OQ-08 | Should day length be a difficulty setting? |
| OQ-09 | Do resource nodes respawn, regenerate, or deplete permanently? |
| OQ-10 | Is there a maximum base area? |

These do not block Phase 1 but should be decided before Phase 4 (companions) and Phase 5 (night combat).
