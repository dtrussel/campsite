# Feature 000 &mdash; Decisions

## D-000-1 &mdash; Engine and language

- **Decision:** Godot 4.x + GDScript only.
- **Rationale:** See
  [`docs/decisions/ADR-0001-engine-and-language-selection.md`](../../docs/decisions/ADR-0001-engine-and-language-selection.md).

## D-000-2 &mdash; Minimal autoloads

- **Decision:** Only `GameManager` and `TimeManager` are registered as
  autoloads in Phase 0. `ResourceManager`, `BuildManager`,
  `ProgressionManager`, and `SaveManager` are described in the
  architecture document but not yet autoloaded.
- **Rationale:** Avoid creating stubs that do nothing. They will be added
  when their first real behavior lands, in their respective phases.

## D-000-3 &mdash; Camera style for the skeleton

- **Decision:** Top-down with a slight tilt (pseudo-isometric), fixed
  rotation, smoothed follow.
- **Rationale:** Matches the readability pillar and lets us defer the
  decision between strict top-down and full iso until later phases.

## D-000-4 &mdash; Movement scheme for the skeleton

- **Decision:** WASD movement directly on the boy. Strafing relative to
  world axes (not camera-relative) to keep the input mapping obvious
  while the camera is fixed.
- **Rationale:** Simplest possible scheme to validate the project skeleton.
  Camera-relative input can be revisited if free camera rotation is added.

## D-000-5 &mdash; Resource list locked at 10

- **Decision:** Lock the resource set to exactly 10 at bootstrap (Wood,
  Stone, Berries, Fiber, Mushrooms, Clay, Leaves, Resin, Scrap, Glow
  Shards).
- **Rationale:** Provides a stable target for UI and data design without
  inviting scope creep. Future additions require updating the design spec
  and a brief justification in a feature folder.

## D-000-6 &mdash; Two prototype companions selected

- **Decision:** When companion implementation begins, use the **Sibling**
  and **Dog** archetypes for the first prototype.
- **Rationale:** Together they cover the two most distinct task patterns
  (gather + scout, vs. guard + distract) so the prototype exercises the
  task system breadth without implementing all four archetypes.

## D-000-7 &mdash; Static typing in GDScript

- **Decision:** Use static typing wherever practical.
- **Rationale:** Faster autocompletion, better error catching, easier for
  agents reading code unfamiliar to them.

## D-000-8 &mdash; Working assumptions for open questions

The following open questions are answered with working assumptions for
now (also listed in
[`docs/requirements/requirements.md`](../../docs/requirements/requirements.md#i-open-questions)):

- Tone: adventurous + slightly spooky, kid-friendly.
- Combat role: boy can fight; companions amplify.
- Companion death: knock-out + recovery, not death.
- Base death: short last-stand window after core HP hits zero.
- Pets: scout / distract / minor combat.
- World: handcrafted for prototype.
- Time control: real-time.
