# Character modelling with an AI agent

How to build or change a character model (a hero, Mum, an NPC, a
creature) in this repo when the work is done by an AI agent writing
Blender Python. This was researched and learned on Mum (feature 043,
three passes). Read it before touching `art/characters/`.

## The short version

1. **Measure the reference before modelling.** Read landmarks off the
   concept sheet as *fractions of the total height*.
2. **Build and render from the sheet's own views.** Use an
   orthographic front and side.
3. **Compare in numbers, not by eye.** Overlay the silhouettes, then
   print the model's landmarks next to the sheet's.
4. **Change the script, re-measure, repeat** until every landmark is
   within about 0.02 of the sheet. Only then do the slow paint bake.

Judging renders by eye drifts. Mum's first two passes looked "fine" in
previews and still measured 7.3 heads tall against the sheet's 5.8, with
shoulders 20% too narrow.

## What the research says

- **Agents need a closed visual loop.** Blender-agent projects agree:
  - checking a render after every step is what keeps geometry from
    compounding errors
    ([3D-Agent on Blender devtalk](https://devtalk.blender.org/t/3d-agent-blender-ai-assistant-built-a-multi-agent-system-on-top-of-blenders-mcp-and-python-api-and-sharing-architecture-learnings-for-the-lab-discussion/44260));
  - a critic should compare the render with the target and name the
    biggest errors in proportion, placement and silhouette
    ([dream-loop](https://github.com/achimala/dream-loop),
    [3DHarnessBench](https://arxiv.org/pdf/2609.06535),
    [SceneCraft](https://arxiv.org/pdf/2403.01248),
    [Planner-Actor-Critic](https://arxiv.org/pdf/2601.05016)).

  Nobody ships a ready-made silhouette metric, so this repo has its own
  (`art/lib/measure.py`).
- **Organic forms from Python primitives are the hard part.** Sculpt
  mode isn't reachable from scripts, and agents tend to produce
  placeholder-looking bodies
  ([MindStudio on Blender MCP](https://www.mindstudio.ai/blog/claude-blender-mcp-real-world-performance)).
  Our answer is the `chibi` kit: lofted limbs, voxel-fused clothing,
  folds and hems. Its weak spot is proportions, so measure them.
- **Alternatives we did not take.**
  - Dedicated human generators (MakeHuman/MPFB, SMPL-family models)
    give realistic bodies. They clash with the painted chibi style and
    the KayKit rig.
  - Image-to-3D services (Meshy, Neural4D) give a mesh without our rig,
    budgets or painted bake.

  Both are worth revisiting only for a realistic character.

## Proportions: the sheet wins, not anatomy

Drawing guides for adults:
- a realistic woman is about **7–7.5 heads** tall, 8 heads is
  "heroic", and chibi is 2–3 heads;
- shoulders and hips are roughly **1.5–2.5 heads** wide; sources
  disagree on the exact figure
  ([Taylor & Francis](https://www.taylorfrancis.com/books/9780080557632/chapters/10.4324/9780080557632-5),
  [Paper Thin Personas](https://paperthinpersonas.com/2016/06/03/quick-dirty-guide-female-proportions-drawing/),
  [Fiveable](https://fiveable.me/drawing-foundations/unit-10/proportions-human-body/study-guide/bVYcw96jRRpCUZJk),
  [ZBrushCentral](https://www.zbrushcentral.com/t/measure-by-heads-rule/379333),
  [Clip Studio chibi](https://tips.clip-studio.com/ko-kr/articles/4946?org=1)).

Our concept art is *stylised*: Mum's sheet is about **5.8 heads** with
a sturdy build. Use the guides only to sanity-check, and match the
sheet's measured numbers.

Mum's sheet landmarks, as fractions of height:

| Landmark | Height | Width |
|---|---|---|
| Head (crown to chin) | 0.173 | — |
| Chin | 0.827 | — |
| Shoulders | 0.755 | 0.255 |
| Chest | — | 0.216 |
| Belt | 0.54 | — |
| Hips | — | 0.216 |
| Crotch | 0.474 | — |
| Thigh (one leg) | — | 0.10 |
| Knees | 0.27 | — |
| Boot tops | 0.137 | — |

## How to measure a sheet

Automatic masks from painted sheets don't work. Dark clothing merges
with dark backgrounds, and filling holes closes the gap between the
legs. Read landmarks by hand instead:

- Crop each turnaround view and draw a labelled pixel grid over a 2×
  zoom (Pillow).
- Read off the heights and widths.
- Divide by crown-to-floor height. Use the skull crown, not loose hair.

## The tools in this repo

- **`art/lib/measure.py`**
  - `landmarks()` and `widths()` give the posed mesh's heights and
    widths as fractions of height.
  - `silhouette()` renders an orthographic flat-white front or side
    view. It uses Cycles, because Workbench needs EGL, which headless
    containers lack.
- **`MEASURE=1` on `art/characters/mum.py`** poses her arms-down like
  the sheet, prints a model-vs-sheet table and writes
  `mum_sil_front.png` and `mum_sil_side.png`. Copy the pattern for a new
  character.
- **Fast loops, slowest last:**
  - `HEAD_ONLY=1`: face and hair only, about 20 s;
  - `MEASURE=1`: about 1 min;
  - `QUICK=1`: whole body, vertex colours, about 1 min;
  - `SCULPT=1`: clay views;
  - the full bake: about 2 min for Mum, up to 10 min for the kids.
- **`game/tools/model_gallery.tscn`** shows the model in the game's own
  look. Always check the game view. Paint, grading and the camera
  change how proportions read.

## Gotchas learned on Mum

- **`chibi.Proportions` only stretches lengths.**
  - `legs`, `spine` and `arms` don't widen anything. Widths live in the
    primitives' radii, so set them from the measured targets.
  - `shins=` (optional) gives longer shins than thighs; Mum's knees
    needed it.
  - Above the neck everything is just lifted, so head size is a
    separate scale (`HEAD_SCALE`).
- **Anything that crosses a stretch boundary changes shape.** In rest
  space, the leg zone is z 0.15–0.52 and the torso is 0.52–1.22.
  - Boot shafts poking above 0.15 become tall gaiters.
  - A thigh pocket 0.12 tall becomes 0.37.
  - Size parts in rest space with the stretch factor in mind.
- **Hidden inner skin pokes through clothes when joints bend.** Mum's
  legs did this when she sat. Drop the inner limbs a garment fully
  covers.
- **Clothing layers must nest.** When an under-layer is wider than the
  layer over it, its paint shows through as dark blotches after the
  bake (trouser hips through the jacket hem).
- **Validate meshes before export.** `mesh.data.validate()` fixes the
  "Mesh … is not valid" glTF warning.
- **Check every clip the game plays, not only Idle.** The gallery plays
  the first `*idle` alphabetically (`2H_Melee_Idle`). The title uses
  `Sit_Floor_Idle`, and the run uses walk, cheer and Wave. Preview them
  with `EXTRA_CLIPS=a,b`.
- **A dark shape trailing off a character in a gallery shot may be its
  ground shadow.** Confirm with a Blender preview of the same clip
  before chasing a skinning bug.
- **Faces are mostly paint.** `face_paint.FaceLayout` sets eye size and
  height, brows, blush and smile. The head loft sets the shape, so
  round the cheeks there. Compare against the sheet's expression heads
  side by side.
- **Hair:**
  - many narrow, layered, wavy locks read fuller than a few wide ones;
  - drape bangs over the head surface (`HEAD.point`) instead of
    offsetting them in space;
  - keep stray locks few and close, or they read as spikes.
