# 07: Smaller per-level bonus, and the picker screenshot

Status: done
Blocked by: 03, 04, 05, 06

**What to build:** with every perk in, shrink the flat HP and damage bonus each level gives, so perks carry the rest of the growth. Then capture the picker for the docs, and mark the feature done.

- [x] The flat bonus per level is smaller for both heroes, and the balance sim still lands on its current targets.
- [x] Screenshot: the picker over a night scene at 1280×720.
- [x] `docs/` updated: the game design spec's progression section, and perk cards (039) set to done in the roadmap.
- [x] A hand-play check that perks feel worth picking is added to `.scratch/hand-play-backlog/`.
- [x] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments

- 2026-10-20: done.
  - **Balance.** `balance_sim.gd` now seeds `PerkManager.rng` (1, or `seed=N`) and prints each night's perks. The sim itself is not repeatable: the same config swings by 20+ HP run to run, so every config was run 4&ndash;9 times. The baseline is 02704df (no perks). The "boy at 33/65" seen after ticket 01 was noise: the pre-perk build already ends night 3 anywhere from 1/65 to 29/65, never at the documented 13/65 reliably.
  - **Result:** Leo +5 &rarr; **+3 HP** per level, Nela +4 &rarr; **+3 HP**. Damage stays +1 per level: at +0.5 (every other level) and +0.75 the fighting player lost night 3 in half the runs, so perks don't replace that much damage. Whole numbers kept the code unchanged.
  - Boy HP at each dawn, task 2 (Leo, Nela guarding the fire); "KO" = knocked out, "fire" = campfire out:

    | Run | Night 1 | Night 2 | Night 3 | Outcome |
    |-----|---------|---------|---------|---------|
    | fight, before (02704df, 9 runs) | 27&ndash;39/55 | 4&ndash;40/60 | 1&ndash;29/65, median 17 | 8 wins, 1 KO on night 3 |
    | fight, perks with old +5 (4 runs) | 23&ndash;38/50&ndash;55 | 23&ndash;44/55&ndash;60 | 12&ndash;24/65 | 4 wins |
    | fight, after (+3 HP, 5 runs) | 21&ndash;30/50&ndash;53 | 16&ndash;23/56 | 11&ndash;33/59, median 15 | 5 wins |
    | idle, before (9 runs) | 42&ndash;50/50 | lost 6 of 9 (fire) | the rest lost | all lost, 6 on night 2 |
    | idle, perks with old +5 (4 runs) | 30&ndash;50/50 | lost 1 | lost 2, 1 win | 3 lost, 1 win |
    | idle, after (5 runs) | 42&ndash;50/50 | lost 5 of 5 | &ndash; | all lost on night 2 |
    | 7 nights fight, before (9 runs) | | | | KO on night 7 &times;5, 5 &times;2, 4, 3 |
    | 7 nights fight, perks with old +5 (4 runs) | | | | KO on night 7 &times;4 |
    | 7 nights fight, after (5 runs) | | | | KO on night 7 &times;3, night 3 &times;2 |

    Nobody wins 7 nights in the sim before or after (the history notes say Guard/Repair wins at 1&ndash;10 HP; that is task 1/3, not run here). Rejected: +3 HP with +0.5 damage (fight: 2 of 4 KO on night 3; 7 nights: out by night 5) and with +0.75 (fight: 2 of 4 KO; 7 nights: out by night 4).
  - **Banner overlap.** The HUD's centre banner draws at alpha 0 while a picker is open (`hud.is_banner_hidden()`) and comes back when it closes. The picker's heading now sits on the banner's canvas ribbon, so the world text behind it can't read through, and the player skips its "LEVEL UP!" float text when the picker opens (the heading says it). Smoke: `_run_perk_07_scenario`.
  - **Screenshot.** `screenshots.gd` shot `07c_perk_picker` (a seeded deal over night 1, after `07_night_later`), copied to `docs/design/screenshots/perk-picker.png`. There was no folder for docs screenshots before this one.
  - **Docs.** Game design spec: level-up effects, the per-level table and a perk cards section with the screenshot. Roadmap 039 set to done. Architecture: a `PerkDefinition` sketch. Hand-play: `.scratch/hand-play-backlog/issues/06-perk-cards-feel.md`.
