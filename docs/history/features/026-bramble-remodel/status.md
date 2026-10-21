# Feature 026: Status

**Done.**

## 2026-09-29

- **Model:** rebuilt after the concept at 9.6k triangles with the eyes,
  using a 1024 px high-to-low bake. Reviewed in Blender from the front
  3/4, side and back, and in clay.
- **Draft fixes:**
  - the arms had merged into the torso and the legs did not separate:
    slimmer limbs, wider legs, arms angled out;
  - moss strands floated at the T-pose arm positions: the raycast now
    starts from inside the body;
  - the eyes blew out to white: smaller and warmer;
  - the moss was too heavy and too neon: toned down.
- **Clips:** reviewed as Blender frames and as in-game filmstrips
  (`tests/sim/anim_frames.tscn -- <dir> beast`). The slam impact and
  the roar's chest thumps were re-posed after the first review.
- **Game:** a telegraphed slam, the `bramble_slam` burst and sound, a
  roar after flattening a building, `model_scale` 1.1, and
  `reference_speed` and `step_distance` retuned to the new stride.
- **`tools/check.sh` passes.** New smoke checks:
  - the beast model has all its clips;
  - no damage during the windup;
  - the damage lands at impact;
  - Leo dodges by stepping away.
- **Balance sim** (3 nights, fighting): won with the fire at 106/150.
