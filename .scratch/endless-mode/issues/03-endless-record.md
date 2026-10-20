# 03: Best-nights record

Status: ready-for-agent
Blocked by: 01

**What to build:** when an endless run ends, the best nights survived and the hero who did it are kept locally (in `story.cfg` until the journal profile exists). The end screen shows "New record!" when it's beaten, and the title's Endless button shows the record. Then wrap up: screenshots, docs, and endless mode (042) set to done in the roadmap.

- [ ] Smoke: a loss on night 9 records 9 nights and the hero, and the record survives a restart.
- [ ] Smoke: a worse run doesn't overwrite it, and "New record!" shows only when it's beaten.
- [ ] Screenshots: the title with the Endless button and its record, and the end screen's "New record!".
- [ ] `docs/` updated, and a hand-play check of how long an endless run lasts added to `.scratch/hand-play-backlog/`.
- [ ] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments
