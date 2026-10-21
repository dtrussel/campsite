# Feature 018: Handoff

## Current state

- A second enemy, the Bramble Beast, joins nights 2 and 3.
- It goes for buildings, hits them hard and barely flinches.
- Version: 0.13.0-playtest1.

## Files

- **Art:** `art/characters/bramble_beast.py`, which exports
  `game/assets/custom/bramble_beast.glb`. About 1 minute to build.
- **Game:**
  - `game/scenes/mobs/BrambleBeast.tscn`;
  - `game/resources/mobs/bramble_beast.tres`.
- **Changed:**
  - `mob_definition.gd`: `prefers_buildings`,
    `building_damage_multiplier`, `knockback_scale`, `spawn_burst`,
    `death_burst`;
  - `mob_controller.gd`: `_find_siege_target`, and an `hp_bar_height`
    export;
  - `mob_spawner.gd`: `heavy_definition`, `heavy_counts`,
    `build_wave()`, `get_heavy_count()`, and the `mob_spawned` signal;
  - `hud.gd`: the banner.
- **Sim:** `balance_sim.tscn -- <task> fight [no_beasts]`.

## Next

- Feature 019: Reinforced Wall (Clay + Stone). It is a natural answer to
  beasts.
- Also in 019: Storage Crate and Crafting Table.
- Feature 020: longer runs and save/load.
