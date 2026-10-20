# Feature 027: Mushroom Gremlin remodel and animations

Reference: [`reference/concept.png`](reference/concept.png) (front 3/4,
side and back views supplied by the team).

## Goal

Make the feature 021 thief read as a cheeky mushroom goblin, not a
walking mushroom, without making it scary. It keeps the purple spotted
cap and glowing eyes, and adds:
- pointed ears in a wide silhouette;
- a small hooked nose and a grin;
- a sneaking pose.

The team's priorities are the face under the cap, the ear silhouette
and the sneak.

## Scope

- **Model:** `art/characters/mushroom_gremlin.py`, rebuilt. Imp-style
  high-to-low bake on the Skeleton Minion rig.
- **Clips:** `art/characters/gremlin_anims.py`, keyed by hand:
  - idle;
  - sneak (the move clip);
  - flee;
  - grab;
  - hit;
  - spawn;
  - death.
- **Shared helpers:** `art/characters/rig_anims.py`, extracted from
  `beast_anims.py`. The beast's clips come out byte-identical.
- **Godot:**
  - `CharacterVisual.set_move_clip()` swaps the locomotion clip; the
    fleeing gremlin uses `flee`;
  - the grab plays when it steals.
  - No gameplay changes.
