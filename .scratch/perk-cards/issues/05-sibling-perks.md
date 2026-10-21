# 05: Sibling perks

Status: done
Blocked by: 04

**What to build:** cards about the two siblings playing together, offered to either hero.
- **Twin Strike:** 50% more damage against a mob the other hero is hitting.
- **Cheer Up:** your level-ups heal the other hero too.

- [x] Smoke: with Twin Strike, damage goes up only on a mob the other hero hit recently.
- [x] Smoke: with Cheer Up, a level-up heals the other hero.
- [x] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments

Done. `resources/perks/twin_strike.tres` and `cheer_up.tres` (pool
`sibling`, `flag` perks); the logic is in `HeroHits`.
- **"The other hero"** is `HeroHits.other_hero()`: the companion for
  the player, the player for the companion. So both cards work for
  either party and either role.
- **"A mob the other hero is hitting"** means one the other hero
  struck within `HeroHits.TWIN_STRIKE_SECONDS` (2 s of game time).
  `strike()` stamps each hero hit on the mob (meta `hero_hit_at`,
  hero instance id -> time). The mob's `_last_damage_source` isn't
  enough, because your own hits overwrite it. The clock is the new
  `PerkManager.clock`, ticked in `_process`, so it follows
  `Engine.time_scale` and stops on pause. Physics frame counts don't
  work here, because they tick in real time.
- **Cheer Up** heals the other hero by `value` (25%) of their max HP
  per copy on each of your real level-ups (not on save replays). It
  doesn't wake a knocked-out hero. It's called from
  `PerkManager._on_level_up` before that level's card is dealt.
  `Companion.heal(amount)` is new.
- **Smoke:** `_run_perk_05_scenario` covers both parties and both roles.

