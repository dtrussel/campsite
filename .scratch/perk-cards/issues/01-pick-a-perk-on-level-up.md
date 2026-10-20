# 01: Pick a perk on level-up

Status: done
Blocked by: none

**What to build:** the first full path through perks. When the player's hero levels up, a picker opens with three wood plate cards (icon, name, one line). The player picks one by clicking or by pressing 1/2/3. While the picker is open, the game runs at about 10% speed, and after 10 s with no pick it takes the first card. Perks are data with a small set of effect kinds (stat multiplier, flag, on-hit), the same pattern as hero definitions. This ticket wires only the stat-multiplier kind, through one shared perk: **Quick Hands** (gather 30% faster). A perk already taken is not offered again, unless it stacks. If the pool has fewer than three cards, show what's left, and skip the picker when it is empty.

- [x] Validate: every perk has an icon, a name, a line of text and a known effect kind.
- [x] Smoke: award XP to level 2 → the picker opens with distinct cards → pick Quick Hands → the gather time drops.
- [x] Smoke: with no input, the auto-pick fires after the timeout and time returns to normal speed.
- [x] Levelling up while restoring a save does not open the picker.
- [x] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments

- 2026-10-20: done. `PerkDefinition` (`scripts/progression/perk_definition.gd`) carries the fields for all three effect kinds (`stat`/`value` for `stat_mult`, `flag` for `flag`, `hit_source`/`extra_targets`/`reach` for `on_hit`), and `problems()` drives the validate check; a new `stat_mult` stat must be added to `PerkDefinition.STATS`. The `PerkManager` autoload deals and holds cards: `offer`, `take`, `has`, `count`, `perks_of`, `restore`, `reset`, plus the hook queries `multiplier`, `has_flag` and `on_hit_perks`. `PerkPicker` (`scripts/ui/perk_picker.gd`) is hosted by `hud.show_perk_picker()`. It slows from `Fx.unstopped_time_scale()`, so a hit-stop can't leave the game slowed. Quick Hands is `gather_time` x0.7 (`ResourceNode.gather_seconds_for`). Tests: `PerkManager.auto_pick_seconds = 0` takes the first card at once with no picker; the smoke test's `_start_fresh_run` and the balance sim set it, and `_run_perk_01_scenario` turns the picker back on. The companion's own pick is left to ticket 06 (a comment in `PerkManager._on_level_up`).
