# Feature 031: Test plan

- [x] The 12 references are in `art/reference/concept-2026-10/` with an index.
- [x] The style guide exists and is linked from spec §L and `art/README.md`.
- [x] `tools/check.sh` passes: import, validator and smoke run.
- [x] Day and night screenshots read as the concept look next to concepts 01 and 03: warm grade, ochre clearing, flowers, tilt-shift band, cozy props, warm pools of light at night.
- [x] The HUD and menus are never blurred: PostFx sits on canvas layer -1.
- [x] New props respect the triangle budget, except the documented stall and well (D7).
- [x] New props stay off resource nodes, the mob lanes and the path.
- [ ] **On a real GPU (Windows):** FPS is about the same as v0.25. The post pass is one full-screen draw with 9 taps.
- [ ] **On Windows:** the pause-menu Blur switch turns the blur off at once and is remembered after a restart.
- [x] M4: the day HUD shot is within about 5 % of the style target's median brightness and colour balance (status.md table).
- [x] M4: the night shot is still blue with warm pools, and the imps are readable.
- [ ] **On a real GPU (Windows):** FPS with the 16-tap bokeh, 4-tap sharpen and prop outlines.
