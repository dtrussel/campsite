# Feature 022: Shadow Imp remodel

## Goal

Give the most common enemy the hand-painted, sculpted treatment the
kids got in features 012–015. Gameplay and the rig are unchanged.

## Scope (`art/characters/shadow_imp.py`)

- **Sculpted forms:** a brow ridge, cheek puffs, a snout, a chin, and
  knee and elbow bumps.
- **New rigid details:**
  - three claws on each hand and foot;
  - a spiky tuft, swept back and rooted on the head surface with a
    raycast;
  - growth rings on the horns.
- **Eyes:** almond-shaped and slanted up at the outer corner, with
  cat-like slit pupils. They look cheeky, not scary.
- **Paint:**
  - a soft oval belly gradient;
  - a fine fur-stroke noise;
  - glowing violet runes on the forearms, cheeks and tail;
  - dark eye sockets and a grin;
  - hands and feet fading to dark.
- **High-to-low bake** (`chibi.lowpoly`): the dense sculpt carries the
  paint and is baked onto a game mesh of about 7.5k triangles (8.4k with
  the eyes; the imp budget is 12k). `HIGH_POLY=1` keeps the dense mesh.
- **Portrait:** `portrait_imp.png` is re-rendered. `render_icons.gd` now
  accepts portrait names after `--` too.
