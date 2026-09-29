# Feature 019: Handoff

## Current state

- Stash caps and the Storage Crate are in.
- The Reinforced Wall and the Crafting Table (with 4 recipes) are in.
- Version: 0.14.0-playtest1.

## Key APIs

- **Stash:**
  - `ResourceManager.get_cap()`, `room_for()`, `is_full()`,
    `notify_caps_changed()`;
  - the `caps_changed` signal and the `storage` group;
  - `ResourceDefinition.base_cap`.
- **Recipes and crafting:**
  - `CraftingRecipe.station` (`STATION_CAMPFIRE`, `STATION_TABLE`);
  - `CraftingManager.has_table()`;
  - `CraftingTable.GROUP`.
- **Traps:** `SnapTrap.GROUP`, `needs_refill()`, `recharge()`.
- **Leo:** `has_sturdy_stick`, `upgrade_stick()`, `try_use_bandage()`
  (action `use_bandage` = X).
- **Nela:** `has_slingshot`, `give_slingshot()`, `get_attack_range()`,
  `apply_bandage()`.
- **Buildings:** `BuildManager.get_definition(id)`;
  `BuildingDefinition.place_sound`; `select_building_5`–`7`.

## Next

- Feature 020: 3- or 7-night runs, and autosave at dawn with Continue.
