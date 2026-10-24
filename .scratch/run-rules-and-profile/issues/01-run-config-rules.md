# 01: Run config holds the chapter and the run's rules, with a unit-test pass

Status: done
Blocked by: none

**What to build:** the run config stores the chapter and the endless flag as fields of its own, and answers the run's rules:
- whether a night is the Moon-Eater's night
- whether the run has a Moon-Eater
- whether a dawn wins
- how many nights a night is past the story
- whether the Moon Lantern starts full
- whether the chapter intro plays

A config can be built for a chapter (with the nights to win defaulted from it) or for Endless. Again makes a copy with the same chapter, mode and party, plus fresh seeds. The day-chest day comes from a roll seeded by the config. The config writes itself into the save's existing keys and reads itself back, inferring the chapter from the run length only for saves from before the chapter was stored.

A new unit-test pass runs headless in the checks script before smoke, with no third-party add-on and no main scene. It covers all of this. Nothing in the game calls the new rules yet, and the game manager's run fields stay as they are, kept in step.

- [x] Unit: every rule for Chapter 1, Chapter 2 and endless configs, including the nights either side of the goal.
- [x] Unit: a config for a chapter gets its nights to win, and a config for Endless is Chapter 2 with the endless flag.
- [x] Unit: Again keeps the party, chapter and mode and gives new seeds.
- [x] Unit: the same seed gives the same day-chest day.
- [x] Unit: the save round trip, including the v2 save fixture and a save from before endless mode.
- [x] The checks script runs the unit pass before smoke and fails on any unit failure. CI runs it.
- [x] `tools/check.sh` passes.

## Comments

- **2026-10-24, done:** `RunConfig` (`game/scripts/core/run_config.gd`) stores `chapter` and `endless` as fields of their own, plus a `chest_seed`. It is built with `for_chapter(n)` (nights to win from `CHAPTER_NIGHTS`: 3 and 7) or `for_endless()` (Chapter 2 with the flag). `again()` copies the chapter, mode, nights, party, starting perk and auto-pick time, with fresh perk, loot and chest seeds. The rules are `has_moon_eater()`, `is_moon_eater_night(night)`, `dawn_wins(night)`, `nights_past_story(night)`, `lantern_starts_full()` and `plays_intro()`. `roll_day_chest(chance)` is now an instance method seeded by `chest_seed`, and the static one on the global RNG is gone. `write_save(data)` writes `nights_to_win`, `endless`, `party` and `day_chest_day`, plus one new `chapter` key so the chapter is stored. `from_save(data)` reads them back and infers the chapter from the run length (7 or more nights is Chapter 2) only when `chapter` is missing. Nothing calls the rules or the save pair yet. `current()` and `RunSession._use_party` keep `chapter` in step with `GameManager.chapter()`. The unit pass is `game/tests/unit/unit_run.tscn`. It plays every `tests/unit/test_*.gd` script (extending `unit_test.gd`, with `check` and `check_eq`) and each `test_*` method on a fresh instance. `-- --unit <name>` plays one script, because Godot itself takes `--test`. `tools/check.sh` runs it after validate and before smoke, so CI runs it. `test_run_config.gd` has 10 tests. The test strategy lists the pass.
