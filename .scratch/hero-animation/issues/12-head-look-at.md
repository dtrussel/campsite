# 12: Head look-at

Status: ready-for-agent
Blocked by: none (can start immediately)

**What to build:** each kid turns their head and chest toward what they're paying attention to. The order is:

1. the attack target while fighting;
2. the resource or building they're working on while gathering or building;
3. the nearest mob within about 6 m while idle at night;
4. otherwise, the other hero now and then.

The look is capped at about 60° of head and chest turn, eases in and out, and blends off during full-body actions. The player's hero and the companion follow the same rules.

- [ ] A look-at `SkeletonModifier3D` on the character visual, and a way for gameplay to set or clear its focus.
- [ ] Unit: the target-priority rule picks the right target in each case, and nothing when no case applies.
- [ ] Smoke: for both roles, the head turns toward the attack target while fighting and toward the resource while gathering, within the cap.
- [ ] In-game captures are under `## Comments` for sign-off.
- [ ] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments
