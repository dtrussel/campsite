# Feature 016: Test plan

- [x] `tools/check.sh` passes (import, validation with the audio checks, smoke run).
- [x] Every `Fx.burst` kind has a sound (validator).
- [x] Day music at run start; night music at night; silence plus a stinger at the end of a run (smoke).
- [x] Volume settings persist in `user://settings.cfg` (smoke).
- [x] Pause menu sliders render (screenshot).
- [ ] **Listen in the editor (F5):**
  - the day→sunset→night→dawn crossfades;
  - the owl at sunset;
  - chop, clink and rustle while gathering;
  - hit, hit-stop and the imp "poof";
  - the build thunk and the craft chime;
  - the campfire crackle near the fire;
  - the win and lose stingers.
- [ ] Adjust the volumes in `audio_library.tres` after a listen; check that nothing is harsh on laptop speakers.
- [ ] Settings survive a restart of the exported build.
