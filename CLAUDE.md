# Campsite: notes for Claude

A Godot 4.3 game (`game/`) with procedural Blender art (`art/`). Docs
live in `docs/`, and feature folders in `.features/NNN-slug/`. Run the
checks with `tools/check.sh`.

## Read before you start

- **Modelling a character** (a hero, Mum, an NPC or a creature in
  `art/characters/`), or changing its proportions, face, hair or
  clothes: read
  [`docs/design/character-modelling.md`](docs/design/character-modelling.md)
  first. It covers the measured render-and-compare loop, the proportion
  targets, the tools (`art/lib/measure.py`, `MEASURE=1`, `HEAD_ONLY=1`)
  and the gotchas.
- **Any art work:** [`art/README.md`](art/README.md) for the pipeline
  and budgets, and
  [`docs/design/art-direction.md`](docs/design/art-direction.md) for the
  look.
- **Story content:** [`docs/design/story.md`](docs/design/story.md).
