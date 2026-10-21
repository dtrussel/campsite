# 01: The run session and run config

Status: done
Blocked by: hero-core (all tickets done)

**What to build:** one run session starts a run from a run config, continues a run from saved data, resets, and signals `restore_finished`. In this first ticket it wraps today's code (expand), so nothing else changes yet. The run config carries the party, the chapter goal, the perk and loot seeds and the perk auto-pick time. The smoke run starts and continues runs through the session: no scenario writes the pending-save field, and no scenario seeds random generators by hand. A save written by today's build is checked in as a fixture.

- [x] Smoke: every save and Continue scenario goes through "continue from".
- [x] Smoke: seeds and the auto-pick time come from the run config.
- [x] Smoke: the checked-in old-format save loads with every field intact.
- [x] Nothing outside the game manager writes its pending-save field.
- [x] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments

- **2026-10-21, implemented:** a `RunSession` autoload (`scripts/core/run_session.gd`, last in the autoload list) and a `RunConfig` (`scripts/core/run_config.gd`: party, nights, perk and loot seeds, auto-pick time; `RunConfig.current()` for the next run). The session has `start(config, open_scene)`, `continue_from(data, config, open_scene)`, `reset(config)`, `snapshot()`, `restore_pending()` and `restore_finished`. It owns the pending save (GameManager's `_pending_save` is gone); `GameManager.start_run` / `continue_run` / `go_to_title` and `SaveManager.save_now` go through it. For now it wraps today's code: `reset` calls `GameManager.reset_autoloads()` (the old reset list, made public), and the restore calls `SaveManager.apply`, starts the clock, then emits `restore_finished` deferred, after the deferred perk top-ups.
  - **For 02 and 03:** list your saving systems in `RunSession._autoload_systems()` (02) and `_world_systems()` (03); `saving_systems()` walks them in the declared order. `load_state` runs before the leftover `SaveManager.apply`, and `snapshot()` merges each `save_state()` over `SaveManager.snapshot()`.
  - **Smoke:** `_start_fresh_run(config)` and `_continue_from(data, config)` go through the session; `_config(auto_pick, perk_seed, loot_seed)` carries the seeds. Continue now takes the party and run length from the save (the hero and continue scenarios check it). One by-hand seed remains: perk 01 searches for a deal seed that offers Quick Hands mid-run; it is a deal search, not run setup.
  - **Fixture:** `game/tests/fixtures/save_v2_day1.json`, written by the build before this change (inventory, hearth, a built fence and a paid half-built watch post, party, XP, signature, task, perks, stats, lantern shards, an Ember Heart torch). `_run_old_save_scenario` continues it and checks each field, and that saving again keeps every key.

