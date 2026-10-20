# Feature 023: Handoff

## API

- **New:** `CharacterVisual.is_moving()`, `active_action_layer()` (for
  tests), `get_animation_tree()`.
- **New exports:** `walk_speed`, `lean`.
- **Upper-body bones:** `UPPER_BONES`.

## Review

- `xvfb-run -a godot --path game --rendering-driver opengl3 res://tests/sim/anim_frames.tscn -- <dir>`

## Next

- Feature 024: the living world (wind, fireflies, leaves, footstep dust).
