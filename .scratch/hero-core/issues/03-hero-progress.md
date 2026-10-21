# 03: Progress and the leveled signal

Status: done
Blocked by: 01

**What to build:** a hero's stats are set up once from its definition, and a level-up applies the stat bumps first and then emits one `leveled(level)` signal. The perk manager reacts to `leveled` (to open the picker for the player's hero, to auto-pick for the companion, and for Cheer Up) instead of the progression manager's raw level-up, so the picker always opens after the new HP shows. Saving still restores levels without opening the picker.

- [x] Smoke (extends 01's scenario): on level-up, max HP has risen before `leveled` fires, in each role.
- [x] Smoke: the perk picker opens for the player's hero and the companion auto-picks, as before.
- [x] Smoke: Continue restores levels and perks with no picker.
- [x] No code depends on the order autoloads connect to the level-up signal.
- [x] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments

- **2026-10-21, implement:** done. Hero's Progress section holds `leveled(level)` and `_setup_progress()` (each role calls it once in `_ready`: max HP and attack damage from the stats, full HP, registers with ProgressionManager, and `PerkManager.watch(self)`). Hero listens to ProgressionManager's raw `level_up` for itself, applies the attack and max-HP bumps, emits `health_changed`, then `leveled`, then the role's `_show_level_up(level, quiet)` (HP-bar level, "LEVEL UP!" and the burst; after `leveled`, so the player's float text still defers to the open picker). Attack damage still lives in each role's own field until ticket 02, behind the `_add_attack_damage(amount, base)` hook; 02 can fold it into Hero. PerkManager no longer connects to `ProgressionManager.level_up`: `watch(hero)` connects that hero's `leveled`, and the restore check (`is_restoring`) stays. The HUD banner and the bark director still use the raw signal; neither depends on connection order. New smoke scenario: `_run_hero_progress_scenario` (both heroes, both roles; max HP is raised when `leveled` fires and when the perk manager reacts; restore emits `leveled` with no picker).

- **2026-10-21, merge:** with 02 in, the `_add_attack_damage` hook is gone: `_setup_progress` and the level-up bump set `attack_damage` on Hero directly.
