# 01: Pick a perk on level-up

Status: ready-for-agent
Blocked by: none

**What to build:** the first full path through perks. When the player's hero levels up, a picker opens with three wood plate cards (icon, name, one line). The player picks one by clicking or by pressing 1/2/3. While the picker is open, the game runs at about 10% speed, and after 10 s with no pick it takes the first card. Perks are data with a small set of effect kinds (stat multiplier, flag, on-hit), the same pattern as hero definitions. This ticket wires only the stat-multiplier kind, through one shared perk: **Quick Hands** (gather 30% faster). A perk already taken is not offered again, unless it stacks. If the pool has fewer than three cards, show what's left, and skip the picker when it is empty.

- [ ] Validate: every perk has an icon, a name, a line of text and a known effect kind.
- [ ] Smoke: award XP to level 2 → the picker opens with distinct cards → pick Quick Hands → the gather time drops.
- [ ] Smoke: with no input, the auto-pick fires after the timeout and time returns to normal speed.
- [ ] Levelling up while restoring a save does not open the picker.
- [ ] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments
