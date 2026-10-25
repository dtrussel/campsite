# 09: Spring chains: the modifier and Leo

Status: ready-for-agent
Blocked by: 01, 08 (08 only orders the model rebuilds)

**What to build:** Leo's hair and backpack (and any other part on his turnaround sheet that visibly hangs or sticks out) lag, swing and settle when he turns, stops or gets hit. The kid kit adds short chains of 2–3 bones for those parts and weights the parts to them instead of binding them rigidly. No clip keys the new bones. A spring-chain `SkeletonModifier3D`, owned by the character visual, moves each chain with stiffness, damping, gravity and a reach limit, tuned per chain on the hero's data.

- [ ] Leo's model has the chains, and every existing clip still plays correctly.
- [ ] The modifier works for the player's hero, the companion and hero select.
- [ ] Smoke: after a sudden 180° turn, a chain's tip moves away from its rest pose and settles back within a time limit.
- [ ] Leo stays within the hero triangle budget.
- [ ] In-game captures (turning, stopping, getting hit) are under `## Comments` for sign-off.
- [ ] `art/README.md` describes the spring bones.
- [ ] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments
