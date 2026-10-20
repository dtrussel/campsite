# 01: Profile and the Chapter 2 lock

Status: ready-for-agent
Blocked by: none

**What to build:** a persistent profile (`user://profile.json`) that a run ending never deletes. It records chapters completed and the last hero pick, and imports `story.cfg` once. On the title, Chapter 2 is locked until Chapter 1 is won. When the profile is first created, Chapter 2 is unlocked for players whose `story.cfg` shows a Chapter 1 win, and in playtest and debug builds. A missing or corrupt profile loads as empty. Settings gets a Delete profile button that asks for confirmation.

- [ ] Smoke: win Chapter 1 → the title shows Chapter 2 unlocked, and this survives a restart.
- [ ] Smoke: a missing or corrupt profile loads as empty without errors.
- [ ] Smoke: an existing `story.cfg` with a Chapter 1 win unlocks Chapter 2 on first launch, and its seen story beats still count.
- [ ] Hero select starts on the last hero picked, after a restart too.
- [ ] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments
