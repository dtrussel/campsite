# Feature 024: Decisions

- **A shader for foliage only.** Characters, props and rocks keep the
  StandardMaterial path. The foliage shader mirrors that material's
  settings so it looks the same when still.
- **The sway is sized per mesh** (`base_y` and `height` come from the
  mesh bounds, cached per material and bounds). Short bushes barely
  move; tall trees sway more at the top.
- **CPUParticles3D** for ambience, because it is safe on the GL
  Compatibility renderer the game targets.
- **Kept subtle.** Numbers were raised once after screenshots; they
  stay low enough never to hide imps at night.
- **Silent footsteps.** Step sounds on every stride would be noisy for
  kids. Footstep bursts are exempt from the "every burst has a sound"
  check through an explicit list.
