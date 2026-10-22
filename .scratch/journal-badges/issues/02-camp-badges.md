# 02: Camp badges

Status: done
Blocked by: 01

**What to build:** about 15 badges (First Night, Fire Keeper, Gremlin Catcher, Builder, Lantern Lighter, Chapter 1, Chapter 2, Both Heroes and more) as data. They are checked live and at the end of a run, kept in the profile, and announced with a small toast. Adds the stats some badges need: gremlins caught, the fire's lowest HP, and whether the Moon Lantern was lit.

- [x] Validate: every badge has an icon, a name, how-to-earn text and a known condition.
- [x] Smoke: surviving night 1 earns First Night once, with a toast, and it survives a restart.
- [x] Smoke: the totals for counting badges (Builder, Gremlin Catcher) carry across runs.
- [x] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments

- **2026-10-21, done:** built test-first; the validator's `_validate_badges` and the smoke `badges scenario` cover every box above.
  - 15 badges in `game/resources/badges/` (`NN_id.tres`, so the file order is the scrapbook order): First Night, Night Owl, Fire Keeper, Gremlin Catcher, Builder, Lantern Lighter, Chapter 1, Chapter 2, Both Heroes, Torch Bearer, Shard Seeker, Gatherer, Crafter, Trapper, Monster Chaser. Icons reuse `assets/icons/` until badge art exists.
  - `BadgeDefinition` (`scripts/meta/badge_definition.gd`) has four conditions: `run_stat`, `total`, `win` (optional chapter and stat floor) and `win_each_hero`. `problems()` checks the stat name against `STATS`.
  - The `Badges` autoload (`scripts/meta/badges.gd`, after GameManager) checks live on the new `GameManager.stat_recorded` signal (play only, not while a save restores) and on `run_ended`. It keeps `badges.<id>`, `totals.<stat>` and `heroes.won.<id>` in the profile and toasts "Badge earned: X!" on the HUD.
  - Totals are added as each stat is recorded, not at the end of a run, so a quit run still counts.
  - New run stats: `gremlins_caught` (a thief mob killed), `fire_low_pct` (lowest campfire HP in %, starts at 100) and `lantern_lit`. `GameManager.set_stat()` sets the level-style stats (`nights_survived` too) and emits the signal.
  - The old-save smoke check now lets `stats` gain keys; old stats must still match.
  - Smoke runs from parallel worktrees share `user://` (`smoke_save.json`, the profile), so concurrent `tools/check.sh` runs can fail each other's autosave checks; run with `XDG_DATA_HOME=<own dir>` to isolate.

