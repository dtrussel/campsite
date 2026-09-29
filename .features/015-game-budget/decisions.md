# Feature 015: Decisions

- **Budget: about 35k triangles per kid, down from about 120k.** Chosen by the user from ~35k (recommended), ~20k, or keeping ~120k.
  - The kids are about 80–100 px tall in play.
  - The inverted-hull outline draws every mesh twice.
  - Hand-painted reference games use 7–15k.
- **High-to-low bake instead of re-authoring low meshes.**
  - The dense build stays the source of truth: voxel cloth with folds, the 100-ring head loft, per-vertex colours.
  - `chibi.lowpoly` decimates each mesh to its budget.
  - `paint_bake.paint(high=...)` paints the dense copy, then transfers the texture with a selected-to-active colour bake.
  - The dense copy is painted with the low mesh hidden, so it can't shadow the copy's AO.
- **The head is decimated, not lofted at lower density.** A 44×48 loft (4.2k) lost more of the lip and chin forms than collapse-decimating the 100×96 loft to 4.5k. The painted results were equal.
- **Budgets per mesh:**
  - Leo: body 20k, head and ears 4.5k, hair 9k, stick 1.5k.
  - Nela: body 18k, head and ears 4.5k, hair 10k, lantern 1.5k, bunny 1.5k.
- **Textures: 1024, down from 2048 (user decision).**
  - The kids are under 100 px on screen, including the title backdrop, and the portraits are 128 px.
  - A 1k head texture still gives the face about 500 texels across.
