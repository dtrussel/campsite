# Feature 010: Leo → Ekko-inspired, Nela → Annie-inspired

## Context
After the v0.5.0 restyle the user is still not satisfied. They want:
- **Leo** to look more like **Ekko** from LoL;
- **Nela** to look more like **Annie** from LoL;
- both still based on their concept artwork.

We take the *style language* of those champions (proportions, silhouettes, shape design, face style) and apply it to the user's own character designs. We do not copy their outfits or logos.

User choices:
- **Leo:** keep the backwards cap, pushed back, with a tall upswept blond quiff bursting out of the front opening (an Ekko-like silhouette). Add a neckerchief, forearm wraps and chunky sneaker-boots.
- **Nela:**
  - an even bigger head and huge round eyes;
  - two puffy blond pigtails with pink ties instead of the curl cloud;
  - she hugs her bunny plush (Annie/Tibbers-style) and still holds the lantern;
  - the artwork's pants, boots and backpack stay.

The pipeline stays as is: `art/characters/{chibi,leo,nela}.py`, the `QUICK=1` previews, the sheet script and `paint_bake`.

## Approach

### Leo (Ekko cues: lean teen, dynamic upswept hair, bold asymmetry, oversized hands and feet)
- **Proportions:**
  - slightly leaner and taller: `Proportions(legs=1.6, spine=1.2, arms=1.15)`;
  - narrower waist, and a slightly longer neck.
- **Face:**
  - a sharper, more angular head: `sculpt_head` with jaw about 0.32, a defined chin, and cheekbones at 0.1;
  - a slightly longer face (radii z > x);
  - bigger almond eyes with a bold winged lid, a teal-blue iris and a bright highlight;
  - a sly one-sided smirk and a raised, cocky brow on one side (per-side brow tilt);
  - freckles kept.
- **Hair:**
  - a tall upswept quiff: 6–8 large `hair_clump`s rising from the front hairline, up and back over the cap front, with the tips curling back;
  - short tapered sides and nape;
  - sandy-blond, with a strong sheen band.
- **Cap:** pushed back on the head (tilted about 15° further back), with the brim angled down behind and the snapback strap visible under the quiff.
- **Outfit (artwork base, Ekko-flavoured asymmetry):**
  - light-blue tee with the rolled sleeve cuffs; the forest badge stays;
  - a teal neckerchief knotted at the side (new rigid chest piece);
  - bandage wraps on both forearms, with one wrist band in lime;
  - striped board shorts; one knee pad in teal;
  - bigger chunky sneaker-boots (scale about 1.3) with thick soles and lime accents;
  - big hands.
- **Gear:** a slightly smaller camo backpack with bedroll, bottle and rope, so it doesn't hide the silhouette. The walking stick becomes a stout carved staff: longer, with a rope-wrapped grip and a carved spiral top.

### Nela (Annie cues: tiny kid, very big head, huge round eyes, simple bold shapes, a plush friend in her arms)
- **Proportions:** `Proportions(legs=1.1, spine=1.0)` and a bigger head, radii about 0.39, with a rounder, softer face. The chin is small but not ball-round (jaw about 0.38, cheeks about 0.16).
- **Face:**
  - huge round eyes (w about 0.075, h about 0.07) with big irises, two highlights and lash flicks;
  - a tiny button nose and strong rosy cheeks;
  - a wide open happy smile.
- **Hair:**
  - replace the curl cloud with a smooth rounded hair cap over the crown and a short wavy fringe;
  - two big puffy pigtails at the sides, set high: fused spheres or clumps, each with a pink tie;
  - a few flyaway strands.
  - Pale honey blond.
- **Bunny in her arms:** a bigger plush bunny (about 0.35 tall) dangling from her **left** hand, held by a paw, like Annie's bear.
  - A new `chibi.place_in_hand(obj, rig, bone, action="Idle")` helper builds it in world coordinates relative to the hand's idle pose, then converts it into the rest pose. That way it hangs naturally in idle and swings with the arm.
  - The bunny is removed from the backpack, and the backpack is simplified (bedroll and cup).
- **Lantern** stays in the right hand.
- **Outfit:** pink tee, plum folk-pattern harem pants with cuffs, cream socks and brown boots with pink laces.

### Shared kit additions (`art/characters/chibi.py`)
- `place_in_hand(...)`: holding props in the idle pose.
- Per-side brow tilt (`brow(..., tilt, lift_side)`) and `almond_eye(..., highlights=2)` for round eyes.
- `pigtail(...)`: fused puffs plus a tie.
- `neckerchief(...)` and `wraps(...)`: bandage rings along a bone segment.

### Game integration
- Re-check scales: Leo about 0.66, Nela about 0.55, keeping Leo at about 1.35× Nela on screen. Adjust the HP bars (`player_controller.gd`, `companion_controller.gd`) and the Sibling TaskLabel and LanternLight.
- Re-render the portraits (`game/tools/render_icons.gd`, retune raise/distance).
- The title backdrop (`title_backdrop.gd`) picks up the new glbs automatically; only the scales need updating.
- Update the docs:
  - `.features/010-ekko-annie-style/*`;
  - `CREDITS.md`: note that the art style is inspired by LoL and the designs are original from the user's concept art.
- Version 0.6.0-playtest1.

## Verification
1. **`QUICK=1` loop:** previews of the T-pose, the face close-up, the back, Idle, Running_A, the attack, and PickUp. Compare side by side with the user's artwork and against each other.
2. **Full bake:** check deformation, the quiff and pigtails during run and attack, and that the bunny hangs from the hand in Idle.
3. `tools/check.sh` is green.
4. **Xvfb screenshots** (title, day, night): check silhouettes, readability and the size contrast.
5. **`tools/export_playtest.sh`:** the self-test passes and both zips stay under 30 MiB.
6. **Ship:** commit, push, and send the face close-ups, sheets, screenshots and zips.
