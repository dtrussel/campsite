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

## D10: Painted materials become one shader (agent)
- **Context.** The style target needs sunny tops, contact shade and fine detail. StandardMaterial3D cannot do these.
- **Decision.**
  - Painted props and characters now use `painted_prop.gdshader`.
  - Emissive bits stay unshaded StandardMaterial3D.
  - The shared finish lives in `painted_common.gdshaderinc`.
  - The noise is in object space so it never swims on moving characters. Characters get less texel noise and no contact shade.

## D11: Props get an ink line (agent)
- **Decision.** Every painted prop gets a thin warm-brown inverted-hull outline: 0.011 m, `Stylize.PROP_OUTLINE_*`.
- **Cost.** This adds one extra draw per prop surface. If the FPS check on a real GPU fails, drop it from rocks and small props first.
- **Foliage.** Swaying foliage has no outline, because the hull would not sway with it.

## D12: No MSAA (agent)
- **Context.** `msaa_3d` 2× under Compatibility (tested under Xvfb) left the night lit like dusk.
- **Decision.** MSAA stays off.
- **Revisit.** Retry on a real GPU before revisiting.

## D13: The grade fades out at night (agent)
- **Context.** The day exposure and contrast crushed the dark night blues to black. Only the warm firelight survived, so the night read warm.
- **Decision.** Exposure, colour balance and contrast blend to neutral with `night_amount`.

## D14: Softer tilt-shift (user)
- **Context.** After M4 the user found the blur a bit too strong.
- **Decision.** The tilt-shift is softened, roughly halfway back toward its pre-M4 strength. The grade is unchanged.

| Setting | M4 | Now |
|---|---|---|
| `focus_band` | 0.08 | 0.12 |
| `falloff` | 0.26 | 0.32 |
| `max_radius` (px at 1080p) | 11 | 7 |
| `max_lod` | 2.6 | 2.0 |
| `bottom_boost` | 1.3 | 1.2 |
| Blur amount cap | 1.3 | 1.15 |
| `haze` | 0.05 | 0.04 |

## D15: Model pass: dense detail, keep only what improved (user and agent)
- **Context.** The user asked for one pass on every model, with a quality check after each, committing a model only if it actually improved.
- **Pipeline.**
  - Detail is modelled dense and baked onto the decimated game mesh in one selected-to-active emission bake (`paint_bake.paint_direct`, `detail.bake_prop`).
  - The bake's ray length must cover the deepest carved detail.
  - Thin open sheets (canvas, awnings) use hand-made low twins (`bake_prop_lows`), because collapse decimation tears them.
- **This fixes D7.** Tile and stripe colours no longer depend on the triangle budget.
- **Gate.** Each model was rendered in game (`tools/model_gallery.tscn`) before and after.
  - Kept as is: `rock_pebbles`, Leo and Nela.
  - Everything else was committed.

## D16: Kids: colour and silhouette over seams (user and agent)
- **Context.** The user asked to improve Leo and Nela after M6 kept them as they were.
- **Decision.** Change only what reads at game scale (about 100 px tall), each change checked in the gallery and in a day screenshot crop:
  - **Palette:** the clothes are saturated past the concept's RGB, so they survive the warm day grade. Tee `TEE` (0.24, 0.52, 0.96); trousers `PANTS` (0.40, 0.20, 0.86).
  - **Emblems** are painted into the tee's colour function on a denser tee (30k faces before the bake), not built as decal geometry.
  - **Soles** follow the foot's outline (`chibi.sole_slab`).
- **Kept:** Nela's bun. The ponytail was tried twice and read worse from above.


## D17: Foliage from individual leaves (user and agent)
- **Context.** The user picked foliage as the next art pass. The trees and bushes read as smooth, glossy blobs and the resin pines as plastic cones; the concept's canopies are built from many small leaves with dark gaps between them.
- **Decision.**
  - **Leaves:** keep the clump shell, painted darker as the shade between leaves, and scatter solid leaves over it (`detail.scatter_leaves`). They are not transparent cards.
    - Trees and bushes get rounded ovals: four triangles each, cupped, with the tip tilted out of the shell.
    - Pines get pointed needle blades that run down each tier's slope.
  - **Export:** the leaves go into the game mesh as they are; only the shell and trunk are decimated.
  - **Bake cage:** leaves carry a `cage_near` attribute, and `paint_bake.paint_direct` gives those vertices a near cage, so a bake ray cannot pick up an overlapping neighbour's colour.
  - **Double-sided shader:** the foliage shader is double-sided, with the normal flipped for back faces.
- **Cost.**

  | Model | Triangles before | Triangles now |
  |---|---|---|
  | Broadleaf tree | 2.9k | 5.1k |
  | Pine | 2.95k | 3.6k |
  | Berry bush | — | 4.5k |
  | Flower bush | — | 3.3k |

  Godot's import LODs reduce the far border trees.
- **Not chosen:** alpha-cut leaf cards would need a second material and texture per tree and an alpha-scissor path in the foliage shader.
