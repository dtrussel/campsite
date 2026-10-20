# Feature 035: Handoff

- **Done:** see `status.md`. Code: `game/scripts/story/` (`StoryBeat`, `StoryLibrary`), `game/scripts/ui/story_book.gd`, `story_card.gd`, and hooks in `game_manager.gd`, `hud.gd`, `end_screen.gd`, `title_screen.gd`, `hero_select.gd` and `audio_manager.gd`.
- **Writing a line:** edit a `.tres` in `game/resources/story/` (rules in `docs/design/story.md`). `tools/check.sh` catches long lines, unknown speakers and missing hero variants.
- **Waiting on the team:**
  - ~~concept art of mum~~ (arrived with 043: `game/assets/ui/story/mum*.png`);
  - new intro and ending paintings (set `painting` on each beat);
  - the voice recordings (see `game/assets/audio/voice/README.md`).
- **Next:** 037 barks reuse `StoryCard.speak` and the voice-by-id rule. 041 adds a title Story button that replays a seen intro (`StoryBook.play(StoryLibrary.find(&"intro", chapter))`).
- **Not done:** a separate volume slider for the Voice bus (it follows the master volume).
