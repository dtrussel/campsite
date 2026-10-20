# Feature 023: Status

**Done.**

## 2026-09-29

- `character_visual.gd` rewritten around an AnimationTree. The kids
  have walk clips.
- **`tools/check.sh` passes.** The new smoke checks:
  - the tree is active;
  - the locomotion blend follows speed;
  - a swing while running goes to the upper layer;
  - a swing standing still goes to the full-body layer.
  - The knock-out and get-up path is still covered by the bandage test.
- **Filmstrip reviewed:** Leo swings his stick with the legs still in
  stride, then turns.
- **No new runtime warnings** in the smoke log.
