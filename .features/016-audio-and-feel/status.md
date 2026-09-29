# Feature 016: Status

**Done** (pending a listen on real speakers).

## What was built

- **One-shots:** 24 sound ids, 54 files, 2–3 variants for most ids.
- **Loops:** 2 music loops (day 40 s, night 53 s) and 3 ambience loops
  (day, night, campfire).
- **Size:** about 1.5 MB of `.ogg` in total.
- **`AudioManager` autoload**, bus layout, `AudioLibrary` data.
- **Wiring:** see plan.md. Also hit-stop, the sunset vignette and the
  volume sliders.

## Verification

- **`tools/check.sh` passes.**
  - The validator checks that every library id has files, that every
    `Fx.burst` kind has a sound, that the loops are set, and that the
    buses exist.
  - The smoke test checks:
    - day mood at run start;
    - the night mood and the night track on every night;
    - silence for the win stinger;
    - that every id plays without error;
    - that the volume setting is saved.
- **Headless error output** is unchanged from before this feature (only
  the known leak-at-exit messages).
- **Screenshots (Xvfb):** the pause menu shows the Music and Sounds
  sliders, and the sunset vignette renders at full strength.
- **Not verified:** listening. This container has no audio output. The
  levels were checked numerically (peak, short-term RMS, loop seams),
  but nobody has listened to the mix yet.
