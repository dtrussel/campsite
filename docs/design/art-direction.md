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
   - The camera looks down at about 42°, close to the kids, with a fairly narrow lens.
   - The top and bottom of the frame blur softly; the play band in the middle stays crisp.
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

## Mobs

The mob sheets in the concept set (06–08) are **not** adopted. The Shadow Imp,
Bramble Beast and Mushroom Gremlin keep the designs from features 026–028.
Each mob still reads by its own palette against the warm ground (spec §L, colour coding).

## Out of scope for now

The river, waterfall and bridge (10), the ruins (11) and the village houses (12)
are reference for future biomes, not for the camp.
