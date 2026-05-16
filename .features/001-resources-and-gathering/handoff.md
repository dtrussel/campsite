# Feature 001 — Handoff

## Current project status

The game now has its first real gameplay verb. The boy can walk up to a tree,
rock, or berry bush, hold position and press **E**, and watch Wood / Stone /
Berries tick up in the HUD. All 10 resources are wired through the data layer
even though only three are gatherable. The HUD is now signal-driven; no
hard-coded resource list remains.

Branch: `claude/bootstrap-godot-game-TEdp5`.

## Files created in this feature

- `.features/001-resources-and-gathering/{plan,status,decisions,test-plan,handoff}.md`
- `game/scripts/resources/resource_definition.gd`
- `game/scripts/resources/resource_node.gd`
- `game/scripts/core/resource_manager.gd`
- `game/scripts/player/gather_interactor.gd`
- `game/resources/items/{wood,stone,berries,fiber,mushrooms,clay,leaves,resin,scrap,glow_shards}.tres`
- `game/scenes/resources/{TreeNode,RockNode,BerryBush}.tscn`

## Files modified

- `game/project.godot` — added `ResourceManager` autoload and `interact` input action (E key).
- `game/scripts/ui/hud.gd` — definition-driven rows; subscribes to `ResourceManager.resource_changed`.
- `game/scripts/player/player_controller.gd` — added `PlayerState` enum and gather flow.
- `game/scenes/player/PlayerBoy.tscn` — added `GatherInteractor` Area3D child.
- `game/scenes/world/TestWorld.tscn` — instanced three trees, three rocks, two berry bushes around the campfire.

## Public APIs introduced

- `ResourceDefinition` (Resource): `id`, `display_name`, `description`,
  `icon`, `rarity`, `max_stack`, `ui_color`.
- `ResourceManager` (autoload): `resource_changed`, `inventory_ready`,
  `get_definitions`, `get_definition`, `get_count`, `has`, `add`, `spend`,
  `can_afford`, `spend_costs`.
- `ResourceNode` (StaticBody3D): `gathered`, `depleted`, `respawned`,
  `begin_gather`, `cancel_gather`.

## Known limitations

- Max-stack caps are **not enforced** in `ResourceManager.add`. The
  autoload accepts any positive delta. Caps can be added when an inventory
  UI demands them.
- No gather VFX / SFX yet. A success cue would help the feel; deferred to
  the polish pass.
- Node respawn is a hard re-enable with no visual transition. Acceptable
  for prototype; revisit when the art pass lands.
- Companions cannot yet gather. The `gathered` signal carries an `actor`
  argument and `ResourceManager.add` is global, so a future companion AI
  needs only to call `ResourceNode.begin_gather(self)`.
- No save/load — gathered resources reset on every run (Phase 8).

## How to open / run

1. Install **Godot 4.x (standard, not .NET)**.
2. Open `game/project.godot` in Godot.
3. Press **F5**.
4. Walk to a Tree (cylinder + cone), Rock, or Berry Bush. Press and hold
   **E** for the gather time. Watch the HUD.

Controls:

- **W / A / S / D** — move
- **E** — interact / gather
- **Esc** — quit

## Next recommended feature

**`002-building-placement`** (Phase 3 of the roadmap):

- `BuildingDefinition` data class + `.tres` files.
- `BuildManager` autoload with build-mode toggle.
- Placement ghost (green / red).
- `WoodenFence` and `WatchPost` scenes.
- `ResourceManager.spend_costs` already exists — use it.

See `docs/roadmap/roadmap.md` Phase 3.

## Unresolved questions

- Should gather cancel when the **interactor** loses the node, or only
  when the player explicitly moves? Currently both cancel (decision
  D-001-8). Revisit if it feels off in playtest.
- How should max-stack caps be communicated to the player? UI work for
  later.
- Should companions be able to gather *in parallel* with the player at
  the same node? Currently the node only tracks one in-flight gather
  (`_active_gather_actor`). Revisit in Phase 4.

## Manual steps the human contributor still needs to perform

- Open the project in Godot once after pulling so it imports the new
  `.tres` and `.tscn` files into its cache.
- Walk through `test-plan.md` and tick the acceptance checkboxes.
