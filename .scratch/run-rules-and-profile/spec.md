# Run rules and the profile

Status: ready-for-agent

Split into tickets in `issues/` (01&ndash;08); the `Blocked by:` lines give the order. Comes from the 2026-10-24 architecture review: candidate 1 (the run config owns the run's rules) and candidate 2 (deepen the profile). Rough size: **M–L**. Blocked by: none. The run config part comes first, because the profile's run outcome reads the chapter, the endless flag and the hero from the run config.

## Problem Statement

This is a refactor. Players should notice no change, except for two fixes listed at the end of this section.

The run config has three homes: fields on the game manager, the run config value, and the run session's copy. Each caller rebuilds the run's rules from those loose fields:
- **The chapter is guessed:** it is inferred from the run length ("7 or more nights is Chapter 2").
- **The same rules are rewritten in several places:** "is this the Moon-Eater's night", "does this dawn win", "how far is this endless run past the story" and "does the Moon Lantern start lit" are each rewritten in the mob spawner, the Moon Lantern, the HUD, the end screen, hero select and the title.
- **The tests push the game around:** they set those fields directly more than 30 times to get a run of the shape they want.

The profile is a key-value store, so what it keeps leaks out to its callers:
- **Key strings:** every small cross-run module builds its own key strings, for badges, totals, heroes won with, journal pages, starting perks, tints, the endless record and story beats seen.
- **Cross-run writes:** these are spread over the game manager, the badges module, the end screen, the day chest and the HUD.
- **Hard-to-test badge rules:** the badge rules read the game manager directly and only run while a run is playing. A badge threshold can only be tested by booting the whole camp and playing a night.
- **Raw keys in tests:** the tests write raw keys to fake an earned badge or a record.

Two player-facing bugs come from this:
- **Mum's dawn notes need the HUD:** they are found as journal pages only because the HUD records them, so with no HUD they are never found.
- **Endless can be missed:** it unlocks only once the true ending's story book has been read to the end, so a player who quits during the book wins Chapter 2 and still gets no Endless.

For maintainers, this means adding a chapter, a run mode or a new kind of progress touches many files. There is also no seam for testing these rules without the full game: today, pure-logic checks live in the project validator or in smoke scenarios that boot the main scene.

## Solution

**The run config** becomes the one value that describes the run in play. The run session holds it, and it stays fixed until the run ends:
- **What it stores:** the chapter (or an endless run), the party, the nights to win, the seeds, the day-chest day and the test settings.
- **What it answers:** the run's rules, such as which night the Moon-Eater comes, which dawn wins, how far an endless run is past the story, whether the Moon Lantern starts full and whether the intro plays.
- **Between runs:** the title builds a draft config for a chapter or Endless, hero select adds the party, and Again replays the last config with fresh seeds.
- **Saves:** they keep their exact format, so existing saves still Continue.

**The profile** gets an interface of domain verbs:
- **During play:** the run tells it when a stat was recorded, a page was found, a beat was seen or a hero was picked.
- **At the end:** the run tells it when the run ended, with a **run outcome**. The profile then records the chapter won, the hero won with, the endless record and the badges.
- **What callers read:** facts such as badges earned, totals, pages found, beats seen, chapters won, the endless best and whether Chapter 2 or Endless is unlocked.
- **Keys:** only the profile knows them, and the profile file keeps its exact format, so no player loses progress.
- **Storage:** it sits behind a seam with two adapters: the file the game uses, and an in-memory one for unit tests.
- **Badges:** every badge is announced through one signal on the profile. The badge rule becomes a pure check of the facts it is given.

The two bugs are fixed along the way:
- **Mum's dawn notes:** the run's own dawn handling finds them, not the HUD.
- **Endless:** it unlocks when Chapter 2 is won, not when the ending book closes.

A new **unit-test pass**, run by the checks script before smoke, tests the run config's rules, the profile on its in-memory adapter and the badge rule, all without the main scene.

## User Stories

1. As a player, I want my Continue save from before this change to load into the same run, so that I don't lose a run in progress.
2. As a player, I want a Chapter 2 save from before this change to continue as Chapter 2, so that my run keeps its Moon-Eater.
3. As a player, I want an endless save to continue as an endless run, so that it still never ends in a win.
4. As a player, I want my badges, journal pages, endless record, chapter wins and seen story beats kept exactly as they were, so that nothing I earned is lost.
5. As a player, I want Mum's dawn note to count as a journal page every time I see it, so that the journal fills in as I play.
6. As a player who wins Chapter 2 and quits during the ending book, I want Endless unlocked anyway, so that the true win counts.
7. As a returning player who saw the true ending before this change, I want Endless to stay unlocked, so that my old progress still counts.
8. As a player, I want the Moon-Eater to come on Chapter 2's last night and never in an endless run, so that the story plays as before.
9. As a player, I want the Moon-Eater's eyes on the nights before its night, as before, so that the build-up stays.
10. As a player, I want the dawn after my last night to win a story run, so that surviving still wins.
11. As a player in an endless run, I want mobs to keep getting tougher for every night past the story's last, so that endless stays a challenge.
12. As a player in an endless run, I want the Moon Lantern to start full, so that shards go to Glow Lanterns and tool tiers.
13. As a player, I want Again to replay the same chapter, mode and party, so that one button starts another try.
14. As a player, I want hero select to open on the hero I picked last, so that I don't pick again.
15. As a player, I want badge toasts during a run and the run's badges on the end screen, as before, so that I see what I earned.
16. As a player, I want "New record!" on the end screen when an endless run beats my best, so that I know I did.
17. As a player, I want the title to show my endless best under Endless, so that I have something to beat.
18. As a player, I want Chapter 2 locked until I win Chapter 1, as before, so that the story comes in order.
19. As a player, I want deleting my profile to start me over, with my audio and look settings left alone, so that it behaves as before.
20. As a maintainer adding a chapter, I want to describe it in one place, so that the spawner, the lantern, the HUD and the win check pick it up.
21. As a maintainer, I want the chapter stored, not guessed from the run length, so that a run's length and its story can't disagree.
22. As a maintainer, I want the run config fixed for the whole run, so that no system sees it change mid-run.
23. As a maintainer, I want one place that writes and reads the run config in the save, so that Continue builds it before any saving system loads.
24. As a maintainer, I want the same run config to replay the same perk deals, shard drops and day chest, so that a bug report can be replayed.
25. As a maintainer, I want the profile's keys known only to the profile, so that a new kind of progress is one change.
26. As a maintainer, I want the profile never to read the game manager or the run session, so that it can be used and tested on its own.
27. As a maintainer, I want the badge rule to be a pure check of the facts it is given, so that a new badge condition can be checked without a scene.
28. As a maintainer, I want one signal that announces a badge, so that the HUD and the end screen can't show the same badge twice or miss one.
29. As a maintainer, I want the badge, journal, starting-perk and tint modules to keep their own tables and rules, so that each stays small and in one place.
30. As a coding agent, I want "what does this run's chapter mean" answered by one module, so that I don't search eight files.
31. As a coding agent, I want "what is kept across runs" answered by one module, so that I find every key at once.
32. As a test author, I want to build a run config of any shape and start a run from it, so that I never set game manager fields by hand.
33. As a test author, I want to unit-test the run config's rules without the main scene, so that rule bugs fail in seconds.
34. As a test author, I want to unit-test the profile on an in-memory store, so that tests never touch a file.
35. As a test author, I want to unit-test each badge condition with plain facts, so that a threshold test doesn't play a night.
36. As a test author, I want to set up a profile through the same verbs the game uses, so that tests can't drift from the real keys.
37. As a test author, I want one test-only way to grant a badge, so that a screenshot of a full scrapbook doesn't need every badge played out.
38. As a test author, I want smoke to keep a real profile file, so that the "restart and reload" scenarios still test the file.
39. As a test author, I want resetting smoke between scenarios to be one profile delete and one "forget the last run", so that cross-run state isn't hand-listed.
40. As a maintainer, I want the unit tests run by the checks script before smoke, so that CI runs them on every push.

## Implementation Decisions

### The run config

- **One holder:** the run session holds the one run config for the run in play, and remembers the last one for Again. The game manager loses its loose run fields: the run length, the endless flag, the party ids and the day-chest day. No alias for the config is kept on the game manager.
- **What it stores:** the chapter and the endless flag as fields of their own. The nights to win stays a field, defaulted from the chapter when a config is built for a chapter. Chapter 1 is 3 nights and Chapter 2 is 7. A config with any night count can still be built, for the balance sim.
- **Fixed for the run:** the config never changes once the run has started. The step that wrote the party and the run length back into both the config and the game manager goes away.
- **Building a config:** a config is built for a chapter (or for Endless, which is Chapter 2 with the endless flag). The party and the starting perk are added at hero select. Again builds a copy of the last config with the same chapter, mode and party, plus fresh seeds and a fresh day-chest roll.
- **The day chest:** its day comes from a roll seeded by the config itself, like the perk and loot seeds, so the same config replays the same chest.
- **Saving the config:** it is not a saving system. The run session writes it into the save itself. On Continue, the run session builds it from the save before any saving system loads, so every system can read it while loading.
- **The save format doesn't change:** the keys stay the same: run length, endless flag, party and day-chest day. The game manager no longer saves those keys. A save from before the chapter was stored has its chapter inferred once, from the run length, and only while the config is read back.
- **Rules on its interface:**
  - whether a night is the Moon-Eater's night (Chapter 2's last night, never in an endless run)
  - whether the run has a Moon-Eater at all (Chapter 2 and not endless)
  - whether a dawn wins (any dawn at or past the nights to win, never in an endless run)
  - how many nights a night is past the story (zero outside an endless run)
  - whether the Moon Lantern starts full (an endless run)
  - whether the chapter intro plays (never in an endless run)
- **Rules that stay with their callers:** the eyes nights stay a mob-spawner setting, built on "has a Moon-Eater" and the nights to win. The Moon Lantern's costs per chapter stay in the lantern and read the config's chapter. Display strings and moon sizes stay in the UI, which reads the nights to win.
- **The win check:** it doesn't depend on run stats. Calming the Moon-Eater changes only the end message.

### The profile

- **Its interface:** domain verbs. Reading or writing a raw key and the key prefixes become private to it. Callers outside the profile never build a key.
- **Writes during play:** a stat was recorded (with the run's facts), a journal page was found, a story beat was seen, and a hero was picked on hero select.
- **The write at the end:** the run ended, with a **run outcome**. The outcome carries:
  - the run config
  - whether the run was won
  - the night it ended on
  - a copy of the run's stats, as a plain dictionary
- **What happens at run end:** the profile records the chapter won, the hero won with, and the endless record if the run was endless. It then checks the badges.
- **What run end returns:** whether the endless record was beaten, and which unlocks it opened (Chapter 2, Endless). The game manager's "new record" flag goes.
- **Reads:** whether a badge is earned, a stat's total across runs, whether a hero has won a run, whether a page is found, whether a beat is seen, whether a chapter is won, the endless best (night and hero), and the last hero picked.
- **Unlock queries on the profile:** whether a chapter is unlocked (Chapter 1 always; Chapter 2 once Chapter 1 is won; every chapter in debug and playtest builds) and whether Endless is unlocked (Chapter 2 won, or, for profiles from before this change, the true ending seen).
- **Badge announcements:** the profile is the one place a badge is earned. It announces each badge through its own badge-earned signal, win badges included, and the HUD and the end screen listen to that signal. Run end does not also return the badges, so no badge is announced two ways.
- **Explicit calls from the run:** the run calls the profile directly, and the profile never reads the game manager, the run session or the time of day. The caller already knows whether a run is playing or a save is being restored, so the "only while playing, not while restoring" checks move to the caller.
- **The badges module:** it stops being an autoload and becomes a static module like the journal. It holds the badge definitions and one pure check: is this badge met, given these facts (run stats, chapter, won, totals, heroes won with, the hero roster).
- **The other cross-run modules:** the journal, starting perks, tints and the endless record keep their tables and rules but read and write only through the profile's verbs. The starting perks and tints keep their badge-to-unlock tables and ask the profile whether the badge is earned.
- **Story beats seen:** the story library marks and checks them through the profile's verbs.
- **The true ending:** it is still marked seen when its book closes, because the title backdrop uses that beat. It no longer decides Endless.
- **Mum's dawn note:** the run's dawn handling picks the dawn beat and records its journal page through the profile. The HUD is handed the beat to show and records nothing.
- **Storage:** an internal seam with two adapters. The JSON-file adapter keeps today's file, keys and value formats byte for byte, including the one-time import of the old story file and the import note that survives a delete. The in-memory adapter is for unit tests. Pointing the profile at another file stays, for smoke and the screenshot sim.
- **Device settings:** unchanged, kept apart from the profile.
- **The test-only shortcut:** one way to grant a badge directly, documented as for tests and screenshots only. Everything else is set up through the real verbs.

### Order of work

The run config tickets come first. Then the profile's verbs and storage seam, then badges through the profile, then the two fixes. The unit-test pass lands with the first ticket that needs it. A final ticket updates the docs.

## Testing Decisions

- **A good test** crosses the same interface as a real caller. It builds a run config and asks it a rule, or calls profile verbs and reads profile facts. It never reads private fields, sets the game manager's state by hand or writes raw profile keys.
- **New unit-test pass:** a small runner script, no third-party add-on, run headless by the checks script before smoke, without the main scene. It is the "script-level tests" layer of the test strategy.
- **Run config unit tests:** every rule for Chapter 1, Chapter 2 and endless configs, around the boundary nights; building a config for a chapter and for Endless; Again keeping the party, chapter and mode with new seeds; the same seed giving the same day-chest day; and the save round trip, including the v2 save fixture and a pre-endless save.
- **Profile unit tests:** on the in-memory adapter:
  - run end records the chapter won, the hero won with and the endless record
  - run end returns "record beaten" only for a better night
  - Chapter 2 and Endless unlock rules, including an old profile with only the true ending seen
  - pages and beats found and seen
  - totals added across runs
  - badges announced once each through the signal
  - delete keeping the import note
- **Profile file-adapter checks:** the round trip, corrupt-file recovery and the one-time old story import move out of the project validator into unit tests that point the profile at a temporary file.
- **Badge rule unit tests:** each condition (run stat, total, win, win in a chapter, win with each hero) with plain facts.
- **What leaves the validator:** unit-test-shaped checks of these modules move to the unit pass. The validator keeps data integrity and the saving-system contract.
- **Smoke:** smoke keeps a real profile file, because its restart scenarios reload it.
  - Scenarios build run configs instead of setting game manager fields.
  - They set up profile state through verbs and the one test-only badge grant.
  - Smoke's reset between scenarios becomes a profile delete plus forgetting the last run config.
  - The existing badge, journal, endless, story, boss, chapter 1 and run lifecycle scenarios keep their checks. Badge thresholds can now be covered by unit tests rather than played nights.
  - A smoke check covers Mum's dawn note being found with no HUD in the scene.
- **Prior art:** the validator's existing profile round-trip and import checks, which become the profile's file-adapter unit tests; the saving-system round trip; the smoke scenarios for run lifecycle, endless and badges.

## Out of Scope

- One run-stats schema (review candidate 3). The run outcome carries the stats as a plain dictionary for now.
- Moving a hero's progress into one value (candidate 4), sharing the heroes' work loops (candidate 5), and the HUD as a view only beyond the dawn note (candidate 6).
- Any change to the save file or profile file formats.
- New chapters, modes, badges or unlocks.
- Device settings.

## Further Notes

- **Behaviour change:** Endless now unlocks when Chapter 2 is won rather than when its ending book closes. Old profiles stay unlocked through the true ending they saw.
- **Glossary:** the glossary's "Run config", "Endless run" and "Run outcome" entries were written during the review. Code and tickets use those words.
- **Docs to update at the end:** the architecture doc's save/load section (the run session and the run config, the profile, Camp Badges, the journal and unlocks); the autoload list (badges no longer an autoload); the test strategy (the unit pass exists); and the notes on the checks script.

## Comments
