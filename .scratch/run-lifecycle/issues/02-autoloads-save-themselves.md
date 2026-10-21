# 02: The autoloads save themselves

Status: ready-for-agent
Blocked by: 01

**What to build:** resources, progression, perks, time and the game's run fields (stats, chapter goal, pity counter, party) each save, load and reset their own state, and the run session walks them in one declared order. The perk top-up listens to `restore_finished`, and the progression manager's restoring flag goes away. The reset gaps are fixed: the perk clock, the perk and loot random generators and the crafting state reset on a new run. The shard pity counter is saved, so it survives Continue.

- [ ] Validate (new): for each of these systems, set state, save, reset (fresh), load, and it matches; no scene needed.
- [ ] Smoke: a level-up just before the dawn autosave still gives its card after Continue.
- [ ] Smoke: the pity counter survives Continue.
- [ ] Smoke: nothing from one run's perks or crafting carries into the next.
- [ ] The old-format fixture still loads.
- [ ] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments
