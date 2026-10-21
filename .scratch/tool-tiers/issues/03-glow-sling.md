# 03: Nela's Glow Sling

Status: done
Blocked by: 02

**What to build:** Nela's tier 3, the **Glow Sling** (Scrap + Clay + 4 Glow Shards). Pebbles pierce, so they also hit the next mob in a line, and briefly light the target.

- [x] Smoke: craft tiers 1 → 2 → 3; one pebble hits two mobs standing in a line.
- [x] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments

- **2026-10-21, implemented:** done.
  - Nela's `tier_3` in `nela.tres` with `resources/recipes/glow_sling.tres` (3 Scrap + 3 Clay + 4 Glow Shards, the generic `tool_tier` effect; slingshot icon reused, no new art). No damage bonus.
  - Two new `ToolTier.EFFECTS`: `pierce` (in `PebbleShot._land`, a first pebble flies on as a follow-on shot to `PebbleShot.pierce_target`: the nearest living mob ahead of the target along the pebble's flat line, within `PIERCE_REACH` 3 m and `PIERCE_WIDTH` 0.8 m of the line; same damage through `HeroHits.strike`; a pierced pebble or a Ricochet bounce never pierces or bounces again) and `glow_hit` (in `Hero.on_attack_hit`, `GlowMark.light` puts a small pale-green OmniLight3D on the mob for 1.5 s; a new hit restarts it).
  - Smoke: `_run_double_sling_scenario` now crafts tier 3 after tier 2 (as player and as companion): 4 shards spent, one shot is one pebble, it hits and lights the front mob, pierces on to the mob 1.5 m behind but not one 2.5 m aside, and the glow fades.
