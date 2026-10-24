# 03: The run session holds the one run config

Status: done
Blocked by: 02

**What to build:** the run session holds the one run config for the run in play, and the last one for Again. The game manager loses its run fields (the run length, the endless flag, the party ids, the day-chest day), and no alias for the config is kept on it.
- **Starting a run:** the title builds a draft config for a chapter or Endless. Hero select adds the party and the starting perk. Again replays the last config with fresh seeds.
- **The save:** the run session writes the config into the save. On Continue it builds the config from the save before any saving system loads. The game manager stops saving those keys, and the save's format is unchanged.
- **The screens:** the HUD, end screen, hero select, title and controls overlay read the config.
- **Tests and sims:** smoke scenarios and sims build run configs instead of setting game manager fields. Smoke's reset between scenarios forgets the last run config.

- [x] Nothing sets or reads run fields on the game manager. The config is never changed once a run has started.
- [x] Smoke: Continue from the v2 save fixture resumes at the saved run length and chapter. An endless save continues as endless.
- [x] Smoke: Again replays the same chapter, mode and party.
- [x] Smoke: hero select still opens on the last hero picked.
- [x] The balance sim still runs a run of any length.
- [x] `tools/check.sh` passes.

## Comments

2026-10-24: Done. `RunConfig.current()`, the `RunSession.config` fallback,
`_use_party` and the game manager's run fields (`nights_to_win`,
`endless`, `hero_id`, `companion_id`, `day_chest_day`,
`day_chest_chance`, `set_party`, `party_hero`/`party_companion`,
`chapter()`) are gone. `RunSession.config` is the run in play (or the
last run, for Again); `RunSession.draft` is the next run, built by the
title (`GameManager.open_hero_select(RunConfig.for_chapter(n))` /
`for_endless()`) and given the party and starting perk by
`begin_chapter`. `GameManager.start_run(null)` is Again
(`config.again()`). `RunConfig` gained `set_party`, `hero()` and
`companion()`. The session writes the config into the save
(`write_save`, in `snapshot`) and builds it on Continue with `from_save`
(seeds from the given config); `RunSession.forget_last_run()` is smoke's
reset. The badges module and `_end_run` only swapped to read
`RunSession.config` (tickets 06 rework them). New unit tests in
`tests/unit/test_run_session.gd`; the balance sim takes `nights=N`.

