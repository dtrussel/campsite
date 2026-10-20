# Feature 033: Decisions

- **Artwork is generated, not drawn by hand.** A seeded Pillow script (`art/ui/hud_kit.py`) keeps the art reproducible and small (7 PNGs, under 100 px each), like the other generated art.
- **Textures tile.** The StyleBoxTextures use `TILE_FIT`, so big menu plates keep the grain at its proper scale.
- **Old colour names stay.** `UiKit.COLOR_NAVY`, `COLOR_GOLD` and `COLOR_TEAL` remain as aliases of the new palette, so existing call sites restyle without edits.
- **`_moons` keeps its name**, because the smoke test checks the 7-night run through it.
