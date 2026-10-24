# 08: Docs and wrap-up

Status: done
Blocked by: 03, 06, 07

**What to build:** the docs match the code:
- **The architecture doc's save/load section:** the run session and the run config, the profile, Camp Badges, the journal and unlocks.
- **The autoload list:** badges are no longer an autoload.
- **The test strategy:** the unit pass exists, with how to add a unit test.
- **The checks-script notes.**

Then set the spec's `Status:` to done.

- [x] The architecture doc, the test strategy and the checks-script notes describe the run config's rules, the profile's verbs and adapters, and the unit pass.
- [x] The glossary's run config, endless run and run outcome entries still match the code.
- [x] Every ticket is done, and the spec says `Status: done`.
- [x] `tools/check.sh` passes.

## Comments

- 2026-10-24: done. The architecture doc's autoload table drops
  `Badges` (now a static module, like the journal and the other meta
  modules), and its section H describes the run config's builders,
  rules, day chest and save keys, `RunOutcome`, the profile's verbs,
  what the run tells it (`record_stat`, `record_run_end` and its
  `Result`), the `FileStore` / `MemoryStore` adapters, the Endless
  unlock (Chapter 2 won, or the true ending seen), Camp Badges earned
  only by the profile, and the journal and unlocks through the verbs.
  Its testing summary points at the unit pass. The test strategy's
  layer 4 is the unit pass, with a new "Writing unit tests" section
  (shape, checks, `after_each()`, `--unit`, and the trap that a script
  error still ends `unit: PASSED`); the `tools/check.sh` header notes the
  same trap. The glossary's Unlock entry names Endless, and the game
  design spec's Endless unlock matches the code.
