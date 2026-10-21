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
- **2026-10-21, slowed-smoke fix:** CI's `SMOKE_FRAME_DELAY=40` run failed "the Glow Sling's pebble hits and lights its target". Cause: a fixed `_wait(FLIGHT_SECONDS + 0.15)` timer is created in the same frame as the pebble's flight tween, and SceneTree steps timers before tweens; on a frame of 0.35 game s or more (about 90 ms at the smoke's 4x speed), the timer ran out and the check ran before the tween landed the pebble. The game was right. The smoke now polls through a new `_wait_until(condition, game_seconds)`: it reads hit and glow in the first frame after the hit, reads pierce/aside once every pebble is down, and requires the glow to fade within `GlowMark.SECONDS + 1 s`. The hero scenario's older "Nela's pebble hit the imp 3.5 m away" check had the same race (seen failing once in a slowed run) and polls the same way now. All three failures reproduced reliably with a 150 ms stall injected before the shot, and they pass with the fix.
