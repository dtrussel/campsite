# Feature 044: Handoff

- **Not yet done:** hand-play the new pace and the auto-build flow. If days feel empty, tune `TimeManager.day_seconds`. If the hero leaves the player's chosen spot to build too eagerly, gate `_tick_auto`'s blueprint pick behind a short idle delay.
- **New buildings:** activate in `_on_built()`, not `_ready()`. Direct children other than `Visual` and the collision shapes are hidden and disabled while the building is a blueprint.
- **Tests that need a working building right away:** instantiate the scene directly (not a blueprint), or call `complete_construction()`.
- **Settings:**
  - `GameSettings` (gameplay) has `auto_attack`.
  - `PostFx` (video) has `blur_level` (0 Off, 1 Soft, 2 Strong).
- **NavSteer** is shared by the hero and the companion. Mobs still steer straight; they could use it too if they get stuck.
