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

## Hero motion

The kids move like kids, not the rig's stock adult adventurers. Their
own clips are hand-keyed (`art/characters/hero_clips.py`) and follow
the animation principles: a short anticipation, a strike on the
contact frame, follow-through and overlap, and chibi-sized
exaggeration.

- **Leo** is bouncy and eager: a little more hop, bigger arm swings, a
  slight forward lean. His attack is an overhead bonk with his walking
  stick: cocked up over his right shoulder, down in front of him, then
  low across his body while his head and arm lag.
- **Nela** is lighter and more careful: less bounce, smaller swings, a
  more upright stance, with her lantern held steady as she runs.

Standing still, each kid has their own idle and now and then a fidget
(every 6-12 s, never the same one twice running):

- **Leo** bobs on his knees and rocks foot to foot, impatient to go.
  He shades his eyes and scans the camp, scratches his head, or lifts
  his stick to look it over and plants it back with a tap.
- **Nela** breathes slowly with a gentle sway and a listening tilt of
  the head. She lifts her lantern to peer left and right, stretches her
  free arm up, or tucks her hair behind her ear.

Both kids share one walk and one run, varied by those knobs. The feet
stay planted: each cycle is authored for a known stride (Leo's longer
legs take longer, slower steps than Nela's quick little ones), and the
game plays it faster or slower with the kid's real speed. The run
leans in, with a short flight between steps and the knees driving up.

Being hit, going down and getting back up are shared too, sized to
each kid and scaled by their bounce. A hit is a flinch: knocked back
a little, hands up in front of the face, the knees giving, then a
wobble back to standing. Going down is a kid's flop: knocked back, a
plop onto the bottom, then flat on the back with the arms flung out
and the head rolled aside, the stick or lantern lying beside them.
Getting up starts from exactly that pose: a dazed shake of the head,
up to sitting on the hands, another shake, a push up through a crouch,
and a quick dust-off of the front. Each kid cheers in their own way:

- **Leo** crouches and leaps with his stick thrust high and his other
  fist up, then hops into two fist pumps.
- **Nela** clasps her hands under her chin, makes a light little hop
  with both arms up in a V (the lantern lifted high), and waves her
  free hand over her head while she sways.

The camp work is shared and takes as long as the stock clips did.
Chopping is a twist back and a forehand whack across into the trunk at
waist height, a jolt off it and a shake of the stung hand (Leo's stick
lands flat on the trunk; Nela's lantern just hangs). Picking up is a
squat with the free left hand to the ground, a look at the find and a
pat into the pocket. Gathering is a lean in with both hands, two tugs
and a hug of the haul. Building swings the barrel mallet in one hand,
up over the shoulder and down onto the plank the other hand steadies,
landing on the blow's impact frame; between blows the kid bends to
wiggle a peg in and seats it with two light taps.

The wind-up stays within 0.1 s at play speed, so attacks still feel
instant. As a hit lands, the attacker and the target hold their pose
for a blink (hit-stop) and the target squashes a little; the camera
never shakes. Each kid turns their head toward what they are dealing
with: the mob they fight, the tree or building they work on, a mob
nearby at night, or now and then the other kid.

What hangs off a kid swings and settles on short spring chains: Leo's
fringe, nape and side tufts and his camo pack; Nela's fringe, locks and
top bun, her pack with the bunny riding on it, her scarf tails and her
lantern; Mum's long hair and her pack. Leo's springs are a little
stiffer, so his tufts flick; Nela's hair and lantern are softer and
sway longer. They hold still through a hit-stop, like the rest of the
pose.

The faces stay painted, in the same hand-painted style as the head,
and change by swapping the painted eyes and mouth:

- **Blink:** every 2-6 s, now and then a quick double blink.
- **Hit:** a wince, eyes screwed shut (`> <`) under knitted brows and
  a gritted frown, for as long as the flinch plays.
- **Cheer:** a beam, the eyes squeezed into smiling arcs and a wide
  open grin.
- **Down:** dazed, swirly eyes, one brow up and a wobbly mouth, until
  the kid is back up.

Mum blinks too; her story beats keep her neutral face.

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
