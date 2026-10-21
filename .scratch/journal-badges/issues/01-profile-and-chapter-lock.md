# 01: The Chapter 2 lock, the last hero, and Delete profile

Status: done
Blocked by: profile, run-lifecycle

**What to build:** on top of the profile (from `.scratch/profile/`, which owns the store, the corrupt-file handling and the one-time `story.cfg` import):
- **Recording progress:** the profile records the chapters completed and the last hero pick.
- **The Chapter 2 lock:** on the title, Chapter 2 is locked until Chapter 1 is won. It is unlocked from the start for players the profile's import marked as having already played Chapter 2 (the Chapter 2 unlocked flag), and in playtest and debug builds.
- **Delete profile:** Settings gets a Delete profile button that asks for confirmation.

- [x] Smoke: win Chapter 1 → the title shows Chapter 2 unlocked, and this survives a restart.
- [x] Smoke: a profile with the imported Chapter 2 unlocked flag shows Chapter 2 unlocked on first launch.
- [x] Hero select starts on the last hero picked, after a restart too.
- [x] Delete profile asks first, then relocks Chapter 2 and leaves audio and graphics settings alone.
- [x] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments

- **2026-10-21, architecture review:** the profile store, the missing/corrupt handling and the `story.cfg` import moved to the profile spec. This ticket keeps the chapter lock, the last-hero pick and the Delete-profile button.
- **2026-10-21, done:** built test-first; the smoke `chapter lock scenario` covers every box above.
  - `Profile` gained `LAST_HERO`, `is_chapter_unlocked()`, `record_chapter_won()` (Chapter 1 sets `chapters.c2.unlocked`) and `unlock_all_chapters`. GameManager records the win in `_end_run` and the pick in `begin_chapter` (`record_hero_pick`); hero select opens on `last_hero_pick()`.
  - The title disables a locked Chapter 2 button and says "Locked - win Chapter 1 first".
  - "Settings" is the pause menu (the only settings UI): Delete profile sits under its settings and asks through a ConfirmationDialog.
  - "Playtest and debug builds" means `OS.is_debug_build()` or a `playtest` feature tag. Today's playtest exports are release builds with no tag, so they show the lock; add the tag to the export preset if testers should get every chapter.
