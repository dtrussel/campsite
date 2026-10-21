# Feature 004 — XP and leveling

## Goal

Add the missing scoring layer to combat and the day loop. Each
character (player and Sibling) earns XP for things they already do
— defeating a mob, placing a building, gathering a resource,
surviving a night — and levels up on a simple cumulative-threshold
table. Level-ups bump attack damage visibly, so subsequent fights
resolve faster.

## Why it matters

Combat works as of Feature 003 but is unscored: there is no reason
to attribute kills, no progression metric, no level-up moment. This
satisfies the third pillar of the prototype's first vertical slice
(*level up characters through useful actions*) and unblocks Phase 7
(crafting XP) and Phase 8 (save/load progression).

## Scope

### In scope
- `CharacterStatsDefinition` data class.
- `.tres` files for the player and the Sibling.
- `ProgressionManager` autoload with per-character XP / level state.
- XP sources: mob kill, building placement, gather completion,
  surviving a night.
- Stat bump on level up: `attack_damage` increases per level.
- HUD shows `Player: Lv N - X / Y XP` and `Sibling: Lv N - X / Y
  XP`; flashes briefly on level-up.
- `Mob.take_damage(amount, source)` damage attribution.

### Out of scope
- Skill trees / branching upgrades.
- Visible XP bars (numbers only this round).
- Companion damage / death (still invulnerable).
- HP bumps (CharacterStatsDefinition has the fields but no system
  reads them yet — wired when something damages the player).
- Crafting XP (Phase 7).
- Save / load (Phase 8).

## Approach

Bottom-up:
1. Data class + two `.tres` files.
2. `ProgressionManager` autoload + register in `project.godot`.
3. `Mob.take_damage(amount, source)`; reward XP on death.
4. Player & Sibling register on `_ready`, listen for `level_up`,
   bump `attack_damage`, pass `self` to `Mob.take_damage`.
5. `BuildManager` and `ResourceNode` call `award_xp` after their
   existing success points.
6. HUD adds two progress rows.

## Dependencies

- Features 000–003.
- Godot 4.x locally for manual playtest.
