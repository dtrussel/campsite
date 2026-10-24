# 02: The run's systems ask the run config

Status: done
Blocked by: 01

**What to build:** the systems that rebuild the run's rules from loose fields ask the run config instead:
- **The mob spawner:** the Moon-Eater's night, the eyes nights (the spawner keeps its own setting for when the eyes start, built on "has a Moon-Eater"), and endless toughness from "nights past the story".
- **The Moon Lantern:** it starts full in an endless run and takes its costs from the config's chapter.
- **The win check:** a winning dawn ends the run, and calming the Moon-Eater changes only the message.
- **The chapter intro:** whether it plays.

Until ticket 03, the run config the run session holds is still filled from the game manager's fields, so play is unchanged.

- [x] None of these systems infer the chapter from the run length or combine the chapter and endless flags themselves.
- [x] Smoke: the boss, endless, story and chapter 1 scenarios pass unchanged.
- [x] `tools/check.sh` passes.

## Comments

2026-10-24: Done. The mob spawner (`is_boss_night`, the now-public
`is_eyes_night`, `endless_nights_past`), the Moon Lantern (`costs`,
the fresh run's shards), the dawn win check and `GameManager.intro_pages`
/ `begin_chapter` ask a run config. The playing systems read
`RunSession.config`, which is built from `RunConfig.current()` on first
read if no reset has set it yet (the sims instance Main directly).
The intro, which plays before the run starts, asks
`RunConfig.current()` (ticket 03's draft config replaces that).
`tests/sim/screenshots.gd` now calls `RunSession.reset()` after setting
the run fields for its boss and endless shots. New unit tests:
`game/tests/unit/test_run_rules_systems.gd`. The HUD, end screen, hero
select and badges still read GameManager's fields.
