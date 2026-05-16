# Feature 000: Project Bootstrap

**Status:** IN PROGRESS
**Phase:** 0
**Goal:** Create a complete, documented, runnable project foundation that any coding agent can continue from.

---

## Scope

This feature covers everything needed before any gameplay implementation begins:
- Repository structure
- All documentation
- Engine/language decision
- Minimal runnable Godot skeleton

This feature does NOT cover:
- Real gameplay (Phase 1+)
- Final art or audio
- Full autoload implementations (stubs only)

---

## Deliverables

### Documentation
- [ ] `README.md`
- [ ] `.editorconfig`
- [ ] `.gitignore`
- [ ] `docs/decisions/ADR-0001-engine-and-language-selection.md`
- [ ] `docs/requirements/requirements.md`
- [ ] `docs/design/game-design-spec.md`
- [ ] `docs/architecture/software-architecture.md`
- [ ] `docs/architecture/coding-standards.md`
- [ ] `docs/roadmap/roadmap.md`
- [ ] `docs/testing/test-strategy.md`
- [ ] `.features/README.md`
- [ ] `.features/000-project-bootstrap/plan.md` (this file)
- [ ] `.features/000-project-bootstrap/status.md`
- [ ] `.features/000-project-bootstrap/decisions.md`
- [ ] `.features/000-project-bootstrap/test-plan.md`
- [ ] `.features/000-project-bootstrap/handoff.md`

### Godot Project Skeleton
- [ ] `game/project.godot`
- [ ] `game/scenes/main/Main.tscn`
- [ ] `game/scenes/world/TestWorld.tscn`
- [ ] `game/scenes/player/PlayerBoy.tscn`
- [ ] `game/scenes/base/CampfireCore.tscn`
- [ ] `game/scenes/ui/HUD.tscn`
- [ ] `game/scripts/core/game_manager.gd` (stub)
- [ ] `game/scripts/core/resource_manager.gd` (stub)
- [ ] `game/scripts/core/progression_manager.gd` (stub)
- [ ] `game/scripts/game_loop/time_manager.gd` (stub)
- [ ] `game/scripts/player/player_controller.gd`
- [ ] `game/scripts/ui/hud_controller.gd`

---

## Approach

1. Create all directories.
2. Write all documentation files.
3. Write Godot project file (`project.godot`) with autoloads.
4. Write stub scripts for autoloads.
5. Create scenes as `.tscn` files with placeholder geometry.
6. Write player movement script.
7. Write HUD script showing 10 resources + time.
8. Verify project opens without errors.
9. Commit and push.

---

## Constraints

- Use only GDScript (no C#).
- No placeholder art files — use CSG nodes or MeshInstance3D with basic materials.
- No external plugins.
- Must run in Godot 4.2 or later.
