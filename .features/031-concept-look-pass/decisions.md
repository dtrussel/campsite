# Feature 031: Decisions

## D1: The current mob designs stay (team, 2026-10-16)
- **Context.** The new sheets 06–08 redesign the imp (violet-black with a smoke aura), the gremlin (red spotted cap, green skin) and the beast (rock-and-log golem with a flower crown). Features 026–028 just remodelled all three after earlier concepts.
- **Decision.** Keep features 026–028. The sheets are kept as reference only.
- **Note.** The imp's purple smoke may still be borrowed as a VFX idea.

## D2: Scope is "look & mood first" (team)
- **In scope:** lighting, grade, tilt-shift, ground, flora and cozy camp props.
- **Out of scope:** the river, waterfall and bridge; ruins and village biomes; a re-paint of the kids. The turnarounds 04–05 already match the current kids.

## D3: References are stored as WebP (team)
- **Decision.** Quality 90 WebP, keeping the original file names.
- **Why.** It keeps git history small. The images are reference, not game assets.

## D4: Tilt-shift is a custom screen shader (agent)
- **Context.** The game runs on GL Compatibility, where the built-in DOF is not available.
- **Decision.** A `canvas_item` shader samples the screen texture with mipmaps (`textureLod`), behind the HUD layer, with an on/off setting.

## D5: Autumn and haunted props move to the edges (agent)
- **Context.** The concept is summery: green pines and no pumpkins.
- **Decision.** Use green pines near the camp. Autumn pines, dead trees and jack-o'-lanterns stay on the outer ring and the mob lanes, so the threat still reads at night.

## D6: The Resin pines keep their autumn colours (agent)
- **Decision.** The gatherable `PineTree` resource still uses `pine_a` and `pine_b`.
- **Why.** Their orange reads at once as "the resin tree" against the now green forest, which helps readability (NFR-6).

## D7: Two unique props go over the budget (agent)
- **Context.** The stall's stripes and the well's bricks are per-face colours, and decimating to 1.5k merged them.
- **Decision.** `market_stall` (2.6k triangles) and `stone_well` (2.4k) are allowed over the budget. There is one of each per map.
- **Signpost.** The signpost's glyph is real geometry, so it stays at budget.

## D8: No moon in this pass (agent)
- **Context.** Neither the game camera nor the title camera shows the sky.
- **Decision.** No moon for now. A moon only makes sense with a camera that sees the horizon, such as a future intro or end-screen shot.
- **Night instead.** The night look comes from the teal-blue grade, fireflies, the fire and the warm lantern and tent lights.

## D9: The decor has no gameplay (agent)
- **Decision.** The well, stall, seats, tripod and sign are dressing.
- **Note.** A gameplay use, such as the well as a water source, is a possible follow-up.
