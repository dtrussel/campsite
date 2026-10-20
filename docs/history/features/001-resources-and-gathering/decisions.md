# Feature 001 — Decisions

## D-001-1 — Detection via Area3D, not raycast or polling

- **Decision:** A child `Area3D` (`GatherInteractor`) on the player detects
  nearby `ResourceNode`s via `body_entered` / `body_exited`. The player
  asks the interactor for the closest in-range node when the interact key is
  pressed.
- **Alternatives:** camera-forward raycast (rejected — the player has no
  facing direction yet, and the camera is fixed); per-frame distance scan
  over all resource nodes (rejected — duplicates physics broad-phase, scales
  poorly).
- **Rationale:** Piggybacks on Godot's broad-phase; O(1) on enter/exit;
  zero per-frame cost when no nodes are nearby; trivially extends to future
  interactables (workbench, building ghost, dropped loot).

## D-001-2 — Inventory authority lives in `ResourceManager`, mutation triggered by `ResourceNode`

- **Decision:** The `ResourceNode`'s internal Timer fires `gathered`, and
  the node itself calls `ResourceManager.add(...)`. The player only
  listens for `gathered` to exit the `GATHERING` state.
- **Rationale:** Clear ownership. World object decides when a gather is
  complete; player owns input and state; autoload owns inventory. Lets a
  future companion AI gather without touching the player at all.

## D-001-3 — One shared `ResourceNode` script across all three scenes

- **Decision:** `TreeNode.tscn`, `RockNode.tscn`, and `BerryBush.tscn` all
  attach `resource_node.gd`. Per-instance values (definition, yield,
  gather time, respawn) live in the `.tscn` properties.
- **Rationale:** Resources are data; behaviour is identical. Specialised
  per-type scripts would be duplication. If a future node needs unique
  logic (e.g. a vine that swings back), that scene gets its own script
  while the rest stay on the shared one.

## D-001-4 — Definitions discovered via `DirAccess`, no manifest

- **Decision:** `ResourceManager._ready` scans `res://resources/items/`
  with `DirAccess` and loads every `*.tres` it finds.
- **Alternatives:** a manifest `_items_manifest.tres` listing all
  definitions (rejected for now).
- **Rationale:** One fewer file to keep in sync. Determinism is achieved
  by sorting the loaded definitions by `rarity` then `display_name`.
- **Trade-off:** drops are silently skipped if a `.tres` is malformed; we
  log a clear warning when this happens.

## D-001-5 — HUD listens only to signals, no `_process` for resource rows

- **Decision:** HUD subscribes to `ResourceManager.resource_changed` and
  updates one `Label` per event. `_process` only updates the time label.
- **Rationale:** Matches the architecture's signal-first style and the
  coding-standards rule "keep `_process` light".

## D-001-6 — Enum state machine instead of `_is_gathering: bool`

- **Decision:** Add `enum PlayerState { IDLE, MOVING, GATHERING }` now.
- **Rationale:** Phase 6 (combat) needs a real state machine anyway; doing
  it now avoids a rework. The added complexity is one enum + one match
  block — well within budget.

## D-001-7 — Collision layer for resource nodes

- **Decision:** `ResourceNode` `StaticBody3D` uses collision layer **2**
  (separate from the default layer 1 used by ground / world geometry). The
  `GatherInteractor` Area3D's `collision_mask` is set to `2` so it
  detects resource nodes only.
- **Rationale:** Keeps the interactor from picking up the ground plane.
  Future interactables (buildings, dropped items) can use additional
  layers as needed.

## D-001-8 — Cancel-on-move

- **Decision:** Moving (any WASD input) while `GATHERING` cancels the
  active gather.
- **Rationale:** Avoids the ambiguity of moving away mid-gather and
  having a count tick after the player is far from the node. The
  interactor's `body_exited` is a secondary safety net for the same case.
