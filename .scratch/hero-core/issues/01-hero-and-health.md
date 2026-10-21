# 01: The Hero base class and health

Status: ready-for-agent
Blocked by: none

**What to build:** Leo and Nela take hits, heal, regenerate and go down through one shared Hero module, whichever role they play. Both controllers extend it. A hero has one down state and one `down_changed` signal; the player's hero still ends the run when down, and the companion still revives at dawn. The game manager, the HUD and the bark director listen to `down_changed`, and mobs, pickups, the perk-hit module and the pointer commands ask the hero whether it is down instead of reading a field by name. The old knocked-out signals and field are removed. Damage-taken perks (Stand Firm and the near-the-fire rule) still apply in both roles.

- [ ] Smoke (new): for each hero in each role, a hit lowers HP, the invulnerability window blocks a second hit, heal raises HP, and going down emits `down_changed`.
- [ ] Smoke: the companion revives at dawn; the player's hero going down ends the run.
- [ ] No code outside the Hero module reads a knocked-out field by name.
- [ ] Smoke scenarios that set the invulnerability timer or read the state enum use the Hero interface instead.
- [ ] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments
