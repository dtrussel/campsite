# 06: Idles and fidgets

Status: done (open: the user's visual sign-off)
Blocked by: 05 (the clip pipeline is from 03; 05 only orders the model rebuilds)

**What to build:** each kid's own idle, and 2–3 idle fidgets each, such as looking around, scratching, stretching or checking their tool. A kid standing still plays a fidget now and then. The fidget never plays while moving, during an action, or while down. Hero select shows the new idle and fidgets.

- [x] `idle` maps to each kid's own clip. The fidgets are listed on each hero's data.
- [x] Unit: the fidget scheduler waits a random interval in a set range, picks no fidget twice in a row, and fires only while the hero is idle.
- [x] Validate: the idles wrap without a pop (enforced).
- [x] Smoke: a hero left idle plays a fidget within the range, and moving cancels it back to locomotion.
- [x] Contact sheets, GIFs and in-game captures (including hero select) are under `## Comments` for sign-off.
- [x] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments

- **2026-10-25, done (open: the user's sign-off on the motion, from the captures below).** Each kid has their own idle and three fidgets, keyed in `hero_clips.py` (`OWN`) and rebuilt into both models; the stock `Idle` stays in the models as the fallback.
  - **Clips:** `Leo_Idle` (32 frames, 1.33 s: a springy knee bob twice a breath, weight rocking foot to foot, head up and looking about) with `Leo_Look` (shades his eyes and scans left and right, 2.5 s), `Leo_Scratch` (head tipped, scratching it, 2.1 s) and `Leo_Stick` (lifts his stick in front, turns it over to look along it, plants it with a tap, 2.2 s). `Nela_Idle` (48 frames, 2 s: slow breath, gentle sway, a listening tilt, the lantern hanging still) with `Nela_Look` (lifts the lantern and peers left and right, 2.75 s), `Nela_Stretch` (free arm up, back arched, a little shake, 2.4 s) and `Nela_Hair` (tucks her hair behind her ear, 1.9 s). Everything starts from the stock Idle's first pose in the kid's posture; the legs are re-solved every frame so the feet stay planted (ankles move at most 0.1 cm), hands are placed with a small damped-least-squares arm solver, Nela's wrist holds the lantern's Idle angle, and each fidget starts and ends on the kid's idle frame 0.
  - **Game:** `HeroDefinition.fidgets` lists the fidget states (each mapped in `clips`); HeroBody and the hero select stage copy them to `CharacterVisual.fidgets`. The new `FidgetScheduler` waits 6-12 s of standing idle (random), never picks the same fidget twice running, and never fires while moving, in an action or down (the wait starts over after each). The visual plays the fidget on the whole body; moving fades it straight back to locomotion, and any other action replaces it. A fidget doesn't count for `is_in_action()`, so a hit, a gather or a turn is never held up by one. The wait pauses during a hit-stop, like the rest of the pose.
  - **Checks:** validator enforces the idle loop for both kids (both wrap at 0.0 cm / 0.0 deg) and fails a listed fidget that is not a mapped state. Unit: `test_fidget_scheduler.gd` (7 tests). Smoke (`hero_animation.gd`): Leo played and Nela as the companion each fidget after a wait in the range, and moving cancels a fidget back to locomotion. `hero_capture` now records the fidgets too. Tris unchanged (Leo 34,999, Nela 35,711).
  - `tools/check.sh`: validate OK, unit PASSED, smoke PASSED in both passes, selftest OK.
  - **For sign-off** (in `../captures/`): clay `06-<kid>-<idle|fidget-*>-clay.png/.gif`; in game `06-<kid>-idle-player-old-vs-new.png` (old on top, captured before the rebuild), `06-<kid>-idle-player-old.gif` / `-new.gif`, `06-<kid>-fidget-*-player-new.png/.gif`, and hero select `06-hero-select-old-vs-new.png` (top: before, six frames 1.5 s apart; below: after, twelve frames 1.1 s apart, where Leo shades his eyes and later scratches his head).
- **2026-10-26, review fixes:** the validator now also enforces each fidget's length (at 1x, against its authored length) and a `handoff` from and back to the idle's first pose (all six at 0.0 cm, 0.0 deg). Status set to `done (open: the user's visual sign-off)`.
