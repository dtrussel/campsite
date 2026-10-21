# Profile

Status: done

Split into tickets in `issues/` (01&ndash;02); the `Blocked by:` lines give the order. From the 2026-10-21 architecture review, candidate 3 (one profile for everything kept across runs). Rough size: **S–M**. Blocked by: none. It blocks endless mode and journal badges.

## Problem Statement

Progress that should outlive a run has no single home:
- **Story beats:** the beats a player has seen live in a small config file of their own.
- **Device settings:** audio, the post-processing look and auto-attack each read and write another shared config file.

The next two features each planned a new store. Endless mode would keep its best record in the story file "for now". Journal badges would then add a profile file and migrate the story file into it, which moves the endless record a second time.

For the player, this risks losing progress during a migration. For the people changing the code, each new kind of progress means writing another config reader. There is also no seam for testing progress without touching the real user folder.

## Solution

One **profile** keeps a player's progress across runs:
- **Where:** a single file, separate from the run save. A run ending never deletes it.
- **What it can do:** read a value with a default, write a value, record a best value (saying whether it is a new record), and delete everything.
- **Bad files:** a missing or corrupt file loads as an empty profile.
- **The old story file:** it is imported into the profile once. That covers the story beats the player has seen, and, for players who have already started or finished Chapter 2, a flag that keeps Chapter 2 unlocked.
- **Who uses it:** story beats read and write through the profile from then on. Endless mode and journal badges each just add their keys.

Device settings (audio, look, auto-attack) stay where they are, so that deleting a profile never resets the player's settings.

## User Stories

1. As a player, I want story beats I've seen to stay seen after this change, so that the intro and the endings don't replay.
2. As a returning player who has won Chapter 1, I want that win to carry over, so that Chapter 2 stays open for me once the chapter lock exists.
3. As a player, I want my progress kept when a run ends, so that losing a night never costs me unlocks.
4. As a player, I want a corrupt or missing profile to start me fresh without errors, so that the game always launches.
5. As a player, I want my best endless run kept in my profile, so that the record is there next time.
6. As a player, I want deleting my profile to leave my audio and graphics settings alone, so that I don't have to set them up again.
7. As a player, I want the old story file imported only once, so that deleting my profile really starts me over.
8. As a maintainer adding endless mode, I want to call "record best" with a key and a value and be told if it is a new record, so that the end screen can say "New record!" with one call.
9. As a maintainer adding journal badges, I want to store badges, chapters and journal pages as profile keys, so that I don't write a new store.
10. As a maintainer, I want one place that reads and writes the profile file, so that file errors are handled once.
11. As a maintainer, I want the profile kept separate from the run save, so that deleting a finished run's save can't touch progress.
12. As a coding agent, I want progress keys to have one module to search for, so that I can find what is remembered across runs.
13. As a test author, I want to point the profile at a temporary file, so that tests never touch the real user folder.
14. As a test author, I want to check set/get across a reload, "record best", corrupt-file recovery and the one-time import without a scene, so that profile bugs fail fast.
15. As a test author, I want to reset the profile between tests, so that scenarios don't depend on order.

## Implementation Decisions

- **The profile** is one autoload with a small interface:
  - get (key, default) and set (key, value), where a write is saved straight away;
  - record best (key, value), which returns true when the value beats the stored one or there is none yet;
  - has (key);
  - delete, which removes the file and empties the profile;
  - a path the tests can change.
- **Keys** are strings with a dotted prefix by owner, such as story, chapters, endless and badges. Values are JSON-friendly.
- **Storage:** a JSON file in the user folder, separate from the run save. A run ending never deletes it. A missing or unreadable file loads as empty and is rewritten on the next write.
- **The one-time import:**
  - **When it runs:** on first load, if the profile has never been created and the old story file exists.
  - **What it copies:** every seen beat. The story file never recorded a Chapter 1 win, so a seen Chapter 2 intro or true ending stands in for it and sets a Chapter 2 unlocked flag (decided 2026-10-21).
  - **Marking it done:** the profile records that the import ran.
  - **The old story file:** it is left on disk, unused, so that a downgrade still works.
- **Story beats** read and write through the profile. The story module's has-seen, mark-seen and forget-progress keep their names, so their callers don't change.
- **Not included:** device settings (audio, the post-processing look, auto-attack) stay in their own file (decided 2026-10-21).
- **No UI:** the chapter lock, the Delete-profile button and badges all belong to journal badges.

## Testing Decisions

- **Test only behaviour through the interface.** A good test drives get, set, has, record best and delete, and the import from a prepared old story file, all on a temporary path. It asserts values, not file contents.
- **A validate-level check, no scene:**
  - set/get across a reload;
  - record best returns true then false;
  - a corrupt file loads as empty;
  - delete empties the profile;
  - an old story file with seen beats (and a seen Chapter 2 intro) imports once and sets the Chapter 2 unlocked flag, and doesn't import again after delete.
- **Smoke:** the existing story scenarios (intro and endings seen once) still pass, now on a temporary profile path.
- **Prior art:** the story module already has a swappable progress path for tests; the profile takes over that seam. The validate tool's existing data checks show the style.

## Out of Scope

- Badges, journal pages, cosmetics and the chapter lock UI (journal badges).
- The endless record's UI (endless mode adds the key and the end screen line).
- Moving device settings.
- Cloud sync, or more than one profile.

## Further Notes

- Small, and it unblocks two specs: endless mode writes its record to the profile from the start, and journal badges' first ticket shrinks to the chapter lock, the last-hero pick and the Delete-profile button.
- The architecture review report: https://claude.ai/artifact/V3mStF5e7Qv6ypXTjwzWCg (private to the project owner).

## Comments

- **2026-10-21, to-tickets:** split into tickets 01-02; the user approved the breakdown.
- **2026-10-21, implement:** done (tickets 01-02).
  - **What exists:** the `Profile` autoload on `user://profile.json`. Story beats read and write `story.<beat>` keys through it. The old `story.cfg` is imported once and sets `chapters.c2.unlocked` for a seen Chapter 2 intro or true ending.
  - **A spec decision settled in the code:** "delete removes the file" and "never import again after delete" pull against each other. Delete keeps only the import note (`profile.story_cfg_imported`), so after an import the profile file holds just that note.
  - **Docs:** `docs/architecture/software-architecture.md`, "Profile" under H.
  - **Next:** endless mode and journal badges add their keys (`endless.`, `badges.`, `chapters.`).
