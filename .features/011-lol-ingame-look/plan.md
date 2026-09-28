# Feature 011: LoL in-game look for Leo and Nela

## Context
The user compared v0.7.0 with in-game LoL models of Ekko and Annie (screenshots attached). The faces in particular still look very different.

**What the LoL models do that ours don't:**
1. **Faces are sculpted and painted, not decals.**
   - The heads have real relief: brow ridge, eye sockets, nose bridge and tip, lips, cheekbones, chin.
   - The eyes are *painted into the texture*: fairly small almond eyes, eyelid and eye-socket shading, eyeliner, iris gradient, catchlight.
   - Brows are painted brush strokes. Lips are shaded, the upper lip darker than the lower.
   - Ours are flat anime decals: big eyes, flat colours, a ball head.
2. **Proportions are less chibi.**
   - Ekko: lanky, long limbs, baggy pants, big shoes, big hands.
   - Annie: head about 1/4 of her height, slim limbs.
3. **Textures are strongly hand-painted.**
   - Baked key light from the top-front, deep occlusion in crevices, value contrast.
   - Painted fabric folds, stitches, seams, patches and worn edges.
   - Colour gradients, with darker values toward the feet.
   - Ours: mostly flat vertex-colour regions.

**User decisions:**
- **Proportions in between:** Leo's head about 1/5 of his height, Nela's about 1/3.5.
- **Keep** the thin outlines.
- Designs stay based on the user's concept art: Leo with the backwards cap, quiff, tee, striped shorts, backpack and stick; Nela with pigtails, pink tee, plum pants, the bunny and the lantern.

## Approach

### 1. Proportions (`chibi.Proportions`, already working)
- **Leo:** legs about 1.85, spine about 1.3, arms about 1.25. Head radii shrink to about (0.25, 0.25, 0.3). Hands and shoes stay big (Ekko).
- **Nela:** legs about 1.3, spine about 1.1, arms about 1.1. Head radii about (0.32, 0.31, 0.33).
- Longer legs mean longer strides, so raise `reference_speed` in `PlayerBoy.tscn` and `Sibling.tscn` to avoid foot sliding.
- Re-fit scales so the on-screen size stays at the v0.7 target: the same height on screen, with Leo about 1.35× Nela.

### 2. Sculpted heads (`chibi.sculpt_head` → add feature sculpting)
- Use a denser base (64×48) and add Gaussian feature deformations, set per character:
  - brow ridge;
  - eye-socket dents with a slight eyeball bulge;
  - nose (bridge ridge, tip ball, nostril wings);
  - upper and lower lip volumes with a mouth-corner dent;
  - philtrum, cheekbones and chin ball;
  - jaw angle, stronger for Leo;
  - a defined neck and jaw line.
- **Leo (Ekko):** a longer face, a strong brow ridge, a straight nose, a firm mouth, an angular jaw.
- **Nela (Annie):** a rounder face, a small upturned nose, small full lips, soft cheeks, a small chin.
- Store the feature positions as face-plane coordinates in a `FaceLayout`. The sculpt and the painted texture then share one layout, so the paint always lines up with the geometry.

### 3. Painted faces (new `art/characters/face_paint.py`, numpy like `art/ground/textures.py`)
- Paint a 1024² RGBA face overlay in front-projected face-plane space: head x,z → u,v, the same frame as the `FaceLayout`. Contents:
  - **Eyes:**
    - almond eye shapes (smaller than now, LoL scale) with a soft sclera shaded darker at the top from the lid;
    - a painted eyelid crease and eyeshadow gradient (Annie: smoky purple-pink);
    - a thick tapered lash line with a small wing, and a lower lash;
    - an iris radial gradient with a limbal ring and lighter lower iris, a pupil, and one sharp catchlight.
  - **Brows:** tapered brush strokes. Leo: thick, one cocky raised brow. Nela: thin and arched.
  - **Nose:** side shadow, nostril marks and a tip highlight.
  - **Lips:** a darker upper lip, a lower lip with a highlight, a mouth line with corner shadows.
    - Leo: a sly smirk, Ekko-like.
    - Nela: a small mischievous smile, Annie-like, with rosy lips.
  - **Skin:** cheek blush, freckles (Leo), under-eye and philtrum shading.
  - **Face paint:** Leo's teal cheekbone marks, painted as brush strokes, Ekko-style.
- **In Blender:**
  - add a `FaceUV` (orthographic front projection) on the head;
  - `paint_bake` gains an `overlay=(image_path, uv_name, facing_mask)` option that alpha-blends the painted face over the base colour, only on front-facing normals, before the lighting and AO steps. The painted face then receives the same baked lighting.
  - Remove the old decal eyes and mouth (the `almond_eye`, `smirk` and `smile` geometry). Keep a very slight eyeball bulge in the sculpt.

### 4. Stronger hand-painted bake (`art/lib/paint_bake.py`, optional params)
- `key_light`: a baked Lambert term from a fixed top-front-left direction, plus a warm highlight. This gives LoL value contrast.
- `cavity`: darken with Geometry Pointiness in crevices, folds and under the chin.
- Stronger AO for the kids, and `foot_darken` stays.
- `fabric`: painted folds (stretched noise/wave strokes following the limbs), seam lines and short stitch marks, driven per material region through a mask in the colour attribute alpha.
- Add painted patches and wear:
  - Leo: patches on the shorts, scuffed shoes;
  - Nela: a stitched patch and a button eye on the bunny (Tibbers-like), and stitches on the pants.

### 5. Outfit tweaks toward the references (still the user's designs)
- **Leo:**
  - a taller, narrower spiky mohawk-quiff out of the cap front;
  - fingerless gloves (Ekko);
  - shin wraps above the big shoes;
  - baggier knee-length shorts;
  - the teal kerchief is kept.
- **Nela:**
  - a slimmer body and arms;
  - striped leg warmers over the boots (an Annie cue, in pink/plum);
  - a bigger, patched bunny;
  - the lantern is kept.

### 6. Self-review against the references
- Copy the two reference images into the scratchpad.
- For each iteration, render matching views: a front 3/4 full body, and a face close-up at a similar angle and lighting (a warm key and cool fill, similar to the in-game shots).
- Build a side-by-side comparison sheet (reference | ours) and review it each time. Iterate on the silhouette, head/body ratio, face layout, eye size and paint contrast until it reads as the same style family.

### 7. Game integration
- Scales, HP bars, `reference_speed`, the Sibling TaskLabel and light, and the title backdrop scales.
- Re-render the portraits (`game/tools/render_icons.gd`).
- Docs: `.features/011-lol-ingame-look/*` and the `art/README.md` section on face paint. Version 0.8.0-playtest1.

## Critical files
- `art/characters/chibi.py`: sculpt features and `FaceLayout`; the decal faces are removed.
- `art/characters/face_paint.py` (new).
- `art/characters/leo.py`, `art/characters/nela.py`.
- `art/lib/paint_bake.py`: `overlay`, `key_light`, `cavity`, `fabric`.
- Game side:
  - `game/scenes/player/PlayerBoy.tscn`, `game/scenes/companions/Sibling.tscn`;
  - `game/scripts/player/player_controller.gd`, `game/scripts/companions/companion_controller.gd` (HP bars);
  - `game/scripts/ui/title_backdrop.gd`, `game/tools/render_icons.gd`.

## Verification
1. **Reference comparison sheets** (face and full body) at each iteration, with a final side-by-side sent to the user.
2. **`QUICK=1` loop** for shapes; full bakes for the paint. Animation frames (Idle, Run, attack, PickUp, Death) to check the longer limbs and ground contact.
3. `tools/check.sh` is green.
4. **Xvfb screenshots** (title, day, night) for on-screen size and readability.
5. **`tools/export_playtest.sh`:** the self-test passes and both zips stay under 30 MiB.
6. **Ship:** commit, push, and send the comparison sheets, screenshots and zips.
