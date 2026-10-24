# 05: The cross-run modules go through the profile's verbs

Status: ready-for-agent
Blocked by: 04

**What to build:** the journal, the story library's seen beats, the starting perks, the tints, the endless record and the hero pick read and write only through the profile's verbs, and none of them builds a key:
- **The tables stay put:** the starting perks and tints keep their badge-to-unlock tables and ask the profile whether a badge is earned, through a read that this ticket adds.
- **The title:** it asks the profile whether Endless is unlocked instead of checking the true ending itself.
- **The true ending:** it is still marked seen when its book closes, for the title backdrop.
- **Tests:** smoke scenarios and the screenshot sim set up pages, beats and records through the verbs.

Badges themselves move in ticket 06.

- [ ] No module but the profile and badges builds a profile key.
- [ ] Smoke: the journal, endless, starting perks, tints, story and chapter 1 scenarios pass, including their reload-as-a-restart checks.
- [ ] `tools/check.sh` passes.

## Comments
