# Feature 028: Handoff

## Knobs

- **Shape and paint:** `art/characters/shadow_imp.py`, which holds:
  - `EYE_X`, `EYE_Z`, the eye and pupil sizes in `eyes()`;
  - `bat_ear()` (length, width, angle);
  - `horns()`, `wings()` (finger tips) and `tail()` (the S points);
  - the colours at the top.

  Rebuild with:

  ```
  tools/build_art.sh characters/shadow_imp
  ```

  `BAKE_SIZE=512` gives a fast draft and `CLAY=1` gives clay views.
- **Poses:** `art/characters/imp_anims.py` (`STANCE` is the crouch). If
  you change the swipe timing, keep the slash near frame 6, since the
  imp's damage is instant.
- **Filmstrip:**

  ```
  tests/sim/anim_frames.tscn -- <dir> imp
  ```

  The `beast` and `gremlin` modes work the same way.

## Status of the mobs

All three mobs now have original models and clips. KayKit supplies only
the Skeleton Minion rig, the kids' rig and animations, and the axe icon.
