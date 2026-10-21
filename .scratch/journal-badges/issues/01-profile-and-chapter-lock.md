# 01: The Chapter 2 lock, the last hero, and Delete profile

Status: ready-for-agent
Blocked by: profile, run-lifecycle

**What to build:** on top of the profile (from `.scratch/profile/`, which owns the store, the corrupt-file handling and the one-time `story.cfg` import):
- **Recording progress:** the profile records the chapters completed and the last hero pick.
- **The Chapter 2 lock:** on the title, Chapter 2 is locked until Chapter 1 is won. It is unlocked from the start for players whose imported `story.cfg` shows a Chapter 1 win, and in playtest and debug builds.
- **Delete profile:** Settings gets a Delete profile button that asks for confirmation.

- [ ] Smoke: win Chapter 1 → the title shows Chapter 2 unlocked, and this survives a restart.
- [ ] Smoke: a profile imported from a `story.cfg` with a Chapter 1 win shows Chapter 2 unlocked on first launch.
- [ ] Hero select starts on the last hero picked, after a restart too.
- [ ] Delete profile asks first, then relocks Chapter 2 and leaves audio and graphics settings alone.
- [ ] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments

- **2026-10-21, architecture review:** the profile store, the missing/corrupt handling and the `story.cfg` import moved to the profile spec. This ticket keeps the chapter lock, the last-hero pick and the Delete-profile button.
