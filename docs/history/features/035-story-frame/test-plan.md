# Feature 035: Test plan

- [x] `tools/check.sh` reports validate OK and smoke PASSED.
- [x] Validate: every `StoryBeat` has lines for every hero, a known trigger, and a painting on intro and ending pages; ids are unique; lines are 60 characters or less; placeholders resolve; every chapter has its intro, its dawn cards and its ending; each voice file matches a line.
- [x] Smoke: the intro pages turn and Esc skips; seen intros are remembered per chapter; dawn 1 shows Leo and Nela's card; the first shard shows its card; a win shows the Chapter 1 ending before the stats; a loss to the fire shows the fire line.
- [x] Screenshots (`tests/sim/screenshots.gd`, under xvfb): intro pages 1 and 3, the dawn card over the HUD, the Chapter 1 ending, and the defeat line on the end screen at 1280×720. The card moved from the top centre to the left edge after the first shots showed it covering the kids.
- [ ] By hand: lines read well for a 7-year-old, and differ when Nela is played; the voices play in order once the recordings exist.
