# Feature 000 &mdash; Status

## 2026-05-16 &mdash; Bootstrap session

**Completed**

- Repository layout created: `game/`, `docs/`, `tools/`, `.features/`.
- Root files committed: `README.md`, `.editorconfig`, `.gitignore`.
- Documentation written:
  - `docs/decisions/ADR-0001-engine-and-language-selection.md`
  - `docs/requirements/requirements.md`
  - `docs/design/game-design-spec.md`
  - `docs/architecture/software-architecture.md`
  - `docs/architecture/coding-standards.md`
  - `docs/testing/test-strategy.md`
  - `docs/roadmap/roadmap.md`
- `.features/README.md` and all five files in
  `.features/000-project-bootstrap/`.
- Minimal Godot project skeleton:
  - `game/project.godot` with `GameManager` and `TimeManager` autoloads.
  - Scripts: `game_manager.gd`, `time_manager.gd`, `player_controller.gd`,
    `hud.gd`.
  - Scenes: `Main.tscn`, `TestWorld.tscn`, `PlayerBoy.tscn`,
    `CampfireCore.tscn`, `HUD.tscn`.
  - Top-down camera and WASD movement implemented.
  - HUD lists all 10 resources with placeholder values.

**Next**

- Phase 1 work in a new feature folder, e.g. `001-movement-and-camp`.

**Blocking**

- None.
