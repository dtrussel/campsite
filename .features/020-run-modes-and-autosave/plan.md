# Feature 020: 3- or 7-night runs, autosave at dawn

## Goal

Longer runs, and a way to stop and come back later. This covers roadmap
Phase 8 (save/load), in the form the user chose: autosave, no save menu.

## Scope

- **Title screen:**
  - **3 Nights** and **7 Nights** buttons;
  - **Continue** when an autosave exists (the tooltip shows the night).
- **Waves for nights 4–7** extend on their own: imps 13, 15, 17, 19;
  beasts 3, 4, 5, 6.
- **HUD moons, the goal picture and the end-screen stars** shrink for
  7 nights.
- **`SaveManager` autoload** (`user://save.json`, version 1):
  - It saves one frame after each dawn, while the run is still going.
  - It holds the run length and day, the inventory, the campfire (HP
    and hearth), and every building (type, position, facing, HP, and
    snaps for traps).
  - It holds Leo's and Nela's XP and upgrades, Nela's task, and the run
    stats.
  - Continue rebuilds all of that and starts the morning after the
    saved dawn.
- **Save life cycle:**
  - a won or lost run deletes its save;
  - a new run (3 or 7, or Again) replaces it;
  - a damaged save, or one from another version, is ignored.

## Out

- Several save slots.
- Saving the time of day in the middle of a day.
- Resource nodes and pickups (they reset).
