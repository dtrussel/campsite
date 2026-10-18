# Feature 038: Handoff

- **Done:** the Moon-Eater is in the game (see `status.md`).
- **Concept:** the character sheet is `art/reference/concept-2026-10/15_moon_eater_character_sheet.webp`, and `docs/design/story.md` (Art plan) sums it up. The code stand-in follows it.
- **Swapping in the team's art:** replace the `Visual` node of `scenes/mobs/MoonEater.tscn`.
  - `BossController` calls `play_action(clip, windup)`, `play_final(&"shrink")`, `set_locomotion`, `face`, `face_instantly` and `rotation.y` on it.
  - Either keep that interface in a wrapper, or give `CharacterVisual` the clips rise, stomp, sweep, summon, stagger, reach and shrink.
  - Keep the stomp and sweep impacts at the windup times in the scene's exports (0.9 s and 0.8 s).
- **Tuning** lives in the scene's exports (phases, stomp, sweep, summon, reach) and in `moon_eater.tres`. All of it was set on paper.
- **Testing by hand:** start a 7-night run, then press the skip-to-night key until night 7. You can also drop `TimeManager.day_number` in a debugger.
- **Open:**
  - play the whole Chapter 2 to check the balance (the test plan's balance box);
  - a voice-free sigh for the Moon-Eater is in `sfx.py`; a real sound designer might want its own recordings;
  - a night-3 mini boss in Chapter 1 was decided against for now.
