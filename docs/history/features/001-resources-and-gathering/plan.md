# Feature 001 — Resources and gathering

## Goal

Implement the first real gameplay verb: **gather**. The player walks up to a
resource node (tree, rock, berry bush), presses **E**, and a counter in the
HUD ticks up. This satisfies Phase 2 of the roadmap end-to-end.

## Why it matters

Closes the first feedback loop in the game and unlocks every later phase that
spends resources (Phase 3 building, Phase 7 crafting, Phase 5 mob drops). It
also exercises the data-driven design pattern (`.tres` resources +
autoload-owned inventory) that everything downstream depends on.

Pillars served: *Gather and manage resources* (primary); *Build and improve a
campsite base* (sets up Phase 3); *Maintain strong visual clarity*
(introduces the first decorative props as a side effect).

## Scope

### In scope
- `ResourceDefinition` data class.
- All 10 resource `.tres` files under `game/resources/items/`.
- `ResourceManager` autoload with inventory dictionary and signal API.
- Shared `ResourceNode` scene script.
- Three resource node scenes (`TreeNode`, `RockNode`, `BerryBush`).
- `GatherInteractor` Area3D composition piece on the player.
- Player state machine (`IDLE` / `MOVING` / `GATHERING`).
- New `interact` input action bound to **E**.
- HUD rewire to definition-driven rows updated on `resource_changed`.

### Out of scope
- Real icons, gather VFX/SFX (text-only HUD this round).
- Companion gathering (Phase 4).
- Mob drops (Phase 5).
- Storage cap enforcement (post Phase 8).
- Build mode (Feature 002 / Phase 3).

## Approach

Build bottom-up: data class → `.tres` files → autoload → resource node script
and scenes → player composition (`GatherInteractor`) → player state machine →
HUD signal wiring → world placement.

## Dependencies

- Phase 0 bootstrap (already shipped).
- Godot 4.x installed locally to run the manual acceptance checks.
