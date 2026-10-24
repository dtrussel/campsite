# 04: The profile's storage seam and its first verbs

Status: ready-for-agent
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

- [ ] Unit (in memory): each verb and read, both unlock rules, and an old profile with only the true ending seen keeping Endless.
- [ ] Unit (temporary file): the round trip, corrupt and missing files loading empty, the one-time old story import, and delete keeping the import note.
- [ ] The validator no longer holds the profile round-trip or import checks.
- [ ] A profile written before this change reads back the same.
- [ ] `tools/check.sh` passes.

## Comments
