# Endless mode

Status: needs-triage

From the 2026-10 brainstorm, planned as feature 042 and never started. Break it into tickets with `/to-tickets` once the open questions are answered.

## Plan

Rough size: **S**.

### Goal
An optional post-story mode, "How long can you last?", for players who finished the story.

### Scope
- It is unlocked by the true ending (041). Nights keep coming, the mobs scale in **toughness** as well as numbers (+10% HP per night after 7), and new mixes appear.
- The Moon Lantern starts lit, and shards go to tool tiers and Glow Lanterns.
- The best-nights record and the best hero are kept in the profile, and the end screen shows "New record!".

### Systems touched
`scripts/core/game_manager.gd` (`nights_to_win = 0` means endless, which feature 020 considered), `scripts/mobs/mob_spawner.gd` (scaling), `scripts/core/profile_manager.gd`, `scripts/ui/title_screen.gd`, and `scripts/ui/end_screen.gd`.

### Depends on
041 and 038.

## Acceptance criteria

- [ ] `tools/check.sh` reports validate OK and smoke PASSED.
- [ ] Smoke: an endless run passes night 8 without a win; mob HP scales; a loss records the best nights in the profile.

## Decisions so far

- **From the 2026-10 brainstorm.** The user chose story (B) and choices / meta (C), with an **adventure** tone (see `docs/design/story.md`), and asked for the roadmap first. This folder is a plan only: nothing is built yet.
- **Optional and last.** Feature 020 did not choose endless mode, so it only comes once the story is done.

## Open questions

- is a leaderboard wanted (online is out of scope today), or a local record only?
