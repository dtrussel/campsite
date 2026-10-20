# Feature 019: Reinforced Wall, Storage Crate, Crafting Table

## Goal

Three buildings that give the late game somewhere to go:
- a tough wall against Bramble Beasts;
- a stash limit, and crates to raise it;
- a workbench with a second set of recipes.

## Scope

### Stash caps and the Storage Crate
- **Caps.** `ResourceDefinition.base_cap` is 20 for raw resources and
  10 for Glow Shards. Crafted items have no cap.
- **Each Storage Crate** (build key 6; 4 Wood + 2 Stone; 60 HP) adds the
  base cap again.
- **When something is full:**
  - gathering shows a crossed-out icon (and doesn't start when nothing
    would fit);
  - Nela's Gather task skips full nodes;
  - Glow Shard pickups wait on the ground;
  - the tray count turns gold, with a "20/20" tooltip.

### Reinforced Wall (key 2)
- 3 Stone + 2 Clay + 1 Wood; 150 HP (three times a fence); repairable.
- Stones in clay, with a lashed log cap.
- Has its own placing sound.

### Crafting Table (key 7)
- 4 Wood + 2 Stone + 1 Scrap; 60 HP.
- **A second crafting station.** Right-click it or press C nearby.
- **Stations.** Recipes have a `station`: the campfire panel shows the
  campfire's 4 recipes (plus a "build a table" hint); the table shows
  its own 4.
- **Table recipes:**
  - **Sturdy Stick:** +2 attack for Leo, once per run.
  - **Nela's Slingshot:** her reach doubles, once per run.
  - **Bandage:** press **X** next to Nela for +25 HP, or to wake her up.
  - **Trap Refill:** every Snap Trap gets its 3 snaps back.

### Build keys and HUD
- **Build keys 1–7 follow `sort_order`:** fence, wall, post, trap,
  lantern, crate, table.
- **HUD:** an X (bandage) slot; the hero bar is wider.
