# Feature 017: Test plan

- [x] `tools/check.sh` passes.
- [x] Clay, mushrooms and scrap gather from their new spots.
- [x] A repair tap spends 1 Wood and restores HP. Leo's repair command walks over and fixes a fence.
- [x] Nela's Repair task heals the campfire.
- [x] Feed the Fire is disabled at full HP and heals +20 otherwise.
- [x] Stone Hearth: +75 max HP, full heal, clay ring, once per run.
- [x] Berry Snack is crafted, and R eats it first (+35 HP).
- [x] A Snap Trap catches an imp (damage, stun, one charge used).
- [x] A Glow Lantern slows and zaps imps and does not burn out at dawn.
- [x] Every third kill drops a Glow Shard pickup, collected by walking close.
- [x] The lantern build preview shows a faint range ring, not a solid disc.
- [ ] **Playtest:** do kids find the far resource spots? Do they notice the hammer cursor on damaged fences?
- [ ] **Playtest:** is the wood economy OK now that repairs compete with building?
- [ ] **Playtest:** are traps and lanterns too strong on night 3 (11 imps)? Tune `snap_damage`, `hold_seconds` and the aura numbers if so.
