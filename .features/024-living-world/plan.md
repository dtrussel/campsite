# Feature 024: Living world

## Goal

The world was static apart from the grass. Make it feel alive without
adding clutter: wind in the trees, drifting leaves and pollen by day,
fireflies at night, and dust kicked up by running feet.

## Scope

- **Foliage wind.**
  - `shaders/painted_foliage.gdshader`: the painted look (baked texture,
    wrap lighting, matte, soft rim) plus a vertex sway. Crowns lean with
    slow gusts and leaves flutter; the trunk stays still (sway fades in
    from 30% of the mesh height).
  - `Stylize` uses it for painted meshes under a node with the
    `foliage` meta.
  - Tagged: border trees, pines and bushes (`world_dressing.gd`), and
    the Visual of the tree, pine, berry-bush and mushroom-patch resource
    nodes.
- **Ambient particles** (`scripts/world/world_ambience.gd`, a node in
  `TestWorld.tscn`, using CPUParticles3D):
  - **day and dawn:** autumn leaves spin down across the meadow, and
    pollen motes float around the camp;
  - **sunset and night:** fireflies wander low over the grass and
    twinkle.
  - They switch on the TimeManager phase; running particles finish
    their lives, so the change is a soft crossfade.
- **Footstep dust.**
  - `CharacterVisual.footstep_dust` and `step_distance` puff a burst at
    the feet while running.
  - Leo and Nela kick up small `step_dust`; the Bramble Beast kicks up
    heavy `step_thud`.
  - Both are silent bursts (`Fx.SILENT_BURSTS`, which the validator
    accepts).
