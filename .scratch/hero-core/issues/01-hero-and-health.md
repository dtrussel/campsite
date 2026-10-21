# 01: The Hero base class and health

Status: done
Blocked by: none

**What to build:** Leo and Nela take hits, heal, regenerate and go down through one shared Hero module, whichever role they play. Both controllers extend it. A hero has one down state and one `down_changed` signal; the player's hero still ends the run when down, and the companion still revives at dawn. The game manager, the HUD and the bark director listen to `down_changed`, and mobs, pickups, the perk-hit module and the pointer commands ask the hero whether it is down instead of reading a field by name. The old knocked-out signals and field are removed. Damage-taken perks (Stand Firm and the near-the-fire rule) still apply in both roles.

- [x] Smoke (new): for each hero in each role, a hit lowers HP, the invulnerability window blocks a second hit, heal raises HP, and going down emits `down_changed`.
- [x] Smoke: the companion revives at dawn; the player's hero going down ends the run.
- [x] No code outside the Hero module reads a knocked-out field by name.
- [x] Smoke scenarios that set the invulnerability timer or read the state enum use the Hero interface instead.
- [x] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments

- **2026-10-21, implement:** done. `game/scripts/characters/hero.gd` (`class_name Hero`, extends CharacterBody3D) is the base of both controllers. It holds `hero`, `stats`, `_visual`, and a Health section: `take_damage`, `heal`, `revive(hp)`, `is_down()`, `is_invulnerable()`, `clear_invulnerability()`, `down_changed(is_down)` and `health_changed`, with regen and the invulnerability window in `_tick_health(delta)`. The roles fill two hooks: `_show_hurt` (the flash, number, shake and sound) and `_on_down_changed` (the player drops its command and gather, and the companion its gather and label). Each role sets its own health tuning in `_init`. `knocked_out`, `knocked_out_changed`, `is_knocked_out` and `PlayerState.KNOCKED_OUT` are gone. GameManager, the HUD and the bark director listen to `down_changed`; mobs, pickups, HeroHits, PointerCommands and the balance sim call `is_down()`. Empty Attack, Progress and Gathering sections are left for tickets 02-04. The new smoke scenario is `_run_hero_health_scenario`. The smoke gather checks that read `_state == 2` belong to ticket 04 (gathering), so they are untouched. The PlaytestLog keys (`player_knocked_out`, `companion_knocked_out`) are kept as they were. Hero HP isn't saved, so the save format doesn't change.

