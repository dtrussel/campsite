# 05: Walk and run

Status: done (open: the user's visual sign-off)
Blocked by: 04 (the clip pipeline is from 03; 04 only orders the rebuilds of the kids' committed models)

**What to build:** new walk and run cycles that keep the feet planted. Leo and Nela share the cycles, varied by the style knobs: Leo bouncy and eager, Nela lighter and more careful. Leo gets his own run only if the knobs can't carry his personality. Each cycle is authored with a known stride length. The character visual scales walk playback by the hero's real speed, as it already does for the run, so the feet match the ground.

- [x] `walk` and `move` map to the new cycles for both kids. The stock cycles stay as a fallback.
- [x] Validate: foot slide per stride at each hero's speed is under the threshold, and both cycles wrap without a pop. Both checks are enforced for these clips.
- [x] The idle, walk and run blend still behaves as in feature 023, with upper-body actions while moving and the lean into turns. The footstep puffs still fire.
- [x] Contact sheets, GIFs and old-and-new in-game captures (walking and running past the camera) are under `## Comments` for sign-off.
- [x] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments

- **2026-10-25, done (open: the user's sign-off on the motion, from the captures below).** Two shared cycles in `hero_clips.py`, `Hero_Walk` and `Hero_Run`, keyed for both kids from their `Style` (no own run for Leo: the knobs carry him). `Walking_A` and `Running_A` stay in the models as the fallback.
  - **How the feet stay planted:** each kid's `Style` now has a `walk` and a `run` `Stride` (frames per cycle, stride in model metres). `cycle()` places each ankle frame by frame (planted, it moves back at exactly the ground's speed; swinging, it first only rises, then comes forward with no speed at either end, then only sets down), solves the leg to it (side-plane 2-bone IK refined in 3D), keeps the planted foot flat and keys every frame. The hips sit as high as the planted legs allow at 97% stretch; a swinging foot that would trail out of reach kicks up behind instead. No foot IK in the game.
  - **Sizes:** Leo walk 16 frames / 1.10 m (1.155 m/s in game), run 12 frames / 2.86 m (4.004 m/s); Nela walk 12 / 0.80 (1.04 m/s), run 10 / 2.56 (3.993 m/s). The runs match the 4 m/s move speed at 1x; the walks are authored at a natural kid cadence and play 1.39x (Leo) and 1.54x (Nela) at the 1.6 m/s walk blend point. Personality: Leo bounces and twists 25% more, swings his arms 15% more and leans in 3 deg; Nela bobs less, swings less, stands a degree back and keeps her lantern hanging steady (`hand_hold` 1.0; Leo's stick 0.5). Shared shape knobs are `WALK` / `RUN` (`Gait`).
  - **Stride matching in the game:** `CharacterVisual.walk_reference_speed` (from the new `HeroDefinition.walk_reference_speed`) and `walk_play_speed()` (clamped 0.5-2x; 0 = 1x, so a stock walk and every non-hero plays as before). `locomotion_play_speed()` mixes idle (1x), walk and run scales by their blend weights, replacing the old run-only lerp. The clip record now carries each cycle's `stride`, and the validator fails if `walk_reference_speed` / `reference_speed` differ from stride x model scale / length by more than 0.01 m/s (`ClipChecks.stride_problems`). `step_distance` is now half a stride (Leo 1.0, Nela 0.83).
  - **Checks:** `check_hero` measures the walk at its stride-matched play speed and the run at both roles' speeds (the worse counts). Enforced for both kids' walk and move: loop and slide. Numbers: Leo walk 0.9 cm slide / 0.1 deg pop, run 1.9 cm / 0.0; Nela walk 0.9 cm / 0.0, run 1.3 cm / 0.1 deg (baseline was 22-43 cm slides and 3-9 deg pops). Unit tests: `test_stride_matching.gd` (new) and three in `test_clip_checks.gd`; the chapter_1 smoke checks the run plays at about 1x while Leo runs. Layering (upper-body swing while running), the lean and the footstep puffs pass as before.
  - Tris unchanged (Leo 34,999, Nela 35,711). `tools/check.sh`: validate OK (hero clips 30 checks, 0 over), unit PASSED (78), smoke PASSED in both passes, selftest OK.
  - **For sign-off** (in `../captures/`): clay `05-<kid>-<walk|run>-clay-34.png/.gif` and `-clay-side.png/.gif` (travelling over half-metre squares at game speed); in game `05-<kid>-<walk|move>-<player|companion>-old-vs-new.png` (old on top, captured before the rebuild) and `05-<kid>-<walk|move>-player-old.gif` / `-new.gif`.
- **2026-10-26, review:** status set to `done (open: the user's visual sign-off)`: the captures above await the user's sign-off.
