# Feature 025: Painted props

## Goal

Replace the last KayKit props and backdrop with hand-painted models in
the camp's style, so the world has one look.

## Scope

- **`art/props/haunted.py`** (Blender, same kit as `camp.py` and
  `forage.py`, painted bake plus decimation budget):
  - `jack_o_lantern` (carved face with a separate emissive glow mesh)
    and `pumpkin_small`;
  - `camp_lantern` (post, cage, emissive flame);
  - `water_bucket` (staves, iron bands, water surface);
  - `dead_tree_a/b/c` (twisted trunks, twigs, hanging moss);
  - `hill_a/b/c` and `mountain_a/b` (low mounds with clumps of trees,
    only seen at the map edge).
- **World dressing:** `world_dressing.gd` uses the `custom/*.glb`
  versions; scales retuned against screenshots.
- **Icons:** the pumpkin icon is rendered from the painted
  jack-o'-lantern. An unused, KayKit-based `_campfire` helper was
  removed from `render_icons.gd`.
- **Assets:** the KayKit Halloween and Hexagon packs are no longer
  referenced, so they are removed from `game/assets/kaykit/` and
  `tools/fetch_assets.sh`. `CREDITS.md` is updated.
