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

## 2026-09-29 (follow-up)

- Lowered the camera to 48°, gave the gremlin a smaller cap, raised
  its head, and made the eyes stronger and the skin darker.
- Checked with a new filmstrip shot of a gremlin facing the camera at
  gameplay zoom (`gremlin_face_0`): the eyes, nose and ears read under
  the cap.
- `tools/check.sh` passes; the regular screenshots look right at the
  new angle.
