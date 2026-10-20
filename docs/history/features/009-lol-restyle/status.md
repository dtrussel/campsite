# Feature 009: Status

## 2026-09-28

**Completed**
- **LoL kid-champion proportions.**
  - `chibi.Proportions` stretches the rig's legs, spine and arms while keeping bone directions.
  - Meshes are remapped the same way.
  - The hips/root translation keys scale with the legs.
  - Leo is set to legs 1.5, spine 1.2, arms 1.1. Nela is set to 1.15 / 1.05 / 1.0.
  - Idle, run, chop, pick-up, spellcast and death all render cleanly.
- **Sculpted heads.**
  - `chibi.sculpt_head` provides jaw taper, chin, chubby cheeks or cheekbones, and a flatter face plane.
  - Face decals ray-cast onto the real surface (`HeadFrame.bind`).
- **LoL faces.**
  - `almond_eye`: almond eyes with a clipped iris, a winged upper lid, a lower lid and lash flicks.
  - `smirk` gives Leo a lopsided grin. Nela has an open laugh.
  - Angled brows.
- **Leo.**
  - A lean V-shaped torso and an angular face with freckles.
  - A sandy swept fringe of sculpted clumps (`hair_clump`) under a snug backwards cap with a big curved brim.
  - Big boots and hands.
  - A longer, knotty walking stick sized to reach the ground.
- **Nela.**
  - A heart-shaped face with big round eyes.
  - A pale-honey curl cloud, curly bangs, corkscrews, and a top bun with a pink scrunchie.
  - A pink tee over a pear-shaped body, and plum pants.
  - A bigger bunny and lantern.
- **Painting.** Characters darken toward the feet (`foot_darken`) and use stronger light/shadow contrast.
- **Game.**
  - Leo is scaled to 0.7 and Nela to 0.57, so Leo is about 1.35 times her height.
  - HP bars and the task label were adjusted, and the portraits re-rendered.
- **Checks.** `tools/check.sh` is green, and the screenshots were reviewed.
