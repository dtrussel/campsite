# Feature 036: Handoff

- **Done:** see `status.md`. Code: `game/scripts/base/moon_lantern.gd`, with hooks in `mob_controller.gd` (slow, ward, drops), `mob_definition.gd` (`drop_chance`, `drop_pity`, `hurt_by_moonlight`), `game_manager.gd` (`roll_loot`), `player_controller.gd` (`try_feed_lantern`), `save_manager.gd`, `hud.gd` and `hud_widgets.gd` (`LanternDial`).
- **Tuning knobs:**
  - on the lantern scene: `costs_chapter_1`/`_2`, radii, `slow_factor`, `ward_fraction`;
  - on the mob `.tres` files: `drop_chance`, `drop_pity`.
- **Waiting on the team:** the lantern's model and painting. Swap the code-built model in `_build_model()` for a scene, and keep the orb, crystals, light and ring as the glowing parts.
- **Next:** 038 checks `lantern.is_full()` before the Moon-Eater's final night. 040 can spend shards on tool tiers and compete with the lantern.
- Open: should the pedestal get a collider? It would need the nav mesh rebaked around it.
