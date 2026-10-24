# 07: Mum's dawn note found without the HUD

Status: ready-for-agent
Blocked by: 05

**What to build:** the run's own dawn handling picks the dawn beat and records its journal page through the profile. The HUD is handed the beat to show and records nothing, so Mum's dawn notes are found whether or not a HUD is in the scene. The winning dawn still shows the ending book rather than a dawn beat.

- [ ] Smoke: a dawn with no HUD in the scene finds that dawn's note as a journal page.
- [ ] Smoke: with the HUD, the dawn card still shows and the page is found once.
- [ ] `tools/check.sh` passes.

## Comments
