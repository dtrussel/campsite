# Feature 016: Audio & feel

## Why

The game had no sound at all: `game/assets/audio/` was empty and nothing
used `AudioStream`. For young players, sound is half of the feedback. A
chop tells you gathering works, an owl tells you night is coming, and a
thwack tells you the hit landed. This was the biggest missing piece of
the playtest build.

## Scope

1. **Sound source.** All sound is procedural and original, built by
   numpy scripts in `art/audio/` (`tools/build_audio.sh`), the same way
   the art is built by scripts in `art/`. The `.ogg` outputs are
   committed.
2. **`AudioManager` autoload.**
   - Pooled 3D and 2D one-shots, with random variants and pitch jitter.
   - Day and night music and ambience, crossfaded on the `TimeManager`
     phase signals.
   - An owl call at sunset, and win and lose stingers.
   - Music and Sounds volume, saved to `user://settings.cfg`.
3. **`AudioLibrary` data** (`resources/audio/audio_library.tres`):
   per-id volume, the UI ids, and the loops. Variant files are found by
   naming convention.
4. **Wiring.**
   - `Fx.burst()` plays the sound of the same id, so every particle
     burst is heard.
   - Explicit calls for: gather ticks, building placed, crafted, UI
     clicks, player, sibling and structure hurt, campfire hit, and
     sibling task confirmation.
   - A crackle loop on every fire (the campfire and torches).
5. **Feel.**
   - Hit-stop when Leo lands a hit (`Fx.hit_stop`).
   - A warm vignette pulse on the screen at the sunset warning.
6. **Settings UI:** Music and Sounds sliders in the pause menu.

## Out of scope

- Mob footsteps and imp voice barks.
- Per-surface footsteps.
- A dynamic intensity layer for big waves.
- Nela voice lines.
