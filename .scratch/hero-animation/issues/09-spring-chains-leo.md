# 09: Spring chains: the modifier and Leo

Status: done (open: the user's visual sign-off)
Blocked by: 01, 08 (08 only orders the model rebuilds)

**What to build:** Leo's hair and backpack (and any other part on his turnaround sheet that visibly hangs or sticks out) lag, swing and settle when he turns, stops or gets hit. The kid kit adds short chains of 2–3 bones for those parts and weights the parts to them instead of binding them rigidly. No clip keys the new bones. A spring-chain `SkeletonModifier3D`, owned by the character visual, moves each chain with stiffness, damping, gravity and a reach limit, tuned per chain on the hero's data.

- [x] Leo's model has the chains, and every existing clip still plays correctly.
- [x] The modifier works for the player's hero, the companion and hero select.
- [x] Smoke: after a sudden 180° turn, a chain's tip moves away from its rest pose and settles back within a time limit.
- [x] Leo stays within the hero triangle budget.
- [x] In-game captures (turning, stopping, getting hit) are under `## Comments` for sign-off.
- [x] `art/README.md` describes the spring bones.
- [x] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments

- **2026-10-26, implemented** (branch `hero-anim-09-spring-chains`). Built; the user's visual sign-off of the captures below is the one open item (hence `ready-for-human`).
  - **Model.** `chibi.add_chain` / `chibi.weight_along` (the kid kit) and `CHAINS` in `leo.py`: five chains of two swinging bones plus a non-deforming `.end` tip each: `hair.front` (the fringe), `hair.back` (the nape tufts), `hair.l` / `hair.r` (the side tufts), parented to `head`, and `pack` on `chest`. Hair locks weight along their own centre lines; the bag, bedroll, bottle and rope along the pack chain's joints; the harness (shoulder straps, sternum strap, compass) stays on the chest. The cap and hair shell stay rigid on the head. Leo is still 34,999 tris; the GLB grew 5.8 -> 6.6 MB (the exporter writes constant rest tracks for the new bones in the clips).
  - **Game.** `SpringChain` (bones, stiffness 1/s^2, damping 1/s, gravity, `max_degrees` reach limit) on `HeroDefinition.spring_chains`, copied by `HeroBody` and `hero_stage.gd` to `CharacterVisual.spring_chains`, which adds a `SpringChainModifier` (after the head look-at, so the hair follows the turned head). It simulates each bone's far end in world space at a fixed 1/120 s step (at most 0.25 s per frame), keeps it at the bone's length and within the reach limit, and turns the bone toward it. Leo's tuning: hair 220-320 / 9-12 / 25-35 deg, pack 110 / 7 / 14 deg, no gravity (the clips already hang them).
  - **Hit-stop:** chosen on purpose that the chains hold still through a hit-stop (`SpringChainModifier.paused`), like the rest of the pose, and swing on from there.
  - **Checks.** Smoke (`hero_animation.gd`, "spring chains"): Leo in both roles and on hero select, a sudden 180-degree turn swings a tip > 4 cm from its animated place (about 17 cm) and it settles within 2.5 s to < 2.5 cm. Validator (`_validate_hero_models`): each hero's model is within the 40k budget, and each chain's tuning is sane, its bones exist, each the child of the one before, and no clip moves them. `tools/check.sh` green (validate OK, unit 86, smoke and stalled smoke PASSED).
  - **Captures** for sign-off (player role, old = before the chains, new = with them; GIFs side by side at game speed): `captures/09-leo-turn-old-vs-new.{png,gif}` (running, a sudden turn back), `captures/09-leo-stop-old-vs-new.{png,gif}` (running, then standing), `captures/09-leo-hit-old-vs-new.{png,gif}`. `hero_capture.tscn` gained the `turn` and `stop` motions for these. The pack's swing reads clearly; the hair's is small at game size.
- **2026-10-26, review:** status set to `done (open: the user's visual sign-off)`: the captures above await the user's sign-off. The smoke turn check now reads the peak swing over every simulation step (`CharacterVisual.spring_swing_peak()`), as one long frame can swing a chain out and back before it ends (CI's stalled pass read 0.027 m for Mum at the frame's end).
- **2026-10-26, stalled-pass settle:** `SpringChainModifier.MAX_FRAME_SECONDS` is now 1 s (was 0.25 s). A long frame jumps the clip ahead by the whole frame, and a chain that simulated only 0.25 s of it was left lagging its animated place for the frames after, so the stalled smoke pass read a resting chain at 2.2-2.7 cm against the 2.5 cm "settled" limit (it failed "hero select: and it settles back" at 0.027 m). Simulating the whole hitch brings the resting reading in that pass to 0.2-1.7 cm.
