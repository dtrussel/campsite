# Feature 000 &mdash; Test plan

## Acceptance criteria

- [ ] The Godot 4 editor opens the project at `game/project.godot`
      without errors.
- [ ] Running the project with **F5** loads `scenes/main/Main.tscn`.
- [ ] No script errors or missing-resource warnings appear in the Output
      panel on startup.
- [ ] A flat ground / test world is visible.
- [ ] The boy placeholder is visible near the center.
- [ ] The campfire core placeholder is visible near the center.
- [ ] The HUD shows time-of-day text, base HP, and a list of all 10
      resources with names and placeholder counts.
- [ ] **W / A / S / D** moves the boy across the test world.
- [ ] The camera follows the boy without stuttering.
- [ ] **Esc** quits the running game.
- [ ] `docs/` contains all documents listed in
      `.features/000-project-bootstrap/plan.md`.
- [ ] `.features/000-project-bootstrap/handoff.md` is complete and
      current.

## Smoke checklist

- [ ] Project opens.
- [ ] Main scene runs.
- [ ] No console errors.
- [ ] Movement works.
- [ ] HUD displays.

## Known things not to test in Phase 0

- Resource gathering (Phase 2).
- Building placement (Phase 3).
- Companions (Phase 4).
- Day/night cycle and mob waves (Phase 5).
- Combat and XP (Phase 6).
- Crafting (Phase 7).
- Save/load (Phase 8).
