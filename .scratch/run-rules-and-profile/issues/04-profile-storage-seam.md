# 04: The profile's storage seam and its first verbs

Status: done
Blocked by: none (can run alongside 01–03)

**What to build:** the profile's storage sits behind an internal seam with two adapters:
- **The JSON file:** today's file, keys and values byte for byte, including the one-time old story import and the import note that survives a delete.
- **In memory:** for unit tests.

Pointing the profile at another file stays, for smoke and the screenshot sim. The profile gains verbs and reads for:
- journal pages found
- story beats seen
- the hero picked on hero select
- chapters won
- the endless best (night and hero)
- whether a chapter is unlocked and whether Endless is unlocked (Chapter 2 won, or the true ending seen, for profiles from before this change)

The old raw key access is still there, so callers move over in ticket 05. The validator's profile checks move to unit tests. If ticket 01 hasn't landed yet, this ticket adds the unit-test pass to the checks script; if it has, it reuses it.

- [x] Unit (in memory): each verb and read, both unlock rules, and an old profile with only the true ending seen keeping Endless.
- [x] Unit (temporary file): the round trip, corrupt and missing files loading empty, the one-time old story import, and delete keeping the import note.
- [x] The validator no longer holds the profile round-trip or import checks.
- [x] A profile written before this change reads back the same.
- [x] `tools/check.sh` passes.

## Comments

- 2026-10-24: Done. `scripts/core/profile.gd` keeps its keys behind a
  `Store` with two adapters, `FileStore` (set_path; the story.cfg
  import lives here) and `MemoryStore` (`use_memory()`), both holding
  the same JSON text. New verbs and reads: `find_page` /
  `is_page_found`, `mark_seen` / `has_seen` / `forget_seen`,
  `record_hero_pick` / `last_hero_pick`, `is_chapter_won` (beside the
  existing `record_chapter_won`), `record_endless` /
  `endless_best_night` / `endless_best_hero`, and
  `is_endless_unlocked` (beside `is_chapter_unlocked`). Raw key access
  stays. Unit tests: `tests/unit/test_profile.gd` (memory) and
  `test_profile_file.gd` (temporary file, with the fixture
  `tests/fixtures/profile_before_verbs.json`, written by the old code,
  checked byte for byte). The validator's profile and story-import
  checks are gone. The unit runner gained an `after_each()` hook.
