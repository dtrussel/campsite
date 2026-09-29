# Feature 013: Sculpted, MOBA-quality Leo and Nela

## Context
Feature 012 put Leo and Nela back on the concept art: faces, outfits and gear. The user now says the models are still:
- too rounded, toy-like and simplified;
- smooth ellipsoid heads with painted-on faces;
- tube limbs with ball joints;
- mitten hands and blob boots;
- clothes whose folds exist only in the texture;
- big uniform hair chunks.

**Goal:** keep the identities, outfits, proportions and gear, and raise the *sculptural* quality to a polished MOBA hero:
- a strong silhouette;
- an expressive, anatomically integrated face;
- stylised anatomical landmarks;
- folds and hems in the geometry;
- layered hair clumps;
- selective sharp edges against soft forms;
- a hand-painted (not plastic) finish.

**User decision:** budgets up to ~120k triangles per kid, with 2048 textures everywhere.

Everything stays procedural in the existing bpy pipeline:
- `art/characters/chibi.py`: shape kit;
- `face_paint.py`: painted face;
- `art/lib/paint_bake.py`: bake;
- `art/lib/common.py`: helpers.

Improve these; don't rewrite them. The imp keeps its current look, so all new kit arguments are optional.

## 0. Review tooling first (sculpt can't be judged on textured, glossy previews)
- Add `preview.render_clay(objects, name, views)` in `art/lib/preview.py`:
  - a matte grey material (no specular), matching the in-game matte `stylize.gd` finish;
  - a strong key light plus a rim light;
  - views: front, 3/4, profile and back of the body, plus face close-ups at front, 3/4 and profile.
- Also add a **silhouette** render: a black fill at game size (~120 px tall) to check readability and outline interest.
- Make `quick_material` / preview materials use specular 0 so previews stop looking plastic.
- The comparison sheets (reference | clay | painted) are built as in feature 012 (PIL scripts in the scratchpad).
- Add `SCULPT=1` mode, a clay-only quick build, for fast shape iteration: head-only in about 20 seconds and full body in about 1 minute.

## 1. Face sculpting (highest priority): `chibi.sculpt_head` / `sculpt_features`
**Replace pure gaussians with curve-driven displacement.** Add a small helper, `_curve_dist(u, w, pts)`, giving the distance to a polyline in the face plane. Features then follow real contours:
- **Eyes set into the skull.**
  - Deeper sockets, with a convex eyeball dome sized to the painted iris area.
  - An **upper-lid ridge** with thickness, following the `face_paint` eye-top curve and a crisp crease line above it.
  - A soft lower-lid roll and a tear-trough dip.
  - Keep the big stylised eyes; the lids wrap them.
- **Brow:** a soft brow mass (child: low ridge) with a plane change into the temple, the temple slightly hollowed.
- **Nose:**
  - a bridge plane with side planes;
  - a defined tip ball;
  - nostril wings (alae) with carved nostril shadows;
  - the columella under the tip.
  - Leo's nose is slightly upturned; Nela's is a tiny button.
- **Mouth:**
  - an upper-lip vermilion with a Cupid's bow;
  - a fuller lower lip;
  - carved **mouth corners** (small pits), a philtrum groove and ridges, and a mentolabial fold above the chin.
  - The open grin gets a recessed mouth cavity, so the painted teeth sit inside.
- **Cheeks / jaw / chin:**
  - cheekbone (zygomatic) planes;
  - child cheek fat pads: stronger for Nela, set low;
  - a clear jaw line with a plane change under the jaw into the neck;
  - a chin pad.
  - Leo has a slightly squarer jaw and longer chin; Nela is round.
- **Skull profile:**
  - forehead slope;
  - occipital bulge;
  - flatter side planes (LoL plane changes);
  - a slightly flattened face front.
  - Check against the profile clay render.
- **Mesh density and deformation:**
  - Head density from `segs` / `tris` goes up to about 24k, so the curves resolve.
  - `decimate_tris` runs *after* sculpt, with a planar-aware ratio.
  - The head stays a single rigid-bound mesh (no facial rig), so deformation is unaffected.
- **Paint re-alignment:**
  - Feed the same `FaceLayout` into the new curves.
  - Retune the lid/crease/lip paint in `face_paint.py` so paint and relief coincide.
  - Paint gets *less* of the lighting burden now that the geometry carries it.

## 2. Hair: layered, intentional clumps (`chibi.hair_clump`, character `hair()` functions)
- **Three tiers per character:**
  - big **primary** masses define the silhouette (3–5);
  - **secondary** clumps of varied width/length layered on top (8–12);
  - **tertiary** sharp flicks and strands at the edges (6–10).
- `hair_clump` gets optional:
  - `sharp=True`: a lens-shaped cross-section with a pinched edge, and no subsurf on the last 30%, for crisp tips;
  - `twist`: a per-clump twist along its length;
  - `split`: a forked tip.
- **Flow:** clumps follow a flow field from the part / crown whorl.
  - **Leo:** strands sweep forward out of the cap opening, fanning to his left, with sides tucked behind the ears.
  - **Nela:** flow radiates from the bun.
  - Randomised length and width inside controlled ranges (seeded, deterministic).
- **Preserve the styles:**
  - Leo: a messy fringe out of the backwards cap, with visible tufts at the nape and sides.
  - Nela: a wild wavy mane, face-framing locks, a messy top bun with a tie, and flyaways.
- **Asymmetry:**
  - Leo: the fringe heavier on one side.
  - Nela: the bun slightly off-centre, one side of the mane fuller.
- **Colour:** strand banding by tier (primaries darker at the roots, tertiaries lighter tips).

## 3. Body contours: landmarks instead of tubes
- Skin, shirt and pants are already unions via `chibi.fuse` (voxel remesh + smooth). **Add landmark volumes to those unions** rather than replacing them:
  - **Shoulders:** a deltoid cap ellipsoid, and a trapezius slope from the neck.
  - **Arms:**
    - a bicep swell;
    - an elbow narrowing with a small olecranon bump at the back;
    - a forearm with a flattened oval section tapering to a narrow wrist.
  - **Legs:**
    - a front knee (patella) mass;
    - a calf bulge at the back (upper third of the shin);
    - a tapering shin;
    - an ankle narrowing with malleolus bumps.
  - **Torso:**
    - a chest plane and shoulder blades;
    - Leo: a lean waist taper;
    - Nela: a toddler belly.
- Extend `chibi.tube` with optional per-point elliptical radii `(rx, ry)` and a section rotation, so limbs aren't circular.
- **Budgets:** raise `fuse(..., faces=)` for skin, shirt, shorts and pants to 8–14k, so landmarks and folds resolve.
- **Deformation:** check it on the Idle, Running_A, attack, PickUp and Death_A frames. The shoulders, elbows and knees must hold up under auto-weights.

## 4. Hands and feet
- **Hands** (`chibi.hands`, new mode `sculpted=True`):
  - a palm block with a thenar pad;
  - a separate thumb (two segments, angled out);
  - the fingers as **two grouped masses** (index+middle, ring+little), with a shallow groove between them and a slight natural curl;
  - knuckle bumps on the back of the hand;
  - a wrist taper into the forearm.
  - The curl is kept compatible with the stick and lantern grips (`handslot.r`).
- **Boots** (`chibi.boot`, new mode `sculpted=True`):
  - a separate **thick sole** with a tread lip and a slight toe spring;
  - a heel block and a toe cap;
  - a padded collar at the ankle and a tongue;
  - lace crosses with eyelet rows (Leo: orange laces; Nela: tan);
  - an ankle transition via the sock fold rolling over the collar.
  - Sharper sole and toe-cap edges (small bevels) against the softer upper.

## 5. Clothing geometry: folds, hems, seams in the mesh
- **New helper:** `chibi.fold(obj, centre, axis, count, depth, radius, profile="sharp")`. It displaces along the normal using a sharpened sine (a crisp crest, soft valleys), masked by a smooth falloff region. LoL-style folds.
- **Where the folds go:**
  - **Leo's tee:** shoulder / armpit tension folds, sleeve folds and a waist compression band.
  - **Leo's shorts:** crotch radiating folds, knee-hem folds and pocket-bottom sag.
  - **Nela's tee:** the same as Leo's, softer.
  - **Nela's harem pants:** big drape folds down the legs, and **gathered accordion cuffs** at the ankles.
  - **Socks:** rolled bunching.
- **Hems:** rolled tubes with real thickness at the sleeve ends, shirt hem and shorts hem, slightly proud of the surface.
- **Seams:** raised ridges along side and shoulder seams, with painted stitching on top.
- **Pockets:** real thickness with a bevelled flap edge.
- **Straps:**
  - Upgrade `chibi.straps` to thick webbing (width by thickness, with bevel).
  - Stitched edges are painted.
  - **Buckles** are new `chibi.buckle()`: a rectangular frame with a prong.
  - Keepers and adjuster sliders.
  - Straps sit slightly off the body with a visible contact shadow.

## 6. Gear: layered construction
- **Backpacks** (both):
  - a main bag with a sculpted top-flap overhang and sag;
  - a front pocket with a flap;
  - side pockets;
  - compression straps with buckles;
  - bottom straps holding the bedroll;
  - a haul loop.
  - Leo's camo pack and Nela's olive pack keep their colours.
- **Bedroll:** a spiral end cap with real layered rings (not just paint), and cinch straps that pinch the roll.
- **Leo's walking stick:** a gnarled shaft with knots and plane-cut facets, a twine wrap as a real helix, and leaves with a centre fold.
- **Leo's bottle and rope:** a bottle with a cap and neck ring; the rope as a braided-look coil on a carabiner.
- **Nela's lantern:** a layered cap and chimney, a vented top, a glass panel frame, a bail with loops, and a thicker base.
- **Nela's bunny:** a stitched patch with raised stitches, a button eye as a real button, and ear folds.
- **Compass:** a hinged lid on Leo's (as in the art), a ring loop, and a raised bezel.
- **Silhouette asymmetry:**
  - Leo: the bedroll overhangs one side; the rope and carabiner on one side, the bottle on the other; the stick.
  - Nela: the bunny on one shoulder, the scarf tails, and the lantern.

## 7. Materials and paint (`paint_bake.py`)
- **Bake size:** 2048 for all maps (the user's decision).
- **New optional bake inputs:**
  - `curvature_tint`: warm skin in concavities (a subsurface feel), cooler and lighter on convex planes;
  - `edge_wear`: lighter worn edges, driven by Bevel on fabric/leather hems and edges;
  - `gradient`: a value gradient top to bottom per part;
  - fold valleys get extra occlusion (short-distance AO).
- **Palettes:** darker and richer, with higher contrast between the parts.
- **Painted detail:** stitching and dirt variation stay painted in `color_by` / `common.grime`.
- **Skin:** a matte finish, a warm head bake (keep the feature 012 fix), and colour variation (a redder nose, cheeks and knees; cooler jaw shadow).
- **Download size:** export painted textures as **WebP** (lossless or quality 90) or JPEG inside the GLB (`export_image_format`). This keeps the files manageable at 2048. Godot 4.3 imports both.

## 8. Budgets, LODs, integration
- **Triangles:** the target is ~90–120k per kid:
  - head ~24k;
  - hair ~25–30k;
  - body and clothes ~35–45k;
  - gear ~15–20k.
- **Distance LODs:** Godot generates mesh LODs on import (already enabled; the import log shows LOD generation), which covers the gameplay camera distance.
- **Docs:** update the budgets in `art/README.md`.
- **Game side:**
  - re-check the HP bar / label heights against the new heights;
  - re-render the portraits with `game/tools/render_icons.tscn`;
  - run `tools/check.sh`;
  - take screenshots (`tests/sim/screenshots.tscn`) at play zoom;
  - run `tools/export_playtest.sh` and report the zip sizes. If the data zip exceeds 30 MiB even with WebP, tell the user; don't raise the limit silently.
- **Version:** 0.10.0-playtest1.
- **Feature docs:** `.features/013-sculpted-kids/{plan,status,handoff}.md`.

## Order of work
1. Review tooling (clay, silhouette, specular-free previews).
2. Face sculpting, iterating in `SCULPT=1` head-only against the references (front, 3/4, profile).
3. Hair tiers.
4. Body landmarks.
5. Hands and boots.
6. Clothing folds, hems and straps.
7. Gear.
8. Bake upgrades and 2K/WebP export.
9. Full bakes.
10. Game integration, checks and shipping.

Commit and push at each milestone to `ccr-10877e76-2578j9`.

## Critical files
- `art/characters/chibi.py`: sculpt, hair, hands, boot, strap, buckle and fold helpers (optional arguments).
- `art/characters/face_paint.py`: re-aligned lids and lips.
- `art/characters/leo.py`, `art/characters/nela.py`.
- `art/lib/paint_bake.py`, `art/lib/preview.py`, `art/lib/common.py` (export image format).
- Game: `player_controller.gd` / `companion_controller.gd` (HP bars), `Sibling.tscn` (label), `render_icons.gd`, `game/project.godot` (version).

## Verification
1. **Clay sheets per iteration:** front, 3/4, profile and back, plus face close-ups at front, 3/4 and profile, next to the reference crops. The final sheets go to the user.
2. **Silhouette sheet** at game size, for both kids.
3. **Animation-frame clay renders** for deformation (shoulders, elbows, knees, hands on the stick/lantern).
4. **Triangle report** (`chibi.report`) within budget.
5. **Godot:**
   - reimport;
   - `tools/check.sh` green;
   - portraits re-rendered;
   - Xvfb screenshots (title, day, night);
   - `tools/export_playtest.sh` self-test, with the zip sizes reported.
