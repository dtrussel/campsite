# Feature 028: Status

**Done.**

## 2026-09-29

- Rebuilt the model after the concept, silhouette first, then the face,
  then the paint: 8.8k triangles with the eyes, 1024 px bake. Reviewed
  in Blender from the front 3/4, side and back, and in clay.
- **Face fixes after review:**
  - the sockets were too deep (a dark noisy patch between the eyes);
  - the pupils were buried in the enlarged eyes;
  - the glow blew out to white.
- Keyed six clips (idle, run, attack, hit, spawn, death) with
  `rig_anims.py`.
- Re-rendered `portrait_imp` (the wave counter and HUD). Portraits can
  now take their own clips, so the imp poses in its idle instead of a
  T-pose.
- **`tools/check.sh` passes.** New smoke checks:
  - the imp model has all its clips;
  - a defeated imp's corpse is cleared.
- **In-game filmstrip** (`tests/sim/anim_frames.tscn -- <dir> imp`) and
  the regular screenshots: the imps read at the game camera (eyes,
  ears, wings, tail).
  - Under software rendering the capture runs at about 1 fps, so game
    time barely moves between shots. The corpse check lives in the
    smoke test for that reason.
- **Balance sim** (3 nights): unchanged, won with the fire at 114/150.
