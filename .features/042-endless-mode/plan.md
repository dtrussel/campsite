# Feature 042: Endless mode (plan)

Status: **planned** (roadmap from the 2026-10 brainstorm). Rough size: **S**.

## Goal
An optional post-story mode, "How long can you last?", for players who finished the story.

## Scope
- It is unlocked by the true ending (041). Nights keep coming, the mobs scale in **toughness** as well as numbers (+10% HP per night after 7), and new mixes appear.
- The Moon Lantern starts lit, and shards go to tool tiers and Glow Lanterns.
- The best-nights record and the best hero are kept in the profile, and the end screen shows "New record!".

## Systems touched
`scripts/core/game_manager.gd` (`nights_to_win = 0` means endless, which feature 020 considered), `scripts/mobs/mob_spawner.gd` (scaling), `scripts/core/profile_manager.gd`, `scripts/ui/title_screen.gd`, and `scripts/ui/end_screen.gd`.

## Depends on
041 and 038.
