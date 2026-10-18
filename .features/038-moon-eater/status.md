# Feature 038: Status

**Done** (2026-10-18). `tools/check.sh`: validate OK (54 barks, 112 voiced lines) and smoke PASSED with the boss scenario. Screenshots `13_boss_rise` to `13e_boss_warm_shadow` show the rise, a stomp ring with the boss bar, the moon let go and the small warm shadow by the fire.

## What was built
- **The boss:**
  - `resources/mobs/moon_eater.tres` (`is_boss`, 800 HP, no loot) and `scenes/mobs/MoonEater.tscn`.
  - `scripts/mobs/boss_controller.gd` (`BossController extends Mob`):
    - it rises, then stomps and sweeps;
    - below 60% it also summons imp packs and puts out torches;
    - below 25% it reaches for the Moon Lantern;
    - at 0 HP it is calmed: the moonbeam, the shrink, and it curls up by the fire.
  - It holds the night while it stands, and snap traps don't hold it.
- **The stand-in model:** `scripts/mobs/moon_eater_visual.gd` (`MoonEaterVisual`), built in code.
  - A hunched wood-and-stone golem (about 3.6 m) after the team's character sheet (`art/reference/concept-2026-10/15_moon_eater_character_sheet.webp`, 2026-10-18): plank trunk lashed with rope, stone legs and fists, a small plank head with two amber eyes, a golden chest window with a crescent and its hoard (a chair, a teddy, a pocket watch), lanterns, bells, a key, a red scarf, moss and saplings.
  - It replaced the first stand-in, a moon-dark shadow blob, the same day.
  - Tween clips: rise, idle and walk, stomp, sweep, summon, stagger, reach and shrink.
- **Telegraphs:** `scripts/mobs/telegraph.gd`, a ground ring (the stomp) or slice (the sweep) that fills over the windup. Kids outside it when it lands are safe.
- **Eyes at the treeline:** `scripts/mobs/moon_eater_eyes.gd`, on nights 5 and 6 of Chapter 2.
- **The spawner:** `MobSpawner`, which now has a `class_name`.
  - The boss night is the boss plus 4 imps, and the boss rises at `SpawnPointN`.
  - New `summon()`, capped by `mob_cap` (14).
  - It shows the treeline eyes, and stops the escort once the boss is calmed.
- **Systems:**
  - `TimeManager.hold_night`;
  - `GameManager` counts `boss_calmed` and wins with "You calmed the Moon-Eater!";
  - `MoonLantern.set_drain()` and `lose_stages()`;
  - `Torch.snuff()`.
- **HUD:** a boss bar under the top strip, plus a thin moon bar for the reach window, and banners.
- **Audio:**
  - five `moon_eater_*` sounds (rise, stomp, sweep, summon, the final sigh), each also an `Fx` burst;
  - `music/boss.ogg`, played as the `boss` mood.
- **Barks:** `boss` (both kids react when it rises) and `boss_lantern` ("It wants the lantern!"). The 8 lines have generated voices.
- **Checks:**
  - the validator checks the boss mob and `music_boss`;
  - a smoke `_run_boss_scenario`;
  - screenshots 13–13e.
