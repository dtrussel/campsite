# 02: Story beats through the profile, and the story.cfg import

Status: done
Blocked by: 01

**What to build:** the story beats a player has seen (the chapter intros and the true ending) are kept in the profile instead of `story.cfg`; the story module's has-seen, mark-seen and forget-progress keep their names, so no caller changes. On the first load of a profile that has never been created, an existing `story.cfg` is imported once: every seen beat is copied, and if `intro.c2` or `ending.c2` was seen, a Chapter 2 unlocked flag is set for journal badges' chapter lock to read. The import is marked as done, so it never runs again, even after delete. `story.cfg` stays on disk, unused.

- [x] Validate: a prepared `story.cfg` with seen beats imports once; the beats read as seen.
- [x] Validate: seen `intro.c2` or `ending.c2` sets the Chapter 2 unlocked flag; seen `intro.c1` alone does not.
- [x] Validate: after delete, the import does not run again.
- [x] Smoke: the existing intro and ending scenarios still pass, on a temporary profile path.
- [x] The spec is set to done, with a note under Comments.
- [x] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments

- **2026-10-21, implement:** done.
  - **Story beats:** `StoryLibrary.has_seen` / `mark_seen` / `forget_progress` keep their names and now read and write `story.<beat>` profile keys (`Profile.STORY_PREFIX`). `StoryLibrary.progress_path` is gone; the smoke run and the screenshot sim swap the profile path instead.
  - **The import:** in `Profile.reload`, when the profile file has never been created and an old story file is set (`set_path(path, old_story_path)`; the autoload uses `user://story.cfg`, tests their own file, and the default is no import). Seen beats are copied; `intro.c2` or `ending.c2` sets `Profile.CHAPTER_2_UNLOCKED` (`chapters.c2.unlocked`). `story.cfg` is left on disk.
  - **Import once, even after delete:** the spec says delete removes the file, but the import must not rerun after it. So `delete` keeps one key, `profile.story_cfg_imported`, in a file holding only that note; without an import it still removes the file.
  - **New:** `Profile.forget(prefix)`, which `forget_progress` uses so that only story keys are cleared.
  - **Tests:** `_validate_story_import` in `tools/validate_project.gd` covers the import, the Chapter 2 flag (and `intro.c1` alone not setting it), no re-import after delete, and `forget_progress`.
