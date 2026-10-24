# 07: Mum's dawn note found without the HUD

Status: done
Blocked by: 05

**What to build:** the run's own dawn handling picks the dawn beat and records its journal page through the profile. The HUD is handed the beat to show and records nothing, so Mum's dawn notes are found whether or not a HUD is in the scene. The winning dawn still shows the ending book rather than a dawn beat.

- [x] Smoke: a dawn with no HUD in the scene finds that dawn's note as a journal page.
- [x] Smoke: with the HUD, the dawn card still shows and the page is found once.
- [x] `tools/check.sh` passes.

## Comments

- 2026-10-24: done. `GameManager._on_dawn_started` picks the dawn beat
  (from `RunSession.config.chapter`), finds its notes through
  `Journal.find_notes_on` (so `Profile.find_page`), and emits the new
  `GameManager.dawn_beat_played(beat)`; the winning dawn returns first,
  so it plays no dawn beat. The HUD only shows the card it is handed.
  `Profile` gained a `page_found(id)` signal (emitted when a page is
  new), which the smoke check counts. Checks in
  `game/tests/automated/scenarios/dawn_notes.gd`.
