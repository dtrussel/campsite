# Feature 002 — Handoff

## Current project status

The game now has its second real gameplay verb. The boy can press **B**
to enter build mode, sees a translucent ghost of a Wooden Fence (or a
Watch Post via **2**) tracking the mouse, and on left-click spends
resources and spawns the building in the world. Resource gathering still
works; the new building system slots in alongside it.

Branch: `claude/bootstrap-godot-game-TEdp5`.

## Files created in this feature

- `.features/002-building-placement/{plan,status,decisions,test-plan,handoff}.md`
- `game/scripts/buildings/building_definition.gd`
- `game/scripts/buildings/building.gd`
- `game/scripts/core/build_manager.gd`
- `game/resources/buildings/wooden_fence.tres`
- `game/resources/buildings/watch_post.tres`
- `game/scenes/buildings/WoodenFence.tscn`
- `game/scenes/buildings/WatchPost.tscn`

## Files modified

- `game/project.godot` — registered `BuildManager` autoload, added five
  new input actions (`toggle_build_mode` = B, `select_building_1` = 1,
  `select_building_2` = 2, `confirm_build` = mouse left,
  `cancel_build` = mouse right).
- `game/scenes/ui/HUD.tscn` — added a `BuildModeLabel` between the
  separator and the resources heading; default `visible = false`.
- `game/scripts/ui/hud.gd` — subscribed to `BuildManager`'s
  `build_mode_entered`, `build_mode_exited`, and
  `placement_validity_changed` signals and surfaced them through the
  new label.
- `game/scripts/player/player_controller.gd` — swallows the `interact`
  action while build mode is active so **E** does not also trigger
  gathering.
- `game/scenes/world/TestWorld.tscn` — added the `Ground`
  `StaticBody3D` to the `ground` group so the ghost footprint can
  filter it out of overlap conflicts.

## Public APIs introduced

- `BuildingDefinition` (Resource): `id`, `display_name`, `description`,
  `scene`, `cost`, `max_hp`, `footprint_size`, `ui_color`.
- `Building` (StaticBody3D): `damaged`, `repaired`, `destroyed`,
  `take_damage`, `repair`, `current_hp`.
- `BuildManager` (autoload): `build_mode_entered`, `build_mode_exited`,
  `building_placed`, `placement_validity_changed`,
  `enter_build_mode`, `exit_build_mode`, `is_in_build_mode`,
  `get_active_definition`, `get_known_definitions`.

## Known limitations

- **HP is a stub.** `Building.take_damage()` and `repair()` exist but
  nothing calls them. Wired in Phase 5 (mobs) and Phase 4
  (companion repair).
- **No rotation.** The ghost is axis-aligned. `R`-key rotation is
  deferred.
- **Only two buildings.** Storage Crate and Crafting Table are listed
  in the design spec but out of scope here.
- **No save / load.** Placed buildings vanish on Godot restart
  (Phase 8).
- **Player blocks placement.** Standing on the ghost makes it red. This
  is intentional but may want revisiting after playtest (see decision
  D-002-5).
- **No build-mode SFX or animation.** Ghost just snaps into the
  cursor position; the placed building appears without a build effect.

## How to open / run

1. Install **Godot 4.x (standard, not .NET)**.
2. Open `game/project.godot`.
3. Press **F5**.
4. Gather 2 Wood + 1 Fiber from a tree and a berry bush.
5. Press **B** to enter build mode.
6. Move the mouse over open ground. The ghost should be green.
7. Left-click to place a Wooden Fence.
8. Press **2** to switch to Watch Post. Gather more resources if needed.
9. Press **right-click** or **Esc** to leave build mode.

Controls (current):

- **W / A / S / D** — move
- **E** — interact / gather
- **B** — toggle build mode
- **1 / 2** — select Wooden Fence / Watch Post while in build mode
- **Left mouse** — place
- **Right mouse / Esc** — cancel build mode (Esc still quits when out
  of build mode)

## Next recommended feature

Two reasonable next steps; pick based on what feels more important to
demo:

- **`003-companion-prototype`** (Phase 4 of the roadmap). The boy is
  alone; adding a Sibling that follows or guards makes the camp feel
  alive and validates the task system.
- **`003-day-night-and-first-wave`** (Phase 5). Wires `TimeManager` to
  real transitions and spawns Shadow Imps that path to the campfire,
  damaging it (and the new fences). This is the first time the
  `Building.take_damage` stub gets exercised.

Recommendation: **Phase 5 first**. It gives the new fences and
campfire a reason to exist *now* and exercises the most game-feel
surface (clock, light, mob spawning, HP damage). The companion can
follow once there is danger to defend against.

## Unresolved questions

- Should the player be able to place a building while standing on it?
  Currently no (decision D-002-5).
- Should successive placements have a small cooldown or build animation?
- Should there be a refund on building destruction? (Phase 5/8.)

## Manual steps the human contributor still needs to perform

- Open the project in Godot once after pulling so the new `.tres` and
  `.tscn` files are imported into the editor cache.
- Walk through `test-plan.md` and tick the acceptance checkboxes.
