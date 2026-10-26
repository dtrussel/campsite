# 11: Hit-stop and squash

Status: done (open: the user's visual sign-off)
Blocked by: 02

**What to build:** when a hero's hit lands on the contact frame, the attacker and the target freeze for about 40–60 ms (**hit-stop**), and the target squashes slightly and recovers. Only their visuals freeze. Damage, knockback, gameplay time, timers, the companion, other mobs and the camera all keep running. Nothing shakes or flashes the screen.

- [x] Hit-stop applies to the attacker's and the target's visuals on every hero hit, melee or pebble, in both roles.
- [x] Smoke: during a hit-stop, the attacker's and target's animation is frozen while the companion and another mob keep animating and moving. Afterwards both resume.
- [x] Smoke: a target killed by the hit still dies normally (no frozen corpse).
- [x] In-game captures are under `## Comments` for sign-off.
- [x] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments

- **2026-10-25, done:** `Hero.on_attack_hit`, which HeroHits.strike calls for every hit a hero lands (swing, Big Swing extra, pebble, Ricochet or pierce bounce, in both roles), calls `CharacterVisual.hit_stop()` on the hero's visual and `hit_stop(true)` on the target's `Visual`. The visual holds for `HIT_STOP_SECONDS` (0.05 game s) and at least `HIT_STOP_MIN_FRAMES` (2) frames: its AnimationTree and AnimationPlayer go to manual processing, and `face`, the lean and the look wait. With `squash` the model goes 12 % wider and shorter through the stop and eases back over 0.14 s. `is_hit_stopped()` is the test hook. Damage, knockback, flash and float text apply as the hit lands; the hit reaction or death clip plays when the stop ends. The smoke scenario is `scenarios/hero_hit_stop.gd`.
  - **The old global hit-stop is gone.** The player's `_swing` used to call `Fx.hit_stop()`, which dropped `Engine.time_scale` to 8 % for 0.05 s, so the whole game stuttered. `Fx.hit_stop` and `Fx.unstopped_time_scale` are removed, and the perk picker and `perks.gd` no longer work around them. `PlayerController._swing` is gone too (Hero's default does the same).
  - **Smoke timing:** physics ticks 60 times per real second whatever the time scale, and the smoke game runs at 4x, so a 0.05 s stop (12.5 ms real) usually sees no physics tick. The smoke checks that the clock stays at full speed through the stop and that the other mob's pose changes, then waits on the next tick for its walk.
  - **Captures** (before the attack, during the stop, 0.1 s after; Leo then Nela played): `.scratch/hero-animation/captures/11-hit-stop-leo.png` and `11-hit-stop-nela.png`. The beast is squashed in the middle frame and back in the last.
- **2026-10-26, review fixes:** an attack now hit-stops the hero once (its first hit), however many mobs it strikes (Big Swing extras, Ricochet bounces, pierces); each mob struck is still hit-stopped and squashed. The hit-stop lives in `CharacterHitStop`, composed by `CharacterVisual`. The smoke checks moved from `hero_hit_stop.gd` into `hero_animation.gd`, with a new one-stop-per-attack check. Status set to `done (open: the user's visual sign-off)`.
