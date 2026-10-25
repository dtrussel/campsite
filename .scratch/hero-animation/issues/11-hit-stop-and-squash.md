# 11: Hit-stop and squash

Status: ready-for-agent
Blocked by: 02

**What to build:** when a hero's hit lands on the contact frame, the attacker and the target freeze for about 40–60 ms (**hit-stop**), and the target squashes slightly and recovers. Only their visuals freeze. Damage, knockback, gameplay time, timers, the companion, other mobs and the camera all keep running. Nothing shakes or flashes the screen.

- [ ] Hit-stop applies to the attacker's and the target's visuals on every hero hit, melee or pebble, in both roles.
- [ ] Smoke: during a hit-stop, the attacker's and target's animation is frozen while the companion and another mob keep animating and moving. Afterwards both resume.
- [ ] Smoke: a target killed by the hit still dies normally (no frozen corpse).
- [ ] In-game captures are under `## Comments` for sign-off.
- [ ] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments
