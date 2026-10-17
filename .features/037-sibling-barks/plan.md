# Feature 037: Sibling barks (plan)

Status: **planned, ready to build** (refined 2026-10-17). Rough size: **S–M**.

## Goal
Let Leo and Nela talk while you play: short speech bubbles on game events,
so the bond and the adventure tone of 035's story come through between the
dawn cards. The companion also calls out danger the player can't see.

## Design
- **Bubble:** world-space, over the speaker's head and above the health bar
  (no overlap). A `Label3D` in the `HealthBar3D` style (`Fx.bold_font()`,
  ink outline, billboard, `no_depth_test`, high render priority) on a rounded
  parchment quad with a small tail. It pops in (scale 0.6 → 1), holds about
  2.5 s (or the voice length) and fades. One bubble per hero; a new one
  replaces the old.
- **Voice:** every bark line has an id (`bark.<trigger>.<speaker>.<n>`), and
  `StoryLibrary.voice(id)` finds its recording for the Voice bus, as in 035.
  Until the recordings exist, a short procedural **chirp** plays per speaker
  (a different pitch for Leo and Nela, in the style of 016). A bark never
  cuts off a story card's voice: while `AudioManager.is_voice_playing()` it
  shows the text only.
- **Keyed by who is played** (034 party). A trigger names a role (`hero`,
  `companion`, `hurt`, or `call_response`). Lines carry `speaker` and an
  optional `when`, like `StoryBeat` lines. Call and response: the played hero
  speaks first, the companion 0.8 s later.
- **Anti-spam:** a global cooldown of 6 s, a per-trigger cooldown of about
  20 s, and `once_per_night` / `once_per_run` where it fits. The random pick
  never repeats the last line. Urgent triggers (low HP, knocked out, danger)
  skip the global cooldown. No barks while a story card or book is open, or
  while paused.

## Triggers (first set)
| Trigger | Source | Who |
|---|---|---|
| `low_hp` (< 30%) | `health_changed` on the player and the companion | the hurt hero |
| `thief` | `Mob.stole` | call and response |
| `thief_caught` | a gremlin defeated while carrying loot (`Mob.defeated`) | the played hero |
| `first_beast` | `MobSpawner.mob_spawned` (a beast, once per night) | call and response |
| `level_up` | `ProgressionManager.level_up(character)` | that hero |
| `sunset` | `TimeManager.sunset_warning` | call and response |
| `dawn` | `TimeManager.dawn_started`, only when no dawn story card plays | the played hero |
| `lantern_stage` | `MoonLantern.stage_changed` | call and response |
| `companion_down` / `companion_up` | `knocked_out_changed` | played hero / companion |
| `danger_behind` | polled every 0.5 s at night: a hostile mob within about 5 m of the player and off-screen or behind them | the companion; urgent, 12 s cooldown, not while knocked out |

At least two lines per hero per trigger, at most 30 characters, adventure
tone. Voiced lines use no `{hero}` placeholders: write one `when` variant
per hero instead.

## Systems touched
- New `scripts/story/bark_set.gd` (`BarkSet` resource): trigger →
  `{role, cooldown, lines: [{id, speaker, text, when}]}`, the same line shape
  as `StoryBeat`. Content in `resources/story/barks.tres`.
- New `scripts/story/bark_library.gd` (`BarkLibrary`, static like
  `StoryLibrary`): loads the set; `pick(trigger, speaker, played)`.
- New `scripts/story/bark_director.gd` (`BarkDirector`, added per run by
  `main.gd`): connects the signals above, owns the cooldowns and the danger
  poll, resolves who speaks, shows the bubble and plays the voice or chirp.
  Resets on `GameManager.run_started`.
- New `scripts/ui/speech_bubble.gd` (`SpeechBubble`, Node3D): built in code
  like `health_bar_3d.gd`, attached at head height above the health bar.
- `scripts/core/audio_manager.gd`: `play_chirp(speaker, syllables)` on the
  Voice bus, procedural like `audio_library.gd`.
- Validator: `_validate_barks`, next to `_validate_story`.
- `assets/audio/voice/README.md`: the bark id pattern.

## Depends on
034 (party) and the story voice from 035.
