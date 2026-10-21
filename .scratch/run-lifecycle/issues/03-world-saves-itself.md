# 03: The world saves itself

Status: ready-for-agent
Blocked by: 01

**What to build:** the campfire, buildings and blueprints, torches (including Ember Heart's), the Moon Lantern and both heroes each save and load themselves. Buildings, blueprints and torches are listed and rebuilt by their own module, which owns its metas and legacy fallbacks (old signature names, a missing paid cost). Each object refreshes its HP label itself after loading; nothing outside calls a private refresh. Heroes save through the Hero interface. The save file header stops promising trap snaps.

- [ ] Smoke: blueprints, half-built buildings and their refunds come back as they were.
- [ ] Smoke: Ember Heart torches come back with their dawns left.
- [ ] Smoke: campfire and building HP show correctly right after Continue.
- [ ] No module outside these objects reads their metas or calls their private methods.
- [ ] The old-format fixture still loads.
- [ ] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments
