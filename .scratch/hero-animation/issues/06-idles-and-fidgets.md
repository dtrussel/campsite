# 06: Idles and fidgets

Status: ready-for-agent
Blocked by: 05 (the clip pipeline is from 03; 05 only orders the model rebuilds)

**What to build:** each kid's own idle, and 2–3 idle fidgets each, such as looking around, scratching, stretching or checking their tool. A kid standing still plays a fidget now and then. The fidget never plays while moving, during an action, or while down. Hero select shows the new idle and fidgets.

- [ ] `idle` maps to each kid's own clip. The fidgets are listed on each hero's data.
- [ ] Unit: the fidget scheduler waits a random interval in a set range, picks no fidget twice in a row, and fires only while the hero is idle.
- [ ] Validate: the idles wrap without a pop (enforced).
- [ ] Smoke: a hero left idle plays a fidget within the range, and moving cancels it back to locomotion.
- [ ] Contact sheets, GIFs and in-game captures (including hero select) are under `## Comments` for sign-off.
- [ ] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments
