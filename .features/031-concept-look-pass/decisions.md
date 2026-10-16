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
