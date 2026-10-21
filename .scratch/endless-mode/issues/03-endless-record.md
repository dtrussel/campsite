# 03: Best-nights record

Status: done
Blocked by: 01

**What to build:** when an endless run ends, the best nights survived and the hero who did it are kept locally (in the profile, under an `endless.` key). The end screen shows "New record!" when it's beaten, and the title's Endless button shows the record. Then wrap up: screenshots, docs, and endless mode (042) set to done in the roadmap.

- [x] Smoke: a loss on night 9 records 9 nights and the hero, and the record survives a restart.
- [x] Smoke: a worse run doesn't overwrite it, and "New record!" shows only when it's beaten.
- [x] Screenshots: the title with the Endless button and its record, and the end screen's "New record!".
- [x] `docs/` updated, and a hand-play check of how long an endless run lasts added to `.scratch/hand-play-backlog/`.
- [x] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments

- **2026-10-21, architecture review:** the record goes in the profile (`record best`), not `story.cfg`.
- **2026-10-21, done:** an endless run's end calls `Profile.record_best(Profile.ENDLESS_BEST_NIGHTS, current_day)` from `GameManager._end_run`, and on a new record writes the hero id to `Profile.ENDLESS_BEST_HERO` (`endless.best_nights`, `endless.best_hero`). The record is the night the run ended on, so a loss on night 9 records 9, as the ticket asks (`nights_survived` would be 8); the glossary's "Record" now says "the furthest night an endless run reached". `GameManager.new_record` (reset each run) tells the end screen, which shows "You lasted to night N." plus "New record!" or the best so far (`record_text()`); story runs show no record line. `GameManager.endless_best_text()` ("Best: night 9 - Leo") sits under the title's Endless button and in its tooltip. Smoke: `_run_endless_record_scenario` (record, restart via `Profile.reload`, a worse run with Nela, a story loss). Screenshots: `screenshots.gd` shots `15_title_endless_record` and `15b_end_screen_new_record` (rendered under xvfb-run), copied to `docs/design/screenshots/endless-title.png` and `endless-new-record.png`; the end-screen shot sets the day and nights survived by hand rather than playing 14 nights. Docs: an endless mode section in the game design spec (including ticket 02's scaling, described per the spec), the endless record in the architecture's profile section, roadmap 042 set to done. Hand play: `.scratch/hand-play-backlog/issues/08-endless-run-length.md`.
