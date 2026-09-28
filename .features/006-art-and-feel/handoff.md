# Feature 006 — Handoff

## Status
The game now uses stylized 3D art, effects, UI and controls inspired by
LoL, built on CC0 KayKit models. Gameplay rules and balance are
unchanged from feature 005, except the Watch Post and the controls.

Version: **0.2.0-playtest1**. Branch:
`claude/game-assessment-testing-plan-uv9mw2`.

## How to work with the art
- **Add a model:** add its basename to the pack list in
  `tools/fetch_assets.sh` and re-run it (network needed). Commit
  `game/assets/kaykit/`.
- **Re-render icons after art changes:**
  `xvfb-run -a godot --path game --rendering-driver opengl3 res://tools/render_icons.tscn`
- **Tint a model:** set `style_tint` metadata on the model or any of its
  parents (see `Stylize.TINT_*`).
- **Characters:** configure the `CharacterVisual` node in the scene
  (model, scale, hidden accessories, hand prop, clip map).

## Key new files
- **Utilities:**
  - `scripts/utilities/{character_visual,stylize}.gd`;
  - `scripts/world/{style_director,world_dressing,navigation_baker,fire_effect}.gd`.
- **Controls:** `scripts/player/pointer_commands.gd`.
- **UI:**
  - `scripts/ui/{hud_widgets,health_bar_3d,title_backdrop}.gd`;
  - rewritten `hud.gd` and `ui_kit.gd`.
- **Shaders:** `shaders/{painted_ground,grass,flame,health_bar,hover_rim}.gdshader`.
- **Tools:** `tools/fetch_assets.sh`, `game/tools/render_icons.{gd,tscn}`.
- **Credits:** `CREDITS.md`.

## Known limitations
- There is still no audio. Suggested next step: CC0 SFX (hits, chops,
  fire crackle, night stinger) plus a music loop.
- The boy is a KayKit adult "Rogue" scaled down; a true child model
  would need custom art.
- The KayKit foliage palette is teal-green; tints soften it.
- Compatibility renderer: no SSAO or volumetric fog.
- Performance has only been checked on the software renderer; it needs
  a pass on real integrated GPUs.

## Next recommended work
1. Run playtest 001 with the new build.
2. An audio pass.
3. Save/load (roadmap Phase 8).
