# Feature 000 &mdash; Handoff

## Current project status

The repository contains the full Phase 0 documentation foundation and a
minimal runnable Godot 4 / GDScript skeleton. The boy character can walk
around a small test world with a placeholder campfire and HUD. No
gameplay systems are implemented beyond movement and the HUD shell.

The branch in use is `claude/bootstrap-godot-game-TEdp5`.

## Chosen technology

- **Engine:** Godot 4.x (standard, not .NET).
- **Language:** GDScript.
- **Reason:** See
  [`docs/decisions/ADR-0001-engine-and-language-selection.md`](../../docs/decisions/ADR-0001-engine-and-language-selection.md).

## Files created in this feature

Root:

- `README.md`
- `.editorconfig`
- `.gitignore`

Documentation:

- `docs/requirements/requirements.md`
- `docs/design/game-design-spec.md`
- `docs/architecture/software-architecture.md`
- `docs/architecture/coding-standards.md`
- `docs/decisions/ADR-0001-engine-and-language-selection.md`
- `docs/roadmap/roadmap.md`
- `docs/testing/test-strategy.md`

Feature workflow:

- `.features/README.md`
- `.features/000-project-bootstrap/plan.md`
- `.features/000-project-bootstrap/status.md`
- `.features/000-project-bootstrap/decisions.md`
- `.features/000-project-bootstrap/test-plan.md`
- `.features/000-project-bootstrap/handoff.md`

Godot project:

- `game/project.godot`
- `game/icon.svg`
- `game/scripts/core/game_manager.gd`
- `game/scripts/core/time_manager.gd`
- `game/scripts/player/player_controller.gd`
- `game/scripts/ui/hud.gd`
- `game/scenes/main/Main.tscn`
- `game/scenes/world/TestWorld.tscn`
- `game/scenes/player/PlayerBoy.tscn`
- `game/scenes/base/CampfireCore.tscn`
- `game/scenes/ui/HUD.tscn`

Folder placeholders (empty subdirectories kept with `.gitkeep`):

- `game/scenes/{companions,mobs,buildings,resources}`
- `game/scripts/{game_loop,companions,mobs,base,buildings,resources,crafting,progression,save,utilities}`
- `game/assets/{placeholder,art,audio,materials,fonts}`
- `game/resources/{game_data,buildings,items,mobs,companions}`
- `game/tests/{manual,automated}`
- `tools/`

## How to open the project

1. Install **Godot 4.x (standard edition, not .NET)** from
   <https://godotengine.org/download>.
2. Launch Godot.
3. Click **Import** and select `game/project.godot` from this repository.
4. Open the project.

## How to run the main scene

- Press **F5** in the editor or use **Project &rarr; Run**.
- The configured main scene is `game/scenes/main/Main.tscn`.
- Expected behavior:
  - A small flat test world is visible.
  - The boy placeholder (a capsule with a hat) stands near the center.
  - The campfire core placeholder (a small pyramid-like shape) is at the
    center.
  - The HUD lists time of day, base HP, and all 10 resources.
  - **W / A / S / D** moves the boy; the camera follows.
  - **Esc** quits.

## Known limitations

- No gathering, no building, no combat, no companions, no day/night, no
  save/load. Those are scoped to Phases 2&ndash;8.
- No real art or audio. Everything is a primitive placeholder.
- `GameManager` and `TimeManager` are minimal stubs (they emit signals
  but do not yet drive gameplay).
- HUD resource counts are placeholder zeros and not connected to a real
  inventory.
- No save / load.
- No automated tests.
- Open questions remain unresolved (see `decisions.md` and the
  requirements document).

## Next recommended feature

**`001-movement-and-camp`** &mdash; Phase 1 of the roadmap:

- Polish camera follow.
- Add a few static world props (placeholder trees, rocks).
- Begin wiring `TimeManager` to a visible HUD clock.
- Begin wiring base HP to the HUD.

Refer to
[`docs/roadmap/roadmap.md`](../../docs/roadmap/roadmap.md#phase-1--playable-movement-and-camp-scene)
for the full Phase 1 deliverable list and acceptance criteria.

## Unresolved questions

See
[`docs/requirements/requirements.md#i-open-questions`](../../docs/requirements/requirements.md#i-open-questions).
Working assumptions are recorded in
[`./decisions.md`](decisions.md). Each remains revisitable.

## Manual steps the human contributor still needs to perform

- Install Godot 4.x locally and open `game/project.godot` once to let
  Godot generate its `.godot/` import cache. This cache is intentionally
  not committed and is ignored by `.gitignore`.
- Confirm the Phase 0 acceptance criteria from
  [`test-plan.md`](test-plan.md) by running the project.
- Decide the project name (the working title is &ldquo;Campsite&rdquo;).
- Pick a license and add a `LICENSE` file when ready.
