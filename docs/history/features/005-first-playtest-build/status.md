# Feature 005 — Status

## 2026-09-28 — Implementation session

**Completed**

- Headless Godot 4.3 toolchain. `tools/check.sh` runs import, the
  project validator, and the smoke test; all pass.
- Fixed:
  - the cyclic `.tscn` ↔ `.tres` references that stopped the game from
    loading;
  - `add_child` / transform ordering;
  - export-unsafe `DirAccess` scans (new `DefinitionLoader`);
  - Fiber, which had no source.
- Run lifecycle, title, pause, controls overlay, and end screen.
- Player and companion health, mob aggro, knockout, regen, and berries.
- FX (flash, floating text, HP labels, swing), HUD bars, and banners.
- Crafting: Torch recipe, CraftingManager, crafting panel, and
  plantable torch.
- Watch Post slingshot; building rotation (R).
- Balance pass, checked with `tests/sim/balance_sim.tscn`.
- Windows and Linux export presets; `--selftest` passes on the exported
  Linux build.
- `tools/export_playtest.sh` produces the Windows zip.
- `PlaytestLog` writes `user://playtest_log.txt`.
- Docs: playtest script, tester README, README, and roadmap.

**Next**

- Hand the zip to 2–3 testers and run `docs/testing/playtest-001.md`.
- A human pass on Windows hardware through `test-plan.md`.

**Blocking**

- None. The Windows build has not been launched on real Windows
  hardware yet; see `test-plan.md`.
