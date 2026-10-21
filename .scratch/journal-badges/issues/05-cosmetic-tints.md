# 05: Cosmetic tints

Status: done
Blocked by: 02

**What to build:** badges unlock tent colours and hero outfit tints, applied through the existing `Stylize` tint hook. Hero select gets an outfit row showing the unlocked tints, and the choice is kept in the profile.

- [x] Smoke: an unlocked tint can be picked and is applied to the hero in the run.
- [x] Locked tints can't be picked.
- [x] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments

- **2026-10-21, done:** built test-first; the smoke `cosmetic tints scenario` covers every box above.
  - `Cosmetics` (`scripts/meta/cosmetics.gd`) holds the tints as data: 6 outfits (Ranger default, then Moss / First Night, Ember / Fire Keeper, Dusk / Night Owl, Moonlight / Lantern Lighter, Mushroom / Gremlin Catcher) and 5 tent colours (Canvas default, then Berry / Builder, Pine / Chapter 1, Night Sky / Chapter 2, Sunrise / Both Heroes). Picks live in the profile: `cosmetics.outfit.<hero>` (one per hero, so the companion wears her own) and `cosmetics.tent`; a pick whose badge is gone reads as the default. The validator checks every named badge exists.
  - `Stylize` now applies `style_tint` to painted materials too (it only tinted KayKit ones). The rock and hill tints in `world_dressing.gd` and `model_gallery.gd` were no-ops on the painted models, so they are dropped to keep the world's look unchanged.
  - The tint goes on the hero's outfit mesh only (`HeroDefinition.outfit_mesh`: "Leo", "Nela"), not the head or hair, through `CharacterVisual.outfit_mesh/outfit_tint` (set by `HeroBody`). The tent is in group `tent` and wears `Cosmetics.tent_tint()`.
  - Hero select: a self-contained outfit row under the goal (`_build_outfit_row`, `_refresh_outfit_row`): swatches for the picked hero's outfits and the tent; locked ones are dimmed, disabled and name their badge. The stage hero previews the outfit.
