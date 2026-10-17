# Feature 037: Decisions

- **From the 2026-10 brainstorm.** The user chose story (B) and choices / meta (C), with an **adventure** tone (see `docs/design/story.md`), and asked for the roadmap first.
- ~~Text bubbles with a procedural chirp, no voice acting.~~ Superseded by the 035 decision that the characters get voiced lines.
- **2026-10-17, audio: voice ids with a chirp fallback.** Every bark has a line id and plays its recording once it exists; until then a per-speaker chirp plays. A bark never interrupts a story card's voice.
- **2026-10-17, danger callouts: yes.** The companion warns about a mob near the player that is off-screen or behind them ("Behind you!"). It helps in fights, not only flavour.
- **World-space bubbles** over the speaker's head, above the health bar, rather than a HUD strip, so you can see who is talking.
