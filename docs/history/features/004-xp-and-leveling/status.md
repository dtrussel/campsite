# Feature 004 — Status

## 2026-05-16 — Implementation session

**Completed**

- Feature folder with all five workflow docs.
- `CharacterStatsDefinition` data class
  (`game/scripts/progression/character_stats.gd`).
- `player_stats.tres` and `sibling_stats.tres` under
  `game/resources/progression/`.
- `ProgressionManager` autoload registered in `project.godot`.
- `Mob.take_damage(amount, source)`: stores the last damager and
  awards `xp_reward` to them on death.
- Player + Sibling register with `ProgressionManager` in `_ready`
  and bump their attack damage on `level_up`.
- `BuildManager` awards 5 XP to the player on every successful
  placement.
- `ResourceNode` awards 1 XP to the actor on every gather
  completion.
- `ProgressionManager` listens to `TimeManager.dawn_started` and
  awards 10 XP to every registered character.
- HUD shows `Player: Lv N - X / Y XP` and `Sibling: Lv N - X / Y
  XP`; rows flash green on level-up.

**Next**

- Manual playtest of `test-plan.md`.
- Feature 005 candidates: crafting (Phase 7) or save/load (Phase 8).

**Blocking**

- None.
