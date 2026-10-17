# Feature 035: Status

**Done.**

- **Chapters.** The title buttons are the chapters: "The Dark Moon" (Chapter 1, 3 nights) and "Into the Hollow" (Chapter 2, 7 nights). `GameManager.chapter()` comes from the run length.
- **Intro storybook.** After hero select, the chapter intro plays the first time (4 pages in Chapter 1, 3 in Chapter 2). It shows painted pages with voiced lines: Space, Enter or a click turns the page, and Esc skips. It is remembered in `user://story.cfg`, so it plays once per chapter.
- **Dawn cards.** Each dawn that doesn't end the run shows a card under the top strip: the played hero speaks first, the companion replies, and a Moon Lantern hint sits underneath. It never pauses the game and fades by itself after 6 s (longer if its voices need it), or on a click. The first Glow Shard of a run gets its own card ("like a little piece of moon").
- **Endings.** A win opens the chapter's ending storybook first (Mum's lantern found in Chapter 1; the Moon-Eater lets the moon go and Mum comes home in Chapter 2), then the stats. A defeat shows why as a voiced story line ("The dark came in...", or "Leo was too tired to stand...").
- **Voice.** Every line has an id. A recording at `game/assets/audio/voice/<id>.ogg` plays on the new Voice bus; until then lines are text only.
- **Data.** 22 `StoryBeat` files in `game/resources/story/` hold 58 lines. They use placeholder paintings (the loading art).
- **Checks.** `tools/check.sh`: validate OK, with new story checks (it reports "22 beats, 58 lines, 0 voiced"), and smoke PASSED, with a new story scenario plus ending and defeat checks.
