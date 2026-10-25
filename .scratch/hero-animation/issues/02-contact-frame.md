# 02: Contact frame on the stock attacks

Status: done
Blocked by: none (can start immediately)

**What to build:** a hero's hit lands on the attack's **contact frame**, not when the attack starts. Leo's swing applies its hit, and Nela's pebble leaves the sling, at a contact time stored on the hero's data. This is the same for the player's hero and the companion, and it still uses today's stock clips. The attack cooldown and its HUD ratio are unchanged, so attacks per second and balance are unchanged. A hero without a contact time keeps the instant hit.

- [x] Each hero definition holds its attack's contact time. The shared Hero module applies the swing or fires the pebble then. The character visual can report when the contact frame of the action it is playing comes.
- [x] Wind-up rules: a hero who goes down before the contact frame loses the hit. A hero who is hit does not. A melee target that has died or left reach by then is missed quietly. The pebble fires toward the target's position at the contact frame.
- [x] Validate: each hero's contact time is at most the wind-up cap (about 0.1 s at play speed) and inside its attack clip.
- [x] Smoke (a new `hero_animation` scenario): for Leo and Nela, as the player's hero and as the companion, the hit or pebble comes at the contact frame and not on the attack's first frame. Waits are on conditions, not durations.
- [x] Smoke: a hero downed during the wind-up deals no damage from that attack.
- [x] Existing combat smoke checks (perks, tool tiers, Ricochet, Big Swing) still pass. Any that assumed an instant hit now wait for the hit.
- [x] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments

- **2026-10-25, done:** `HeroDefinition.attack_contact_time` (clip seconds, 0 = instant hit) is set to 0.14 for both kids, and HeroBody passes it to `CharacterVisual.contact_times`. `CharacterVisual.action_contact_in()` reports the game seconds to the playing action's contact frame. `Hero.attack` starts the cooldown and the clip at once, then runs a tween to `_on_contact_frame`, which shoots, or swings when the target is alive and within 1.4x reach. `_set_down` and `reset` cancel the pending hit. The play speeds moved to `Hero.ATTACK_ANIM_SPEED` (1.5) and `COMPANION_ATTACK_ANIM_SPEED` (1.45). The validator checks `contact / 1.45 <= HeroDefinition.WIND_UP_CAP_SECONDS` and that the contact time falls inside the attack clip (`_validate_hero_contact_times`). The smoke scenario is `scenarios/hero_animation.gd`. `tool_tiers.gd` (`_pebbles_from` counts launches), `heroes.gd` (attack lands) and `perks.gd` (`_attack_and_wait`, and a 3 s cap on `_attack_and_wait_until`) now wait on the hit.
  - **0.14 is capped, not the stock contact.** Measured on the stock clips, the chop's strike comes about 0.6 s in and the spell cast's thrust about 0.1–0.3 s in. At 1.5x speed that is 0.4 s and 0.2 s, both over the cap. So both kids use 0.14 (0.093 s played, 0.097 s as the companion) until tickets 03 and 04 key real contact frames.
  - **Feel change:** the player's old 0.22 s wind-up (`ATTACK_WINDUP`) is gone, so the player's hit now lands sooner (about 0.09 s). The companion's hit, which used to be instant, now comes at the contact frame too.
