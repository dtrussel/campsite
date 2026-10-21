# Feature 019: Status

**Done** (pending a human playtest).

## 2026-09-29

- **Built:**
  - wall, crate and table: art (`art/props/forage.py`), scenes and data;
  - caps in `ResourceManager`;
  - the station-aware crafting panel;
  - 4 table recipes and the bandage item;
  - 7 icons and 2 sounds.
- **`tools/check.sh` passes.** The smoke test covers:
  - the caps (20, then 40 with a crate, and keeping items after losing
    the crate);
  - the wall's HP and a beast's 12-damage hit on it;
  - table-locked recipes;
  - the stick, the slingshot, the bandage waking Nela, and the trap
    refill.
- **Screenshots reviewed:** the table panel, the gold full-stash count,
  and the 7 build chips.
