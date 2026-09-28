# Feature 014: Stylized game heads (restart the heads)

## Why
The feature 013 heads went from "too round, doll-like" to "too skull-like and anatomical".
- **Cause:** both attempts carve anatomy into the mesh:
  - first by displacing a sphere;
  - then with signed-distance anatomical forms, carved lids, lips and folds.
- **What reference games do:** hand-painted games (League of Legends, WoW/Blizzard style) work the other way round.
  - The head is a simple, planar low-poly shape that matches the concept's silhouettes.
  - The face (eyes, lids, lashes, brows, nostrils, lips, mouth line, cheek and jaw shading) is painted into the texture.
  - Up-facing planes are painted lighter and down-facing planes darker.
  - They use few, bold value steps and no specular.
- **Nela:** she also reads too toddler-like: big cranium, features set very low, chubby cheeks.

## Research summary
- **League champions:** about 7–10k polygons in total, with small hand-painted textures. Riot adjusts concept art for 3D readability and exaggerates heads, hands and silhouettes for the top-down camera. Annie is "hyper-stylized", but her features stay readable.
- **Blizzard style:** low-poly models with everything painted by hand. About 3 tones, bold colours, impressionistic strokes, no specular, and top-down painted light.
- **Translating 2D to 3D:** match the concept's front and side silhouettes. Use clean primary and secondary shapes, with sharp edges and flat planes only where they help. Don't overcomplicate the pipeline.
- **Youth:** youth reads mainly from the head-to-body ratio and eye placement, not from anatomical baby fat.

## Decision
- **Restart the heads (and the hair built on them).** This is a new head generator with a different philosophy, not another tuning pass on the SDF sculpt.
- **Keep everything else from feature 013:** the body landmarks, hands, boots, cloth folds, gear, bake upgrades, draft bakes, and the SCULPT, clay and silhouette review tools.
- The SDF sculptor stays in the repo only if something reuses it; otherwise it is removed.

## New head approach: "drawn planes" heads
1. **Silhouette-driven base.**
   - The head is lofted from the concept's own outlines:
     - a **front outline** (width at each height: cranium, temples, cheekbones, cheeks, jaw corner, chin);
     - a **side profile** (back of skull, crown, forehead, brow, nose, upper lip, lower lip, chin, jaw underside, neck).
   - Each outline is a small list of key points per character, read off the concept sheets.
   - Cross-sections are **superellipses**: squarer than an ellipse.
     - This gives broad front and side planes that turn at defined corners (temple, cheek and jaw corners), which is the drawn, planar game look.
     - The squareness is a parameter per region: softer on the cranium, crisper on the cheek and jaw planes.
   - The mesh is an edge-loop grid, not voxels.
     - It has clean loops around the eyes and mouth region, using the eye-loop topology from game-character guides.
     - About 2–4k triangles for the head. Detail lives in the paint, as in LoL.
2. **A few deliberate forms, and nothing anatomical.**
   - **Brow:** a single soft brow plane shelf. No bar.
   - **Nose:** a small wedge, with a flat front plane, two side planes and a rounded tip.
   - **Eyes:** a shallow, flat eye plane per eye (a slight inset), so the painted eyes sit in a readable socket shadow. No eyeball bulge, no carved lids.
   - **Mouth:** a very slight muzzle curve, with the mouth painted.
   - **Cheeks:** a subtle cheek plane with the edge at the cheekbone.
   - **Chin and jaw:** a jaw corner and a small chin plane.
   - Plane changes get a crisp crease where they should read as drawn lines, and are smoothed elsewhere.
3. **The painted face carries the detail** (`face_paint.py` already does most of this).
   - Painted lids and lash lines, iris, catchlights, brows, nostril accents, lips and the mouth line.
   - Painted plane lighting: a light forehead, nose bridge, cheek tops and chin top; darker under the brow, under the nose, the jaw underside and the neck.
   - About 3 value steps, with warm shadows and cool light.
   - Eyes are painted slightly smaller and more almond-shaped than the concept's big round eyes, as you asked earlier. They stay large and expressive.
4. **Character identities** (same family, different base proportions).
   - **Leo (~7):**
     - a longer face with narrower cheeks;
     - a defined jaw corner and chin plane;
     - eyes at about the head's mid-height;
     - a slightly longer, upturned wedge nose;
     - a confident grin painted with a clear upper and lower lip.
   - **Nela (~4-ish read, age 3 in the story):**
     - less toddler-like than the SDF head;
     - a moderately larger cranium than Leo relative to her face, eyes a little below mid-height, and a shorter lower face than Leo;
     - rounded, not chubby, cheeks with a soft cheek plane;
     - a small but present chin, and a tiny wedge nose;
     - the concept's big laugh painted in.
   - Both heads are a little smaller relative to the body than now, as you asked earlier.
5. **Neck and shoulders.**
   - A wider neck (an elliptical section) that flares into the trapezius and shoulders on the body mesh.
   - The underside of the head meets the neck on a clean jaw-underside plane, with no gap and no ball joint.
6. **Hair (after the heads are approved).**
   - Rebuild on the new skull, in the same drawn style:
     - a few big **planar** primary masses that define the concept's silhouette (Leo's fringe out of the cap; Nela's wild mane and top bun);
     - medium clumps;
     - a handful of accent strands.
   - Clumps get flat, faceted sections and sharp tips, not tubes. Strand banding is painted.
   - No uniform spikes and no helmet shell showing through.

## Review gates (you approve at each)
1. **Heads (clay and painted), before anything else:**
   - front, 3/4 and side clay renders at the same scale as the concept crops;
   - a profile silhouette;
   - the painted face in the in-game (Godot) portrait, where it actually matters.

   Iteration uses `SCULPT=1` (seconds per head, because the loft is analytic with no voxels).
2. **Heads with hair** on the bodies.
3. **Neck, shoulders and body fit** with the new heads.
4. **512 draft bake** of both kids, then the full 2K bake, the Godot reimport, portraits, `tools/check.sh`, the export, and push.

## Budgets
- **Heads:** about 2–4k triangles each.
- **Hair:** about 6–10k each.
- **Characters:** they stay within the current 120k budget, and will probably come in well under it.

## Risks
- **The loft is new code.** The first iteration may need a couple of rounds to get the nose wedge and the jaw corner right.
- **Mitigation:** the approach is analytic and fast (no voxel or marching cubes step), so rounds are quick. The clay, painted and portrait review renders already exist.
- **Paint does more of the work.** Face quality now depends more on paint than on geometry. I'll judge it in the Godot portrait lighting, not only in Blender previews.

## Sources
- [Battlecast Illaoi: Modeling and Texturing (Riot)](https://nexus.leagueoflegends.com/en-us/2018/01/battlecast-illaoi-modeling-and-texturing/)
- [Annie (Development), League of Legends Wiki](https://leagueoflegends.fandom.com/wiki/Annie/Development)
- [In-game 3D Model Poly Count (LoL forums)](http://forums.oce.leagueoflegends.com/board/showthread.php?t=82447)
- [How to achieve Blizzard style (polycount)](https://polycount.com/discussion/87043/how-to-achieve-blizzard-style)
- [Need advice on low-poly hand painted model, WoW inspired (polycount)](https://polycount.com/discussion/147944/need-advice-on-low-poly-hand-painted-model-wow-inspired)
- [Topology for Low Poly Game Characters (Thundercloud Studio)](https://thundercloud-studio.com/article/topology-for-low-poly-game-characters/)
- [How to Create Your Own Hand-Painted 3D Characters (The Rookies)](https://discover.therookies.co/2019/07/21/how-to-create-your-own-hand-painted-3d-characters/)
- [Crafting a Stylized Character Based on 2D (80.lv)](https://80.lv/articles/crafting-a-stylized-character-based-on-2d)
- [Transforming a 2D Concept into an Expressive 3D Model (80.lv)](https://80.lv/articles/how-to-transform-a-2d-concept-of-a-fantasy-character-into-an-expressive-3d-model)
- [Why Proportions Are the Key to Great 3D Character Design (Whizzy Studios)](https://www.whizzystudios.com/post/why-proportions-are-the-key-to-great-3d-character-design)
