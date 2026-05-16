# Feature 000: Status

**Feature:** Project Bootstrap
**Last Updated:** 2026-05-16
**Status:** REVIEW — all files created; pending Godot editor validation

---

## Deliverable Checklist

### Documentation
- [x] `README.md`
- [x] `.editorconfig`
- [x] `.gitignore`
- [x] `docs/decisions/ADR-0001-engine-and-language-selection.md`
- [x] `docs/requirements/requirements.md`
- [x] `docs/design/game-design-spec.md`
- [x] `docs/architecture/software-architecture.md`
- [x] `docs/architecture/coding-standards.md`
- [x] `docs/roadmap/roadmap.md`
- [x] `docs/testing/test-strategy.md`
- [x] `.features/README.md`
- [x] `.features/000-project-bootstrap/plan.md`
- [x] `.features/000-project-bootstrap/status.md` (this file)
- [x] `.features/000-project-bootstrap/decisions.md`
- [x] `.features/000-project-bootstrap/test-plan.md`
- [x] `.features/000-project-bootstrap/handoff.md`

### Godot Project Skeleton
- [x] `game/project.godot` (with autoloads and input mappings)
- [x] `game/icon.svg`
- [x] `game/scenes/main/Main.tscn`
- [x] `game/scenes/world/TestWorld.tscn`
- [x] `game/scenes/player/PlayerBoy.tscn`
- [x] `game/scenes/base/CampfireCore.tscn`
- [x] `game/scenes/ui/HUD.tscn`

### Core Scripts
- [x] `game/scripts/core/game_manager.gd` (autoload stub)
- [x] `game/scripts/core/resource_manager.gd` (autoload, full API)
- [x] `game/scripts/core/progression_manager.gd` (autoload, full API)
- [x] `game/scripts/core/resource_definition.gd` (Resource class)
- [x] `game/scripts/game_loop/time_manager.gd` (autoload, full timer)
- [x] `game/scripts/game_loop/wave_manager.gd` (stub for Phase 5)
- [x] `game/scripts/player/player_controller.gd` (WASD movement)
- [x] `game/scripts/ui/hud_controller.gd` (all 10 resources + time)
- [x] `game/scripts/base/base_core.gd` (health + damage)
- [x] `game/scripts/buildings/building.gd` (base class)
- [x] `game/scripts/buildings/building_definition.gd` (Resource class)
- [x] `game/scripts/crafting/crafting_recipe.gd` (Resource class)
- [x] `game/scripts/mobs/mob_definition.gd` (Resource class)
- [x] `game/scripts/progression/character_stats_definition.gd` (Resource class)
- [x] `game/scripts/companions/companion_controller.gd` (stub + Follow/Guard)
- [x] `game/scripts/resources/resource_node.gd` (gatherable node)
- [x] `game/scripts/save/save_manager.gd` (stub save/load)

---

## Known Issues / Pending Validation

- [ ] Project must be opened in Godot 4.2+ to validate `.tscn` files and script references
- [ ] HUD requires the `HUD` global to be accessible in `base_core.gd` — this is done via autoload name; if HUD is not an autoload it needs to be accessed differently (see handoff)
- [ ] `PlayerBoy.tscn` uses `@onready` nodes — scene tree structure must match script expectations
- [ ] Input map in `project.godot` uses physical keycodes — verify with Godot editor
- [ ] `CampfireCore.tscn` references `HUD` which is a CanvasLayer instance, not an autoload — needs fix (see handoff)

---

## Session Log

| Date | Agent | Work Done |
|------|-------|-----------|
| 2026-05-16 | Bootstrap Agent | Created all directories, documentation, and Godot skeleton |
