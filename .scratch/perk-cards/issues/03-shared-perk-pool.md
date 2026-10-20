# 03: The rest of the shared pool

Status: done
Blocked by: 01

**What to build:** the other three shared perks, which any hero can be offered.
- **Ember Heart:** torches last a night longer and have a bigger light radius.
- **Berry Belly:** snacks heal 50% more.
- **Builder's Knack:** buildings cost 1 Wood less, never below 0.

- [x] Smoke: each of the three perks, once taken, changes its number (torch life and radius, snack healing, Wood cost).
- [x] Builder's Knack shows the lower cost in the build menu too.
- [x] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments

- Done. `ember_heart` (flag, value 1.4), `berry_belly` (stat_mult
  `snack_heal` 1.5) and `builders_knack` (flag, value 1 Wood) in
  `game/resources/perks/`. Hooks: `Torch.kindle(placer)` (called from
  `_try_place_torch`) adds a dawn (`dawns_to_burn`) and `set_radius()`
  scales the ring mesh and `FireEffect.set_light_range()`; the Glow
  Lantern is untouched. `BuildManager.cost_of(def)` is the one cost
  path (spend, can-afford, HUD tray and build row); a blueprint keeps
  its `paid_cost` meta so a refund returns what was paid. The discount
  counts if the player or a companion holds the card. The HUD redraws
  the build row on `perk_taken`.
- With four shared cards a 3-card deal can miss Quick Hands, so
  `_run_perk_01_scenario` now seeds `PerkManager.rng` to a deal that
  holds it; the win-run snack check allows for an auto-taken Berry Belly.
