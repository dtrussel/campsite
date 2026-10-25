# 02: Contact frame on the stock attacks

Status: ready-for-agent
Blocked by: none (can start immediately)

**What to build:** a hero's hit lands on the attack's **contact frame**, not when the attack starts. Leo's swing applies its hit, and Nela's pebble leaves the sling, at a contact time stored on the hero's data. This is the same for the player's hero and the companion, and it still uses today's stock clips. The attack cooldown and its HUD ratio are unchanged, so attacks per second and balance are unchanged. A hero without a contact time keeps the instant hit.

- [ ] Each hero definition holds its attack's contact time. The shared Hero module applies the swing or fires the pebble then. The character visual can report when the contact frame of the action it is playing comes.
- [ ] Wind-up rules: a hero who goes down before the contact frame loses the hit. A hero who is hit does not. A melee target that has died or left reach by then is missed quietly. The pebble fires toward the target's position at the contact frame.
- [ ] Validate: each hero's contact time is at most the wind-up cap (about 0.1 s at play speed) and inside its attack clip.
- [ ] Smoke (a new `hero_animation` scenario): for Leo and Nela, as the player's hero and as the companion, the hit or pebble comes at the contact frame and not on the attack's first frame. Waits are on conditions, not durations.
- [ ] Smoke: a hero downed during the wind-up deals no damage from that attack.
- [ ] Existing combat smoke checks (perks, tool tiers, Ricochet, Big Swing) still pass. Any that assumed an instant hit now wait for the hit.
- [ ] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments
