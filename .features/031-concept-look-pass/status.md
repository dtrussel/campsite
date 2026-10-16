# Feature 031: Status

**Done.** Milestones 0–3 are in. The open items are the Windows checks in `test-plan.md`.

## 2026-10-16: Milestone 0 (reference and style guide)

- **Analysed** the team's 12 concept images (see `plan.md` › Context).
- **Added** them as WebP in `art/reference/concept-2026-10/`: about 2.2 MB, against 18 MB of PNG.
- **Wrote** the style guide `docs/design/art-direction.md`, with a palette sampled from the camp scenes.

## 2026-10-16: Milestone 1 (lighting, grade, tilt-shift, camera)

- **Palettes:** the `world_lighting.gd` palettes are retuned to golden hour, deep amber sunset and teal-blue night (fire ×1.6).
- **Environment:** the TestWorld Environment is warmer, with tuned glow and saturation.
- **PostFx:** new `PostFx` (`scripts/world/post_fx.gd`) and `shaders/post_tiltshift.gdshader`. It does the tilt-shift blur, a split-tone grade that cools at night, and a vignette.
  - It sits on canvas layer -1, under every UI layer.
  - The pause menu gets a **Blur** switch, saved in `user://settings.cfg` under `[video]`.
- **Camera:** fov 42 → 34, pitch 48 → 50, distance 15 → 18.5. The framing stays the same, with a flatter, miniature perspective.
- **Title backdrop:** gets the same pass at dusk.

## 2026-10-16: Milestone 2 (ground and flora)

- **Ground textures:** deeper greens, more flowers (including purple) and warm ochre dirt.
- **Ground shader:** the clearing radius goes 4.2 → 5.4, and a winding dirt path runs to the south lane (`painted_ground.gdshader`, mirrored by `WorldDressing.on_path`).
- **Wildflowers:** daisy and buttercup clumps plus purple lupine spikes, in two MultiMeshes. `grass.gdshader` gains `color_height`.
- **Pines:** green pines `pine_c` (2.5k tris) and `pine_d` (3.0k) in the border rings. The autumn Resin pines are unchanged.
- **Shrub:** a new `flower_bush` (2.2k) around the camp and in the inner ring.
- **Rocks:** warm beige-grey (`rocks.py` STONE, `Stylize.TINT_ROCK`).

## 2026-10-16: Milestone 3 (cozy camp props)

- **New props** in `art/props/homestead.py`:

  | Prop | Triangles |
  |------|-----------|
  | `log_seat` | 660 |
  | `stump_seat` | 600 |
  | `cook_tripod` | 1.3k |
  | `camp_sign` (tent glyph as real geometry) | 1.2k |
  | `lantern_post` (emissive glass) | 1.4k |
  | `market_stall` | 2.6k |
  | `stone_well` | 2.4k |

- **Retuned:** the tent is now cream canvas with seams, crossed A-frame poles, a bedroll and a pillow. The campfire has a chunkier ring of 12 stones in the warm stone colour.
- **Placement:** `WorldDressing._build_homestead` places the props on the diagonals, away from the mob lanes, the path and the resource nodes.
  - The stall and the well get colliders.
  - Warm OmniLights sit in the three lantern posts and inside the tent.
- **Checks:** `tools/check.sh` passes (import, validator, smoke run). The screenshots were reviewed against concepts 01 and 03.

## 2026-10-16: Milestone 4 (HD-2D style finish)
- **Request.** The team sent a village screenshot as a **style** target (`13_style_target_village.webp`): the finish, not the props.
- **Post pass** (`post_tiltshift.gdshader`):
  - A narrower crisp band with a light unsharp mask.
  - A 16-tap golden-angle bokeh, stronger in the foreground.
  - Grade:
    - day colour balance and exposure;
    - contrast and S-curve on luminance;
    - brown-lifted blacks and a split tone;
    - a faint warm haze in the blur;
    - a warm vignette.
  - Exposure, contrast and balance fade out at night.
- **Lighting:** a stronger, lower day sun, low warm ambient (shadows read brown), less fog, and env saturation and contrast handed over to the post grade.
- **Materials:**
  - New `painted_prop.gdshader` and the shared `painted_common.gdshaderinc`, also used by the foliage shader:
    - warm sunlit tops and brown undersides;
    - contact shade near the ground;
    - object-space texel and blotch detail.
  - Stylize gives every painted prop a thin warm ink line.
  - The grass gets a deeper base with sunlit tips; the ground gets texel mottling.
- **Measured** (day HUD shot, play area) against the target:

  | | Median brightness | Darkest 5 % | Brightest 5 % | G/R | B/R |
  |---|---|---|---|---|---|
  | Before | 164 | 114 | 207 | 0.88 | 0.33 |
  | After | 123 | 67 | 184 | 0.79 | 0.28 |
  | Target | 122 | 50 | 189 | 0.77 | 0.30 |

- **Checks:** `tools/check.sh` passes. The night shot keeps the blue world with the firelit centre, and the imps stay readable.
