# Feature 023: Move and act together (animation layering)

## Goal

Characters played one clip at a time: an attack replaced the run, so
Leo's legs froze mid-stride whenever he swung. Layer the animation so
characters can move and act together, blend walking into running by
speed, and lean into turns.

## Scope

- **`CharacterVisual` builds an AnimationTree in code**, and keeps the
  same public API, so no gameplay script changed:
  ```
  BlendSpace1D "loco" (idle . walk . run) -> TimeScale
    -> OneShot "upper" (spine, chest, head, arms, hands)
    -> OneShot "full" (whole body)
  ```
- **Walk and run.** The kids now have a `&"walk"` clip (Walking_A): idle
  → walk (1.6 m/s) → run (from about 3.5 m/s). The run still speeds up
  or slows down with the character.
- **Actions:**
  - `play_action` plays on the **upper body while moving** (the legs
    keep the gait), and on the **whole body when standing** (chops keep
    their full-body wind-up);
  - a new action replaces one playing on the other layer;
  - `play_final` and `unlock` (death, knock-out, get-up) bypass the tree
    and hold the last frame, as before.
- **Lean.** A roll of up to about 10° into turns, proportional to the
  turn rate, and a slight forward tilt while moving; both ease back
  upright.
- **Filmstrip tool:** `tests/sim/anim_frames.tscn` (Xvfb) captures Leo
  swinging while running, then turning.
