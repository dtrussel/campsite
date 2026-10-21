# Feature 001 — Test plan

Run inside the Godot editor with **F5** on `Main.tscn`.

## Acceptance criteria

- [ ] On startup, the HUD lists all 10 resource names with count `0`
      (Wood, Stone, Berries, Fiber, Mushrooms, Clay, Leaves, Resin, Scrap,
      Glow Shards).
- [ ] Walking up to a Tree and pressing **E** for the full gather time
      increments the **Wood** counter by the tree's `yield_amount`.
- [ ] Same flow at a Rock increments **Stone**.
- [ ] Same flow at a Berry Bush increments **Berries**.
- [ ] The HUD updates immediately (within one frame) on each successful
      gather.
- [ ] Mushrooms, Clay, Leaves, Resin, Scrap, and Glow Shards rows remain
      visible at 0 throughout play (data-and-UI-only resources).
- [ ] Starting a gather and then pressing any WASD key before the timer
      finishes cancels the gather. The counter does **not** change. The
      player can move again immediately.
- [ ] Standing in open ground (no node in range) and pressing **E**
      produces no error in the Godot Output panel.
- [ ] After a node is depleted, it becomes gatherable again after
      `respawn_seconds` (default 20 s).

## Smoke checklist (no regressions from Phase 0)

- [ ] Project opens.
- [ ] Main scene runs.
- [ ] No errors or warnings in Output on startup.
- [ ] WASD still moves the boy.
- [ ] Camera still follows smoothly.
- [ ] **Esc** still quits.

## Edge cases worth exercising

- [ ] Press **E** repeatedly while in range — only one gather runs at a
      time.
- [ ] Walk just outside the interactor radius mid-gather (without WASD,
      e.g. via momentum from inertia) — gather cancels via
      `body_exited`.
- [ ] Stand between two nodes (Tree and Rock side by side) — pressing
      **E** picks the closest one; the other is untouched.
- [ ] Gather a resource that is already at max stack — count clamps at
      `max_stack`; no error. *(Optional; the autoload currently does not
      enforce caps; document the gap if this is left for later.)*
