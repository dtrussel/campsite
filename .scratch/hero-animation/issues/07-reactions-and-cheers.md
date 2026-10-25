# 07: Reactions and cheers

Status: ready-for-agent
Blocked by: 06 (the clip pipeline is from 03; 06 only orders the model rebuilds)

**What to build:** being hit, going down and getting back up fit a kid's size and weight. These are shared clips varied by the style knobs. Each kid also gets their own cheer for wins, level-ups and Mum's arrival.

- [ ] `hit`, `death` and `getup` map to the shared clips, and `cheer` to each kid's own. The stock clips stay as fallbacks.
- [ ] Going down still holds the last pose. The companion's getup at dawn still plays and leaves the down pose.
- [ ] Validate: each action clip's length at its play speed matches the gameplay durations recorded in 01 (enforced).
- [ ] Contact sheets, GIFs and in-game captures are under `## Comments` for sign-off.
- [ ] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments
