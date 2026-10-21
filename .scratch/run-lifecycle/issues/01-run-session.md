# 01: The run session and run config

Status: ready-for-agent
Blocked by: hero-core (all tickets done)

**What to build:** one run session starts a run from a run config, continues a run from saved data, resets, and signals `restore_finished`. In this first ticket it wraps today's code (expand), so nothing else changes yet. The run config carries the party, the chapter goal, the perk and loot seeds and the perk auto-pick time. The smoke run starts and continues runs through the session: no scenario writes the pending-save field, and no scenario seeds random generators by hand. A save written by today's build is checked in as a fixture.

- [ ] Smoke: every save and Continue scenario goes through "continue from".
- [ ] Smoke: seeds and the auto-pick time come from the run config.
- [ ] Smoke: the checked-in old-format save loads with every field intact.
- [ ] Nothing outside the game manager writes its pending-save field.
- [ ] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments
