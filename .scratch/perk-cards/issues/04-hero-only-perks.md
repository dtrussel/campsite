# 04: Leo's and Nela's own perks

Status: done
Blocked by: 01

**What to build:** hero-only pools. Each hero is offered their own cards on top of the shared ones, and never the other hero's. This adds the on-hit and flag effect kinds.
- **Leo:** **Big Swing** (a swing hits up to 2 mobs) and **Stand Firm** (25% less damage near the fire).
- **Nela:** **Ricochet** (a pebble bounces to a second mob) and **Eagle Eye** (20% more reach).

- [x] Validate: each hero has at least two hero-only perks.
- [x] Smoke: Leo is never offered Nela's cards, and Nela is never offered Leo's.
- [x] Smoke: each of the four perks has its effect (two mobs hit, less damage near the fire, a bounce, longer reach).
- [x] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments

- 2026-10-20: done. Four cards in `resources/perks/` (`big_swing`, `stand_firm` in Leo's pool; `ricochet`, `eagle_eye` in Nela's). Every hero hit and hurt now goes through `HeroHits` (`scripts/characters/hero_hits.gd`), in both `PlayerController` and `Companion`: `strike()` deals melee swings, pebbles and bounces, and `damage_factor(attacker, target)` is the per-target hook for ticket 05 (Twin Strike). `extra_targets()` serves Big Swing (+1 mob within 2 m of the first) and Ricochet (`PebbleShot.bounce`, +1 mob within 4 m, no second bounce). Stand Firm takes 0.75 of a hit within `HeroHits.NEAR_FIRE_RADIUS` (6 m) of the campfire. Eagle Eye is a `stat_mult` on the new stat `attack_range`, read through `get_attack_range()` on both controllers; the player's attack reach, auto-attack radius, keyboard target and pointer range ring (now rescaled to the live reach) all use it. Validate checks each hero has at least two own cards and is never offered another hero's; `_run_perk_04_scenario` checks the deals and all four effects for each hero as player and as companion.
