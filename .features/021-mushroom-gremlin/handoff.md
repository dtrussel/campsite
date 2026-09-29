# Feature 021: Handoff

## Current state

- Mushroom Gremlins steal from the stash on nights 2 and later.
- Version: 0.16.0-playtest1.

## Files

- **Art:** `art/characters/mushroom_gremlin.py`.
- **Game:**
  - `game/scenes/mobs/MushroomGremlin.tscn`;
  - `game/resources/mobs/mushroom_gremlin.tres`.
- **Changed:**
  - `mob_definition.gd` (`steals_resources`, `steal_amount`);
  - `mob_controller.gd`: `_tick_thief`, `_steal`, `_escape`,
    `_drop_loot`, and the `stole` and `escaped` signals;
  - `mob_spawner.gd` (`sneak_*`, `get_sneak_count`);
  - `item_pickup.gd` (icon mode);
  - `hud.gd` (banners).

## Next

- Feature 022: the Shadow Imp art remodel.
