# Feature 005 — First playtest build

## Goal

Turn the Phase 0–6 prototype into something a person with no Godot
knowledge can unzip, launch, and play through a complete 3-night run,
with a clear win or loss. Close the gather → craft → defend loop with
roadmap Phase 7 (crafting).

## Why it matters

Features 000–004 were written without ever running the project. The
first headless run showed the main scene **did not load at all**
(cyclic resource references). Fiber had no source, so fences could
never be built. There was no win condition, no restart, no pause, no
menus, and nothing could hurt the player. We need real player feedback
before building more systems, and that requires a stable, readable,
self-explanatory build.

## Scope

### In scope
- **Stabilise:**
  - fix load and runtime errors;
  - make data loading export-safe;
  - name the physics layers;
  - headless validation and smoke test.
- **Run flow:**
  - title screen, pause menu, controls overlay, end screen;
  - win after 3 nights, loss when the campfire goes out or the boy is
    knocked out;
  - restart that resets every autoload.
- **Threat:**
  - boy and Sibling have HP;
  - imps chase characters within an aggro radius;
  - the Sibling is knocked out until dawn;
  - day-time regen, and eating berries heals.
- **Feedback:**
  - hit flash, floating numbers, HP labels, swing ring;
  - HUD HP bars, event banners, gather progress.
- **Crafting (Phase 7):**
  - `CraftingRecipe` and `CraftingManager`;
  - campfire crafting panel;
  - a Torch that slows and singes imps until dawn.
- **Content fixes:**
  - bonus yields (Leaves, Fiber) and a Pine (Resin);
  - Watch Post slingshot;
  - building rotation;
  - larger ground.
- **Balance pass** (first cut).
- **Windows export, tester package**, playtest script, questionnaire,
  and an event log.

### Out of scope
- Save/load (Phase 8).
- Audio (no assets yet; hooks noted in handoff).
- New mobs, companions, or buildings beyond the fixes above.
- Controller support, rebinding, settings menu.

## Deliverables

See `handoff.md` for the file list.
