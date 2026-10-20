# Feature 032: Decisions

**D1. The quadrants follow the camera.** The pond goes NE (back right), as in concept 01, where the water is top right. The pines go NW, so their tall silhouettes stay at the back. The low-growing groves (woodlot props, berry hollow) go south, nearer the camera.

**D2. Lanes stay empty of solid things.** Mobs walk straight at their target with `move_and_slide` and no navigation. So solid decor stays out of a 3 m half-width corridor along each axis (`WorldLayout.in_lane`). Ground paint, grass and lane-mouth dead trees are fine there; the dead trees stand at 17–24 m, beyond the spawn markers.

**D3. No tall decor where it can hide the kids or shade the lanes.** There is no occlusion fade. Tall dressing in the southern groves is limited to z > 16.5. The Berry Hollow's landmark is a giant stump, because a big oak (first try) threw a near-black shadow over the east lane beside the camp.

**D4. Dressing trees stay at the back of the groves.** Dressing trees look the same as the gatherable ones. In the groves they stand from about 13.5–14.5 m out, so they read as forest, not as resources; stumps, logs and ferns fill the reachable part.

**D5. The plan is data, and the shader reads it.** Paths, groves and the pond are uniforms (segment arrays) set at load by `WorldLayout.apply_to_ground`. This replaces the old hand-synced sine path in two places. In the editor, without the dressing running, the ground shows no paths; that is accepted.

**D6. Resource counts and timings are unchanged.** Only positions moved. Basic resources moved about 2–4 m further out (see status). If playtests find the early game slower, move the nodes inward; the groves will follow the circles in `WorldLayout.GROVES`.
