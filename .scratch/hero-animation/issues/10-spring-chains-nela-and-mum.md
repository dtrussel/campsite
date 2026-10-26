# 10: Spring chains: Nela and Mum

Status: done (open: the user's visual sign-off)
Blocked by: 09

**What to build:** Nela's hair, backpack and lantern swing and settle like Leo's, with her own tuning. Mum gets chains for her hair and pack too, wherever her rig and model take them at no extra cost. If a part of Mum's needs real remodelling, it is left out and the reason is noted.

- [x] Nela's model has its chains, tuned on her data, and the smoke check from 09 passes for her.
- [x] Mum has chains where they are free, and her story clips (arrival, wave, cheer) still play.
- [x] Nela and Mum stay within the triangle budget.
- [x] In-game captures are under `## Comments` for sign-off.
- [x] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments

- **2026-10-26, done.** Nela swings on eight chains: `hair.front` (fringe
  wisps), `hair.back` (nape locks), `hair.l` / `hair.r` (face-framing
  locks), `hair.bun` (one bone, the whole top bun), `pack` (her bunny
  rides on it), `scarf` (hangs off the swinging pack) and `lantern` (one
  bone from her hand; the lantern and its glow swing whole, and it still
  hides while she builds). Her own tuning is in `nela.tres`. Mum has four,
  all free (no new triangles, no remodelling): `hair.l` / `hair.r` (the
  long side fall and face-framing locks), `hair.back` (the hair under her
  bun) and `pack` (with the mug). Her bun and crown stay on the head:
  they sit tight to the skull, so a chain there would only read as the
  head wobbling. Her tuning is `MumArrival.SPRINGS` (she has no hero
  data); her long hair is softer and slower to settle (~0.5 s) than the
  kids' locks (~0.2 s).
- Triangles: Nela 35,711, Mum 35,500 (unchanged; budget 40k). The GLBs
  grow by the chain bones' constant rest tracks in every clip (Nela
  6.1 -> 7.3 MB, Mum 5.3 -> 5.9 MB).
- Tests: the `hero_animation` smoke now asserts Nela has chains (her turn
  and settle run in both roles and on hero select through the existing
  loop) and checks Mum: her chains swing on a turn and settle, and her
  walk, wave and cheer still play. The validator checks Mum's chains
  against her model and her triangle budget, like the heroes'.
  `tools/check.sh`: validate OK, unit and both smoke passes PASSED.
- Captures (old above / left, new below / right; player role):
  `captures/10-nela-{turn,stop,hit}-old-vs-new.{png,gif}` and
  `captures/10-mum-{turn,stop,wave}-old-vs-new.{png,gif}`.
  `hero_capture` takes `mum` as the hero now (her story look and clips).
  Mum's frame crops the top of her head; the hair fall and pack are in
  view.
