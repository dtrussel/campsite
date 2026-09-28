# Feature 010: Status

## 2026-09-28

**Completed**
- **Leo (Ekko-inspired).**
  - Taller and leaner (legs 1.6, arms 1.15), with a longer, more angular face.
  - A tall upswept blond swoosh bursting out of a pushed-back backwards cap.
  - One cocky raised brow, a smirk, and bigger almond eyes.
  - A teal neckerchief, bandage wraps on both forearms, a lime wrist band and one teal knee pad.
  - Bigger sneaker-boots, a smaller backpack, and a longer carved staff.
  - In-game scale is 0.63.
- **Nela (Annie-inspired).**
  - A bigger, rounder head with chubby cheeks.
  - Huge round eyes with two sparkles and lash flicks.
  - A smooth hair cap, a soft fringe, and two puffy high pigtails with pink scrunchies.
  - Her plush bunny dangles from her left hand (`chibi.place_in_hand`), and she keeps the lantern in her right.
- **Kit.** `place_in_hand` and `idle_bone_position`.
- **Game.** Portraits hide the bunny, lantern and staff. Scales and HP bars were retuned.
- **Checks.** `tools/check.sh` is green, and the screenshots were reviewed.

## 2026-09-28 (faces pass, v0.7.0)
- **Leo, more Ekko.**
  - Heavy half-lidded confident eyes (`almond_eye` gains `lid_drop` and `lid_scale`).
  - Thick angled brows, one of them cocky and raised.
  - A wide, open cocky grin.
  - Teal face-paint stripes on the cheekbones, a squarer jaw with cheekbones, and a lighter blush.
- **Nela, more Annie.**
  - A rounder face with a small chin and big cheeks.
  - Huge, low-set, wide-apart eyes with big pupils and two sparkles (`pupil`, `big_highlight`).
  - Thin high brows, a blunt straight-cut fringe, and a small cheeky grin.
- **Scale.** Both characters are about 15% bigger on screen: Leo 0.72, Nela 0.66. The HP bars and task label were raised to match.
