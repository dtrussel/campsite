# Feature 036: Moon Lantern (plan)

Status: **planned** (roadmap from the 2026-10 brainstorm). Rough size: **M**.

## Goal
Glow Shards become the plot. The kids rebuild the **Moon Lantern** by the tent, and every stage lights up more of the night.

## Scope
- **A lantern pedestal** stands next to the tent (`world_dressing.gd`) as an interactable like the campfire. E delivers carried shards; a shard pickup goes into the stash and the player brings it over. It has stages 0 to 3 for Chapter 1 and 0 to 6 for Chapter 2.
- **Effects per stage:**
  - a safe light ring around camp that grows with each stage (radius 4 → 9 m);
  - imps inside the ring are slowed and take light damage, like the Glow Lantern building's aura;
  - from a high stage on, gremlins won't enter the ring.
- **Shards:** the drop moves from `GameManager.stats.kills % n` to a chance per mob (`drop_chance`) with a pity counter, so a beast kill no longer shifts the imp drop timing. The chapter's goal is tuned so that a careful player finishes on the last night.
- **HUD:** a moon dial next to the day counter fills by stage. The dawn card (035) names the next stage.
- **Story hook:** the last stage of Chapter 2 is what lets the kids face the Hollow King (038).

## Systems touched
- New: `scripts/base/moon_lantern.gd` and `scenes/base/MoonLantern.tscn` (a painted, baked model in the 031 style).
- `scripts/mobs/mob_definition.gd` and `mob_controller.gd` (`_maybe_drop_loot`): `drop_chance` and the pity counter.
- `scripts/mobs/shadow_aura.gd`: reused for the ring effect.
- `scripts/core/save_manager.gd`: `lantern{stage, shards}`. The snapshot stays at VERSION 1, with a default of 0.
- `scripts/ui/hud.gd`: the moon dial.
- `scripts/buildings/` Glow Lantern: keep it, but it competes for shards, which is a choice.

## Depends on
035 (lines). Feeds 038 and 040.
