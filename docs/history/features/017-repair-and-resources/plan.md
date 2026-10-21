# Feature 017: Repair and resources

## Goal

Make every system in the camp loop pay off.

- **Repair:** damaged buildings and the campfire can be fixed. The code
  already had `repair()`, but nothing called it.
- **Resources:** all 10 resources get a source and a use. Clay,
  Mushrooms, Scrap and Glow Shards were shown in the HUD but could not be
  gathered or spent.

## Why

**Pillars.** "Build a cozy fortress" and "every trip out of camp
matters". Before this feature:
- a damaged fence could only be replaced;
- half the resource tray was dead weight;
- nothing drew the player out to the edges of the map.

## Scope

### In

- **Repair.**
  - Leo right-clicks a damaged building, walks over and hammers it.
  - One tap costs 1 Wood, restores 12 HP and gives 1 XP.
  - The campfire is healed with the **Feed the Fire** recipe (1 Wood,
    +20 HP).
  - **Nela gets a Repair task (V).** She fixes the most damaged structure,
    the campfire first when it is below 70%. She guards the camp when
    there is nothing to fix or no wood left.
- **New resource spots**, all with painted art from `art/props/forage.py`:
  - clay pits (Clay);
  - mushroom patches (Mushrooms);
  - junk piles (Scrap).

  They sit on the map diagonals, away from the camp, so gathering them
  is a small trip.
- **Glow Shards.** Every third imp kill drops a glowing pickup. Leo or
  Nela collect it by walking close; it drifts toward Leo within 3 m.
- **Recipes:**
  - Feed the Fire;
  - Berry Snack: 2 Berries + 1 Mushroom. R eats one: +35 HP;
  - Stone Hearth: 5 Clay + 4 Stone. The campfire gets +75 max HP and a
    full heal, and a clay-brick ring appears. Once per run.
- **Buildings (build menu 3 and 4):**
  - **Snap Trap:** 2 Wood, 1 Fiber, 1 Scrap. It snaps the first imp on
    it for 10 damage and holds it for 2.5 s. 3 snaps, then it breaks.
  - **Glow Lantern:** 2 Glow Shards, 1 Scrap, 2 Wood. A permanent torch
    aura: 5 m radius, 40% speed, 2 damage per second.
- **UI:**
  - a hammer hover and cursor;
  - a 5th Nela task button;
  - 12 items in the tray;
  - the Berry Snack on the eat button;
  - build chips for 1–4;
  - a compact crafting panel;
  - "Fix" and V in the help screen.
- **Sounds:** hammer tap, clay squelch, mushroom pop, scrap clank,
  shard chime, trap snap.

### Out (moved to later features)

- **To 019:** Reinforced Wall (Clay), Storage Crate, Crafting Table.
- **Not planned yet:** feeding snacks to Nela.
