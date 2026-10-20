# Feature 006 — Status

## 2026-09-28

**Completed**
- **Asset pipeline:**
  - `tools/fetch_assets.sh` vendors the 4 KayKit packs and 2 OFL fonts;
  - `tools/render_icons.tscn` renders the icons and portraits.
- **Models:**
  - animated boy, sibling and shadow minions (`CharacterVisual`);
  - house material style (`Stylize`, `StyleDirector`);
  - model-based trees, pines, rocks, bush, fence, tower, torch and
    campfire.
- **World:**
  - painted ground shader, grass MultiMesh, forest border with haunted
    spawn lanes, dressed camp;
  - day/sunset/night/dawn lighting blends, glow, fog and grading.
- **VFX:**
  - flame shader, embers, bursts, level-up pillar, spawn/death smoke;
  - LoL-style health bars and pop-up combat text.
- **Controls:**
  - right-click move, attack, gather and campfire commands on a
    runtime navmesh;
  - hover rim, cursors, click markers, range ring, camera zoom and
    shake.
- **UI:**
  - hextech theme, new HUD, title screen over a live 3D dusk scene;
  - restyled menus.
- **Tests:** the smoke test covers the navmesh and the move, gather
  and attack commands. `tools/check.sh` is green.

**Next**
- Human playtest on Windows hardware (performance on integrated GPUs
  in particular).
