# 02: Perks survive save and Continue

Status: ready-for-agent
Blocked by: 01

**What to build:** the perks each hero has taken are written to the save, for both the player's hero and the sibling. On Continue they are restored, and their effects apply again without the picker opening. Older saves with no perks still load.

- [ ] Smoke: pick a perk, save, Continue → the perk is still held and its effect still applies.
- [ ] Smoke: a save from before perks loads with no perks and no errors.
- [ ] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments
