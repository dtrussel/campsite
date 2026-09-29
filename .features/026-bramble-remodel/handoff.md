# Feature 026: Handoff

## Knobs

- **Shape and paint:** `art/characters/bramble_beast.py` holds the
  radii, masks, colours and extras. Rebuild with:

  ```
  tools/build_art.sh characters/bramble_beast
  ```

  `BAKE_SIZE=512` gives a fast draft and `CLAY=1` gives clay views.
- **Poses and timing:** `art/characters/beast_anims.py` (see its sign
  cheat-sheet). If you move the slam's impact frame, update
  `attack_hit_delay` in `resources/mobs/bramble_beast.tres` (frame / 24
  / 1.6).
- **Dodge window:** `DODGE_MARGIN` in `mob_controller.gd`.
- **Feedback:** the `bramble_slam` burst in `fx.gd` and the
  `bramble_slam` sound in `art/audio/sfx.py`.

## Next

- The same approach could give the imp and the gremlin their own
  clips, which would remove the last KayKit animations from the mobs.
