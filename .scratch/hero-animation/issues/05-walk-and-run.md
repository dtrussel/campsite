# 05: Walk and run

Status: ready-for-agent
Blocked by: 04 (the clip pipeline is from 03; 04 only orders the rebuilds of the kids' committed models)

**What to build:** new walk and run cycles that keep the feet planted. Leo and Nela share the cycles, varied by the style knobs: Leo bouncy and eager, Nela lighter and more careful. Leo gets his own run only if the knobs can't carry his personality. Each cycle is authored with a known stride length. The character visual scales walk playback by the hero's real speed, as it already does for the run, so the feet match the ground.

- [ ] `walk` and `move` map to the new cycles for both kids. The stock cycles stay as a fallback.
- [ ] Validate: foot slide per stride at each hero's speed is under the threshold, and both cycles wrap without a pop. Both checks are enforced for these clips.
- [ ] The idle, walk and run blend still behaves as in feature 023, with upper-body actions while moving and the lean into turns. The footstep puffs still fire.
- [ ] Contact sheets, GIFs and old-and-new in-game captures (walking and running past the camera) are under `## Comments` for sign-off.
- [ ] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments
