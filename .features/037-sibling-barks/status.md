# Feature 037: Status

**Done** (2026-10-17). `tools/check.sh`: validate OK (46 barks, 11 triggers) and smoke PASSED with the bark scenario. Screenshot `03c_barks` shows a call and response over both kids.

## What was built
- `game/resources/barks/barks.tres` (`BarkSet`, `scripts/story/bark_set.gd`): 11 triggers with their tuning, and 46 lines (2–3 per hero per trigger, at most 30 characters).
- `scripts/story/bark_library.gd`: picks a line for a trigger and speaker, never the same one twice in a row.
- `scripts/story/bark_director.gd`: added by `main.gd` for every run. It listens to the events, applies the cooldowns, resolves who speaks from the party, and polls for danger behind the player every 0.5 s.
- `scripts/ui/speech_bubble.gd`: the on-screen bubble anchored above a hero's health bar.
- `AudioManager.play_bark`: a recording by line id, else `chirp_leo` / `chirp_nela` (new in `art/audio/sfx.py`, 4 variants each), on the Voice bus. It stays quiet while a story line speaks.
- Validator `_validate_barks`, a smoke `_run_bark_scenario`, and the screenshot `03c_barks`.
- `StoryBook.is_open()`: a book that has finished but is still fading no longer counts as open.
