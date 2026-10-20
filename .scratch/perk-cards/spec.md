# Perk cards

Status: done

From the 2026-10 brainstorm, feature 039. Built (tickets 01&ndash;07 done). It is split into tickets in `issues/` (01&ndash;07). Start with 01; the `Blocked by:` lines give the order.

## Plan

Rough size: **M**.

### Goal
Make levelling a choice. On each level-up, pick 1 of 3 perk cards, so two runs with the same hero can play differently.

### Scope
- **A card picker** on level-up: three wood plate cards (each with an icon, a name and a line), picked by click or by 1/2/3. The game slows to about 10% while the picker is open. Ignoring it for 10 s auto-picks the first card, so the picker never hides combat for long.
- **Pools:** a shared pool plus hero-only cards. A card can't be offered twice once taken, unless it stacks.
  - Shared:
    - **Quick Hands:** gather 30% faster.
    - **Ember Heart:** torches last a night longer and have a bigger radius.
    - **Berry Belly:** snacks heal +50%.
    - **Builder's Knack:** buildings cost 1 Wood less.
  - Leo:
    - **Big Swing:** hits up to 2 mobs.
    - **Stand Firm:** takes 25% less damage near the fire.
  - Nela:
    - **Ricochet:** a pebble bounces to a second mob.
    - **Eagle Eye:** +20% reach.
  - Sibling:
    - **Twin Strike:** +50% damage against a mob the other hero is hitting.
    - **Cheer Up:** level-ups heal the companion too.
- **The companion gets a random card** when they level up, shown on a small toast.
- The flat +HP/+damage per level stays, but smaller. Perks carry the rest.

### Systems touched
- New: `scripts/progression/perk_definition.gd`, `resources/perks/*.tres`, `scripts/progression/perk_manager.gd` (an autoload or part of `progression_manager.gd`), and `scripts/ui/perk_picker.gd`.
- `scripts/core/progression_manager.gd`: the `level_up` signal opens the picker. The stat bump is retuned in `resources/progression/*.tres`.
- Hooks where perks apply: `resource_node.gd` (gather time), `torch.gd`, `crafting_manager.gd` (costs), `player_controller.gd` / `companion_controller.gd` / `pebble_shot.gd` (damage, reach, bounce).
- `scripts/core/save_manager.gd`: `player.perks` and `sibling.perks`.

### Depends on
034 (hero-only pools). It sets up 041's starting perks.

## Acceptance criteria

- [x] `tools/check.sh` reports validate OK and smoke PASSED.
- [x] Validate: every perk has an icon, text and a known effect kind; each hero has at least two hero-only perks.
- [x] Smoke: award XP to level 2 → the picker opens with 3 distinct cards → pick → the effect applies (for example the gather time drops); the save then Continue keeps perks.
- [x] Smoke: the auto-pick fires after the timeout.
- [x] Screenshot: the picker over a night scene at 1280×720.

## Decisions so far

- **From the 2026-10 brainstorm.** The user chose story (B) and choices / meta (C), with an **adventure** tone (see `docs/design/story.md`), and asked for the roadmap first.
- **Perks are data (`PerkDefinition`) with a small set of effect kinds** (stat multiplier, flag, on-hit), the same pattern as `HeroDefinition`.
- **The flat bump per level is +3 HP for both heroes (was +5 / +4); damage stays +1** (ticket 07, from the balance sim: a smaller damage bump lost night 3).
- **Picking slows time instead of pausing it,** so the night keeps its tension; the auto-pick covers kids who ignore it.

- **The companion picks its own card,** at random from its pool, shown on a toast (decided 2026-10-20). The picker only ever opens for the player's hero, so combat is never interrupted twice.

## Open questions

None.

## Comments

- 2026-10-20: split into seven tickets. 01 is the first end-to-end slice (data, picker, auto-pick, Quick Hands). 02, 03, 04 and 06 can follow in any order, 05 needs 04, and 07 closes the feature.
