# Feature 026: Bramble Beast remodel and animations

Reference: [`reference/concept.png`](reference/concept.png) (front 3/4,
side and back views supplied by the team).

## Goal

The feature 018 Bramble Beast is a blobby metaball body with floating
eyes, and it borrows the Skeleton Minion's generic clips (a one-hand
punch, a skeleton walk). This feature rebuilds it to match the concept
art and gives it its own heavy animations, so it reads as the big,
slow, building-smashing tree golem it is in gameplay.

## Current state

- `art/characters/bramble_beast.py`: metaballs along the Skeleton
  Minion bones, voxel-remeshed and decimated to 4.2k triangles, with
  vertex-colour paint baked at 1024 px. The extras are 32 small thorns,
  two moss tufts, three leaves and two orange eye spheres that sit in
  front of the face.
- `BrambleBeast.tscn` maps its clips to KayKit clips:
  - idle: `Idle_Combat`;
  - move: `Walking_D_Skeletons`;
  - attack: `Unarmed_Melee_Attack_Punch_A`;
  - hit: `Hit_B`;
  - spawn: `Skeletons_Awaken_Floor`;
  - death: `Death_C_Skeletons`.
- The GLB carries all 95 rig clips, although only 6 are used.
- The attack deals damage on the first frame of the swing, so it gives
  no warning (`mob_controller.gd`, `_try_attack`).

## Part A: model (matching the concept)

The model is rebuilt with the imp's feature 022 method: a dense sculpt
carries the paint and is baked onto a game mesh (`paint_bake.paint(...,
high=...)`, `chibi.lowpoly`, and `HIGH_POLY=1` for review).

**Silhouette.** The concept's defining shape is a narrow waist between
huge shoulders and giant log fists.
- Broad, rounded shoulder masses and a chest that tapers to a narrower
  waist and hips.
- Long arms. The forearms swell into huge log-club fists that hang
  near knee height. The rig's arm bones are lengthened in edit mode with
  a helper like `chibi.stretch_rig`. The clips are rotation-based, so
  they follow the new lengths.
- Short, thick trunk legs that flare at the feet into three or four
  splayed root toes each.
- No separate head blob. The face is carved into the top of the trunk
  and sits between the shoulders.

**Face** (the biggest readability gain):
- a heavy, angry brow ridge;
- two slanted almond eye sockets with the glowing eyes set inside them
  (warm yellow-white as in the concept, instead of today's orange);
- a wide carved grin in darker bark.

The eyes stay a separate emissive mesh, placed by raycast onto the face
surface, the same fix that stopped the imp's tuft from floating.

**Bark paint:**
- vertical grain streaks and a V-shaped grain on the chest and back;
- knots, and end-grain spiral rings on the fists and shoulder caps;
- darker grain in the crevices from the AO and edge terms of the bake.

**Moss mantle.** A ragged green cape over the crown, shoulders and upper
back, with dripping, jagged edges. It is painted from a noise mask by
height and facing, plus a thin shell of hanging moss strands at the
edge. Smaller moss patches sit on the knees, the feet and the tops of
the fists.

**Extras.** All extras are rigid, weighted 100% to one bone.
- **Twig antlers:** two branching horns on the head, built with
  `curved_tube`.
- **Leaf crown:** five or six broad leaves with a midrib, one of them
  autumn orange, fanned on the crown.
- **Berry cluster:** red-orange berries with a few leaves on the right
  shoulder, as a colour accent.
- **Thorns:** fewer and bigger. Five or six large cones along each
  shoulder and forearm ridge, and a few on the back, replacing the 32
  small ones.
- **Vines:** a vine wrapping each forearm and one running diagonally
  across the torso, with small leaves.

**Budgets:**
- body game mesh about 9k triangles, 12k at most with the eyes;
- bake at 1024 px, WebP like the kids if the PNG is too large.

**Review:** Blender previews in front 3/4, side and back views (the
concept's three views), clay renders for form, and an in-game Xvfb
screenshot at gameplay zoom beside Leo for scale.

## Part B: custom animations

A new `art/characters/beast_anims.py` keyframes the rig's pose bones in
Blender, like the rig-edit work in `chibi.py`. The clips are exported
in the same GLB, and only the needed actions are kept, so the file drops
from 95 clips to about 8.

| Clip | Content |
|------|---------|
| `Beast_Idle` | Slow heavy breathing: shoulders rise, fists sway a little, the head turns a little. Loops. |
| `Beast_Walk` | A lumbering stomp: wide stance, the torso rolls side to side over each planted foot, the arms swing heavily and out of phase. Loops. The stride length sets `step_distance`, so the `step_thud` dust lands on each footfall. |
| `Beast_Slam` | A two-fist overhead hammer: about 0.55 s windup (fists raised, body arched back), impact (body crunched forward, fists on the ground), then about 0.5 s recovery. |
| `Beast_Hit` | A small, heavy flinch. It barely staggers (it is tanky). |
| `Beast_Spawn` | It pulls itself out of the ground: it starts sunk to the chest, heaves up and shakes, then gives a short arms-wide roar. |
| `Beast_Death` | It topples forward onto its fists and knees, then slumps. The last frame is held (`play_final`). |
| `Beast_Roar` | A chest-thump roar, played when it destroys a building. The clip is short and cosmetic, and the beast can still be interrupted during it. |

Motion principles:
- anticipation before every big move;
- the weight settles on the plant frames;
- the body lags behind the fists (overlap);
- nothing is snappy.

The clips are checked with filmstrips from `tests/sim/anim_frames`
(walk, slam, spawn, death) and Blender frame previews.

**Godot wiring:**
- `BrambleBeast.tscn` `clips` maps to the new names. `reference_speed`
  and `step_distance` are retuned to the new stride. `lean` stays small
  or off (it is heavy).
- **Telegraphed slam (small gameplay change):**
  - A new `MobDefinition.attack_hit_delay` (default 0.0, so imps and
    gremlins are unchanged); the beast's value is about 0.55 s.
  - `_try_attack` starts the slam, then applies the damage at impact,
    and only if the target is still valid and within `attack_range`
    plus a margin (buildings are always hit).
  - The cooldown and damage are unchanged, so DPS is almost the same,
    but the kids get a readable tell and can step away. This suits the
    target audience.
- **Impact feedback:**
  - a new `bramble_slam` Fx burst (a dust ring and wood chips) with a
    small camera shake near the camp;
  - a new `bramble_slam` sound in `art/audio/sfx.py` (a low wooden
    thud with a crunch), needed because the validator requires a sound
    for every burst;
  - optionally a `bramble_roar` sound for the roar and spawn.

## Tests

- **Smoke:**
  - the beast model has every clip named in `clips`;
  - the slam damage lands after `attack_hit_delay` and not before (a
    building's HP is checked at t=0 and after the delay);
  - a kid who steps out of range during the windup is not hit;
  - the existing beast scenarios (waves, building preference, death
    and drop) still pass.
- **Validator:** the `bramble_slam` burst has a sound.
- **Balance:** `tests/sim/balance_sim` run once to confirm nights 1–3
  outcomes barely move with the delayed hit.

## Files

- **Art:** `art/characters/bramble_beast.py` (rewritten),
  `art/characters/beast_anims.py` (new), `art/audio/sfx.py`, and
  `game/assets/custom/bramble_beast.glb` with its textures.
- **Game:**
  - `game/scenes/mobs/BrambleBeast.tscn`;
  - `game/resources/mobs/bramble_beast.tres`;
  - `game/scripts/mobs/mob_definition.gd`;
  - `game/scripts/mobs/mob_controller.gd`;
  - `game/scripts/utilities/fx.gd`;
  - the audio library entries.
- **Tests:** `game/tests/automated/smoke_run.gd`, plus a re-rendered
  beast portrait or icon if one exists.
- **Docs:** this folder, the roadmap, the art README and a version bump
  to 0.21.0-playtest1.

## Order of work

1. The model (Part A), iterating on previews against the concept.
2. The clips (Part B), iterating on filmstrips.
3. Godot wiring, the delayed slam, the burst and sound, and tests.
4. `tools/check.sh`, screenshots, docs, then commit and push.

## Risks

- **Rig proportions.** Lengthening the arms may push fists into the
  ground in some clips. The custom clips are authored for the new
  proportions, and none of the old KayKit clips are used any more.
- **The mantle and fists hide the face from the top-down game camera.**
  Check at gameplay zoom early and tilt the face or eyes up if needed.
