# 04: Gathering, the shared queries, and Party

Status: ready-for-agent
Blocked by: 01

**What to build:** gathering is one shared path in the Hero module: start on a resource, cancel, whether it is active, and a finished signal, used by both roles through the typed path. Nearest mob, node radius and flat distance are one copy each; the node-radius fallback is settled at 0.4 (the player's value), noted in the code. A small Party lookup gives the player's hero, the companion, the other hero, both heroes and a hero's role; the perk-hit module and the perk manager use it instead of group-name lookups. Other group lookups move to Party only where this ticket touches them.

- [ ] Smoke: both heroes gather, cancel and finish in each role; the companion never stays stuck on a resource.
- [ ] Smoke scenarios that call the private gather method or read the active node use the Hero interface instead.
- [ ] Smoke: Party returns the right heroes after a hero swap.
- [ ] The perk-hit module and the perk manager have no group-name lookups for heroes.
- [ ] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments
