# Feature 037: Handoff

- **Done:** barks are in the game (see `status.md`). Voice files drop in as `game/assets/audio/voice/bark.<trigger>.<speaker>.<n>.ogg`.
- **Writing more lines:** add them to `game/resources/barks/barks.tres`. A new trigger needs tuning there and a call to `BarkDirector.bark(&"name")` from the event. `tools/check.sh` enforces the rules (see `docs/design/story.md`, Barks).
- **Tune by playing:** the cooldowns (6 s shared, per trigger in the data) and the danger range (5 m behind the player, 12 s) were set on paper. Watch a full night for chatter.
- **Known quirk:** under xvfb the companion's reply comes about 2.8 s after the call instead of 0.8 s, because frames are slow. The screenshot waits for it, and the headless smoke test sees the right timing.
- **Next on the roadmap:** 038 The Moon-Eater. It stays wordless, but it could take a `boss` bark trigger for the kids.
