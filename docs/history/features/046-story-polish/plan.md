# Feature 046: Story polish (plan)

Status: **done**. Rough size: **M**.

## Goal
User request: improve the storytelling and world building, by improving the existing content and concepts rather than adding features.

An audit found that the story bible was sound, but the game's text contradicted it and itself:
- **The lanterns were mixed up.** Mum's lantern was "found" in Chapter 1 yet "swallowed" in the finale, and a bark called the Moon Lantern "Mum's lantern".
- **The Chapter 2 ending was out of date.** Its text still described the old "shrank into a little shadow" version.
- **Two mystery layers never reached the player.** Layers 3 and 4 were waiting on the journal (041).
- **Creatures had no motive.** The design spec still called them "evil".
- **Places had no names in game,** and item text read like a design document.
- **Barks clashed with each other and with the game.** Some lines were duplicated or repeated, and some contradicted the game state.

## Decisions taken with the user
- **Mum's lantern:** the Moon-Eater drank its light. The kids find it cold, and it relights in the true ending.
- **All creatures are lost things:**
  - imps are lost shadows;
  - beasts are fallen trees woken by the dark;
  - gremlins carry shiny things to the Moon-Eater's hoard.
- **Mum's notes come in now,** on the existing dawn cards. 041 collects them later.
- **Nela stays 3,** with her current voice.

## Work
1. **Story bible** (`docs/design/story.md`): the three lights, the creatures table, the places, the table of Mum's notes, and the revised chapter beats.
2. **Mum's notes:** a `note` speaker (shown as "Mum's note", her face, quoted, in her voice). One note per dawn from Chapter 1 night 2.
3. **Story text:**
   - the Chapter 1 ending and the Chapter 2 intro rewritten;
   - a 3-page true ending (the Moon-Eater falls apart, the little golem, Mum comes home);
   - the boot print moved to Stony Pond;
   - dawn lines no longer claim the lantern's state;
   - paintings re-picked to fit each page.
4. **HUD:** a story card is never cut short. A new card waits for the open one.
5. **Barks:**
   - the lantern line fixed and the duplicate lines split;
   - lore lines (the Hollow, the old tree, the cold imps);
   - `thief_escaped` is new;
   - `first_beast` barks once per run (`once: "run"`).
6. **World text:**
   - item and building descriptions in the storybook voice, naming places;
   - `MobDefinition.description` shown under a creature's banner the first time it appears in a run;
   - lore loading tips;
   - the SE grove renamed from Berry Hollow to Fairy Ring (it is a stump, not an oak, and the old name clashed with "the Hollow").
7. **Docs:** the design spec pitch (no "evil"; Parent, pets and the Night Crow marked superseded), the README, art direction, the roadmap, and the 035 folder.
