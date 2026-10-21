# Feature 045: Test plan

- [x] Smoke: a fresh blueprint has a `Ghost` with a ShaderMaterial, a `Site`, and less HP.
- [x] Smoke: the idle hero builds it with the hammer out; blows land (`BuildBeat.hits`); the ghost's `clip_y` rises.
- [x] Smoke: after completion the ghost and site are gone, the hammer is put away, and HP is full.
- [x] Smoke: the companion's Repair task still builds a fence, with the mallet out and Nela's lantern (and its glow) put away; afterwards the mallet goes and the lantern comes back.
- [x] Smoke (blueprint save scenario): a watch post saved at 50% comes back on Continue as a blueprint at the same spot and turn, with the same HP, its ghost and site, the build line at the same height, and its slingshot not yet working. The hero then finishes it and it works.
- [x] Screenshots: a fresh blueprint, one at 40%, finished, a zoomed-in watch post, and a side-on mid-blow.
- [x] Art: the hammer preview render and grip checks on the rig (idle and the 2H chop).
- [ ] Hand play: the look and feel at normal speed (the smoke checks above cover the logic).
