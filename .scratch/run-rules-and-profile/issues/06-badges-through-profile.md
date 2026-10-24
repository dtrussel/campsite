# 06: Badges through the profile, with the run outcome

Status: ready-for-agent
Blocked by: 03, 05

**What to build:** the run tells the profile when a stat is recorded (with the run's facts) and when the run ends, with a **run outcome**: the run config, whether it was won, the night it ended on, and a copy of the run's stats.
- **At run end:** the profile records the chapter won, the hero won with and the endless record, then checks the badges. Endless now unlocks when Chapter 2 is won.
- **What run end returns:** whether the endless record was beaten and which unlocks opened. The game manager's "new record" flag goes.
- **Badge announcements:** the profile announces every badge, win badges included, through its own badge-earned signal. The HUD toast and the end screen's list listen to that signal.
- **During play:** the caller checks "only while playing, not while restoring", so the profile never reads the game manager, the run session or the time of day.
- **The badges module:** it stops being an autoload. It becomes a static module holding the badge definitions and a pure check of whether a badge is met, given its facts.
- **Test shortcut:** one test-only badge grant (documented as for tests and screenshots) replaces raw badge-key writes in smoke and the screenshot sim.
- **The contract:** the profile's raw key access becomes private.

- [ ] Unit: each badge condition (run stat, total, win, win in a chapter, win with each hero) with plain facts.
- [ ] Unit (in memory): run end records the chapter won, the hero won with and the endless record, and returns "record beaten" only for a better night.
- [ ] Unit (in memory): a Chapter 2 win unlocks Endless.
- [ ] Unit (in memory): totals add up across runs, and each badge is announced once.
- [ ] Smoke: badge toasts during a run, the run's badges on the end screen and "New record!" behave as before.
- [ ] Nothing outside the profile reads or writes a raw profile key.
- [ ] `tools/check.sh` passes.

## Comments
