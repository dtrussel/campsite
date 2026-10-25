# 01: Clip checks and review captures (baseline)

Status: done
Blocked by: none (can start immediately)

**What to build:** the yardstick for the rest of the feature. The validator measures every hero clip as data (foot slide, loop wrap and action durations) and reports the numbers for today's stock clips, warning but not failing. An art contributor can render clay contact sheets and GIFs of any kid clip from the game camera without launching the game. A capture scene records a hero playing a list of states in the game, so old and new can be shown side by side.

- [x] Validate: for Leo and Nela, every mapped state has a clip. Looping clips (idle, walk, run) report their first-to-last pose difference. Walk and run report foot slide per stride at the hero's speed, sampling the foot bones against the distance the root travels. Action clips report their length at their gameplay play speed.
- [x] Each check has a threshold and a per-clip switch from "report" to "enforce". Every stock clip starts on "report", so `tools/check.sh` stays green.
- [x] The art side: one command renders a contact sheet (frames in a strip) and a GIF of a named clip for a named kid, in clay, from the game camera's angle.
- [x] The capture scene: one command records a hero in the game playing the listed states, in both roles' poses, and writes PNG strips or a GIF that can be put next to another capture.
- [x] The baseline (today's slide, loop and duration numbers per clip) is written under `## Comments`, with the stock contact sheets.
- [x] `art/README.md` and `docs/testing/test-strategy.md` say how to run the renders, the capture scene and the clip checks.
- [x] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments

- **2026-10-25, implemented** (branch `hero-anim-01-clip-checks`):
  - **Validator:** `game/tools/clip_checks.gd`, called by
    `validate_project.gd`. Every mapped state must have its clip (always
    enforced). Loop, slide and duration checks report; the per-clip
    switch is `ENFORCED` in that file (hero -> state -> checks), and the
    limits are its constants (loop 1 cm / 3°, slide 4 cm a stride,
    duration ±0.05 s from `ACTION_SECONDS`). `tools/check.sh` shows one
    summary line; `res://tools/validate_project.tscn -- --clips` prints
    every number. Unit tests: `game/tests/unit/test_clip_checks.gd`.
  - **Contact sheets:** `.venv-blender/bin/python art/review/clip_sheet.py <kid> <state|clip>`
    renders a clay strip and GIF from the game camera's pitch, walking
    and running over a checked ground at the game's speed.
  - **In-game capture:** `xvfb-run -a godot --path game --resolution 320x180 --fixed-fps 30 res://tools/hero_capture.tscn -- <out_dir> <hero> [state ...]`
    writes a PNG strip per state as the player and as the companion
    (`--all-frames` for a GIF, `--stack <old> <new> <out>` to compare).
  - **Baseline** (stock clips; the same clips for both kids except the
    attack, so most numbers differ only by model scale):

    | Hero | State (clip) | Loop pop | Foot slide / stride | Length at play speed |
    |------|--------------|----------|---------------------|----------------------|
    | Leo | idle (Idle) | 0.1 cm, 0.2° | | |
    | Leo | walk (Walking_A) | **2.1 cm, 8.6°** | **22.4 cm** at 1.6 m/s, 1x | |
    | Leo | move (Running_A) | **1.1 cm, 3.3°** | **14.1 cm** at 4.0 m/s, 0.60x | |
    | Leo | attack (1H_Melee_Attack_Chop) | | | 0.694 s at 1.5x |
    | Nela | idle (Idle) | 0.0 cm, 0.2° | | |
    | Nela | walk (Walking_A) | **1.4 cm, 8.6°** | **43.4 cm** at 1.6 m/s, 1x | |
    | Nela | move (Running_A) | 0.7 cm, **3.3°** | **21.6 cm** at 4.0 m/s, 0.66x | |
    | Nela | attack (Spellcast_Shoot) | | | 0.611 s at 1.5x |
    | both | hit (Hit_A) | | | 0.476 s at 1.4x |
    | both | death (Death_A) | | | 0.792 s at 1x |
    | both | getup (Lie_StandUp) | | | 2.333 s at 1x |
    | both | cheer (Cheer) | | | 1.389 s at 1.2x |
    | both | gather (Interact) | | | 0.994 s at 1.3x (the companion's) |
    | both | chop (1H_Melee_Attack_Chop) | | | 0.694 s at 1.5x |
    | both | pick (PickUp) | | | 0.861 s at 1.5x (1.6x as the build beat's fetch) |
    | both | tinker (Use_Item) | | | 0.990 s at 1.6x |
    | both | hammer (2H_Melee_Attack_Chop) | | | 0.903 s at 1.8x |

    Bold is over its limit: 8 of 30 checks. Walk slides most: the stock
    walk's planted foot sweeps back at about 1 m/s while the walk blend
    plays it at 1.6 m/s. The slide reads the ankle, so a foot that stays
    flat longer (Nela's walk) counts a longer stance.
  - **Stock contact sheets:** `../baseline/<kid>_<clip>.png` (8 frames
    each, from the game camera's pitch, turned 35°).
