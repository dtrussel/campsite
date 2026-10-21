# 02: Attack on the Hero

Status: ready-for-agent
Blocked by: 01

**What to build:** attacking lives in the Hero module: attack a target, reach, whether the hero is ready, current damage and whether it is attacking, with the cooldown and the melee vs pebble branch shared. The perk-hit module stays the perk math underneath it. The player's hero keeps its wind-up, range re-check and hit-stop around the shared attack, and the companion keeps its quick sparkle. Applying the signature tool is one method. The module gains a tier value and an on-hit hook for tool tiers, both unused. The pointer commands ask the hero whether it is attacking and what its reach is, with no magic numbers.

- [ ] Smoke (extends 01's scenario): attack damage and reach match the hero definition in each role, and the signature tool changes them.
- [ ] Smoke: Big Swing, Ricochet and Twin Strike still apply in both roles.
- [ ] Smoke scenarios that call the private attack method or read the current-damage field use the Hero interface instead.
- [ ] The pointer commands no longer compare a command number.
- [ ] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments
