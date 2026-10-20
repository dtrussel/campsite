# Feature 044: Decisions

- **The intro replays every time, with no setting.** Esc skips it in one key. The seen flags stay for the true ending and for 041.
- **Auto-attack only when the hero is idle or gathering.**
  - A move or click from the player always wins, and walking by hand pauses it for 1 s.
  - It also works in build mode, so a hero who is building defends themself.
  - Radius max(range × 1.3, 3.5 m): Leo 3.5 m, Nela 5.85 m.
- **Fights keep the same number of hits.** HP and damage are unchanged; only time stretches.
  - The night still ends early when the wave is cleared, so 120 s is the cap, not the usual length.
- **Mushroom patches stay as scenery.** The gremlin's theme and the NW and SE corner dressing need them. The item icons stay in `assets/icons` (the loading tips use them).
- **Construction cost is paid on placement.** Only an unstarted blueprint refunds (click it with the ghost in build mode). A blueprint can be attacked and destroyed, and its cost is then lost.
- **Building feedback without see-through models.** `GeometryInstance3D.transparency` does not show in the Compatibility renderer, so a blueprint reads as a model sunk into a pale marked-out site instead.
- **Build mode no longer blocks hero commands.** Pointer clicks and keys are still owned by build mode, but the hero can walk off and build while the player places more.
- **Companion stuck fallback.** After 3 s it hops 1.2 m toward the goal, onto the nav map, with a dust puff. It is rare (0 hops in smoke) and better than a stuck helper.
