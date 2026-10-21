# Feature 008: Handoff

**State:** done; the build is v0.4.0-playtest1.

- **Tweak a kid:**
  1. Edit `art/characters/leo.py` or `nela.py`. Parts are grouped: body pieces, head (face and hair), gear.
  2. Iterate with `QUICK=1 .venv-blender/bin/python art/characters/leo.py`. It renders in seconds, with no bake.
  3. Run a full `tools/build_art.sh characters/leo`.
  4. Re-render the portraits with `tools/render_icons.tscn`.
- **Tweak the ground:** edit `art/ground/textures.py` and rebuild with `tools/build_art.sh ground/textures`. The shader tile sizes are uniforms in `painted_ground.tres` / `painted_ground.gdshader`.
