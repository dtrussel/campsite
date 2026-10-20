# Feature 020: Handoff

## Current state

- The title offers 3- or 7-night runs.
- The game autosaves every dawn, and Continue resumes the next morning.
- Version: 0.15.0-playtest1.

## Key APIs

- **`SaveManager`:**
  - `has_save()`, `load_save()`, `save_now()`, `snapshot()`, `apply()`,
    `delete_save()`;
  - `serialize()` and `parse()` (static);
  - `set_save_path()` (tests);
  - `VERSION`. Bump it when the snapshot changes shape.
- **`GameManager`:** `start_run(nights = 0)` (0 keeps the length),
  `continue_run()`.
- **`TimeManager`:** `start_run(first_day = 1)`.
- **`ProgressionManager`:** `restore_xp()`, `is_restoring`.
- **Buildings:** `Building.BUILDINGS_GROUP`.
- **Sim:** `balance_sim.tscn -- <task> fight [no_beasts] [7]`.

## Adding saved state later

1. Add it to `snapshot()` and `apply()`.
2. Bump `VERSION`; old saves are then ignored, not half-loaded.
3. Extend the continue scenario in `smoke_run.gd`.

## Next ideas

- An endless mode.
- The Mushroom Gremlin, which steals resources and so makes Storage
  Crates matter.
- The art track: Imp remodel, animations, painted environment.
