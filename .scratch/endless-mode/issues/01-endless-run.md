# 01: An endless run that never ends in a win

Status: ready-for-agent
Blocked by: none

**What to build:** once the true ending has been seen, the title offers **Endless**. An endless run starts as Chapter 2 with the Moon Lantern already lit, keeps going past night 7 with no win, and has no Moon-Eater. It is a separate `endless` flag, so the chapter logic, the HUD and end-screen moon rows, hero select's text and the Continue subtitle ("Night N") all still read sensibly. Shards still go to Glow Lanterns. Autosave and Continue work as in the story chapters.

- [ ] Smoke: with the true ending seen, the Endless button appears; without it, it doesn't.
- [ ] Smoke: an endless run passes night 8 without a win, and no Moon-Eater spawns.
- [ ] Smoke: save and Continue in endless keeps the run endless.
- [ ] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments
