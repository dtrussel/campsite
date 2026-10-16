# Feature 031: Concept-art look pass

## Context
The team supplied 12 new concept images (zip): 3 campsite scenes (day overview, campfire close-up, night), Leo/Nela turnarounds, 3 mob sheets, 4 environment vignettes (forest path, river bridge, ruins, village). They define a clear target look the game doesn't hit yet:

- **Tilt-shift miniature diorama**: high 3/4 camera, strong depth-of-field blur at top and bottom of the frame, a crisp middle band.
- **Golden-hour warmth**: saturated amber light, an ochre/orange dirt clearing, yellow-green foliage, and deep but warm shadows.
- **Dense dressing**: wildflowers everywhere (yellow, white daisies, purple lupines), rounded mossy beige rocks, and **green** pines and leafy trees. The game currently uses autumn-orange pines and haunted pumpkins.
- **A cozy, lived-in camp**: stone-ring fire with log and stump seats, a cooking tripod with a pot, a cream A-frame tent with crossed poles, crates, barrels, lanterns on posts, a carved tent-glyph signpost, a red/white striped market stall, and a stone well with a red tile roof.
- **Night**: a deep blue world, the fire and lanterns as warm pools of light, a big moon, and a glowing tent interior.

**User decisions:**
- **Mobs:** keep the current designs from features 026–028. The new mob sheets are stored as reference only.
- **Scope:** "look & mood first". No river, waterfall or kids remodel in this pass.
- **Reference images:** store them as WebP copies in the repo.

**Constraint:** the game renders with **GL Compatibility** (`game/project.godot:205`). No SSAO or SSR, and the built-in DOF can't be relied on. Post effects must therefore be a custom screen-space shader.

## Workflow (agents)
Create `.features/031-concept-look-pass/` with plan/status/decisions/test-plan/handoff, per `.features/README.md`. Work on branch `ccr-fe888da3-3beawe`, commit per milestone, and push.

## Milestone 0: Reference art and style guide
- `art/reference/concept-2026-10/NN_name.webp`: 12 files, Pillow, quality ~90, keeping the original names. That is about 3–5 MB versus 18 MB of PNG.
  - Convert with a one-off script, `art/reference/convert.py`, run with `python -I`.
  - The zip stays out of git.
- `art/reference/concept-2026-10/README.md`: index of the images, what each one is canonical for, and an explicit note that sheets 06–08 (the mobs) are **not** adopted.
- `docs/design/art-direction.md`: the style guide.
  - Palette swatches sampled from 01/02/03 with Pillow (dirt ochre, grass yellow-green, pine green, rock beige, canvas cream, wood brown, awning red, night blue, fire amber).
  - Composition rules: the tilt-shift band, warm key light, flower density, and "cozy day / warm-pool night".
  - Link it from `docs/design/game-design-spec.md` §art (lines ~395–407) and from `art/README.md`.

## Milestone 1: Lighting, grade and tilt-shift (biggest win, code only)
- **`game/scripts/world/world_lighting.gd` `PALETTES`**: retune toward the references.
  - DAY becomes golden: sun ≈ (1.0, 0.86, 0.62), pitch ≈ -40, warmer ambient ≈ (0.70, 0.64, 0.56), warmer horizon and fog.
  - SUNSET becomes deeper amber.
  - NIGHT becomes deep teal-blue: ambient ≈ (0.12, 0.17, 0.32), moon-blue sun, fire ×1.6.
  - The tween logic stays as it is.
- **`game/scenes/world/TestWorld.tscn` Environment** (lines 33–64): saturation ~1.25, slight contrast increase, glow tuned so the fire and lanterns bloom. Mirror these settings in `scripts/ui/title_backdrop.gd:80-118`.
- **New `game/shaders/post_tiltshift.gdshader`** (canvas_item, `hint_screen_texture, filter_linear_mipmap`, all supported in Compatibility):
  - A vertical tilt-shift blur via `textureLod` (a mip blend plus a small 8-tap kernel), driven by `focus_center` / `band` / `max_lod`.
  - Warm split-tone grading (shadows→plum, highlights→amber), a soft vignette, and a `night_amount` uniform that cools the grade.
- **New `game/scripts/world/post_fx.gd`**:
  - A `CanvasLayer` (layer below the HUD) with a full-rect `ColorRect` running the shader.
  - It listens to `TimeManager.phase_changed` and tweens `night_amount` alongside `world_lighting`.
  - Add it to TestWorld and the title backdrop.
  - UI must stay unblurred, so the HUD CanvasLayer index must sit above it.
- **Settings toggle:** add "Tilt-shift blur" on/off in the existing options. Check the existing settings/autosave code for where volume settings live and reuse that pattern. Default is on.
- **Camera** (`game/scripts/utilities/camera_follow.gd:12-16`): try fov 42→34 with a longer distance, for a flatter, more miniature perspective; keep pitch ~48–52. Expose the values as exports and tune them against screenshots.

## Milestone 2: Ground and flora
- **`art/ground/textures.py`** (grass ramp at lines 134–135, dirt ramp at 177–178): warmer ochre dirt with scattered pebbles, and yellower, sunnier grass. Rebuild `ground_*.png`.
- **`game/shaders/painted_ground.gdshader`**: a larger and more irregular dirt clearing (radius ~4.2 → ~6), a dirt **path** leaving camp toward the main mob lane (matching 09), and a reduced cool edge tint by day.
- **`game/scripts/world/world_dressing.gd` `_build_grass` / `_tuft_color`** (lines 41–90):
  - Raise the flower share and add three flower colours: yellow, white daisy and purple lupine. The lupine is a tall spike: a new tuft mesh variant in `_make_tuft_mesh`.
  - Cluster the flowers at camp edges, the fence line and around rocks.
  - Keep the seed fixed (1337).
- **`art/nature/pines.py`**: add a **green** palette variant (pine_c/pine_d, or a palette switch) with yellow-green tips. `_build_border` uses green pines near camp; the autumn and haunted ones stay only in the outer ring and the mob lanes, so the night threat still reads.
- **`art/nature/rocks.py`**: shift `STONE` from blue-grey (0.5, 0.53, 0.64) to warm beige-grey, with moss tops.
- **`art/nature/bush.py`**: add a yellow-flowering shrub variant.

## Milestone 3: Cozy camp props
These go in `art/props/camp.py`, or a new `art/props/homestead.py` if camp.py gets too long.
- Use the existing helpers: `common.srgb`, `common.grime`, `paint_bake.paint`, `common.export_glb`.
- Respect the ≤1.5k triangle prop budget.
- Materials end in `_painted`, so `stylize.gd` picks them up automatically.

Props:
- **Retune:**
  - the tent: cream canvas, crossed pole tips, a rolled bedroll inside;
  - the campfire: a bigger rounded stone ring.
- **New decor:**
  - `log_seat`, `stump_seat`;
  - `cook_tripod` (with a pot; reuse fire_effect smoke for steam);
  - `camp_sign` (carved tent glyph);
  - `lantern_post` (emissive glass, matching Torch's OmniLight pattern);
  - `market_stall` (red/white awning, crates of fruit);
  - `stone_well` (red tile roof, bucket);
  - `barrel_stack`, `supply_table` (mugs and a map).
- **Placement:** add them in `world_dressing.gd` `_build_camp` (lines 185–221) using `_spawn_model` and `_add_blocker`, while respecting `_collect_keep_out`, so build spots and paths stay clear.
  - Keep pumpkins and jack-o'-lanterns only along the mob lanes, away from the camp.
  - Decor is non-interactive in this pass; recording any gameplay use, such as the well as a water source, as a follow-up in decisions.md.
- **Night:**
  - lantern-post OmniLights (warm, low range) on a phase toggle;
  - an emissive tent interior glow at night;
  - a moon billboard in the sky (an unshaded quad far away) added by `world_lighting` at night;
  - retune firefly colour and density in `world_ambience.gd`.
- **Icons:** if any new prop becomes buildable, re-render icons with `game/tools/render_icons.gd`. Not expected in this pass.

## Out of scope (recorded in decisions.md / roadmap "Next")
- Mob remodels to the new sheets.
- The river, waterfall and bridge environment.
- Kids re-paint to the turnarounds. They already match: navy cap, blue tee, teal shorts / purple folk pants.
- Ruins and village biomes.

## Docs
- Add a 031 row to `docs/roadmap/roadmap.md`.
- Update the `art/README.md` layout table for the new scripts and `reference/`.
- Note the post-FX in README Status.

## Verification
1. **Art.** Run `tools/setup_blender.sh`, then `tools/build_art.sh nature/pines` (and the same for each changed script). Review the Cycles previews in `build/art_previews/` side by side with the reference WebPs, and check triangle counts in the script logs.
2. **Engine.** Download Godot 4.3-stable as `.github/workflows/build.yml` does, then run `tools/check.sh`. It covers the headless import, `validate_project` and the smoke run, and must report no SCRIPT ERROR or failed resources.
3. **Visual.** Run `game/tests/sim/screenshots.tscn` under xvfb.
   - Capture day, sunset and night, before and after.
   - Assemble a comparison sheet with Pillow next to concept 01, 02 and 03, and share it with the user.
   - Check that the HUD is unblurred, the fire and lanterns bloom at night, and mobs stay readable (NFR-6, readability over realism) with the blur band on.
4. **Performance.** Keep the grass MultiMesh count about the same. The post shader is one full-screen pass. Sanity-check FPS in the smoke run log if it is printed.
5. **Setting.** Toggling tilt-shift off removes the blur but keeps the grade.

## Milestone 4: HD-2D style finish (requested after M3)
- **Target:** the team's village screenshot (`13_style_target_village.webp`), for its overall graphic style only. No prop changes.
- **Post pass:**
  - a stronger and narrower tilt-shift with bokeh and a sharpen;
  - a warm filmic grade on luminance;
  - a warm vignette and haze.
- **Lighting:** higher contrast (strong sun, low warm ambient).
- **Materials:**
  - a shared painted shader (top light, contact shade, texel detail);
  - ink lines on props;
  - grass and ground detail.
- **Verification:** measure the screenshots against the target numbers, then run `tools/check.sh`.

## Milestones 5 and 6 (requested after M4)
- **M5:** soften the tilt-shift (D14).
- **M6:** one detail pass on every model, keeping only what improved (D15). The per-model results are in status.md.
