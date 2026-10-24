# 01: Run config holds the chapter and the run's rules, with a unit-test pass

Status: ready-for-agent
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

- [ ] Unit: every rule for Chapter 1, Chapter 2 and endless configs, including the nights either side of the goal.
- [ ] Unit: a config for a chapter gets its nights to win, and a config for Endless is Chapter 2 with the endless flag.
- [ ] Unit: Again keeps the party, chapter and mode and gives new seeds.
- [ ] Unit: the same seed gives the same day-chest day.
- [ ] Unit: the save round trip, including the v2 save fixture and a save from before endless mode.
- [ ] The checks script runs the unit pass before smoke and fails on any unit failure. CI runs it.
- [ ] `tools/check.sh` passes.

## Comments
