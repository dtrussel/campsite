# Feature 015: Handoff

- **Rebuilding the kids:** run `.venv-blender/bin/python art/characters/leo.py` (and `nela.py`). It takes about 4–5 minutes per kid at 1024.
  - `SCULPT=1 QUICK=1` shows the low-poly clay.
  - `HIGH_POLY=1` keeps the dense meshes, for comparison.
- **Per-mesh budgets:** the `budget = {...}` dict in each `build()`.
- **Head budget:** raise it if facial forms look faceted in close-ups. The paint comes from the dense head either way.
- **After a rebake, Godot creates new `*_paint.webp.import` files only if they are missing.** The committed ones keep `compress/mode=1` (lossy). New textures should use the same setting.
- **Export templates:** `tools/export_playtest.sh` needs Godot 4.3 export templates in `~/.local/share/godot/export_templates/4.3.stable/`.
- **Optional cleanup:** the SDF code in `art/characters/head_sculpt.py` is unused except `ear()`.
