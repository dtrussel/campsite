# Feature 047: Decisions

- **Paintings are data, built by a script.**
  - The sources (q95 WebP, about 5 MB for all 12) stay in `art/ui/source/story/`.
  - The game gets 1600×900 q90 copies, the same size as the loading screens.
  - Re-running `story_art.py` rebuilds them all, the retouch included, so a new painting only needs dropping in.
- **The cold lantern is a retouch, not a re-paint.**
  - A soft rounded-box mask over the glass replaces the flame with dim smoky glass, keeping a little of the painting's detail; the warm halo is calmed.
  - The lit original stays as `c2_1_lit.webp`, so a proper painting can replace it.
- **Kids' faces are optional per line.**
  - A `face` on a hero line needs `assets/ui/story/<hero>_<face>.png`; the validator fails a face that doesn't exist.
  - Without one, the hero portrait shows. So Leo's lines carry no faces until his are painted.
- **The Moon Lantern's lamp is open in the model.**
  - Godot adds a faint glass box, so the shards (one per stage), the moon core and the light inside show.
  - The carved crescent's glow is a code-drawn crescent decal that wakes in the second half of the stages and blazes at the top. It is driven by the same `_set_glow` as the core, including the Moon-Eater's drain.
- **The little golem is its own model and script.**
  - It replaces the old trick of a quarter-scale Moon-Eater.
  - It keeps the climb-out tween and the walk to the fire.
  - It is scaled by `1 / model_scale`, so it stays its real size (about 0.75 m) under the Moon-Eater's visual scale.
- **Loading screens use only paintings that give nothing away:** the camping evening and the Moon Lantern.
