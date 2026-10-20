# Feature 045: Construction polish (plan)

Status: **done**. Rough size: **M**.

## Goal
User feedback on 044's construction:
- The building animation should look more like building.
- A blueprint should look clearly different from a finished building.

Before this feature, a blueprint was the finished model sunk into the ground, and the hero looped the attack chop at it.

## Decisions taken with the user
- **Blueprint look:** a ghost plus a construction site. A see-through blue copy of the finished shape, with the solid building rising inside it. Corner stakes, a rope line and a pile of materials that shrinks as the work goes on.
- **Tool:** a hammer prop from the art pipeline, held while building and repairing, with a dedicated beat of blows and fetching.

## Work
1. **Art:** a `hammer` prop in `art/props/camp.py`, exported as `game/assets/custom/hammer.glb` (497 tris, 256 px painted bake).
2. **`CharacterVisual`:** `show_tool(key)` / `hide_tool()` put a tool on `handslot.r` through a BoneAttachment3D. They also hide `tool_hidden_parts` (from `HeroDefinition`: `Leo_Stick`, `Nela_Lantern` and `Nela_LanternGlow`).
3. **`BuildBeat`** (`scripts/utilities/build_beat.gd`): the shared hammering rhythm. Two `hammer` blows (`2H_Melee_Attack_Chop`), then `pick` or `tinker` (`PickUp` / `Use_Item`). It calls `Building.on_build_hit()` at the impact frame. The hero (BUILD, REPAIR) and the companion (Repair task) both own one, and put the hammer away whenever they are not working.
4. **`Building`:**
   - `_dress_blueprint()` makes the `Ghost` (a duplicate of `Visual` with `blueprint_ghost.gdshader`) and swaps `Visual`'s painted materials for cut-off copies (`painted_prop_build.gdshader`).
   - It also builds the `Site`: stakes, rope, dirt patch and the cost pile.
   - `_refresh_construction()` moves the build line (both shaders' clip heights) and hides pile pieces.
   - `on_build_hit()`: a squash, a ghost flash and chips.
   - `_undress_blueprint()` on completion: restore the materials, fade the ghost, sink the site, a bounce, plus a new `build_done` sparkle burst.
5. **Tests and docs:** the smoke construction check, new screenshots, the design spec, art direction, the art README and the roadmap.
