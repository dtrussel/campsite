# 02: Perks survive save and Continue

Status: done
Blocked by: 01

**What to build:** the perks each hero has taken are written to the save, for both the player's hero and the sibling. On Continue they are restored, and their effects apply again without the picker opening. Older saves with no perks still load.

- [x] Smoke: pick a perk, save, Continue → the perk is still held and its effect still applies.
- [x] Smoke: a save from before perks loads with no perks and no errors.
- [x] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments

Done. `SaveManager.snapshot()` writes `player.perks` and `sibling.perks` (ids as strings, one per copy, in the order taken); `apply()` hands them to `PerkManager.restore` right after `restore_xp`, so no picker opens and no `perk_taken` fires. A missing or malformed `perks` key reads as none, so no VERSION bump. Covered by `_run_perk_02_scenario()` in `smoke_run.gd`.
