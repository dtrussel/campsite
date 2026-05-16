# Feature 002 — Decisions

## D-002-1 — Ghost lives in the autoload, not in the building scene

- **Decision:** `BuildManager` instantiates the building scene as a
  one-off ghost, walks the tree to swap materials and disable physics,
  and adds a child `Area3D` for the overlap query.
- **Alternatives:** ship every building scene with a built-in
  `Ghost` Node3D pre-prepared (rejected — doubles authoring per
  building and keeps a dead branch in every placed instance).
- **Rationale:** Authoring stays single-source (one scene per
  building). The autoload owns the ghost's lifecycle, so build mode is
  always exactly one node to free on exit.

## D-002-2 — Mouse → ground via raycast, not click-to-place

- **Decision:** Every `_process` tick, the manager raycasts from the
  mouse through the active camera onto layer 1 (ground), and snaps the
  ghost to the hit point. Left-click confirms; right-click / Esc / B
  cancels.
- **Rationale:** Matches the natural &ldquo;place where I'm looking&rdquo;
  affordance of comparable games. Re-raycasting on `_process` is cheap
  with one ray per frame.

## D-002-3 — Filter the ground out of footprint overlaps via a group

- **Decision:** The ground `StaticBody3D` is added to the `ground`
  group. The ghost footprint Area3D uses `collision_mask = 7`
  (layers 1+2+3 — everything physical in the prototype). When
  evaluating validity, the manager skips any body in the `ground`
  group.
- **Alternatives:** put the ground on a dedicated layer the footprint
  doesn't mask (rejected — would force renaming and migrating every
  existing scene that already collides with ground). Or skip layer 1
  entirely (rejected — we *want* to overlap-check the player and the
  campfire core, both on layer 1).
- **Rationale:** Cheapest possible compatibility win. Groups are a
  zero-cost tag that survives scene composition.

## D-002-4 — Buildings on collision layer 3 (value 4)

- **Decision:** Placed buildings use `collision_layer = 4`,
  `collision_mask = 1`. Existing convention extends cleanly: layer 1 =
  ground, layer 2 = "interactable" bit (set on resource nodes), layer
  3 = buildings.
- **Rationale:** Lets future systems (mob aggro, companion repair task)
  query the buildings layer directly without scanning the scene tree.

## D-002-5 — Player blocks placement under them

- **Decision:** The footprint Area3D uses mask 7, which includes the
  player's default layer 1. Standing under the ghost makes it red.
- **Rationale:** A small but believable rule, and easier than special-
  casing the player out. If playtest hates it, drop the player from
  the mask later.

## D-002-6 — Stay in build mode after a successful placement

- **Decision:** On confirm, the ghost re-spawns immediately so the
  player can place another fence with one click. Exiting build mode
  requires explicit `cancel_build` / **Esc** / **B**.
- **Rationale:** Placing five fences in a row is a common operation;
  toggling build mode each time would be friction.

## D-002-7 — Esc routing

- **Decision:** `quit_game` (Esc) is intercepted by `BuildManager` when
  build mode is active and treated as a cancel. When build mode is
  inactive, the existing `main.gd` quit handler still runs.
- **Rationale:** Esc is the universal cancel; quitting the game while
  the player is mid-placement would be jarring.

## D-002-8 — HP API on `Building` is a stub for Phase 5

- **Decision:** `Building.take_damage()` and `Building.repair()` exist
  and emit `damaged` / `repaired` / `destroyed`, but nothing in this
  feature calls them. Phase 5 (mobs) and Phase 4 (companion repair)
  drive them later.
- **Rationale:** Adds maybe ten lines to ship now, saves a follow-up
  edit to every building scene later, and prevents a cross-feature
  refactor when Phase 5 lands.

## D-002-9 — Open questions deferred

- Should the ghost rotate (R key)? Deferred — buildings are
  rotation-friendly even at fixed angles for the prototype, and
  rotation interacts with footprint shape selection.
- Should the player be unable to confirm while standing on the ghost
  even if everything else is fine? Currently yes (player blocks
  placement). Revisit after playtest.
- Should buildings save their HP across cancel/replay? Out of scope for
  this feature.
