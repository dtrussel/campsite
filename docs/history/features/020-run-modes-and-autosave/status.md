# Feature 020: Status

**Done** (pending a human playtest).

## 2026-09-29

- **Built:**
  - the title buttons (3 or 7 nights, Continue);
  - `SaveManager` (snapshot, serialize and parse, apply, autosave,
    delete);
  - `GameManager.start_run(nights)` and `continue_run()`;
  - `TimeManager.start_run(first_day)`;
  - `ProgressionManager.restore_xp`;
  - UI that scales for 7 nights.
- **`tools/check.sh` passes.** The smoke test checks that:
  - an autosave is written after night 1, with the inventory;
  - winning or losing deletes the save;
  - corrupt and other-version saves are refused, and a save round-trips
    through JSON;
  - Continue restores the day, inventory, buildings, campfire and
    hearth, Leo's XP and stick, and the stats;
  - a 7-night run has 7 moons, and night 7 has 19 imps and 6 beasts.
- **Screenshot:** the title with Continue and the 3/7 buttons.
- **Balance sim:** 7 nights, see decisions.md.
