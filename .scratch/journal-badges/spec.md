# Ranger's Journal and Camp Badges

Status: needs-triage

From the 2026-10 brainstorm, planned as feature 041 and never started. Break it into tickets with `/to-tickets` once the open questions are answered.

## Plan

Rough size: **L**.

### Goal
Give players a reason to play again: a persistent profile that remembers achievements, tells mum's story through journal pages, and unlocks things.

### Scope
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
  - **Journal:** pages in a painted book frame (a placeholder frame until the team's art arrives).
- **Unlocks:**
  - Chapter 2 / 7 Nights after Chapter 1 is won;
  - cosmetic tent colours and hero outfits (a tint or material swap on the hero models);
  - starting perks that take one 039 card at the start;
  - Endless mode after the true ending (042).

### Systems touched
- New: `scripts/core/profile_manager.gd` (an autoload, the same JSON helpers as `save_manager.gd`), `scripts/meta/badge_definition.gd` with `resources/badges/*.tres`, `resources/story/journal/*.tres`, `scripts/ui/scrapbook.gd` with `scenes/ui/Scrapbook.tscn`, and `scripts/world/day_chest.gd`.
- `scripts/core/game_manager.gd`: `stats` and `record()` feed badge checks at the end of a run and live; `run_ended` updates the profile.
- `scripts/ui/title_screen.gd`: the Journal button, Chapter 2 locked until unlocked, and a badge toast.
- `scripts/ui/hero_select.gd`: an outfit picker row (later).

### Depends on
035 (chapters), 036/038 (lantern and true-ending badges), 039 (starting perks).

## Acceptance criteria

- [ ] `tools/check.sh` reports validate OK and smoke PASSED.
- [ ] Smoke: win Chapter 1 → the profile records the chapter and the badge → the title shows Chapter 2 unlocked; this survives a restart of the game.
- [ ] Smoke: a missing or corrupt profile loads as empty without errors.
- [ ] Smoke: a day chest gives a page, and the page shows in the scrapbook.
- [ ] Screenshots: the scrapbook's Badges and Journal tabs; the title with Chapter 2 locked and unlocked.

## Decisions so far

- **From the 2026-10 brainstorm.** The user chose story (B) and choices / meta (C), with an **adventure** tone (see `docs/design/story.md`), and asked for the roadmap first. This folder is a plan only: nothing is built yet.
- **The profile is separate from the run save** and never deleted by a run ending. Deleting it is a Settings button that asks for confirmation.
- **Unlocks are mostly sideways** (cosmetics, story, modes) or small starting perks, so a new player isn't far behind.

## Open questions

- should the existing playtest builds start with Chapter 2 unlocked?
- for cosmetics, is a tint enough, or are new model parts wanted (hats, capes)?
