# Feature 009: Leo and Nela, LoL-style restyle

## Context
v0.4.0 introduced Leo and Nela, built from the concept art. The user's feedback:
- the faces are **too round** (ball heads);
- the two **look too similar**;
- they should look more **stylish, like in-game League of Legends characters**, while staying roughly based on the artwork.

User decisions:
- **LoL kid-champion proportions** (Annie or Tristana style): the head is about 1/4 of body height, longer legs, a sculpted face, chunky hands and boots.
- **Contrast through shape and palette:**
  - Leo is taller and leaner, with an angular face, a confident smirk, swept spiky hair and cool blue/teal colours.
  - Nela is tiny, with a soft heart-shaped face, a big cloud of curls with a bun, warm plum/pink colours and the lantern glow.
  - Leo's hair is darker sandy-gold; Nela's is pale honey.

The existing pipeline is kept and extended:
- `art/characters/chibi.py` (the kit);
- `leo.py` and `nela.py`;
- `lib/paint_bake.py`;
- `QUICK=1` previews and the sheet script.

## Approach

### 1. Longer rig, same animations (`chibi.py`: `load_rig(proportions)`)
- In edit mode, scale bone **lengths** without changing directions:
  - legs about 1.3× (upperleg/lowerleg);
  - spine/chest about 1.12×;
  - arms about 1.1×.
- Children are shifted along, and the IK/control bones follow their targets.
- Actions are rotation-driven. Hips location keys are scaled by the leg factor, so the feet still touch the ground.
- Per-character factors:
  - Leo: legs 1.35, spine 1.15;
  - Nela: legs 1.1, spine 1.05, so she stays a toddler.
- All body coordinates in the scripts are derived from bone positions (`bone_points`), not hard-coded z values. This way the clothing follows the new rig.
- **Validation:** render Idle, Running_A, 1H_Melee_Attack_Chop, Spellcast_Shoot, PickUp and Death_A. Check for foot sliding or ground penetration, and fix the hips offset if needed.
- **Fallback if clips break:** keep the original rig and get the proportions by shrinking the head instead.

### 2. Sculpted heads instead of ellipsoids
- A new `sculpt_head(spec)` in `chibi.py` builds the head from fused primitives (cranium, cheek pads, jaw or chin wedge, brow ridge), voxel-remeshes it, then applies smooth per-vertex shaping:
  - lower-face taper to a chin;
  - flattened sides and back;
  - a slight forward chin.
- **Leo:** a narrower, longer face; a defined square-ish chin; cheekbones; a straight nose bridge wedge; ears slightly pointed back.
- **Nela:** a wide forehead; soft chubby cheeks narrowing to a small pointed chin (heart shape); a button nose.
- **Decal projection:** `HeadFrame` keeps its (yaw, pitch) parameterisation, but places decals by **BVH ray-cast** onto the sculpted mesh (`mathutils.bvhtree`), along the ellipsoid normal, then lifts them by the offset. The eyes, brows and mouth keep working on any head shape.

### 3. LoL-style faces
- **Eyes:**
  - smaller and almond-shaped, with an iris covering most of the eye;
  - a thick, dark, tapered upper lid and a thin lower lid;
  - a painted iris gradient and a single highlight.
  - **Leo:** eyes tilted slightly upward at the outer corners, with confident, angled brows.
  - **Nela:** rounder, bigger eyes with lash flicks and raised happy brows.
- **Mouths:**
  - **Leo:** an asymmetric smirk-grin, opening on one side.
  - **Nela:** an open laugh.
- **Cheeks and nose:** a nose shadow and a cheek blush painted in the head colours. Freckles only on Leo.

### 4. Hair: big sculpted LoL clumps
- A new `hair_clump(root, path, width, thickness)`: a flattened, tapered ribbon-tube with a sharp tip. The strand streaks and a painted **sheen band** go in `hair_colour`.
- **Leo:** 8–10 large swept spikes flowing to his right from under the backwards cap, with a strong flipped fringe (Ezreal-like), sides tight, and a short nape. The cap is refit to the new head: a snug crown, a larger curved brim and a visible snapback strap with hair poking through.
- **Nela:** a big rounded cloud silhouette, built as a curl-cluster shell (fused spheres, voxel-remeshed), plus curl clumps ending in spirals, a top bun with a pink scrunchie, and a few flyaways. Her head plus hair reads about 1.5× wider than Leo's.

### 5. Bodies and outfits (from the artwork, exaggerated)
- **Leo:**
  - tapered torso with slightly broad shoulders;
  - tee with a folded sleeve cuff and a chest badge;
  - longer board shorts with a stripe band;
  - knee pads of skin with a painted scuff, chunky boots at 1.2× (LoL big feet), big mitten hands with separated thumbs;
  - backpack enlarged above the shoulders, with the bedroll strapped on top;
  - the stick is longer and knottier and gets a carved tip.
- **Nela:**
  - pear silhouette: short torso, round belly;
  - puffy harem pants with bold folk bands and gathered cuffs;
  - the bunny plush is bigger and more visible;
  - a larger lantern with a stronger glow.
- **Palette contrast:**
  - Leo: blue/teal/navy with lime accents;
  - Nela: plum/magenta/pink with cream.

### 6. More painterly texture (`paint_bake.py`, new optional params)
- `foot_darken`: a vertical gradient that darkens toward the feet, which is typical of LoL textures.
- `cavity`: a stronger cavity/fold darkening.
- `hair_sheen`: handled per mesh through the colour functions.
- Characters use a higher light/shadow contrast and a warm rim.
- The head keeps its own 1024 px texture.

### 7. Game integration
- Scales in the scenes (`PlayerBoy.tscn`, `Sibling.tscn`, `title_backdrop.gd`):
  - Leo about 0.62 (he is now taller in model units);
  - Nela about 0.6.
  - Tune them so on screen Leo is about 1.35× Nela's height.
- Update the HP bar heights: `companion_controller.gd` `HealthBar3D.attach(self, 2.3…)`, the player equivalent, and Sibling's LanternLight.
- Re-render the portraits (`tools/render_icons.gd`, with new raise/distance values).
- Keep the triangle budget at or below about 25k per character. Decimate the hair clumps.

## Critical files
- `art/characters/chibi.py`: `load_rig` proportions, `sculpt_head`, ray-cast `HeadFrame`, the eye/mouth styles, `hair_clump`.
- `art/characters/leo.py`, `art/characters/nela.py`.
- `art/lib/paint_bake.py`: optional `foot_darken` and `cavity`.
- `game/scenes/player/PlayerBoy.tscn`, `game/scenes/companions/Sibling.tscn`, `game/scripts/ui/title_backdrop.gd`.
- `game/scripts/companions/companion_controller.gd` and the player HP bar height.
- `game/tools/render_icons.gd`.
- Docs:
  - `.features/009-lol-restyle/*`;
  - version 0.5.0-playtest1.

## Verification
1. **Fast loop** with `QUICK=1` previews and sheets (T-pose, face close-up, back, Idle, Run, attack) for each iteration. Compare side by side with the concept art and against each other: distinct silhouettes and faces.
2. **Full bake**, then the animation check: 6 clips × 2 characters, for skinning, ground contact and the effects of the rig stretch.
3. `tools/check.sh` is green.
4. **Xvfb screenshots** (title, day, night) confirm on-screen readability, size contrast, and HUD portraits.
5. **Export:** `tools/export_playtest.sh`. The self-test passes and both split zips stay under 30 MiB.
6. **Ship:** commit, push, and send the preview sheets, screenshots and zips.
