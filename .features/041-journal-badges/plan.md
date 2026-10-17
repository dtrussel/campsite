# Feature 041: Ranger's Journal and Camp Badges (plan)

Status: **planned** (roadmap from the 2026-10 brainstorm). Rough size: **L**.

## Goal
Give players a reason to play again: a persistent profile that remembers achievements, tells mum's story through journal pages, and unlocks things.

## Scope
- **A profile** in `user://profile.json`, separate from the run save (`save.json` is deleted at the end of a run). It keeps:
  - badges;
  - journal pages;
  - unlocks;
  - best records (for example most nights or gremlins caught);
  - chapters completed;
  - the last hero pick (moved here from `GameManager`).
- **Camp Badges:** Scout-style badges for milestones, about 15 to start:
  - First Night;
  - Fire Keeper: the fire never drops below 50%;
  - Gremlin Catcher: 10 gremlins caught in total;
  - Builder: 50 buildings in total;
  - Lantern Lighter;
  - Chapter 1;
  - Chapter 2;
  - Both Heroes: win with each.
- **Journal pages:** 10–12 short pages by mum (story layer 3–4 of `story.md`). They are found as a **day chest** that appears at the map edge (one per run, 50% chance) or awarded by certain badges.
- **Scrapbook screen** from the title (a Journal button), with two tabs:
  - **Badges:** a grid with locked silhouettes and how to earn each one.
  - **Journal:** pages in a painted book frame.
- **Unlocks:**
  - Chapter 2 / 7 Nights after Chapter 1 is won;
  - cosmetic tent colours and hero outfits (a tint or material swap on the hero models);
  - starting perks that take one 039 card at the start;
  - Endless mode after the true ending (042).

## Systems touched
- New: `scripts/core/profile_manager.gd` (an autoload, the same JSON helpers as `save_manager.gd`), `scripts/meta/badge_definition.gd` with `resources/badges/*.tres`, `resources/story/journal/*.tres`, `scripts/ui/scrapbook.gd` with `scenes/ui/Scrapbook.tscn`, and `scripts/world/day_chest.gd`.
- `scripts/core/game_manager.gd`: `stats` and `record()` feed badge checks at the end of a run and live; `run_ended` updates the profile.
- `scripts/ui/title_screen.gd`: the Journal button, Chapter 2 locked until unlocked, and a badge toast.
- `scripts/ui/hero_select.gd`: an outfit picker row (later).

## Depends on
035 (chapters), 036/038 (lantern and true-ending badges), 039 (starting perks).
