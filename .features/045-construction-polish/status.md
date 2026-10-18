# Feature 045: Status

**Done.**

- **Blueprints:**
  - A pale-blue see-through ghost with drifting stripes, a fresnel edge and a pulse.
  - The solid model is cut at a build line that starts at 4% of its height and rises with progress.
  - The site has 4 stakes, a rope line, a faint dirt patch, and up to 7 pile pieces chosen from the cost (planks, stones, clay, scrap, shards).
- **Builders:**
  - The hero and the companion take out a mallet and loop hammer, hammer, then fetch (pick up or tinker). Blows run at 1.8× clip speed, about 0.9 s each; the impact lands at 52% of the clip.
  - Every blow squashes the building, flashes the ghost and throws wood chips with their knock.
  - Repair taps use the mallet too.
  - Build times are unchanged (`build_seconds`); the beat is only visual.
- **Finish:** the ghost fades over 0.25 s, the site sinks, the model bounces, and there is a gold sparkle on top of the old dust and place sound.
- **Smoke** (all pass):
  - a fresh blueprint has `Ghost`, `Site` and less HP;
  - the hero builds it with the hammer out (2 blows landed in 3 s of work);
  - the ghost's clip rises;
  - after completion the ghost and site are gone, the hammer is away and HP is full;
  - the companion still builds on Repair, with the mallet out and her lantern put away (and back afterwards);
  - Continue restores a half-built watch post as a blueprint (progress, HP, place, ghost, site, build line), and the hero finishes it.
- **Screenshots:**
  - `04b1_blueprint_fresh`
  - `04b2_blueprint_building` (40%)
  - `04b4_blueprint_done`
  - `04b3_build_close` (zoomed in on a watch post)
  - `04b5_hammer` (side on, mid-blow)
