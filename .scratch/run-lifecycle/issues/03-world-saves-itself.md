# 03: The world saves itself

Status: done
Blocked by: 01

**What to build:** the campfire, buildings and blueprints, torches (including Ember Heart's), the Moon Lantern and both heroes each save and load themselves. Buildings, blueprints and torches are listed and rebuilt by their own module, which owns its metas and legacy fallbacks (old signature names, a missing paid cost). Each object refreshes its HP label itself after loading; nothing outside calls a private refresh. Heroes save through the Hero interface. The save file header stops promising trap snaps.

- [x] Smoke: blueprints, half-built buildings and their refunds come back as they were.
- [x] Smoke: Ember Heart torches come back with their dawns left.
- [x] Smoke: campfire and building HP show correctly right after Continue.
- [x] No module outside these objects reads their metas or calls their private methods.
- [x] The old-format fixture still loads.
- [x] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments

- **2026-10-21, implemented:** the campfire (`BaseCore`), the Moon Lantern and both heroes (`Hero`, the companion adding its task) have `save_state` / `load_state` / `reset`; buildings and blueprints are listed by `BuildingSaves` and torches by `TorchSaves` (`scripts/buildings/`), and each writes and rebuilds its own line (`Building.save_entry` / `Building.rebuild`, `Torch.save_entry` / `Torch.rebuild`). `RunSession._world_systems()` lists them: campfire, buildings, torches, lantern, then the player's hero and the companion. Keys and places are unchanged.
  - **Metas gone:** a blueprint is started with `Building.start_as_blueprint(progress, paid)` and refunds `paid_cost()` (`BuildManager.place_blueprint` takes the paid cost; `PAID_COST_META` is gone). The legacy fallbacks moved with them: a missing `"paid"` into `Building.rebuild`, `"stick"` / `"slingshot"` into `Hero.LEGACY_SIGNATURE_KEYS`.
  - **HP bars:** each object refreshes its own bar on load; `BaseCore.health_bar()`, `Building.health_bar()` and `HealthBar3D.fill()` / `maximum()` let the smoke check them.
  - **Shared entries:** `RunSession.snapshot()` now merges an entry two systems both write (a hero's signature and its XP, under `"player"`) instead of overwriting it, so ticket 02's progression and perks can write there too.
  - **Reset:** the world objects put back what they load (no hearth and full HP, a dark lantern, no signature tool, an idle companion); buildings and planted torches are removed. This also clears the smoke's leftovers from earlier scenarios.
  - **Smoke:** `_run_world_save_scenario` (all of the above through Continue, plus an older save with no paid cost and the old `"stick"`); the perk review check reads `paid_cost()` instead of the meta. The save header no longer promises trap snaps.

