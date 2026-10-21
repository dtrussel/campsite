# 01: The profile store

Status: ready-for-agent
Blocked by: none

**What to build:** a profile that keeps a player's progress across runs, in its own file next to (never inside) the run save. Any module can read a key with a default, write a key (saved straight away), ask whether a key exists, record a best value (told whether it beat the stored one), and delete the whole profile. A missing or corrupt file loads as an empty profile and is rewritten on the next write. Tests point it at a temporary path. Nothing uses it yet beyond its own check.

- [ ] Validate: set/get survives a reload from disk.
- [ ] Validate: record best returns true for a first and a higher value, false for a lower one.
- [ ] Validate: a corrupt file and a missing file both load as empty, without errors.
- [ ] Validate: delete empties the profile and removes the file.
- [ ] No test touches the real user folder.
- [ ] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments
