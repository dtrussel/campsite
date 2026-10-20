# Feature 044: Playtest 1 fixes (plan)

Status: **done**. Rough size: **L**.

## Goal
Act on the first round of user-test feedback (2026-10-18):

1. The intro story only played on the first game.
2. Nela got stuck behind a prop on the Guard task and could no longer help.
3. Too many resources to keep track of.
4. Movement and fights too fast; the day/night cycle too short.
5. The hero should attack a nearby enemy on its own.
6. Zooming in should also lower the camera angle.
7. The blur is too strong.
8. Buildings just appear; the hero should build them.

## Decisions taken with the user
- Resources: keep 6 raw ones (wood, stone, berries, clay, scrap, glow shards).
- Building: the hero walks to a blueprint and hammers it up.
- Pacing: moderate (about 20% slower moves, ×1.25 cooldowns, 200 s days, 120 s nights).

## Scope
- **Intro:** `GameManager.begin_chapter` plays the intro on every new game. Esc skips it, and Continue and Restart never show it.
- **Companion:** every task walks on the nav mesh (`NavSteer`). A watchdog re-paths and sidesteps after 1 s without progress, and hops her to open ground after 3 s.
- **Resources:**
  - Fiber, leaves, resin and mushrooms are removed.
  - Their recipes and costs are rewritten.
  - Pines give wood, and mushroom patches become scenery.
  - Save VERSION 2.
- **Pacing:** the values live in `TimeManager`, the hero and mob `.tres` files and `MobSpawner`. HP and damage are unchanged.
- **Auto-attack:** handled in `PlayerController._tick_auto`, with a pause-menu switch (`GameSettings`).
- **Camera:** `CameraFollow` lerps the pitch from 42° to 28° and lifts the aim by up to 0.8 m between zoom 1.0 and `min_zoom`. The tilt-shift band follows.
- **Blur:** `PostFx` levels Off / Soft / Strong. The shader defaults are Soft.
- **Construction:**
  - Placed buildings are blueprints (`Building.build_progress`); subclasses switch on in `_on_built()`.
  - The hero has a BUILD command and auto-takes the oldest blueprint. The companion builds on Repair.
  - XP is given on completion, and an unstarted blueprint refunds when removed.
