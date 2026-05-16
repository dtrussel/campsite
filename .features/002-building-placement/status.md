# Feature 002 — Status

## 2026-05-16 — Implementation session

**Completed**

- Feature folder created with all five workflow docs.
- `BuildingDefinition` data class (`game/scripts/buildings/building_definition.gd`).
- Two building `.tres` files (`wooden_fence.tres`, `watch_post.tres`).
- Shared `Building` script (`game/scripts/buildings/building.gd`).
- `WoodenFence.tscn` and `WatchPost.tscn` scenes.
- `BuildManager` autoload (`game/scripts/core/build_manager.gd`); registered in `project.godot`.
- Input actions added: `toggle_build_mode` (B), `select_building_1` (1), `select_building_2` (2), `confirm_build` (mouse left), `cancel_build` (mouse right).
- `HUD.tscn` extended with `BuildModeLabel`.
- `hud.gd` subscribes to `BuildManager.build_mode_entered`, `build_mode_exited`, and `placement_validity_changed`.
- `TestWorld.tscn` ground node added to the `ground` group so the ghost can filter it out.

**Next**

- Manual playtest of `test-plan.md` (requires local Godot).
- Feature 003: companion prototype (Phase 4) or Feature 003: day/night + first mob wave (Phase 5).

**Blocking**

- None.
