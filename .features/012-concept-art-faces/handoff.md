# Feature 012: Handoff

**State:** done; the build is v0.9.0-playtest1.

- **The reference is the concept art.** Each character script's docstring lists what it follows from the two concept sheets (faces, hair, outfit, gear). Keep new details inside that design; LoL flavour comes from proportions, silhouette and the painted bake, not from champion cosplay.
- **Fast loops:**
  - **Face:** call the script's `head_piece()` after `common.reset()`, give the head and hair `chibi.quick_material`, and `preview.render` them. This takes about 20 seconds.
  - **Full body:** `QUICK=1 .venv-blender/bin/python art/characters/leo.py` renders the whole character without a bake, including a larger `*_front` Idle view.
- **Face paint:** `face_paint.FaceLayout` now also has `catch2` (a second catchlight), `flush_alpha` (sun-flush over the nose and cheeks), `tongue` (for open mouths) and `lid_fold`. All default to off.
- **Painted wear:** `common.grime(obj, colour, amount_fn)` blends dirt, scuffs and mud over existing colours before the bake.
- **Hands:** `chibi.hands(..., mitten=True, crease=colour)` gives the kids readable mitten hands; the imp is unchanged.
- **Budgets:** the hero kids are ≤ 50k triangles (Leo 40.4k, Nela 44.8k). Heads are 11k, and hair is decimated to 10k/12k.
- **Heads bake warm:** the heads use their own warm `shadow`/`light` tint so faces stay bright like the art. The clothes keep the darker, higher-contrast look.
- **Rebuild:** `tools/build_art.sh characters/leo characters/nela` (about 10 minutes each on CPU), then re-render the portraits with `tools/render_icons.tscn`.
