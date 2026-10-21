# 03: Progress and the leveled signal

Status: ready-for-agent
Blocked by: 01

**What to build:** a hero's stats are set up once from its definition, and a level-up applies the stat bumps first and then emits one `leveled(level)` signal. The perk manager reacts to `leveled` (to open the picker for the player's hero, to auto-pick for the companion, and for Cheer Up) instead of the progression manager's raw level-up, so the picker always opens after the new HP shows. Saving still restores levels without opening the picker.

- [ ] Smoke (extends 01's scenario): on level-up, max HP has risen before `leveled` fires, in each role.
- [ ] Smoke: the perk picker opens for the player's hero and the companion auto-picks, as before.
- [ ] Smoke: Continue restores levels and perks with no picker.
- [ ] No code depends on the order autoloads connect to the level-up signal.
- [ ] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments
