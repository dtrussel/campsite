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

## 2026-10-16: Milestone 5 (softer blur)
- **What changed.** The user found the M4 blur a bit too strong, so the band is wider and the bokeh smaller (D14). The grade is unchanged.
- **Measured.** The day stats are the same as M4: median 123, G/R 0.79, B/R 0.28.

## 2026-10-16: Milestone 6 (model detail pass)
**Method.**
- Every model had at least one improvement pass. Each was checked in the in-game model gallery (`game/tools/model_gallery.tscn`), before against after, plus the triangle count and bounds (±10 %).
- A model was committed only if it clearly improved (D15).
- **New pipeline (`art/lib/detail.py`).** Props are modelled dense and the painted look is baked straight onto the budget mesh (`paint_bake.paint_direct`), so the detail lives in the texture.

**Results.**

| Group | Improved | Kept as is |
|---|---|---|
| Camp and homestead (16) | all: log and stump seats, campfire, tent, fence, watch post, torch, woodpile, crate, barrel, toadstools, tripod, sign, lantern post, market stall, stone well | none |
| Forage and haunted props (18) | all: clay pit (+ dug), mushrooms (+ picked), junk pile (+ picked), snap trap base and jaw, glow lantern, glow shard, hearth ring, reinforced wall, storage crate, crafting table, jack-o'-lantern, small pumpkin, camp lantern, water bucket | none |
| Nature (24) | trees a–c, tree stump, pines a–d, rocks a–c, rock cluster, berry bush (+ picked), flower bush, dead trees a–c, hills a–c, mountains a–b | `rock_pebbles`: cracks did not read at its size |
| Characters (5) | shadow imp (ringed horns, veined wings, clean stripes), mushroom gremlin (soft raised cap spots instead of square pixels, gills), bramble beast (hooked thorns, leaf veins, moss; modest) | Leo and Nela: seams and smudges did not read at game scale |
| Code meshes | grass tufts (5 curved blades), daisies (petal cups with a golden centre), lupines (floret tiers) | none |

**Notable fixes.**
- The well roof and stall awning were a scrambled checker (D7). They are now real tile courses and crisp stripes.
- The watch post's side rails were rotated 90°.
- The jack-o'-lantern's glow panels floated; its face is now carved into the body.
- The campfire (7.4k) and watch post (5.2k triangles) are now within the 1.5k budget.

**Also changed.**
- The painted shader's texel noise is finer (0.025 m, 4 %), so it no longer reads as a checker up close.
- The UI icons and the imp portrait were re-rendered.

**Checks.** `tools/check.sh` passes after every batch. The day grade stats are unchanged.

## 2026-10-16: Milestone 7 (Leo and Nela)
**Diagnosis.** In game a kid is about 100 px tall, so the gains are colour blocks and silhouette, not seams. Compared with the concept turnarounds (04, 05):
- The warm grade washed Leo's sky-blue tee to grey and turned Nela's purple trousers maroon or pink.
- Both boots stood on box soles that read as planks.
- Leo's shorts had lime bands instead of denim.
- The chest emblems were small or missing.

**Results (D16).**

| Kid | Improved | Tried and dropped |
|---|---|---|
| Leo | Saturated sky-blue tee. Teal-blue denim shorts with a light rolled cuff and two mended patches (no lime bands). Big painted camp logo (globe, hill, pines, sun) in the centre of the tee. Compass moved from the neck cord to his right strap. Light-blue socks, a brighter blue bedroll, rounded soles. | Logo as stacked decal geometry: the ink line and the bake turned it to mush, so it is painted into a denser tee instead. |
| Nela | Violet trousers with thinner cream zigzags (purple dominates). Big pale-blue heart on the tee. Less dirt. A brighter purple hair tie. Compass clipped to her strap (no cord across the heart). Rounded soles. | High ponytail (two attempts). From the game camera the crown read as a smooth, bright blob, and the old bun reads better, so the bun was kept. |

- **Shorter necks (user follow-up):** both heads sit 0.055 lower in rest space (`HEAD` z), so the chin meets the collar like a chibi. No clipping in the idle, run, attack or pick-up poses; the portrait cameras were lowered to match.
- **Leo's cap (user follow-up):** now a full baseball cap worn backwards: a six-panel crown down to a band, the snapback opening and strap over his forehead with the fringe coming through, and the brim behind, angled a little to his left and up so it shows from the game camera.
- **Camera (user follow-up):** pitch 50 → 42 and distance 18.5 → 15.5 (`camera_follow.gd`), a more tilted view closer to the kids (about 20 % bigger on screen). Zoom limits are unchanged.
- **Triangles:** Leo 35.0k, Nela 35.7k, unchanged.
- **Unchanged:** rigs, clips, proportions and attach points.
- **Re-rendered:** both portraits.
- **Checks:** `tools/check.sh` passes.


## 2026-10-16: Milestone 8 (art pass picked by the user)
The user picked foliage, the campfire and hearth, the lanterns and the shadow imp. The ground is left as it is.

**Foliage (D17).**
- **Broadleaf trees `tree_a`–`c`:** about 1,000 rounded leaves over a dark shell. Sunlit yellow-green leaf tops, shade between the leaves and a jagged leafy silhouette.
- **Berry and flower bushes:** 380–450 smaller leaves. The berries and blossoms sit a little further out.
- **Pines `pine_a`–`d`:** about 600 needle blades running down the tiers. The tier hems still read.
- **Checks:** gallery before/after; day, sunset and night screenshots; `tools/check.sh` passes.

**Campfire and hearth.**
- **Campfire:** 14 rounded grey cobbles of mixed sizes (the dense `stone` helper) replace the pale chiselled boulders, which the old 1.5k budget had turned into angular cream facets. They are sooted on the side facing the fire, with a little moss. Six thicker charred logs. The budget is now 2.8k (`campfire` sits in the middle of every shot).
- **Hearth ring:** the bricks vary in size and set angle, about a third are burnt darker, and all are slightly dustier. The budget is unchanged.
