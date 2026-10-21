# 02: Story beats through the profile, and the story.cfg import

Status: ready-for-agent
Blocked by: 01

**What to build:** the story beats a player has seen (the chapter intros and the true ending) are kept in the profile instead of `story.cfg`; the story module's has-seen, mark-seen and forget-progress keep their names, so no caller changes. On the first load of a profile that has never been created, an existing `story.cfg` is imported once: every seen beat is copied, and if `intro.c2` or `ending.c2` was seen, a Chapter 2 unlocked flag is set for journal badges' chapter lock to read. The import is marked as done, so it never runs again, even after delete. `story.cfg` stays on disk, unused.

- [ ] Validate: a prepared `story.cfg` with seen beats imports once; the beats read as seen.
- [ ] Validate: seen `intro.c2` or `ending.c2` sets the Chapter 2 unlocked flag; seen `intro.c1` alone does not.
- [ ] Validate: after delete, the import does not run again.
- [ ] Smoke: the existing intro and ending scenarios still pass, on a temporary profile path.
- [ ] The spec is set to done, with a note under Comments.
- [ ] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments
