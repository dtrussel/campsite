# Feature 004 — Test plan

Run inside the Godot editor with **F5** on `Main.tscn`.

## Acceptance criteria

- [ ] On startup, the HUD shows `Player: Lv 1 - 0 / 30 XP` and
      `Sibling: Lv 1 - 0 / 30 XP`.
- [ ] Gathering wood from a tree adds **1 XP** to the player.
- [ ] Placing a Wooden Fence adds **5 XP** to the player.
- [ ] Landing the killing blow on a Shadow Imp with **LMB** adds
      **5 XP** to the player.
- [ ] If the Sibling is in `Guard Base` and lands the killing blow
      on a Shadow Imp, **5 XP** goes to the Sibling, not the
      player.
- [ ] If the Sibling is in `Gather Nearest` and finishes a tree,
      **1 XP** goes to the Sibling, not the player.
- [ ] Surviving until dawn adds **10 XP** to every registered
      character.
- [ ] At 30 XP the player flips to `Lv 2`; the row briefly flashes
      green; the next mob takes one fewer hit to kill.
- [ ] At 30 XP the Sibling flips to `Lv 2`; subsequent guarding
      kills are visibly faster.
- [ ] XP and level persist across day/night transitions (they only
      reset on Godot restart, since save/load is Phase 8).

## Smoke checklist (no regressions)

- [ ] Project opens; no Output errors on startup.
- [ ] Main scene runs.
- [ ] WASD still moves, camera still follows.
- [ ] E still gathers; resource counts still update.
- [ ] B still toggles build mode; LMB still places; resources still
      decrement on placement.
- [ ] LMB outside build mode still attacks the nearest mob.
- [ ] F / G / T / Y still assign companion tasks.
- [ ] Day → Sunset → Night → Dawn still cycles; sun still dims at
      night.
- [ ] Mobs still spawn at night, still attack the fences and the
      campfire, still die.
- [ ] Camp-destroyed banner still appears at base HP 0.

## Edge cases worth exercising

- [ ] Land a finishing blow on a mob from across the attack range
      — the XP still goes to the player (range gating happens in
      `_find_nearest_mob_in_range`).
- [ ] Have the Sibling whittle a mob down to ~1 HP, then steal the
      kill with LMB — XP goes to the player (last damager wins).
- [ ] Earn more than one level of XP in a single award (e.g. by
      surviving a night while sitting at 25 XP) — the manager
      emits `level_up` once per crossed threshold, the HUD reflects
      the final level.
- [ ] Place a building mid-wave — XP still awarded, build mode
      stays active.
