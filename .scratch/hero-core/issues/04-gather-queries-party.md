# 04: Gathering, the shared queries, and Party

Status: done
Blocked by: 01

**What to build:** gathering is one shared path in the Hero module: start on a resource, cancel, whether it is active, and a finished signal, used by both roles through the typed path. Nearest mob, node radius and flat distance are one copy each; the node-radius fallback is settled at 0.4 (the player's value), noted in the code. A small Party lookup gives the player's hero, the companion, the other hero, both heroes and a hero's role; the perk-hit module and the perk manager use it instead of group-name lookups. Other group lookups move to Party only where this ticket touches them.

- [x] Smoke: both heroes gather, cancel and finish in each role; the companion never stays stuck on a resource.
- [x] Smoke scenarios that call the private gather method or read the active node use the Hero interface instead.
- [x] Smoke: Party returns the right heroes after a hero swap.
- [x] The perk-hit module and the perk manager have no group-name lookups for heroes.
- [x] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments

- **2026-10-21, implement:** done. Hero's Gathering section has `start_gather(node) -> bool`, `cancel_gather()`, `is_gathering()`, `gather_target()` and a `gather_finished(node)` signal (named for the hero, rather than a bare `finished`), plus the `_on_gather_started` role hook (the player stops, faces and plays the clip). Both roles use it; the companion's `has_method` checks are gone, and so is the player's `PlayerState` enum (only GATHERING was ever read). The shared queries are one copy each: `nearest_mob(within)` (public), `_flat_distance` and `_node_radius`, with the 0.4 fallback noted in the code (the companion's repair reach used 0.5). New `Party` (`game/scripts/characters/party.gd`, a static class): `player_hero()`, `companion()`, `other(hero)`, `heroes()`, `role_of(hero)` (PLAYER, COMPANION or &""; it goes by the role group, so the validator's perk probe still counts). `HeroHits.other_hero` is removed in favour of `Party.other`; PerkManager's three role branches use `Party.role_of`. One stuck case is settled: the companion's gather task skips a node the other hero is gathering (`ResourceNode.is_taken_by_other`), where before it stood at it forever. Smoke: `_run_hero_gather_scenario`; the auto-attack, perk 04 and perk 05 checks now use the interface and Party.
