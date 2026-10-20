# Art direction: the "golden diorama" look

This guide distils the team's October 2026 concept art
([`art/reference/concept-2026-10/`](../../art/reference/concept-2026-10/README.md)).
It refines §L of the [game design spec](game-design-spec.md#l-art-direction).
Readability over realism (NFR-6) still wins every conflict.

## The look in one line

The camp should look like a **warm miniature diorama in golden-hour light**.
By night it becomes **a deep blue world with warm pools of fire and lantern light**.

## Pillars

1. **Tilt-shift miniature.**
   - The camera looks down at about 42°, close to the kids, with a fairly narrow lens. Zoomed in, it lowers to 28° and looks across the camp (044).
   - The top and bottom of the frame blur softly; the play band in the middle stays crisp. Since playtest 1 (044) the default blur is Soft (half the old radius, a wider crisp band); Strong keeps the original look.
   - The UI is never blurred.
2. **Golden hour by day.**
   - Light is warm amber and saturated. Shadows are deep but warm: brown and plum, never grey.
   - The dirt clearing glows orange-ochre.
3. **Dense, flowery nature.**
   - Wildflowers are everywhere: yellow, white daisies and purple lupine spikes.
   - Pines are **green** with yellow-green tips. Leafy trees are made of chunky clusters.
   - Rocks are rounded, warm beige-grey and mossy on top.
4. **A lived-in camp.**
   - Wood and canvas, crates, barrels, lanterns on posts, log and stump seats around a stone fire ring.
   - A cooking tripod with a pot, a carved tent-glyph signpost, a red/white striped stall and a stone well with a red tile roof.
   - Clutter frames the clearing but never blocks the play space.
5. **Night is cozy-tense, not black.**
   - Moon-blue ambient light and a visible moon.
   - The fire is the key light; lanterns and the tent interior glow warm.
   - Fireflies drift in the dark.
   - Mobs bring their own glow (imp eyes, beast eyes, Glow Shards).

## The HD-2D finish (milestone 4)

Reference `13_style_target_village.webp` sets the finish on top of the pillars:

- **Contrast.** Lit tops glow; sides and undersides fall into deep warm-brown shade.
  - Day frame target: median brightness about 120–125 of 255, darkest 5 % near 50, brightest 5 % near 190.
  - Colour balance about R:G:B = 1 : 0.77 : 0.30.
  - `screenshots.tscn` day shots are measured against these numbers.
- **Painted detail.** Smooth surfaces carry fine texel and blotch noise (`painted_common.gdshaderinc`, ground `texel_*`). They never read as plastic.
- **Ink line.** Props get a thin warm-brown inverted-hull outline; heroes a darker one; imps a heavy purple one.
- **Tilt-shift.** A crisp middle band with a light sharpen; the foreground blurs more than the background, into soft bokeh.
- **Grade on luminance.** Contrast and the S-curve act on brightness only, so the hues survive. The grade fades to neutral at night, where the blue world and warm pools come from the lighting.

## Palette

These colours are sampled from the camp scenes (sRGB, median-cut on 01–03). The accent colours are picked by eye. Use them as targets for
ground textures, lighting palettes (`world_lighting.gd`) and prop scripts.

| Role | Day | Night |
|------|-----|-------|
| Dirt clearing (lit) | `#f6b65f`, `#e4ac67`, `#ce9357` | `#a4572f`, `#d38a43` (firelit) |
| Dirt (shade) / wood | `#b4733d`, `#8b5830`, `#84421e` | `#793013`, `#601d0c` |
| Deep warm shadow | `#5d452b`, `#2f2718` | `#3d1a0e`, `#231612` |
| Foliage | `#766d3f`, `#6b6038`, `#3d432d`, `#303d28` | `#0a1a27` |
| Sand / canvas | `#c6a968`, `#b88d4b` | — |
| Sky / ambient | — | `#252c3b`, `#080a0d` |
| Accents | Awning red `#c8402e`, daisy white, lupine purple `#8a62c8`, water teal `#3fb2c8` | Lantern amber `#ffb455`, moon `#e8ecf4` |

## Construction (feature 045)

An unfinished building must never read as a finished one.

- **Blueprint ghost:** pale cyan-blue (about `#61adff`), see-through, unshaded, with a bright fresnel edge, thin stripes drifting upward and a slow pulse (`shaders/blueprint_ghost.gdshader`). It is the only cool, glowing thing in the warm camp, so it stands out by day and at sunset.
- **Rising solid:** the real painted building is cut off at the build line (`shaders/painted_prop_build.gdshader`), so it grows from the ground up inside the ghost. A thin warm glow marks the line, and fresh timber just under it is paler.
- **Site:** four wooden stakes with a twine line, a faint dirt patch, and a small crossed pile of planks (stones, clay, scrap or shards to match the cost). Simple boxes styled as props; they sink away when the building is done.
- **Mallet:** a kid-sized barrel mallet (`art/props/camp.py` `hammer`, about 500 tris) held in the right hand while building or repairing.

## Storybook and story props (feature 047)

- **Storybook paintings:** 16:9, painted in the key art's storybook style:
  golden-hour warmth, deep-blue nights, the kids exactly as on their
  turnarounds. In game they are cover-fitted at 1600×900 under a dark text
  band over the bottom third, so faces and key props sit in the top two
  thirds (`story_art.py` can `lift` a painting that needs it).
- **Expression portraits:** the head and shoulders, cut into a 192 px round with
  a brass ring, the same for Mum and the kids.
- **Moon Lantern:** weathered granite, about 1.9 m tall. A tapered plinth of
  stone courses with a carved crescent on the front, then an iron-framed
  glass lamp, a stepped stone roof and a pointed finial. Moss and ivy grow on
  the tops and joints. Its light is moon-blue: shards inside the glass, a
  soft core, and the crescent glowing warm gold at the top stage.
- **Little golem:** knee-high and chibi, in warmer versions of the
  Moon-Eater's materials, with a head 0.42 of its height. It has a rounded face
  of upright planks with tall, deep-set amber eyes and a small smile, under a
  shaggy shingle bob with a round plank-slice ear on each side, and stick
  pegs and a sprout on top. Its shield-shaped plank trunk has a big amber
  window with a pale gold crescent. Chunky arms of stones and planks hang
  to its hips, and its legs are stacked stones. It is the only warm glow of
  its own by the fire.

## Mum (feature 043)

Mum follows the team's character sheet
(`art/reference/concept-2026-10/14_mum_character_sheet.webp`): a grown-up
on the kids' rig, much longer in the legs, body and arms with a smaller
head, in the same painted, ink-lined look. The palette is a lime jacket
`#bdcc3d`, a black top, a tan scarf `#a88c6b`, charcoal trousers, brown
boots with red laces, an olive pack and a blue bedroll. Her storybook
portraits are cut from the sheet's expressions. The beagle isn't adopted.

## Mobs

The mob sheets in the concept set (06–08) are **not** adopted. The Shadow Imp,
Bramble Beast and Mushroom Gremlin keep the designs from features 026–028.
Each mob still reads by its own palette against the warm ground (spec §L, colour coding).

## Map layout (feature 032)

The camp sits in a forest clearing. Four mob lanes come in along the axes as open, trodden trails. The corners between them are four groves, each with its resource, ground, landmark and forest wall:

| Corner | Grove |
|---|---|
| NW | Pine Grove |
| NE | Stony Pond |
| SW | Woodlot |
| SE | Fairy Ring |

Footpaths lead to each grove, and the old road runs south.

The plan lives in `WorldLayout`. The rules and the map are in [`docs/history/features/032-world-layout/plan.md`](../history/features/032-world-layout/plan.md).

## UI: "campcraft" (feature 033)

The HUD and menus are built from the same camp materials as the world, not a
cold overlay.

- **Plates.** Dark walnut with plank grain, a brass rim (`#c9974a`), an ink
  inner line and brass rivets in the corners. Shadows are warm brown.
- **Accents.** Cream canvas (`#efe2c4`) for key tabs, level badges, tooltips,
  the imp tag and the event ribbon. Ember orange for fire and highlights,
  moon-blue for night.
- **Bars.** Rounded, in a warm dark trough with a brass rim: HP leaf-green
  (`#6cc04a`), campfire ember, XP lavender. World health bars match.
- **Type.** Cinzel for titles, Nunito Sans for body. Text is cream with a dark
  brown (`#28180e`) outline, never pure black or grey-white.
- **Footprint.** The HUD stays in the corners and edges, out of the play band.
  The top centre is one slim strip (moons, day dial, campfire), and banners
  appear on a ribbon just below it.
- **Artwork.** `art/ui/hud_kit.py` generates the 9-slice pieces into
  `game/assets/ui/hud/`; `UiKit` and `HudWidgets` use them.

## Out of scope for now

The river, waterfall and bridge (10), the ruins (11) and the village houses (12)
are reference for future biomes, not for the camp.
