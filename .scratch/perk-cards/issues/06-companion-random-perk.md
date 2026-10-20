# 06: The companion picks its own card

Status: ready-for-agent
Blocked by: 01

**What to build:** when the companion (the sibling the player isn't controlling) levels up, it takes a random card from its own pool by itself. No picker opens, so combat is never interrupted for it. A small toast names the hero and the card, for example "Nela took Eagle Eye!". This was the spec's open question, decided 2026-10-20: the companion picks by itself.

- [ ] Smoke: a companion level-up adds a perk to the companion without opening the picker, and shows the toast.
- [ ] The companion's card follows the same pool rules: no repeats unless it stacks, and only its own hero's cards.
- [ ] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments
