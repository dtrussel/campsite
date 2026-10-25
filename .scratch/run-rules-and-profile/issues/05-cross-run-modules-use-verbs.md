# 05: The cross-run modules go through the profile's verbs

Status: done
Blocked by: 04

**What to build:** the journal, the story library's seen beats, the starting perks, the tints, the endless record and the hero pick read and write only through the profile's verbs, and none of them builds a key:
- **The tables stay put:** the starting perks and tints keep their badge-to-unlock tables and ask the profile whether a badge is earned, through a read that this ticket adds.
- **The title:** it asks the profile whether Endless is unlocked instead of checking the true ending itself.
- **The true ending:** it is still marked seen when its book closes, for the title backdrop.
- **Tests:** smoke scenarios and the screenshot sim set up pages, beats and records through the verbs.

Badges themselves move in ticket 06.

- [x] No module but the profile and badges builds a profile key.
- [x] Smoke: the journal, endless, starting perks, tints, story and chapter 1 scenarios pass, including their reload-as-a-restart checks.
- [x] `tools/check.sh` passes.

## Comments

- 2026-10-24: Done. The profile gained `is_badge_earned(id)` and pick verbs for the starting perk (`record_starting_perk_pick`, `starting_perk_pick`), outfits (`record_outfit_pick(hero, id)`, `outfit_pick(hero)`) and the tent (`record_tent_pick`, `tent_pick`); the keys are unchanged, and the before-verbs fixture test checks them byte for byte. Journal, StoryLibrary, StartingPerks, Cosmetics, EndlessRecord and GameManager's hero pick use the verbs; the title asks `Profile.is_endless_unlocked()`, so Endless now shows once Chapter 2 is won too. The end screen still marks the true ending seen. The endless, chapter 1 and screenshot tests use the endless and hero-pick verbs. Left for 06: Badges' own keys and the raw badge-key writes in smoke and the screenshot sim, which wait for the test-only badge grant. `tools/check.sh` passes.
