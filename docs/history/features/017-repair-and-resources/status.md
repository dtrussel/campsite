# Feature 017: Status

**Done** (pending a human playtest).

## 2026-09-29

### Built

- Repair: Leo's command, the hover and cursor, Feed the Fire, and Nela's
  Repair task with its HUD button and the V key.
- Clay pits, mushroom patches and junk piles, placed in `TestWorld`.
- Glow Shard pickups from imps.
- Berry Snack, Stone Hearth, Snap Trap and Glow Lantern.
- Art, all within the 1.4k-triangle budget: 11 new props, 8 new icons
  and a hammer glyph.
- 6 new sounds, 15 files.
- HUD, crafting panel and help screen updates.

### Verification

- **`tools/check.sh` passes.** The validator now also checks:
  - recipe effects and their result icons;
  - mob drop items;
  - that every needed item is obtainable. Glow Shards count as
    obtainable through the mob drop.
- **The smoke test** gathers all three new resources and checks:
  - a repair tap, Leo's repair command, and Nela repairing the campfire;
  - Feed the Fire (disabled at full HP), the Stone Hearth (once only),
    and cooking and eating a snack;
  - a snap trap catching an imp;
  - the lantern slowing and zapping an imp, and not burning out;
  - shard drops over a full run (8 for 26 kills).
- **Screenshots (Xvfb) reviewed:**
  - the crafting panel (4 recipes);
  - the camp with the hearth, trap, lantern and shard;
  - the lantern build preview with its range ring and the 1–4 chips;
  - the night view;
  - the help screen.
- **Balance sim** (`balance_sim` with task 2, fight) runs unchanged. It
  does not use the new systems.
