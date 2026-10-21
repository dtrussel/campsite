# Feature 001 — Status

## 2026-05-16 — Implementation session

**Completed**

- Feature folder created with all five workflow docs.
- `ResourceDefinition` data class (`game/scripts/resources/resource_definition.gd`).
- Ten resource `.tres` files under `game/resources/items/`.
- `ResourceManager` autoload (`game/scripts/core/resource_manager.gd`); registered in `project.godot`.
- New `interact` input action bound to E in `project.godot`.
- `ResourceNode` shared script (`game/scripts/resources/resource_node.gd`).
- `TreeNode.tscn`, `RockNode.tscn`, `BerryBush.tscn` scenes.
- `GatherInteractor` composition piece (`game/scripts/player/gather_interactor.gd`).
- `PlayerBoy.tscn` updated with the GatherInteractor child.
- `player_controller.gd` extended with `IDLE` / `MOVING` / `GATHERING` state machine.
- `hud.gd` rewired to drive resource rows from `ResourceManager.resource_changed`.
- `TestWorld.tscn` populated with three trees, three rocks, two berry bushes around the campfire.

**Next**

- Manual playtest of the acceptance checklist in `test-plan.md` (requires local Godot install).
- Feature 002: building placement (Phase 3 of the roadmap).

**Blocking**

- None.
