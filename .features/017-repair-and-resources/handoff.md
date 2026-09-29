# Feature 017: Handoff

## Current state

- Repairs work, by Leo and by Nela.
- All 10 resources can be gathered and spent. Glow Shards drop from
  imps.
- Three new campfire recipes: Feed the Fire, Berry Snack, Stone Hearth.
- Two new buildings: Snap Trap and Glow Lantern.
- Version: 0.12.0-playtest1.

## Key files

- **Rules:**
  - `game/scripts/buildings/repair.gd` (`Repair`);
  - `snap_trap.gd`;
  - `torch.gd` (the `burns_out_at_dawn` flag);
  - `game/scripts/world/item_pickup.gd`.
- **Data:**
  - `game/resources/recipes/{feed_fire,berry_snack,stone_hearth}.tres`;
  - `game/resources/buildings/{snap_trap,glow_lantern}.tres`;
  - `game/resources/items/snack.tres`;
  - `shadow_imp.tres` (`drop_item`, `drop_every_n_kills`).
- **Scenes:**
  - `game/scenes/resources/{ClayPit,MushroomPatch,JunkPile}.tscn`;
  - `game/scenes/buildings/{SnapTrap,GlowLantern}.tscn`;
  - `game/scenes/world/ItemPickup.tscn`.
- **Art and icons:**
  - `art/props/forage.py` (run: `.venv-blender/bin/python art/props/forage.py [prop]`);
  - icons: `xvfb-run -a godot --path game --rendering-driver opengl3 res://tools/render_icons.tscn -- clay trap ...`.
    Pass names after `--` so the existing icons are not re-rendered.
- **Sounds:** `tools/build_audio.sh sfx repair clay mushrooms scrap shard trap_snap`.

## API changes

- **Structures:**
  - the `repairable` group;
  - `get_max_hp()`, `get_missing_hp()`, `repair_per_tap` on `Building`
    and `BaseCore`;
  - `BaseCore.build_hearth()` and `has_hearth`.
- **Player:** `command_repair(target)` and `Command.REPAIR`.
- **Nela:** `Companion.Task.REPAIR` (index 4); `GameManager` input
  action `assign_repair` (V).
- **Recipes:** `CraftingRecipe.effect`, `icon_name`, `result_icon()`,
  `CraftingRecipe.EFFECTS`.
- **Imps:** `Mob.stun(seconds)` and `is_stunned()`;
  `MobDefinition.drop_item` and `drop_every_n_kills`.
- **Buildings:** `BuildingDefinition.icon`; input actions
  `select_building_3` and `select_building_4`.
- **Stats:** `repairs`, `shards`, `trap_snaps`.

## Known limitations

- The balance sim does not exercise traps, lanterns or repair. Night 3
  may now be easy for a player who uses all three; watch the playtest.
- The Glow Lantern can be attacked only if it blocks an imp's path (like
  any building); imps do not target it on purpose.

## Next

- Feature 018: the Bramble Beast (targets fences, which makes repair
  matter).
- Feature 019: Reinforced Wall (Clay + Stone), Storage Crate, Crafting
  Table.
