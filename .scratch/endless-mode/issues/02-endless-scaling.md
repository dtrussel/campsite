# 02: Mobs grow tougher after night 7

Status: done
Blocked by: 01

**What to build:** in endless, each night after 7 gives mobs +10% HP on top of the wave growth that already exists, and heavy and sneaky mobs make up a growing share of each wave. No new mob types.

- [x] Smoke: a mob spawned on night 9 has more HP than the same mob on night 7.
- [x] Smoke: the heavy and sneak share on night 10 is higher than on night 7.
- [x] The story chapters are unchanged.
- [x] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments

- **2026-10-21, done:** `MobSpawner.hp_multiplier(night)` is 1 + `endless_hp_per_night` (0.1) per night past `nights_to_win` in endless (1 in the story), and `_spawn_one` sets it on each `Mob` before it enters the tree (summons too). `Mob.max_hp()` is the definition's HP times it, used for the start HP and the HP bar; `BossController`'s identical `max_hp()` was dropped in favour of it. In endless, each night past 7 also turns one imp into a beast and one into a gremlin (`get_wave_size` is the imps left), so with the default lists imps hold at 19 while beasts and gremlins climb: night 10 is 55% beasts and gremlins against 37% on night 7, and an imp has 14 HP on night 9 against 12. Story waves are unchanged (night 10: 25 imps, 9 beasts, 8 gremlins). Smoke: in `_run_endless_scenario`, via `_summoned_hp` and `_heavy_sneak_share`.
