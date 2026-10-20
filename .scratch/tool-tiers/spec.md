# Tool tiers

Status: needs-triage

From the 2026-10 brainstorm, planned as feature 040 and never started. Break it into tickets with `/to-tickets` once the open questions are answered.

## Plan

Rough size: **M**.

### Goal
Turn the one-off signature crafts into a small upgrade path, and give Glow Shards a second, competing use against the Moon Lantern.

### Scope
- **Leo:**
  - Stick;
  - **Sturdy Stick** (today, +2 damage);
  - **Ember Stick** (hits leave a short burn: 1 damage/s for 3 s, and the stick lights the way at night).
- **Nela:**
  - Slingshot (today, more reach);
  - **Double Sling** (every 3rd shot fires two pebbles);
  - **Glow Sling** (pebbles pierce and briefly light the target).
- The upper tiers cost **Glow Shards** plus Resin and Scrap. Every shard spent there is one the lantern doesn't get.
- **Item descriptions get real uses.** Resin gives longer torches (it fixes a survey finding), and Mushrooms go into a **Brave Brew** that heals and makes you immune to knockback for 10 s.
- **HUD:** the attack slot shows the tier pip.

### Systems touched
- `scripts/characters/hero_definition.gd`: `signature_tiers: Array[{recipe, damage_bonus, range_factor, effect}]` replaces the single signature fields.
- `scripts/core/crafting_manager.gd` (`_signature_owner`): the next tier becomes available once the previous one is owned. New `resources/recipes/*.tres`.
- `scripts/player/player_controller.gd`, `scripts/companions/companion_controller.gd`, `scripts/characters/pebble_shot.gd`: the burn, double and pierce effects.
- `scripts/core/save_manager.gd`: `signature` becomes a tier int, and old booleans map to tier 1.
- Item descriptions in `resources/items/*.tres`.

### Depends on
036 (the shard economy). It shares effect hooks with 039.

## Acceptance criteria

- [ ] `tools/check.sh` reports validate OK and smoke PASSED.
- [ ] Validate: every hero's tiers point to existing recipes; item descriptions match a real use.
- [ ] Smoke: craft tiers 1 → 2 → 3 for both heroes in either role; each effect fires (the burn ticks, the double shot, the pierce hits two mobs in a line).
- [ ] Smoke: an old save with `signature: true` loads as tier 1.
- [ ] Screenshots: the crafting panel with tier 3 available, and the HUD tier pip.

## Decisions so far

- **From the 2026-10 brainstorm.** The user chose story (B) and choices / meta (C), with an **adventure** tone (see `docs/design/story.md`), and asked for the roadmap first. This folder is a plan only: nothing is built yet.
- **The tiers live on the hero data,** so a new hero brings their own tool path.

## Open questions

- are the tiers kept per run only (as today), or do they unlock as starting tools in the meta profile (041)?
