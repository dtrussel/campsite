# Feature 031: Handoff

**Done:** milestones 0–6. See `status.md`.

**Where the look lives:**
- **Lighting:** `world_lighting.gd` PALETTES and the TestWorld Environment.
- **Post pass:** `PostFx` and `post_tiltshift.gdshader`. Tune `focus_center`, `focus_band`, `max_radius` and the tints there.
- **Ground:** `painted_ground.gdshader`, plus `art/ground/textures.py`.
- **Dressing:** `world_dressing.gd` (flowers, border, homestead).
- **Props:** `art/props/homestead.py`.

**Keep in sync:** the path curve is in two places, `painted_ground.gdshader` (`path_*`) and `WorldDressing.on_path`.

**Open / ideas:**
- Measure FPS on a real Windows GPU. In the cloud session it only ran under Xvfb with software GL.
- A moon needs a camera that sees the sky (D8).
- Further steps from the concept art:
  - the river, waterfall and bridge (concept 10);
  - a chicken critter;
  - more lived-in clutter (a supply table with mugs and a map).

**Milestone 4 (HD-2D finish):**
- **Where to tune:**
  - Look numbers live in `post_tiltshift.gdshader` uniforms: `exposure`, `contrast`, `pivot`, `day_balance`, `focus_*` and `sharpen`.
  - The material finish is in `painted_common.gdshaderinc` (`top_light`, `under_dark`, `contact_*`, `texel_*`).
- **Measuring:** `screenshots.tscn` day shots against `13_style_target_village.webp`. Compare median brightness, the darkest and brightest 5 %, and the R:G:B ratios (see status).
- **MSAA is off (D12).** Turning it on under Compatibility broke the night lighting in the Xvfb test.

**Milestones 5 and 6 (softer blur, model detail):**
- **Model review:**
  - Render a model in the game look with `xvfb-run -a godot --path game --resolution 960x540 res://tools/model_gallery.tscn -- <out_dir> <model ...>`, before and after a change.
- **Detail pipeline (`art/lib/detail.py`):**
  - `bake_prop` and `bake_prop_lows` bake the dense look onto the budget mesh.
  - Dense helpers: `bark_log`, `plank`, `leaf_clump` and `colour_foliage`.
  - The prop scripts carry more (`camp.py`: `board`, `bark_stake`, `shingles`, `rope_tube`; `forage.py`: `dense_block`, `twisted_rope`, `rivets`).
- **Bake pitfalls:**
  - **Black texels.** A bake ray that is too short leaves black texels; raise `ray` past the deepest carved detail.
  - **Collapse decimation tears thin sheets.** Give canvas, awnings and roof panels a hand-made low twin with `bake_prop_lows`.
  - **Slow vertex loops.** Reading `v.normal` while moving vertices is very slow; read all the normals first.
- **Characters:** a denser body voxel causes black blotches in the bake, so mob detail comes from colour functions at the current density.
- **Kids (M7, D16):**
  - **Logos:** paint them into the clothing colour function. Painting a big logo needs a dense high mesh (`faces=30000` on the tee); the game mesh budget is unchanged.
  - **Colour check:** check clothing colours in a day screenshot crop, not just the gallery; the warm grade pulls blues toward grey and purples toward pink.
  - **Hair:** the crown is what the game camera sees, so a hair change must keep it textured.

**Foliage (M8, D17):** canopies are a shell plus `detail.scatter_leaves`. Tune leaf size, coverage, tilt and droop in each nature script.
- Leaves are their own bake source, so they need the `cage_near` cage (it is set automatically).
- Bake rays from the full cage would pick up overlapping leaves and muddy the colours.

**Imp aura (M8, D18):** tune it in `scripts/mobs/shadow_aura.gd` (amount, size, colour ramp).
- It is additive, so many imps stacked together brighten.
- Lower the ramp alpha if late waves get too hazy.
