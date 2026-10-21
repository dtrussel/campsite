# Feature 007 — Status

## 2026-09-28

**Completed**
- **Blender toolchain:** `tools/setup_blender.sh` installs headless bpy
  4.5; `tools/build_art.sh` runs the scripts in `art/`.
- **Painted pipeline:** `art/lib/paint_bake.py` bakes colour, a warm/cool
  tint, AO, edge highlights and brush noise into one texture per model.
- **Characters:**
  - a new Shadow Imp on the Skeleton Minion rig (about 8.8k tris, all 95
    clips);
  - an upgraded boy (hair, scarf, backpack, chunky axe);
  - an upgraded sibling (floppy starry hat, cape, glowing star wand).
- **Nature:** 3 broadleaf trees plus a stump, 2 autumn pines, 3 rocks
  plus a cluster and pebbles, and a berry bush (full and picked).
- **Camp props:** campfire, tent, fence, watch post, torch, woodpile,
  crate, barrel and toadstools.
- **Godot:**
  - the `_painted` material style (lambert wrap and rim);
  - an inverted-hull ink outline on the kids and imps;
  - scenes and world dressing swapped to the custom models;
  - icons and portraits re-rendered.
- **Kid UI:**
  - moons for nights, a fire bar, an imp counter, and sibling task
    icons;
  - a picture help guide, a big Play button, a stars/trophy end
    screen, and an icon crafting panel;
  - icon pop-ups replace hint text.
- **Tests:** `tools/check.sh` is green, and the Xvfb screenshots were
  reviewed.

**Not done / deferred**
- Hand-painted ground textures. The procedural ground shader is kept.
- A dedicated `painted.gdshader`. `StandardMaterial3D` with lambert wrap
  gave the look with less risk.
- The facilitator questionnaire (`docs/testing/playtest-001.md`) still
  words some tasks with text controls; the tester README is updated.
