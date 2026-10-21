# 01: The profile store

Status: done
Blocked by: none

**What to build:** a profile that keeps a player's progress across runs, in its own file next to (never inside) the run save. Any module can read a key with a default, write a key (saved straight away), ask whether a key exists, record a best value (told whether it beat the stored one), and delete the whole profile. A missing or corrupt file loads as an empty profile and is rewritten on the next write. Tests point it at a temporary path. Nothing uses it yet beyond its own check.

- [x] Validate: set/get survives a reload from disk.
- [x] Validate: record best returns true for a first and a higher value, false for a lower one.
- [x] Validate: a corrupt file and a missing file both load as empty, without errors.
- [x] Validate: delete empties the profile and removes the file.
- [x] No test touches the real user folder.
- [x] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments

- **2026-10-21, implement:** done.
  - **The autoload:** `Profile` (`game/scripts/core/profile.gd`, registered right after PlaytestLog) on `user://profile.json`.
  - **The interface:** `get_value(key, fallback)`, `set_value` (saved at once), `has_value`, `record_best` (true only for a first or strictly higher value), `delete`, `reload`, and `set_path` / `file_path`. The names avoid Node's own `get`, `set` and `get_path`.
  - **Bad files:** a missing or corrupt file loads as empty without printing an error, because it parses with a `JSON` instance rather than `JSON.parse_string`.
  - **Tests:** `_validate_profile` in `tools/validate_project.gd` runs the four checks on `user://validate_profile.json`, then points the profile back. The smoke run points it at `user://smoke_profile.json`. Like the existing save and story tests, these test files sit in `user://`, but never at the player's profile path.
  - **Users:** nothing else uses the profile yet; ticket 02 moves story beats onto it.
