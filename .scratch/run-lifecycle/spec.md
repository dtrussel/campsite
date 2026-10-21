# Run lifecycle

Status: ready-for-agent

Split into tickets in `issues/` (01&ndash;04); the `Blocked by:` lines give the order. From the 2026-10-21 architecture review, candidate 2 (saving systems and a run session). Rough size: **L**. Blocked by: hero-core. It blocks endless mode and journal badges.

## Problem Statement

A run's state is spread across several autoloads and many scene objects. Starting, saving, continuing and resetting a run are written as separate lists in separate places:
- **Resetting:** a reset list in the game manager.
- **Saving:** a save list that reads each system's internals, including metas, private refresh methods, duck-typed fields and torch rules.
- **Restoring:** the order is held together by a global restoring flag, a deferred perk top-up and the order of autoloads in the project file.

Nothing checks that the lists agree, and they already don't:
- **Never reset on a new run:** the perk clock and perk random generator, the loot random generator and the crafting state.
- **Not saved:** the shard pity counter, so it is lost on Continue.
- **A wrong promise:** the save file's header says trap snaps are saved, and they aren't.

For the player, this shows up as small things lost on Continue, and as state from the last run leaking into the next. For the people changing the code, every feature that adds run state has to touch four or more places. Perk cards did, and its review found two save bugs in exactly those places. Endless mode and journal badges are next, and both add run state. The smoke test continues a save by writing a private field on the game manager, and has to remember to seed random generators by hand.

## Solution

Each **saving system** (anything that holds run state) saves, loads and resets itself. One **run session** owns the run's lifecycle:
- start a run from a run config;
- continue a run from saved data;
- reset;
- announce when a restore has finished.

It walks the saving systems in one declared order. The save manager shrinks to the file itself: reading, writing, the version and the parse checks.

For the player, nothing changes except that the bugs above are fixed: the pity counter survives Continue, and nothing leaks from one run into the next. A save from before the change still loads.

## User Stories

1. As a player, I want everything about my run to come back on Continue, so that a reload never changes my odds or my camp.
2. As a player, I want the shard pity counter to survive Continue, so that quitting doesn't reset my luck.
3. As a player, I want a new run to start clean, so that nothing from my last run (perk timers, crafting state, random sequences) carries over.
4. As a player, I want my saves from before this change to keep loading, so that I don't lose a run in progress.
5. As a player, I want blueprints, half-built buildings and their refunds to come back as they were, so that Continue is faithful.
6. As a player, I want Ember Heart torches and their remaining dawns to come back, so that my perks keep their value.
7. As a player, I want my campfire's and buildings' HP to show correctly right after Continue, so that the HUD never shows stale numbers.
8. As a player, I want a level-up earned just before the dawn autosave to still give me its card after Continue, so that no card is lost.
9. As a maintainer, I want a new piece of run state to be saved, loaded and reset in the module that owns it, so that I touch one file.
10. As a maintainer, I want the restore order written down in one place, so that I don't depend on autoload order or deferred calls.
11. As a maintainer, I want a "restore finished" signal, so that follow-ups like the perk top-up have a clear hook.
12. As a maintainer, I want the save manager to know nothing about buildings, torches or heroes, so that its job is only the file.
13. As a maintainer, I want spawned objects (buildings, blueprints, torches) to be rebuilt by their own module, so that their metas and legacy fallbacks live next to the code that reads them.
14. As a maintainer, I want legacy save fallbacks (old signature names, a missing paid cost) kept in the module they belong to, so that old saves stay supported without clutter.
15. As a maintainer adding endless mode, I want its flag saved and reset by declaring it once, so that endless can't leak into a story run.
16. As a maintainer adding journal badges, I want the run's stats to save through the same path, so that badge checks see the same numbers after Continue.
17. As a coding agent, I want one entry point for "start", "continue" and "reset", so that I don't have to read four files to understand a run.
18. As a coding agent, I want the run config to carry the seeds and the auto-pick time, so that I can reproduce a run exactly.
19. As a test author, I want to continue a run by passing saved data to one public call, so that I stop writing private fields on the game manager.
20. As a test author, I want to check each saving system on its own, without a scene, so that a save bug points at one module.
21. As a test author, I want a check that every saving system resets to a fresh state, so that a forgotten reset fails a test instead of a playtest.
22. As a test author, I want a fixture of today's save format that must still load, so that compatibility is guarded.
23. As a test author, I want seeds set through the run config, so that every scenario is deterministic without extra lines.

## Implementation Decisions

- **The saving-system interface** has three parts:
  - **save state:** returns a dictionary;
  - **load state:** takes a dictionary and tolerates missing keys;
  - **reset:** returns the system to a fresh run.

  It is implemented by:
  - resources, progression, perks, time, and the game's run fields (stats, chapter goal, pity counter, party);
  - the campfire, the Moon Lantern, and both heroes, through the Hero interface from hero-core.
- **Spawned objects:**
  - **Who rebuilds them:** buildings, blueprints and torches are listed and rebuilt by their own module, which owns its metas and legacy fallbacks.
  - **Refreshing after load:** private refresh calls from outside go away; each object refreshes itself after it loads.
- **The run session** is the public interface for the lifecycle:
  - start (run config), continue from (saved data), reset, and a `restore_finished` signal.
  - It replaces the game manager's reset list, the pending-save field and the progression manager's restoring flag.
- **One declared restore order:**
  - **The order:** time and run fields, then resources, then progression, then perks, then the world objects, then the heroes.
  - **Follow-ups:** the perk top-up listens to `restore_finished` instead of being deferred.
  - **The dawn autosave:** it runs after the dawn handlers through the session, not through a deferred call that happens to come last.
- **The run config** carries:
  - the hero and party;
  - the chapter goal (with the endless flag added later by endless mode);
  - the seeds for the perk and loot random generators;
  - the perk auto-pick time.
- **The save manager** keeps only:
  - the file path and version;
  - reading and writing JSON;
  - the parse checks;
  - delete.

  Its snapshot is the run session gathering each system's saved state.
- **Save format:** today's save files must still load. Keys keep their current names and places where possible. Where a module's saved state moves, load state reads both the old and the new place. The version number changes only if an old save can no longer be read the old way.
- **Bugs fixed on the way:**
  - The pity counter is saved.
  - The perk clock, the perk and loot random generators and the crafting state are reset.
  - The trap-snaps line is removed from the save file header (they were never saved, and don't need to be).

## Testing Decisions

- **Test only behaviour through the interface.** A good test saves, loads or resets through the saving-system interface or the run session, and asserts what a player would see: counts, HP, timers, perks and buildings. It never asserts how the data is stored.
- **A validate-level check, no scene:** for every saving system, set some state, save it, reset it, check it is fresh, load it, and check it matches. A system that keeps state across a reset fails here.
- **Smoke:**
  - **Continue:** the save and Continue scenarios go through "continue from" on the run session; no scenario writes the pending-save field.
  - **The round trip:** the existing round-trip check stays, through the session.
  - **Seeds:** they come from the run config; the scenarios no longer set them by hand.
- **An old-format fixture:** a save written by today's build is checked in as a test fixture and must load with every field intact.
- **Prior art:** the smoke run's save round trip and its perk save scenarios; the validate tool's existing data checks.

## Out of Scope

- Progress across runs (the profile spec).
- New saved features. Endless mode and journal badges add their own state on top of this.
- Saving trap snaps or other state that is not saved today.
- Changing what autosaves or when (still at dawn).

## Further Notes

- This builds on hero-core, because heroes save themselves through the Hero interface.
- Endless mode and journal badges are now blocked by this spec, so their new run state lands in one place.
- The architecture review report: https://claude.ai/artifact/V3mStF5e7Qv6ypXTjwzWCg (private to the project owner).

## Comments

- **2026-10-21, to-tickets:** split into tickets 01-04; the user approved the breakdown.
