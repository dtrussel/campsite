# Feature 007 — Handoff

**State:** done, and ready for playtest as v0.3.0-playtest1.

- **Change art:** edit a script in `art/`, run
  `tools/build_art.sh <group/asset>`, check the preview in
  `build/art_previews/`, then run `tools/check.sh`. Godot re-imports
  the `.glb`.
- **Add a model:** follow `art/props/camp.py` (build, then
  `paint_bake.paint`, then `export_glb`). Name the material
  `*_painted` so `Stylize` styles it.
- **UI glyphs:** add a `kind` to `HudWidgets.Glyph._draw`. Use
  `HudWidgets.icon_button` for buttons and `Fx.icon_popup` for
  in-world feedback.
- **Next ideas:**
  - painted ground textures;
  - a Blender-modelled goblin variety or a boss imp;
  - animated sibling task icons;
  - sound (still none).
