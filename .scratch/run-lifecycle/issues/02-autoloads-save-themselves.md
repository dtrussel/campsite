# 02: The autoloads save themselves

Status: done
Blocked by: 01

**What to build:** resources, progression, perks, time and the game's run fields (stats, chapter goal, pity counter, party) each save, load and reset their own state, and the run session walks them in one declared order. The perk top-up listens to `restore_finished`, and the progression manager's restoring flag goes away. The reset gaps are fixed: the perk clock, the perk and loot random generators and the crafting state reset on a new run. The shard pity counter is saved, so it survives Continue.

- [x] Validate (new): for each of these systems, set state, save, reset (fresh), load, and it matches; no scene needed.
- [x] Smoke: a level-up just before the dawn autosave still gives its card after Continue.
- [x] Smoke: the pity counter survives Continue.
- [x] Smoke: nothing from one run's perks or crafting carries into the next.
- [x] The old-format fixture still loads.
- [x] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments

- **2026-10-21, implemented:** `TimeManager` ("day"), `GameManager` ("nights_to_win", "party", "stats", and a new "loot_misses" for the pity counter), `ResourceManager` ("inventory"), `ProgressionManager` ("player"/"sibling" "xp"), `PerkManager` ("player"/"sibling" "perks") and `CraftingManager` (reset only) each have `save_state` / `load_state` / `reset`, listed in that order in `RunSession._autoload_systems()` (public `autoload_systems()` for the validator). The keys and their places are unchanged. A hero's keys are shared between systems, so `RunSession.merge_state` merges nested entries. `Party.SAVE_KEYS` maps the roles to "player"/"sibling", and `Party.member(role)` finds the role's node (a stand-in counts).
  - **Removed:** the matching parts of `SaveManager.snapshot` / `apply`, and the moved entries in `GameManager.reset_autoloads` (only `BuildManager.exit_build_mode` is left, for 04 to retire).
  - **Restoring:** `ProgressionManager.is_restoring` is gone; `RunSession.is_restoring()` is true while the systems load, and the hero, the HUD and the perk manager read it. The perk top-up runs on `restore_finished`, for the heroes whose save has "perks". Inventory loaded back no longer counts as "gathered".
  - **Resets:** `PerkManager.reset` zeroes the clock and reshuffles the deal; `GameManager.reset` reshuffles the loot rolls; `CraftingManager.reset` clears `is_crafting`. The session still seeds the generators from the run config.
  - **Checks:** a validate check (`_validate_saving_systems`) and the smoke scenario `_run_lifecycle_02_scenario`. Three smoke checks used to replay level-ups by calling `restore_xp` on their own. They now continue from a save through the session (`_continue_with_xp`), because the quiet replay belongs to a restore.
