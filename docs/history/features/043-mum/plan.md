# Feature 043: Mum (plan)

Status: **done**. Rough size: **M**.

## Goal
Bring the team's character sheet for Mum (2026-10-17) into the game:
- her storybook portraits, cut from the sheet's six expressions;
- a 3D Mum built the same way as Leo and Nela, who walks home in the true ending.

## Scope
- The sheet is stored as reference `art/reference/concept-2026-10/14_mum_character_sheet.webp`, with its source `art/ui/source/mum_sheet.png`.
- `art/ui/story_art.py` writes `game/assets/ui/story/mum.png` and `mum_<face>.png`. A story line picks a face with its `face` key.
- `art/characters/mum.py` builds `game/assets/custom/mum.glb`:
  - the kids' rig, with adult proportions and a smaller head;
  - the 76 stock clips, plus a hand-keyed `Wave`.
- `scripts/story/mum_arrival.gd`: the Chapter 2 win plays Mum's arrival first, then the ending book (`end_screen.gd`).
- The title backdrop seats Mum by the fire once `StoryLibrary.TRUE_ENDING` has been seen.

## Not in scope
The beagle on the sheet (concept flavour only).
