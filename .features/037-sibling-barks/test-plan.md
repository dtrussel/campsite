# Feature 037: Test plan

- [x] `tools/check.sh` reports validate OK and smoke PASSED.
- [x] Validate: every trigger has at least two lines per hero; no line is over 30 characters; ids are unique (also against story beats); known speakers; no placeholders. It reports how many barks are voiced.
- [x] Smoke: the companion at low HP gets a bubble with a `low_hp` line for that speaker; triggering again within the cooldown shows nothing.
- [x] Smoke: playing Leo vs Nela swaps the speakers of the `thief` call and response.
- [x] Smoke: a bark while a story card's voice plays does not stop that voice.
- [x] Smoke: `level_up` on the player shows a bubble on the player.
- [x] Smoke: a mob behind the player at night makes the companion call out; not while the companion is knocked out.
- [x] Screenshot: a bubble over each hero, readable at 1280×720, without overlapping the health bars.
- [ ] Manual: a full night with no bark spam (not yet played by hand).
