# 13: Face atlas: blink and expressions

Status: done (open: the user's visual sign-off)
Blocked by: 10 (it only orders the rebuilds of the kids' and Mum's models)

**What to build:** the kids blink, and their eyes and mouth show a wince when hit, a beam when cheering and a dazed look while down. Each kid's eyes and mouth become a small painted atlas of states (open, closed, happy, hurt, dazed), painted with the existing face painter so they match today's look. The face shader picks the cell at runtime. Blinks come at random intervals, with an occasional double blink. `hit`, `cheer` and down set the expression for their duration, then it returns to neutral. Mum gets the blink if her head takes it at no extra cost.

- [x] Leo and Nela each have a face atlas, and their faces still match the turnaround sheets in the neutral state.
- [x] Unit: the blink scheduler's intervals stay within a set range and sometimes double.
- [x] Smoke: a hero hit shows the hurt cell and returns to neutral after it. A downed hero shows dazed.
- [x] The kids stay within the hero triangle and texture budgets.
- [x] Close-up renders of each cell and in-game captures are under `## Comments` for sign-off (the sign-off itself is the user's).
- [x] `art/README.md` describes the face atlas.
- [x] `docs/design/art-direction.md` gains a short "Hero motion" section on each kid's personality in motion, the springs and the faces.
- [x] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments

- **2026-10-26, implemented** (branch `hero-anim-13-face-atlas`):
  - **Art.** `face_paint.expression(FACE, state)` paints the five states
    (`open`, `closed`, `happy`: smiling arcs and an open grin, `hurt`:
    `> <` eyes, knitted brows, gritted frown, `dazed`: spiral eyes, one
    brow up, wobbly mouth). New `art/characters/face_atlas.py`:
    `paint_head` bakes each state under the head's own painted lighting
    onto the front-projected face plane (so a cell matches the baked head
    around it), keeps one window (brows to below the mouth), paints the
    head as before, gives its front faces in the window their own
    material (`<Kid>_Face_painted`, same texture) with the face-plane UVs
    as UV2, and writes `game/assets/custom/<kid>_face.webp` + `.tres`.
    One window, not separate eye/mouth windows: Nela's and Mum's mouths
    sit close under the eyes and the grin overlapped both; a blink is
    its own cell (closed eyes over the neutral mouth), as only a
    neutral face blinks.
  - **Budgets.** No new triangles (Leo 34,999, Nela 35,711, Mum 35,500).
    Atlases: Leo 712x895 (43 KB), Nela 668x778 (37 KB), Mum 338x584
    (16 KB, open and closed only: she blinks). GLB sizes unchanged (the
    face material shares the head texture).
  - **Game.** `FaceAtlas` resource, `painted_face.gdshader` (painted_prop
    plus the cell over the window, its feathered edge fading into the
    baked head), `BlinkScheduler` (2-6 s, 20 % double blinks 0.1 s
    apart, 0.12 s shut), and a Face section in `CharacterVisual`
    (`face_atlas` export, `face_shown()` and `blinks_shown` test hooks).
    `hit` -> hurt and `cheer` -> happy while the action plays, down
    (`play_final`) -> dazed until `unlock`. Hit-stop: chosen that the
    face holds (blink timer and all) like the rest of the pose.
    `HeroDefinition.face_atlas`, copied by HeroBody and hero_stage; Mum's
    from `MumArrival.FACE_PATH`.
  - **Tests.** Unit `test_blink_scheduler.gd`; smoke `_run_face_scenario`
    in `hero_animation.gd` (blink, hit -> hurt -> neutral, cheer ->
    happy -> neutral, both kids in both roles; companion down -> dazed ->
    neutral after revive; Mum blinks); validator `_validate_face_atlas`
    (states, 1024 texture limit, the head's face surface and its UV2).
    `tools/check.sh`: validate OK, unit PASSED (88), smoke and stalled
    smoke PASSED, selftest OK.
  - **Review.** `hero_capture.tscn ... --face` frames the head close up
    (from above for `death`). Sign-off files in `../captures/`:
    `13-<kid>-face-atlas.webp` (every cell), and old (top) vs new
    (bottom) close-up strips `13-leo_hit`, `13-leo_cheer`,
    `13-leo_death`, the same for Nela, and `13-mum_idle`
    (`-face-old-vs-new.png`). The neutral face matches the old one with
    no visible seam at the window edge. Blinks are too short to land in
    an 8-frame strip; the smoke checks them.

