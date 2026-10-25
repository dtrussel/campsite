# 01: Clip checks and review captures (baseline)

Status: ready-for-agent
Blocked by: none (can start immediately)

**What to build:** the yardstick for the rest of the feature. The validator measures every hero clip as data (foot slide, loop wrap and action durations) and reports the numbers for today's stock clips, warning but not failing. An art contributor can render clay contact sheets and GIFs of any kid clip from the game camera without launching the game. A capture scene records a hero playing a list of states in the game, so old and new can be shown side by side.

- [ ] Validate: for Leo and Nela, every mapped state has a clip. Looping clips (idle, walk, run) report their first-to-last pose difference. Walk and run report foot slide per stride at the hero's speed, sampling the foot bones against the distance the root travels. Action clips report their length at their gameplay play speed.
- [ ] Each check has a threshold and a per-clip switch from "report" to "enforce". Every stock clip starts on "report", so `tools/check.sh` stays green.
- [ ] The art side: one command renders a contact sheet (frames in a strip) and a GIF of a named clip for a named kid, in clay, from the game camera's angle.
- [ ] The capture scene: one command records a hero in the game playing the listed states, in both roles' poses, and writes PNG strips or a GIF that can be put next to another capture.
- [ ] The baseline (today's slide, loop and duration numbers per clip) is written under `## Comments`, with the stock contact sheets.
- [ ] `art/README.md` and `docs/testing/test-strategy.md` say how to run the renders, the capture scene and the clip checks.
- [ ] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments
