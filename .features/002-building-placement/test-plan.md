# Feature 002 — Test plan

Run inside the Godot editor with **F5** on `Main.tscn`.

## Acceptance criteria (maps to roadmap Phase 3)

- [ ] Press **B**. The HUD shows a build-mode label naming the active
      building and its cost (e.g. *&ldquo;Build: Wooden Fence (2 Wood,
      1 Fiber)&rdquo;*).
- [ ] A translucent ghost of the building follows the mouse over the
      ground.
- [ ] With enough resources and an unobstructed cursor location, the
      ghost is green and the HUD label is green.
- [ ] Hovering the ghost over a tree, rock, the campfire, or the
      player makes the ghost red and the HUD label red.
- [ ] Pressing **B** at zero resources shows the ghost red even on
      open ground.
- [ ] Left-clicking on a green ghost spends the resources, drops the
      counts in the HUD, and spawns a real Wooden Fence at the cursor
      position.
- [ ] After placing, the ghost keeps following the mouse so a second
      fence can be placed immediately.
- [ ] Pressing **2** switches the active building to Watch Post; the
      HUD label updates to its name and cost. Pressing **1** switches
      back to Wooden Fence.
- [ ] Pressing **right-click**, **B**, or **Esc** exits build mode.
      The ghost disappears; placed buildings remain.

## Smoke checklist (no regressions from prior features)

- [ ] Project opens; no Output errors on startup.
- [ ] Main scene runs.
- [ ] **W / A / S / D** still moves the boy.
- [ ] Camera still follows the boy.
- [ ] **E** still gathers from trees, rocks, and berry bushes.
- [ ] Resource counts still increase on gather and decrease on build.
- [ ] **Esc** still quits when build mode is inactive.
- [ ] No console errors or warnings after a 60 s play session that
      includes gathering and building.

## Edge cases worth exercising

- [ ] Tap **B** repeatedly — toggles cleanly with no ghost duplication.
- [ ] Place a fence, then place another fence immediately on top of
      the first — the second placement is rejected (red ghost).
- [ ] Spend the last of your fiber on a fence — the next fence ghost
      goes red instantly because the cost is no longer affordable.
- [ ] Move the mouse off the ground (e.g. over the sky) — ghost
      hides or shows red.
- [ ] Stand on the ghost location yourself — ghost goes red.
- [ ] Exit build mode while the ghost is over a tree — the tree is
      untouched; no ghost remnant; gather still works.
- [ ] Press **E** while in build mode — does nothing harmful; the
      controller swallows the action while build mode is on.
