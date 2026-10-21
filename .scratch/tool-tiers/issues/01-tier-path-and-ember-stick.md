# 01: Tier path and Leo's Ember Stick

Status: ready-for-agent
Blocked by: perk-cards 05 (the shared damage and on-hit hooks), hero-core

**What to build:** a signature tool becomes a tier path on the hero's data. Once Leo owns the Sturdy Stick (tier 1, today's craft), the crafting panel offers the **Ember Stick** (tier 2: Wood + Scrap + 2 Glow Shards). Its hits leave a burn (1 damage/s for 3 s), and at night it gives a small personal light. The save stores the tier as a number, and old saves with `signature: true` (or the older `stick`/`slingshot` keys) load as tier 1. The HUD's attack slot shows a tier pip. This works for Leo as the player's hero and as the companion.

- [ ] Validate: every hero's tiers point to existing recipes.
- [ ] Smoke: craft tier 1, then tier 2, as Leo; the shards are spent, and a hit's burn ticks 3 times.
- [ ] Smoke: an old save with `signature: true` loads as tier 1.
- [ ] The tier-2 recipe only appears once tier 1 is owned.
- [ ] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments

- **2026-10-21, architecture review:** now also blocked by hero-core: build the tier on the shared Hero attack (its tier value and on-hit hook).
