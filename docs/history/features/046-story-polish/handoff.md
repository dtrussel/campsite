# Feature 046: Handoff

- **The rules are in `docs/design/story.md`:**
  - the three lights (never call the Moon Lantern "Mum's lantern");
  - the creatures table;
  - the places;
  - Mum's notes.

  New lines follow those.
- **A new note:** add a line `{id: "dawn.cX.nY.note", speaker: "note", face: <Mum face>, text: ...}` with no `when`. Then run `tools/build_audio.sh voice dawn.cX.nY.note`. The kid line before it should say they found a page.
- **041 (journal):** collect the `note` lines (`StoryLibrary.all()`, lines whose speaker is `note`) as the journal pages, ordered by chapter and night. Unlock a page once its dawn has been seen.
- **A new creature:** fill `MobDefinition.description` (what lost thing it is, and why it comes). The HUD shows it under the creature's first banner of a run.
- **Paintings:** each intro and ending page still reuses the 4 loading paintings. The team's paintings drop in per beat (`painting`). The pages most in need are the dark moon, Mum walking into the woods, the golem, and the homecoming.
- **Not done:** the requirements doc and ADR-0001 still say "evil forest mobs". They record the original brief and were left as written.
