# Feature 016: Handoff

## Where things are

- **Rebuild sounds:** `tools/build_audio.sh`, or
  `tools/build_audio.sh sfx hit wood` for a few ids. It creates
  `.venv-audio/` (numpy + soundfile) on first run.
- **Scripts:**
  - `art/audio/dsp.py`: oscillators, filters, reverb, and instruments
    (pluck, bell, pad, knock, owl);
  - `art/audio/sfx.py`: one-shots, in the `SOUNDS` table;
  - `art/audio/music.py`: loops.
- **Add a sound:**
  1. write a function in `sfx.py` and add it to `SOUNDS`;
  2. build it;
  3. add the id to `volumes` in `game/resources/audio/audio_library.tres`;
  4. call `AudioManager.play_sfx(&"id", position)`, or use a matching
     `Fx.burst` kind.
- **Mix:**
  - per-id offsets are in `audio_library.tres`;
  - music and ambience levels are `MUSIC_DB` and `AMBIENCE_DB` in
    `game/scripts/core/audio_manager.gd`;
  - bus volumes are set by the pause menu sliders.

## Public API

- `AudioManager.play_sfx(id, position = null)`.
- `set_mood(&"day" | &"night" | &"")`.
- `current_music()`.
- `make_ambient_emitter(stream, volume_db)`.
- `set_music_volume(linear)`, `set_sfx_volume(linear)`.
- Signal `mood_changed`.
- `Fx.hit_stop(seconds, slow_factor)`.

## Open items

- **Nobody has listened to the mix yet.** Do that first, then tune
  `volumes`.
- **Possible follow-ups:**
  - imp footsteps and chatter at night;
  - a louder intensity layer when many imps are alive;
  - a distinct sound for Nela gathering.

## Next features (agreed roadmap)

- **017:** repair, and uses for the unused resources.
- **018:** Bramble Beast.
- **019:** more buildings.
- **020:** longer runs, plus save/load.
- **Art in parallel:** the Imp remodel, then animations, then the
  environment.
