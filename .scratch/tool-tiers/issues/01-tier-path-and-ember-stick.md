# 01: Tier path and Leo's Ember Stick

Status: done
Blocked by: perk-cards 05 (the shared damage and on-hit hooks), hero-core

**What to build:** a signature tool becomes a tier path on the hero's data. Once Leo owns the Sturdy Stick (tier 1, today's craft), the crafting panel offers the **Ember Stick** (tier 2: Wood + Scrap + 2 Glow Shards). Its hits leave a burn (1 damage/s for 3 s), and at night it gives a small personal light. The save stores the tier as a number, and old saves with `signature: true` (or the older `stick`/`slingshot` keys) load as tier 1. The HUD's attack slot shows a tier pip. This works for Leo as the player's hero and as the companion.

- [x] Validate: every hero's tiers point to existing recipes.
- [x] Smoke: craft tier 1, then tier 2, as Leo; the shards are spent, and a hit's burn ticks 3 times.
- [x] Smoke: an old save with `signature: true` loads as tier 1.
- [x] The tier-2 recipe only appears once tier 1 is owned.
- [x] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments

- **2026-10-21, architecture review:** now also blocked by hero-core: build the tier on the shared Hero attack (its tier value and on-hit hook).
- **2026-10-21, implemented:** done.
  - `ToolTier` (`scripts/characters/tool_tier.gd`) is one step of a hero's path: recipe, label, icon, damage bonus, range factors by role, and `effects` (`burn`, `night_light`). `HeroDefinition.signature_tiers` replaces the single signature fields. Owned tiers add up: bonuses add, factors multiply, and every owned tier's effects apply.
  - All tier recipes use one generic `tool_tier` effect (`CraftingRecipe.EFFECT_TOOL_TIER`), and the owner is found by recipe id, so a new hero only adds data. `CraftingManager.is_offered()` hides a tier until the one before it is owned, and the crafting panel uses it.
  - `Hero.tool_tier` is the state; `has_signature` is now read-only (`tool_tier > 0`), and `set_tool_tier()` raises it. The burn is a `Burn` child node on the mob (1 damage/s, 3 ticks, a new hit restarts it, no knockback). The night light is an OmniLight3D on the hero, off inside a torch's radius.
  - The save writes `tier` (an int). `signature: true` and the older `stick`/`slingshot` keys load as tier 1. The HUD attack slot draws ember pips (`AbilitySlot.pips`).
  - The Ember Stick costs 3 Wood + 2 Scrap + 2 Glow Shards and reuses the stick icon (no new art yet). The smoke scenario is `_run_tool_tiers_scenario`, which runs with Leo as the player and as the companion.
