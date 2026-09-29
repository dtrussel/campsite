# Feature 027: Handoff

## Knobs

- **Shape and paint:** `art/characters/mushroom_gremlin.py`, which
  holds:
  - the cap (`CAP_R`, `CAP_H`, `CAP_TILT`, colours);
  - the ears (`length` and `width` in `ear()`);
  - the face (`EYE_*`, `_brow_z`, `_mouth_z`).

  Rebuild with:

  ```
  tools/build_art.sh characters/mushroom_gremlin
  ```

  `BAKE_SIZE=512` gives a fast draft and `CLAY=1` gives clay views.
- **Poses:** `art/characters/gremlin_anims.py` (`SNEAK` is the base
  crouch; `DROOP` is the hand droop).
- **Camera angle:** `pitch_degrees` in
  `game/scripts/utilities/camera_follow.gd` (48°).
- **In game:** `model_scale`, `reference_speed` and `step_distance` in
  `MushroomGremlin.tscn`.

## Next

- The Shadow Imp is the last mob on KayKit clips. `rig_anims.py` makes
  giving it its own clips a small job.
