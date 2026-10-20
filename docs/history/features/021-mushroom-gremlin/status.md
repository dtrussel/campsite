# Feature 021: Status

**Done** (pending a human playtest).

## 2026-09-29

- **Built:** model, scene and data; thief AI (steal, flee, escape, drop
  loot); sneak waves; icon-style loot pickups; HUD banners; 3 sounds and
  2 effects.
- **`tools/check.sh` passes.** The smoke test checks:
  - the wave make-up (0, 1, 1 gremlins, early in the wave);
  - that a gremlin steals 4 of the most plentiful resource and leaves
    the rest;
  - that a caught one drops its loot, and walking over it gets the loot
    back;
  - that an escaped one keeps the loot.
- **Night screenshot:** the gremlin's spotted cap reads well from the
  game camera, and the loot pickup shows the icon and count.
