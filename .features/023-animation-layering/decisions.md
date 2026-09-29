# Feature 023: Decisions

- **Built in code, per instance.** Every character (kids, imps, beasts,
  gremlins) gets its own tree resources. The clip names come from each
  scene's `clips` dictionary, as before, so there are no new scene files
  to maintain.
- **Upper-body only while moving.** Standing still, full-body clips look
  better, because the chop's weight shift comes from the legs.
- **Death and get-up bypass the tree.** It is simpler than an extra
  state machine, and the AnimationPlayer holds the final pose natively.
- **The tree updates on physics frames** (its default), so tests wait
  for physics frames after firing an action.
- **Monsters keep a two-point blend** (idle to move). They have no
  separate walk clip in use.
