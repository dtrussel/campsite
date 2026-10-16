# Feature 031: Handoff

**Done:** milestones 0–3. See `status.md`.

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
- The imp's purple smoke aura (concept 08) as a spawn VFX.

**Milestone 4 (HD-2D finish):**
- **Where to tune:**
  - Look numbers live in `post_tiltshift.gdshader` uniforms: `exposure`, `contrast`, `pivot`, `day_balance`, `focus_*` and `sharpen`.
  - The material finish is in `painted_common.gdshaderinc` (`top_light`, `under_dark`, `contact_*`, `texel_*`).
- **Measuring:** `screenshots.tscn` day shots against `13_style_target_village.webp`. Compare median brightness, the darkest and brightest 5 %, and the R:G:B ratios (see status).
- **MSAA is off (D12).** Turning it on under Compatibility broke the night lighting in the Xvfb test.
