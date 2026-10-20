# 02: Camp badges

Status: ready-for-agent
Blocked by: 01

**What to build:** about 15 badges (First Night, Fire Keeper, Gremlin Catcher, Builder, Lantern Lighter, Chapter 1, Chapter 2, Both Heroes and more) as data. They are checked live and at the end of a run, kept in the profile, and announced with a small toast. Adds the stats some badges need: gremlins caught, the fire's lowest HP, and whether the Moon Lantern was lit.

- [ ] Validate: every badge has an icon, a name, how-to-earn text and a known condition.
- [ ] Smoke: surviving night 1 earns First Night once, with a toast, and it survives a restart.
- [ ] Smoke: the totals for counting badges (Builder, Gremlin Catcher) carry across runs.
- [ ] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments
