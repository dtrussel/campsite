# 01: An endless run that never ends in a win

Status: done
Blocked by: profile, run-lifecycle

**What to build:** once the true ending has been seen, the title offers **Endless**. An endless run starts as Chapter 2 with the Moon Lantern already lit, keeps going past night 7 with no win, and has no Moon-Eater. It is a separate `endless` flag, so the chapter logic, the HUD and end-screen moon rows, hero select's text and the Continue subtitle ("Night N") all still read sensibly. Shards still go to Glow Lanterns. Autosave and Continue work as in the story chapters.

- [x] Smoke: with the true ending seen, the Endless button appears; without it, it doesn't.
- [x] Smoke: an endless run passes night 8 without a win, and no Moon-Eater spawns.
- [x] Smoke: save and Continue in endless keeps the run endless.
- [x] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments

- **2026-10-21, architecture review:** now blocked by profile and run-lifecycle: declare the `endless` flag as run state through the run session.
- **2026-10-21, done:** `GameManager.endless` is run state: it rides on `RunConfig.endless`, `RunSession` sets it on start and from the save on Continue (saves without it are story runs), and the run fields save it as `"endless"`. `nights_to_win` stays 7, so `chapter()` is 2. In endless the dawn win check is skipped, the spawner has no boss night and no eyes, the Moon Lantern starts (and resets) fully lit so shards stay in the stash for Glow Lanterns, and the chapter intro is skipped (endless comes after the story). The title shows Endless once `TRUE_ENDING` is seen (the chapter buttons clear the flag); its Continue tooltip reads "Hero - Endless, night N"; hero select reads "Endless: how long can you last by the campfire?". The HUD and end screen still show 7 moons / stars (all lit past night 7); the end screen's record is ticket 03. Smoke: `_run_endless_scenario`.
