# 02: Attack on the Hero

Status: done
Blocked by: 01

**What to build:** attacking lives in the Hero module: attack a target, reach, whether the hero is ready, current damage and whether it is attacking, with the cooldown and the melee vs pebble branch shared. The perk-hit module stays the perk math underneath it. The player's hero keeps its wind-up, range re-check and hit-stop around the shared attack, and the companion keeps its quick sparkle. Applying the signature tool is one method. The module gains a tier value and an on-hit hook for tool tiers, both unused. The pointer commands ask the hero whether it is attacking and what its reach is, with no magic numbers.

- [x] Smoke (extends 01's scenario): attack damage and reach match the hero definition in each role, and the signature tool changes them.
- [x] Smoke: Big Swing, Ricochet and Twin Strike still apply in both roles.
- [x] Smoke scenarios that call the private attack method or read the current-damage field use the Hero interface instead.
- [x] The pointer commands no longer compare a command number.
- [x] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments

- **2026-10-21, implement:** done. The Attack section of `game/scripts/characters/hero.gd` holds `attack(target) -> bool`, `get_attack_damage()`, `get_attack_range()` (reach, after Eagle Eye), `is_attack_ready()`, `is_attacking()`, `get_attack_cooldown_ratio()` (the HUD's slot), `apply_signature()`, the `attacked` signal, and the `attack_damage` / `attack_range` / `attack_cooldown_seconds` / `has_signature` fields. It owns the cooldown (`_tick_attack`) and the melee vs pebble branch; Big Swing and the strike go through HeroHits as before. `attack()` does not wait for the cooldown (callers check `is_attack_ready()`), as the old private methods did. The definition's reach, cooldown and signature range factor are read by role through `_read_attack_tuning()` and a `_is_companion_role()` hook. The roles fill `_show_attack` (the animation; the companion also faces the target) and `_swing`: the player's wind-up, range re-check (x1.4) and hit-stop, the companion's instant sparkle. The player's `is_attacking()` is its attack command, as the range ring had it. Tool tiers: `tool_tier` (0) and `on_attack_hit(target, damage)`, which `HeroHits.strike` calls for every hero hit; both are unused. Settled drift: the signature float text lasts 2.8 s in both roles. `_perform_attack`, `_attack_mob` and `_current_attack_damage` are gone. PointerCommands uses `is_attacking()` and `get_attack_range()`, and the HUD uses `get_attack_cooldown_ratio()`. The new smoke scenario is `_run_hero_attack_scenario`. The hero and perk 04 scenarios now attack and read damage through the interface. The level-up damage bump stays in each role's `_on_level_up` (now on `attack_damage`) for ticket 03.
