# Feature 012: Leo and Nela back on the concept art (faces first)

## Context
The two attached sheets are the original concept art: `leo.py` and `nela.py` still quote them in their docstrings. Features 010 and 011 moved the kids toward Ekko and Annie:
- **Leo** got teal cheek marks, a kerchief, arm wraps, fingerless gloves, shin wraps, a knee pad and a mohawk quiff.
- **Nela** got a pink tee, a plum pack, pink laces, leg warmers, smoky eyeshadow, a blunt fringe and pigtails.

The user now wants the artwork to be the primary reference, with the faces as the top priority. The LoL in-game look should come from these, not from champion cosplay:
- proportions and silhouette;
- darker, higher-contrast hand-painted textures;
- clean, deformation-friendly, game-ready meshes.

**User decisions:**
- Remove the Ekko/Annie add-ons and match the artwork.
- Full scope: models, portraits, checks, version bump, then commit and push to `ccr-10877e76-2578j9`.

**Improve, don't restart.** The existing pipeline is used as-is:
- `chibi.sculpt_head` / `sculpt_features` for the head and relief;
- `face_paint.FaceLayout` + `paint_face` for the painted face;
- `paint_bake.paint` for the painted look (`key_light`, `cavity`, `overlay`, `foot_darken`);
- `chibi.Proportions` for proportions;
- `chibi.hair_clump` / `sweep` for hair;
- `chibi.boot`, `bedroll`, `rope_coil`, `compass`, `straps` for gear.

Changes go mostly into the two character scripts. Small, backwards-compatible additions go into `face_paint.py` and `chibi.py`, so the Shadow Imp stays untouched.

## Setup
- `tools/setup_blender.sh` installs bpy 4.5.4 into `.venv-blender/`. PyPI is reachable.
- Copy both references into the scratchpad for the comparison sheets.

## 1. Faces (highest priority)
Match the art's faces in the `FaceLayout` and `FEATURES` values and the `sculpt_head` arguments.

**Leo (~7), from the art:**
- **Face shape:** a rounder face with full cheeks and a softer, shorter jaw. Lower `jaw`, `chin_len` and `cheekbone`; raise `cheeks`.
- **Eyes:** bigger, open, bright blue, looking up and to the side. Larger `eye_w`/`eye_h`/`iris_r` and a lower `lid` (no heavy lids). Upward `look`, with a strong catchlight.
- **Brows:** soft, raised, light brown. No cocked brow.
- **Nose:** a small upturned button nose, with a smaller `nose` relief.
- **Mouth:** a wide, open, happy grin with a hint of teeth and a slight lopsided lift. No smirk.
- **Skin detail:** freckles across the nose bridge and cheeks, a warm sun-flush on the cheeks and nose, and ears that stick out a little.
- **Removed:** the teal marks and the eyeshadow.

**Nela (~3), from the art:**
- **Face shape:** a toddler face with a big round cranium, very full low cheeks, a tiny chin and a short midface (the eyes sit low on the head).
- **Eyes:** huge, round, deep blue, with a big iris and two catchlights. No smoky shadow and no wing. A light lash line only.
- **Brows:** faint, soft and high.
- **Nose:** a tiny button.
- **Mouth:** a wide, open laughing smile with the upper teeth showing and a pink tongue hint.
- **Skin detail:** a strong rosy blush and sparse freckles.

**`face_paint.py` additions** (optional args, so the existing defaults are unchanged):
- an open-mouth fill (dark inner, teeth band, tongue) so the grins read;
- a second catchlight;
- a nose-tip and cheek sun-flush.

**Sculpt:** tune `FEATURES` for softer child relief: a shallow brow ridge, a small nose, full cheek/apple volume and a small chin. Keep the paint and the relief driven by the same `FaceLayout` so they stay aligned.

**Hairline:**
- **Leo:** messy blond clumps spilling out from under the cap front and over the ears, a few strands on the forehead, and an uneven tousled fringe. This replaces the tall mohawk quiff.
- **Nela:** a wild wavy mane with face-framing locks, a small messy top bun/ponytail with a purple tie, and loose flyaways. This replaces the blunt fringe and pigtails.

## 2. Proportions and silhouette (LoL-style, age-true)
- **Leo:** head about 1/5.5 of his height, so he reads as ~7. Slightly lower the legs, spine and arms stretch factors from 1.85/1.3/1.25 as needed. Keep big hands and big boots, a readable pack and a stick taller than his shoulder.
- **Nela:** head about 1/3.2. A rounder toddler belly, short chubby limbs and big boots. The bunny head stays visible over her shoulder, and the lantern stays a strong silhouette accent.
- **Checks:** the silhouette is checked on the black-fill preview at game zoom, and `chibi.report` keeps the triangle counts at or under 12k per character.

## 3. Outfits and gear (match the artwork)

**Leo (`leo.py`):**
- **Removed:** `accessories()` (kerchief, wraps, band, knee pad), the gloves (hands become skin) and the shin wraps.
- **Tee:** light blue, with the circular camp logo badge (trees and mountains).
- **Shorts:** teal-blue with two diagonal lime/green stripes and cargo pockets with flaps.
- **Legs and boots:** grey socks, and navy hiking boots with tan soles, orange laces and a lime tab.
- **Cap:** a navy backwards cap with a camo under-brim.
- **Pack:** a green-camo pack with brown leather straps and buckles, a navy bedroll on top, a steel bottle with the mountain logo, a rope coil and a red carabiner.
- **Compass:** a brass compass on a cord.
- **Stick:** twine-wrapped, with leaves.

**Nela (`nela.py`):**
- **Top:** a light-blue tee with painted dirt smudges, in place of the pink tee.
- **Pants:** purple/magenta harem pants with a cream folk (diamond/zigzag) pattern, gathered cuffs and a cargo pocket.
- **Legs and boots:** cream socks, and brown leather work boots with tan laces. The leg warmers and pink laces go.
- **Pack:** an olive/green pack with brown leather straps and brass buckles, in place of the plum pack. It carries a green bedroll, a knotted purple scarf, a leaf sprig and the compass hanging on the pack.
- **Bunny:** the cream patched bunny peeks from the pack.
- **Wrists:** leather bracelets on both.
- **Lantern:** the glowing bronze lantern stays.

## 4. Materials and paint (darker, richer, higher contrast)
- **Palette:** push all palettes darker and more saturated. For example, the navy, teal and camo go deeper, the purple richer, and the leather is dark brown with warm edge highlights.
- **Bake:** use the existing `paint_bake.paint` params with stronger contrast settings:
  - higher `key_strength`, `ao_strength` and `cavity`;
  - a cooler, deeper `shadow`;
  - `foot_darken` about 0.5.
- **Painted fabric detail**, in the `color_by` functions, which are cheap and bake straight into the texture:
  - fold streaks at the elbows, waist, crotch and knees;
  - dashed stitch lines along seams and hems;
  - worn/lighter edges and dirt/scuff noise toward the knees, shins and boots;
  - Nela's shirt smudges;
  - scuffs and knee grime on Leo.
- **Hair:** stronger light-to-dark strand banding, and a darker root shadow under the cap and bun.

## 5. Topology and game-readiness
- **Clothing:** keep the fused, voxel-remeshed, auto-weighted clothing and rigid gear on single bones, as now.
- **Head:** keep enough edge loops at the mouth and eyes (the `sculpt_head` segs) for the relief. Bump them if the grin needs it, within budget.
- **Test poses:** render Idle, Running_A, the attack, PickUp and Death_A in `QUICK=1` mode to catch deformation problems at the shoulders, hips and knees, and cap/hair clipping.

## 6. Iteration loop and review
1. Run `QUICK=1 .venv-blender/bin/python art/characters/leo.py` (and the same for `nela.py`) for fast shape passes.
2. After each pass, build side-by-side sheets with PIL: reference crop | our front 3/4 | face close-up | back. Review the likeness of the face first, then the silhouette, then the colours.
3. Run the full bakes with `tools/build_art.sh characters/leo characters/nela`.
4. Send the final comparison sheets to the user.

## 7. Game integration and shipping
- **Scales and HP bars:** re-check the model scale, the HP bar height, `reference_speed` and the Sibling label/light if the heights change. The files are `game/scenes/player/PlayerBoy.tscn`, `game/scenes/companions/Sibling.tscn`, `player_controller.gd`, `companion_controller.gd` and `title_backdrop.gd`.
- **Portraits:** re-render them with `game/tools/render_icons.tscn`.
- **Docs:** write `.features/012-concept-art-faces/{plan,status,handoff}.md`, update the character rows in `art/README.md`, and bump the version to `0.9.0-playtest1` in `game/project.godot` and the README.

## Critical files
- `art/characters/leo.py`, `art/characters/nela.py`: most of the work.
- `art/characters/face_paint.py`: open-mouth, catchlight and flush options.
- `art/characters/chibi.py`: only small optional-arg additions if needed.
- Outputs: `game/assets/custom/leo*.{glb,png}` and `nela*.{glb,png}`, plus the portraits.

## Verification
1. The comparison sheets (reference vs model: face close-up, full body, back) look right at each iteration. The final sheets are shared with the user.
2. Triangle counts are at or under 12k per character, and the animation-frame renders show no bad deformation or clipping.
3. `tools/check.sh` is green, if Godot is available here. If it isn't, report that and at least validate that the GLBs import in Blender.
4. Game screenshots at play zoom, where Godot/Xvfb is available, for readability.
5. Commit and push to `ccr-10877e76-2578j9`. No PR unless asked.
