# Feature 035: Decisions

- **From the 2026-10 brainstorm.** The user chose story (B) and choices / meta (C), with an **adventure** tone (see `docs/design/story.md`), and asked for the roadmap first.
- **Text-first.** The cards reuse the existing paintings until new art exists, so the feature isn't blocked on art.
- **Dawn cards never pause the game.** The day timer keeps running, and the card fades by itself.
- **Placeholders until the team's art arrives.** The intro and ending cards use the existing loading paintings; the `StoryBeat` painting field is swapped later without code changes.
- **Mum, not Grandpa** (decided with the user).
- **Voiced lines** (decided with the user when building). Each line has an id, and its recording is found by that id (`assets/audio/voice/<id>.ogg`), so the recordings are data. Voiced lines don't use `{hero}`/`{companion}`; a `when` variant per hero replaces them.
- **The intro plays before loading, over the hero select screen.** This answered the open question: the loading screen keeps its own job (tips), and the intro can take as long as the reader wants.
- **Once per chapter, remembered on disk** (`user://story.cfg`). A replay button comes with the title's Story button (041).
- **One beat per page.** An intro or ending is several `StoryBeat`s with `page` numbers, so the team can add or reorder a page by adding a file.
- **The played hero speaks first.** Each dawn beat has a pair of lines per hero (`when`), so Leo and Nela keep their own voices whichever is played.
- **Chapter 2's ending is the true ending for now.** The Moon-Eater fight (038) will sit between the last night and this ending.
- **The first shard has a story card.** This is mystery layer 1 ("pieces of the moon's light"). It isn't shown again on Continue, because the shard count is saved.
