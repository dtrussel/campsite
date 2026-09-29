# Feature 020: Decisions

- **Autosave at dawn, chosen by the user.** Kids never lose more than
  one day, and there is no save menu to learn. Dawn is also a clean
  state: the wave is over, torches are gone and Nela is awake.
- **The save is taken one frame after dawn** (`call_deferred`), so it
  captures the state after every dawn handler: the win check, Nela
  waking up, dawn XP, and torches burning out.
- **Continue starts the next morning** (`TimeManager.start_run(day + 1)`)
  instead of the mid-dawn moment.
- **Progress is restored by replaying XP** (`ProgressionManager.restore_xp`).
  Level-ups then apply their stat boosts exactly as in play. An
  `is_restoring` flag mutes the "LEVEL UP!" fanfare.
- **Buildings join a `buildings` group** (`Building.BUILDINGS_GROUP`) so
  the save can list them. The name avoids clashing with the
  `SnapTrap.GROUP` and `CraftingTable.GROUP` constants in subclasses.
- **Validation over partial loading.** A save with the wrong version or
  missing keys is refused as a whole.
- **Tests use their own save path** (`SaveManager.set_save_path`), so
  running `tools/check.sh` never deletes a player's save.

## Balance (7 nights, balance sim `-- <task> fight 7`)

- Guard and Repair tasks both win 7 nights, but Leo ends nights 5 and 7
  at 1–10 HP. That is hard but possible without fences, traps or
  snacks, which real players have.
