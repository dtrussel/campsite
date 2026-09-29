# Feature 027: Status

**Done.**

## 2026-09-29

- Rebuilt the model after the concept: 7.9k triangles with the eyes,
  1024 px bake. Reviewed in Blender from the front 3/4, side and back,
  and in clay.
- Keyed seven clips. The crouch and the hand droop were deepened after
  the first review.
- **In-game filmstrip** (`tests/sim/anim_frames.tscn -- <dir>
  gremlin`) of spawn, sneak, grab, flee and death. The cap colour and
  size, the ear length and the scale were tuned from it.
- **`tools/check.sh` passes.** New smoke checks:
  - the model has all its clips;
  - a fleeing gremlin uses the scurry clip.
- **Balance sim** (3 nights): unchanged, won with the fire at 102/150.
- Refactor check: after moving the helpers to `rig_anims.py`, the
  beast's animation data is identical.
