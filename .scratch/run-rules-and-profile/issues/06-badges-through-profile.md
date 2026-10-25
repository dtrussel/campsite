# 06: Badges through the profile, with the run outcome

Status: done
Blocked by: 03, 05

**What to build:** the run tells the profile when a stat is recorded (with the run's facts) and when the run ends, with a **run outcome**: the run config, whether it was won, the night it ended on, and a copy of the run's stats.
- **At run end:** the profile records the chapter won, the hero won with and the endless record, then checks the badges. Endless now unlocks when Chapter 2 is won.
- **What run end returns:** whether the endless record was beaten and which unlocks opened. The game manager's "new record" flag goes.
- **Badge announcements:** the profile announces every badge, win badges included, through its own badge-earned signal. The HUD toast and the end screen's list listen to that signal.
- **During play:** the caller checks "only while playing, not while restoring", so the profile never reads the game manager, the run session or the time of day.
- **The badges module:** it stops being an autoload. It becomes a static module holding the badge definitions and a pure check of whether a badge is met, given its facts.
- **Test shortcut:** one test-only badge grant (documented as for tests and screenshots) replaces raw badge-key writes in smoke and the screenshot sim.
- **The contract:** the profile's raw key access becomes private.

- [x] Unit: each badge condition (run stat, total, win, win in a chapter, win with each hero) with plain facts.
- [x] Unit (in memory): run end records the chapter won, the hero won with and the endless record, and returns "record beaten" only for a better night.
- [x] Unit (in memory): a Chapter 2 win unlocks Endless.
- [x] Unit (in memory): totals add up across runs, and each badge is announced once.
- [x] Smoke: badge toasts during a run, the run's badges on the end screen and "New record!" behave as before.
- [x] Nothing outside the profile reads or writes a raw profile key.
- [x] `tools/check.sh` passes.

## Comments

- 2026-10-24: Done. `Badges` is no longer an autoload: it is a static
  module (`class_name Badges`) with the definitions, `total_stats()` and
  the pure `Badges.is_met(badge, Badges.Facts)`. New `RunOutcome`
  (`scripts/core/run_outcome.gd`, with `RunOutcome.Result`:
  `record_beaten`, `unlocked` of `&"chapter_2"`/`&"endless"`). Profile
  gained `badge_earned`, `record_stat(stat, amount, run, run_stats)`,
  `record_run_end(outcome) -> RunOutcome.Result`, `stat_total`,
  `has_won_with` and `grant_badge_for_tests`; its raw key access and key
  constants are private. GameManager calls the profile only while
  playing and not restoring, and keeps `run_end` (the result) in place
  of `new_record`; `stat_recorded` and `EndlessRecord.submit` are gone
  (the record's playtest log line moved into `Profile.record_endless`).
  Unit tests in `test_badges.gd` and `test_profile.gd`; the smoke boss
  scenario now checks that winning Chapter 2 opens Endless on the title.
