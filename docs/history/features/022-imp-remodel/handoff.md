# Feature 022: Handoff

- **Rebuild:** `.venv-blender/bin/python art/characters/shadow_imp.py`
  (about 1 minute).
  - `BAKE_SIZE=512` for a draft;
  - `AZ=0` for a front preview;
  - `HIGH_POLY=1` to keep the dense mesh.
- **Portrait:** `xvfb-run -a godot --path game --rendering-driver opengl3 res://tools/render_icons.tscn -- portrait_imp`.
- **Next on the art track:** animations (gather, attack and hit for the
  kids), then the painted environment and props.
