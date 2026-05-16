# Feature 000 &mdash; Project bootstrap

## Goal

Create a clean, agent-friendly foundation for a stylized 3D base-builder /
survival defense game built in Godot 4 + GDScript. Cover documentation,
architecture, design specification, repository layout, and a minimal
runnable Godot skeleton.

## Why it matters

This feature serves **all eight game pillars** indirectly by setting the
ground rules. Concretely it satisfies the Phase 0 deliverables in
[`docs/roadmap/roadmap.md`](../../docs/roadmap/roadmap.md) and the bootstrap
acceptance criteria.

## Scope

### In scope

- Repository layout: `game/`, `docs/`, `tools/`, `.features/`.
- Root files: `README.md`, `.editorconfig`, `.gitignore`.
- Documentation:
  - ADR-0001 (engine and language selection).
  - Requirements specification.
  - Game design specification.
  - Software architecture specification.
  - Coding standards.
  - Test strategy.
  - Roadmap.
- `.features/` workflow with this bootstrap feature.
- Minimal Godot project skeleton:
  - `game/project.godot` with autoloads for `GameManager` and
    `TimeManager`.
  - `Main.tscn`, `TestWorld.tscn`, `PlayerBoy.tscn`, `CampfireCore.tscn`,
    `HUD.tscn`.
  - Top-down / isometric camera.
  - Basic WASD player movement.
  - Placeholder HUD listing all 10 resources.

### Out of scope

- Gathering, building, crafting, combat, mobs, save / load.
- Final art and audio.
- Companion behavior (beyond the architecture description).

## High-level approach

1. Lay out folders.
2. Write all documentation first so the implementation is explicit.
3. Build the Godot project files (`project.godot`, scenes, scripts) in a
   small, runnable form.
4. Sanity-check by re-reading the project file structure.
5. Update `status.md`, `decisions.md`, `test-plan.md`, `handoff.md`.

## Dependencies

- Godot 4.x installed locally to verify the project (humans).
- No external libraries.
