# 04: Contract and wrap-up

Status: done
Blocked by: 02, 03

**What to build:** the old lifecycle code is gone (contract). The save manager only handles the file: path, version, reading, writing, parse checks and delete; its snapshot is the run session gathering each saving system. The game manager's reset list is deleted. The architecture doc describes saving systems, the run session and the restore order. The spec is set to done.

- [x] The save manager names no building, torch, hero or perk.
- [x] The game manager has no reset list of its own.
- [x] `docs/architecture/software-architecture.md` describes saving systems, the run session and the restore order.
- [x] The spec and every ticket are set to done, with notes under Comments.
- [x] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments

- **2026-10-21, implemented:** `SaveManager` is the file only: path, `VERSION`, `REQUIRED_KEYS`, `serialize` / `write`, `load_save` / `parse` and `delete_save`. Its `snapshot` (the camp presence check), its dawn autosave and its delete-on-run-end moved to `RunSession` (`snapshot`, `save_now`, and the session's `_ready`). `party_of` moved to `GameManager`, which owns the `"party"` key and its Leo-with-Nela fallback.
  - **The reset list is gone:** `GameManager.reset_autoloads` is deleted; `RunSession.reset` leaves build mode itself (it is not run state, so not a saving system).
  - **The dawn autosave** no longer rides a deferred call: `TimeManager.dawn_settled` fires right after every `dawn_started` handler has run, and the session saves there.
  - **Checks:** a validate check (`_validate_run_lifecycle_contract`) fails if `save_manager.gd` names a game system, if `GameManager` has `reset_autoloads` or if `SaveManager` gathers a snapshot. The old-format fixture scenario still passes. A grep found nothing else reading saving systems' internals for saving (the boss reads `burns_out_at_dawn` to snuff torches, which is not saving).
  - **Docs:** `docs/architecture/software-architecture.md` section H now describes the saving systems, the run session, the run config, the restore order and the save file. `GLOSSARY.md` already used these names.
