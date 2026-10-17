# Feature 038: The Hollow King (plan)

Status: **planned** (roadmap from the 2026-10 brainstorm). Rough size: **L**.

## Goal
The final night of Chapter 2 is a boss fight, and beating it is the true ending of the story.

## Scope
- **The boss.** A huge, sad shadow, about 3× the size of a beast, with glowing eyes and pieces of lost things in its body (a toy, a boot, branches). It is painted and baked like the 026–028 remodels and has its own clips: rise, idle, stomp, sweep, summon, stagger and the shrink ending.
- **Phases:**
  1. Telegraphed **stomp** (a ring on the ground, as with the beast slam) and **sweep**.
  2. At 60% HP it **summons** imp packs from the lanes and puts out torches.
  3. At 25% HP it reaches for the Moon Lantern. The lantern stage (036) decides how long the kids have.
- **HUD:** a boss bar under the top strip, with its name.
- **Ending:** it doesn't die but **shrinks** into a small warm shadow by the fire. Then comes the true-ending card (035).
- **Nights before:** its eyes appear at the treeline from night 5.

## Systems touched
- New: `resources/mobs/hollow_king.tres`, `scenes/mobs/HollowKing.tscn`, `scripts/mobs/boss_controller.gd` (extends or composes `mob_controller.gd`).
- `scripts/mobs/mob_spawner.gd`: a final-night override (the boss plus a small escort).
- `scripts/core/game_manager.gd`: win on boss defeat as well as on dawn of the last night.
- `scripts/ui/hud.gd`: the boss bar.
- Audio: a boss music mood in `audio_manager.gd`.

## Depends on
036 (the lantern stage changes phase 3) and 035 (ending card).
