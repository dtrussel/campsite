# Feature 037: Sibling barks (plan)

Status: **planned** (roadmap from the 2026-10 brainstorm). Rough size: **S**.

## Goal
Let Leo and Nela talk while you play, so the bond and the adventure tone come through in short lines.

## Scope
- **Speech bubbles** float over a hero's head (a world-space `Label3D` or a canvas bubble that follows the character) for about 2.5 s.
- **Triggers:**
  - low HP (both heroes);
  - a gremlin steals, and a gremlin is caught;
  - the first beast of the night;
  - a level up;
  - sunset ("Back to the fire!");
  - dawn;
  - a lantern stage;
  - the companion knocked out and revived.
- **Lines are keyed by speaker and party,** so Leo played gets Nela's replies. A pair can be call and response (Leo then Nela, 0.8 s apart).
- **Anti-spam:** a global cooldown of 6 s and one per trigger of about 20 s. Barks are skipped during combat surges unless they are urgent.

## Systems touched
- New: `scripts/story/bark_library.gd` with `resources/story/barks.tres` (or JSON), and `scripts/ui/speech_bubble.gd`.
- Signals already present: `ProgressionManager.level_up`, `TimeManager.sunset_warning` / `dawn_started`, the companion's knocked-out state, `ResourceManager.resource_changed` (theft), and the mob spawn.
- `scripts/core/audio_manager.gd`: a tiny chirp per speaker (procedural, as in 016).

## Depends on
034 (party), story voice from 035.
