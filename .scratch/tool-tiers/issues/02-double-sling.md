# 02: Nela's Double Sling

Status: done
Blocked by: 01

**What to build:** once Nela owns the Slingshot (tier 1), she can craft the **Double Sling** (tier 2: Wood + Scrap + 2 Glow Shards). Every third shot fires two pebbles. It works for Nela as the player's hero and as the companion.

- [x] Smoke: as Nela, craft tiers 1 → 2; the third shot launches two pebbles.
- [x] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments

- **2026-10-21, implemented:** done.
  - Nela's tier 2 is data: a `tier_2` ToolTier on `nela.tres` with the new `double_shot` effect, made by `resources/recipes/double_sling.tres` (3 Wood + 2 Scrap + 2 Glow Shards, the generic `tool_tier` effect, slingshot icon for now).
  - `Hero._shoot()` counts pebbles per run (reset with the run, not saved); with a `double_shot` tier every third (`Hero.DOUBLE_SHOT_EVERY`) fires a second pebble at the same target, same damage, launched with the first but flying 0.08 s later (`PebbleShot.fire`'s new `delay`). Both pebbles go through `HeroHits.strike`, so perks and Ricochet apply to each.
  - Smoke: `_run_double_sling_scenario`, with Nela as the player and as the companion: not offered before the Slingshot, 2 shards spent, pebbles per shot `[1, 1, 1]` at tier 1 and `[1, 1, 2, 1, 1, 2]` at tier 2.
