# 04: Leo's tier 3

Status: done
Blocked by: 01

**What to build:** Leo's third tier, the **Blaze Stick** (Scrap + Clay + 4 Glow Shards). It keeps the Ember Stick's burn, and each hit also splashes the burn onto mobs standing right next to the target; the personal night light grows a little. It works for Leo as the player's hero and as the companion.

- [x] Decide what Leo's tier 3 is and does, then fill in this ticket.
- [x] Smoke: as Leo, craft tiers 1 → 2 → 3; a hit burns the target and a mob right next to it, but not one further away.
- [x] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments

- **2026-10-21, decision:** the user chose the **Blaze Stick**: the burn splashes onto adjacent mobs and the light grows a bit, mirroring the Glow Sling's "hits more than one mob". Now `ready-for-agent`.
- **2026-10-21, implemented:** done.
  - The Blaze Stick is Leo's `tier_3` in `leo.tres` with `resources/recipes/blaze_stick.tres` (3 Scrap + 3 Clay + 4 Glow Shards, the generic `tool_tier` effect; stick icon reused, no new art). No damage bonus.
  - Two new `ToolTier.EFFECTS`: `burn_splash` (in `Hero.on_attack_hit`, a burning hit also calls `Burn.splash`, which ignites every living mob within `Burn.SPLASH_RADIUS` = 1.6 m flat of the target; the splash deals no hit damage, only the burn) and `bright_light` (the night light's range goes from 3.0 to 4.2 m, `Hero.get_tool_light_range()`).
  - Smoke: `_run_tool_tiers_scenario` now crafts tier 3 after tier 2 (as player and as companion); a mob 1 m from the target burns 3 ticks, one 4 m off does not; the light is wider at night; the save and Continue hold tier 3.
