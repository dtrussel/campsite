# 03: The run session holds the one run config

Status: ready-for-agent
Blocked by: 02

**What to build:** the run session holds the one run config for the run in play, and the last one for Again. The game manager loses its run fields (the run length, the endless flag, the party ids, the day-chest day), and no alias for the config is kept on it.
- **Starting a run:** the title builds a draft config for a chapter or Endless. Hero select adds the party and the starting perk. Again replays the last config with fresh seeds.
- **The save:** the run session writes the config into the save. On Continue it builds the config from the save before any saving system loads. The game manager stops saving those keys, and the save's format is unchanged.
- **The screens:** the HUD, end screen, hero select, title and controls overlay read the config.
- **Tests and sims:** smoke scenarios and sims build run configs instead of setting game manager fields. Smoke's reset between scenarios forgets the last run config.

- [ ] Nothing sets or reads run fields on the game manager. The config is never changed once a run has started.
- [ ] Smoke: Continue from the v2 save fixture resumes at the saved run length and chapter. An endless save continues as endless.
- [ ] Smoke: Again replays the same chapter, mode and party.
- [ ] Smoke: hero select still opens on the last hero picked.
- [ ] The balance sim still runs a run of any length.
- [ ] `tools/check.sh` passes.

## Comments
