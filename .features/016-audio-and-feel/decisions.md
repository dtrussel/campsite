# Feature 016: Decisions

- **Procedural sound instead of vendored CC0 packs.** The plan was to
  vendor Kenney CC0 audio. This environment's network policy blocks
  kenney.nl and opengameart.org. Synthesis also fits the project better:
  - every sound is original, with no licence questions;
  - every sound is reproducible from a script, like the art;
  - every sound is tunable in code.

  **Trade-off:** synthesized sound is simpler than recorded foley. Any
  sound can be swapped later by replacing `sfx/<id>_<n>.ogg`. Nothing
  else needs to change.
- **Variants by naming convention** (`<id>_<n>.ogg`, probed with
  `ResourceLoader.exists`, so it also works in exported builds). The
  `.tres` holds only the tuning, so adding a variant needs no data edit.
- **Burst ids = sound ids.** `Fx.burst(kind)` already marks every
  gameplay moment that needs feedback. Playing the sound there gives
  full coverage with one line. `validate_project` fails if a burst kind
  has no sound.
- **Buses.** Master contains Music and SFX, and UI sends into SFX.
  - The Sounds slider covers the UI sounds.
  - Ambience plays on SFX: it is "world sound", not music.
- **Mood follows the clock only while a run is playing.** The winning
  dawn also ends the run, so the day tune must not start over the win
  stinger.
- **Music keeps playing in pause** (AudioManager is PROCESS_MODE_ALWAYS).
  The 3D SFX pool is PAUSABLE, so world sounds freeze with the world.
- **Hit-stop** scales `Engine.time_scale` down for 50 ms of real time,
  then restores the previous scale. The smoke test runs at 4x, so the
  previous scale is kept. Hit-stops never stack.
- **Loops.**
  - Music loops fold their note tails and reverb back to the start.
  - The night drone uses whole cycles per loop.
  - Ambience beds get a 0.75 s equal-power crossfade at the seam.
- **Levels.** Sounds are peak-normalized at build time. Mix offsets
  live in the library (`volumes`). Music is at -6 dB and ambience at
  -10 dB (constants in `AudioManager`).
