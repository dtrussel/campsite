# 06: Starting perks

Status: done
Blocked by: 02, and perk-cards done

**What to build:** once unlocked by a badge, a run can start with one perk card already taken, chosen from a short starting list in hero select.

- [x] Smoke: with the unlock, a run starts with the chosen perk and its effect applies.
- [x] Without the unlock, no starting perk is offered.
- [x] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments

- **2026-10-21, done:** built test-first; the smoke `starting perks scenario` covers every box above (it passes with `SMOKE_FRAME_DELAY=40` too).
  - `StartingPerks` (`scripts/meta/starting_perks.gd`, a static class, no autoload) lists three shared cards and the badge that unlocks each: Quick Hands (Gatherer), Builder's Knack (Builder), Ember Heart (Torch Bearer). The validator checks the perks exist and are shared, and the badges exist.
  - Hero select gets a self-contained "Start with:" row under the goal line (None plus the unlocked cards); it is left out while none is unlocked. The pick is kept in the profile (`perks.starting`), and is dropped if its badge is gone (Delete profile).
  - `RunConfig.starting_perk` (from `StartingPerks.chosen()`) is given to the played hero by `GameManager` when a new run's scene is ready, never on Continue; a locked perk is ignored.
  - `PerkManager.take_starting` records it apart from the level-up cards and the save keeps it (`starting_perk` under the hero's key), so the Continue top-up still deals a card owed when the autosave landed with the picker open.

