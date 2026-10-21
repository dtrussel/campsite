# Feature 048: Little golem, second pass

## Why

The first little golem (feature 047) read poorly next to its sheet
(`art/reference/concept-2026-10/18_little_golem_sheet.webp`):
- a sphere head with googly white eyes ringed in rope;
- a bucket-like barrel body;
- short arm stubs floating off the body, and a neck gap;
- short pegs on top.

## What

Rebuild `art/characters/little_golem.py` from the sheet, following
`docs/design/character-modelling.md`:
1. Measure the sheet's front and side views as fractions of height.
2. Add a `MEASURE=1` mode that prints the model against the sheet and
   renders silhouettes.
3. Iterate with `QUICK=1` clay views until the landmarks are within about
   0.02, then bake.

The node names and pivots stay, so `LittleGolem` keeps working. The
crescent becomes its own `Body_Moon` glow, and the curled-up pose tucks
the longer arms in.
