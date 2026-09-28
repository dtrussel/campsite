# Feature 005 — Decisions

## D-005-1 — Definitions reference scenes by path

- **Decision:** `MobDefinition`, `CompanionDefinition` and
  `BuildingDefinition` store `scene_path: String` and load it lazily
  through `get_scene()`. They no longer store `scene: PackedScene`.
- **Rationale:** Each scene embeds its definition, so a `PackedScene`
  reference back from the definition is a cycle. Godot refuses to load
  it ("Parse Error: Busy"), which stopped `Main.tscn` from loading.

## D-005-2 — Directory scans go through `DefinitionLoader`

- **Decision:** All "load every .tres in a folder" code uses
  `DefinitionLoader.load_all`, which strips `.remap`/`.import`.
- **Rationale:** Exported PCKs list resources as `foo.tres.remap`. The
  old `ends_with(".tres")` scan found nothing in an exported build.
  Verified with `--selftest` on an exported binary.

## D-005-3 — The autoloads are reset instead of reloaded

- **Decision:** `GameManager.start_run()` calls `reset()` on
  `TimeManager`, `ResourceManager` and `ProgressionManager`, exits
  build mode, then changes scene. `TimeManager` only ticks after
  `start_run()`.
- **Rationale:** Autoloads survive scene changes. An explicit reset
  keeps state ownership in each manager, and starting the clock from
  the scene means day 1's signals reach scene listeners.

## D-005-4 — Losing the boy loses the run

- **Decision:** The boy at 0 HP ends the run. The Sibling at 0 HP is
  knocked out until the next dawn.
- **Rationale:** This is the simplest rule a tester can understand. We
  will revisit after playtest feedback (e.g. a knock-out timer or a
  respawn at the tent).

## D-005-5 — Named physics layers

- **Decision:**
  1. ground
  2. resources
  3. buildings + campfire
  4. mobs
  5. characters

  Mobs don't collide with characters; they attack them by proximity.
- **Rationale:** The player used to sit on the ground layer, which
  polluted the build raycast. Mobs also shoved the player around.

## D-005-6 — Compatibility (OpenGL 3) renderer

- **Decision:** `rendering_method = gl_compatibility`.
- **Rationale:** Playtesters use whatever laptop they have. The
  Compatibility renderer runs on much older and integrated GPUs than
  Forward+ (Vulkan/D3D12). It is also the renderer the screenshots
  were checked with. The prototype uses no Forward+-only features.

## D-005-7 — Torch as a per-night consumable

- **Decision:** The Torch is an inventory item planted with Q. It
  slows imps to 45 % speed and deals 1 damage per second within
  3.5 m, and it burns out at the next dawn.
- **Rationale:** This meets the roadmap Phase 7 criterion "output is
  usable in the world". It gives a reason to gather Resin and Leaves
  every day without adding a new system.

## D-005-8 — Clearing a wave brings dawn early

- **Decision:** When every imp of the wave is dead, the night skips
  to dawn.
- **Rationale:** This was already written in roadmap Phase 5 but
  wasn't implemented. It rewards fighting well and keeps runs around
  10 minutes.

## D-005-9 — The headless tests run as scenes

- **Decision:** The validator and the smoke test are `.tscn` scenes
  run with `godot --headless <scene>`, not `-s` scripts.
- **Rationale:** `-s` scripts run without autoloads, so any script
  that references an autoload fails to compile in that mode.
