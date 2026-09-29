# Game design specification

> Companion document to
> [`docs/requirements/requirements.md`](../requirements/requirements.md). This
> file describes the game itself: loops, characters, systems, content.

## A. High-level pitch

A 7-year-old boy must protect his family campsite from evil forest mobs by
gathering resources, crafting tools, building defenses, assigning
companions to tasks, and surviving increasingly dangerous nights.

By day, the woods are cozy and inviting: birdsong, dappled light,
gatherable plants and rocks. At sunset, light fades and shadows lengthen.
At night, the trees press in and shapes move at the edge of vision. The
campfire is the heart of safety; everything is about keeping it lit and
your family alive until dawn.

## B. Core gameplay loop

### Day

1. Wake up at camp.
2. Review base damage and resource stockpile.
3. Explore nearby woods.
4. Gather resources (wood, stone, berries, etc.).
5. Assign companions to tasks (gather, repair, scout, guard).
6. Craft items, tools, traps.
7. Build or repair defenses (fences, watch posts).
8. Prepare before sunset (top up health, stock arrows / supplies, position
   companions).

### Night

1. Mobs emerge from the forest.
2. The base comes under attack.
3. The player directly controls the boy.
4. Companions execute their assigned roles (guard, follow, support).
5. Defend the campfire / tent / base core.
6. Defeat mobs.
7. Earn XP and salvage / loot.
8. Survive until morning.

### Meta-progression

1. Level up characters with XP earned across day and night.
2. Unlock stronger buildings and crafting recipes.
3. Improve base layout (fence rings, choke points, watch posts).
4. Survive stronger nights (more mobs, new mob types).
5. Explore deeper forest areas (further from camp, higher reward / risk).

## C. Player character &mdash; the Boy

**Identity:** brave but small. Fast and flexible. Resourceful rather than
overpowered. He can do everything (gather, craft, build, fight) at a
modest level; companions specialize.

### Initial stats (placeholder values)

| Stat            | Description                                         | Initial |
|-----------------|-----------------------------------------------------|---------|
| Health          | Damage he can take before being knocked down.       | 50      |
| Stamina         | Sprint / dodge resource. Regenerates over time.     | 100     |
| Courage         | Resists fear effects. Mob proximity reduces actions.| 50      |
| Build Speed     | How fast he places / repairs structures.            | 1.0     |
| Gather Speed    | How fast he harvests resource nodes.                | 1.0     |
| Attack Power    | Damage per swing of his small weapon.               | 5       |
| Crafting Skill  | Discount / speed bonus on crafting actions.         | 1.0     |

All numbers are placeholder until balancing.

### Level-up effects

- Every level grants a small stat boost on at least one of the above.
- Specific level-up bonuses are defined in
  `game/resources/companions/` and via a `CharacterStatsDefinition`
  resource (see architecture doc).

## D. Companions

Family members and pets form a small team around the boy. Each companion
has a clear role.

### Parent Companion

- Repairs and defends.
- Can calm scared characters (resets fear).
- Durable, slower.
- Strong in melee, weak at range.

### Sibling Companion

- Gathers and scouts.
- Faster, less durable.
- Can dash to evade mobs.

### Dog Companion

- Detects mobs early (alert radius around camp).
- Distracts and chases small mobs (taunts).
- Best scouting role.

### Cat Companion

- Stealthy scout.
- Finds rare resources (Glow Shards bonus chance).
- Avoids direct combat.

**For the first prototype, only two companions are implemented** &mdash;
recommended: **Sibling** (gather / scout focus) and **Dog** (guard /
distract focus). They cover the two most distinct task patterns.

## E. Companion task system

### Task types (full list)

- **Idle** &mdash; stand at last position.
- **Follow Player** &mdash; stay within X meters of the boy.
- **Gather Resource** &mdash; walk to the nearest matching resource node
  and harvest until full / depleted, then deposit at the base.
- **Guard Base** &mdash; stay near the campfire core and engage approaching
  mobs.
- **Repair Building** &mdash; find the lowest-HP damaged building and
  repair it.
- **Craft Item** &mdash; stand at a crafting station and produce queued
  items.
- **Scout Area** &mdash; patrol a defined point or sweep a radius and
  report sightings.
- **Support Combat** &mdash; assist the player&rsquo;s current target.

### Prototype subset

For the first prototype, implement only:

- **Follow Player**
- **Gather Resource**
- **Guard Base**

Other tasks are stubbed out in the data layer (so the UI can list them) but
not behaviorally implemented yet.

### Assignment UI (prototype)

- Select a companion with the mouse.
- Press a hotkey or click a HUD button to set their task.
- Display the current task above the companion or in the HUD panel.

## F. Resource system

All 10 resources are present in data and UI from day one. Initial uses are
guidelines; final recipes will live in `.tres` data files.

| Name        | Rarity   | Stack | Initial uses                                                  |
|-------------|----------|-------|---------------------------------------------------------------|
| Wood        | Common   | 99    | Fences, watch posts, torches, traps, most early buildings.    |
| Stone       | Common   | 99    | Reinforced walls, watch post tops, heavy traps.               |
| Berries     | Common   | 50    | Food, basic healing snack, simple recipes.                    |
| Fiber       | Common   | 99    | Ropes, traps, bows, bandages.                                 |
| Mushrooms   | Uncommon | 50    | Potions, risky food, magical-adjacent recipes.                |
| Clay        | Uncommon | 50    | Reinforced walls, ovens, brick variants.                      |
| Leaves      | Common   | 99    | Camouflage, bedding, simple roofs, ground cover crafts.       |
| Resin       | Uncommon | 50    | Glue, fire upgrades, longer-burning torches.                  |
| Scrap       | Rare     | 30    | Improvised tools, weapon upgrades, complex devices.           |
| Glow Shards | Rare     | 20    | Magical upgrades, night defenses, vision items.               |

*Feature 017 status:* every resource now has a source and a use.

| Resource | Source | Uses |
|----------|--------|------|
| Clay | Clay pits in the NE and SW corners | Stone Hearth |
| Mushrooms | Mushroom patches in the NW and SE corners | Berry Snack |
| Scrap | Junk piles near the E and S spawn lanes | Snap Trap, Glow Lantern |
| Glow Shards | Every third imp kill drops one as a pickup | Glow Lantern |

### Display

Each resource has:

- A display name (above).
- A short description (above).
- An icon (placeholder is a colored square per resource).
- A rarity tier (used for spawn weights and UI tinting).
- A stack size (used by storage UI).
- A list of initial uses (used by hint UI).

These are stored as `ResourceDefinition` `.tres` files; see the architecture doc.

### Gathering

- Resource nodes appear in the world (tree, rock, berry bush).
- Approaching and interacting (button-press) starts a short gather timer.
- On finish, the boy (or companion) gains N units of the matching resource.
- Nodes have a small respawn / regrowth timer.

## G. Building system

### Building catalog

| Building       | Purpose                                                      |
|----------------|--------------------------------------------------------------|
| Campfire Core  | Central base object; mobs target it; provides light radius.  |
| Wooden Fence   | Cheap barrier; blocks or slows mobs.                         |
| Watch Post     | Elevated post; companions can guard from here.               |
| Storage Crate  | *(019)* +20 stash cap per resource (caps start at 20). 4 Wood + 2 Stone. |
| Crafting Table | *(019)* A second crafting station with the Sturdy Stick, Slingshot, Bandage and Trap Refill. 4 Wood + 2 Stone + 1 Scrap. |
| Reinforced Wall | *(019)* 150 HP, three times a fence. 3 Stone + 2 Clay + 1 Wood. |
| Snap Trap      | *(017)* Snaps the first imp on it: 10 damage, held 2.5 s; 3 snaps. 2 Wood + 1 Fiber + 1 Scrap. |
| Glow Lantern   | *(017)* A torch that never burns out: slows and zaps imps within 5 m. 2 Glow Shards + 1 Scrap + 2 Wood. |

### Prototype subset

- **Campfire Core** (pre-placed in the test world, not built).
- **Wooden Fence** (placeable by the player).
- **Watch Post** (placeable by the player, companions can be assigned).

### Build mode

- The player toggles build mode (e.g. with **B**).
- A &ldquo;ghost&rdquo; building follows the cursor.
- Green ghost = valid placement; red ghost = invalid (overlapping, off
  terrain, or insufficient resources).
- Left-click commits placement and spends resources.
- Right-click or Esc cancels build mode.

### Building health and repair

- Each building has HP.
- Mobs attacking buildings reduce HP.
- HP at zero destroys the building (no repair allowed).
- Players or companions with the Repair task can restore HP at a fraction
  of the original resource cost.
  *Feature 017:*
  - Leo right-clicks a damaged building, walks over and hammers it. Each
    tap costs 1 Wood and restores 12 HP.
  - The campfire is fed at the crafting panel (Feed the Fire: 1 Wood,
    +20 HP).
  - Nela's Repair task (**V**) fixes the most damaged structure, the
    campfire first when it is low. She guards the camp when there is
    nothing to fix.
  - Snap Traps are rebuilt, not repaired.

## H. Crafting system

### Initial recipe examples

| Item         | Recipe                                |
|--------------|---------------------------------------|
| Wooden Fence | 2 Wood + 1 Fiber                      |
| Watch Post   | 4 Wood + 2 Stone + 1 Fiber            |
| Torch        | 1 Wood + 1 Resin + 1 Leaves           |
| Berry Snack  | 2 Berries + 1 Leaves                  |
| Simple Trap  | 2 Wood + 2 Fiber + 1 Scrap            |

These numbers are placeholder; final values live in `CraftingRecipe`
resources.

*Implemented at the campfire (feature 017):*

| Recipe | Inputs | Result |
|--------|--------|--------|
| Feed the Fire | 1 Wood | +20 campfire HP (only while it is damaged) |
| Torch | 1 Wood + 1 Resin + 1 Leaves | A torch (plant with Q) |
| Berry Snack | 2 Berries + 1 Mushroom | A snack (R: +35 HP); mushrooms replace leaves to give mushrooms a use |
| Stone Hearth | 5 Clay + 4 Stone | Campfire +75 max HP, fully healed; once per run |

The Simple Trap became the Snap Trap building (build menu 3).

### Prototype subset

Implement **one** recipe end-to-end (recommended: **Torch** &mdash; small,
useful at night, exercises three resources). The other recipes exist in
data only.

### Crafting flow

1. Player opens a crafting menu (key or by interacting with a station).
2. UI lists known recipes; locked recipes show their requirements.
3. Selecting a recipe checks resource availability and shows confirmation.
4. Confirming consumes resources, shows a small craft-time bar, and
   produces the item.
5. Crafting grants XP to the crafter.

## I. Mob system

### Mob catalog

| Mob              | Behavior summary                                              |
|------------------|---------------------------------------------------------------|
| Shadow Imp       | Small, fast, weak. Attacks structures and characters alike.   |
| Bramble Beast    | Slow, durable. Specializes in destroying fences.              |
| Night Crow       | Flying scout / harasser. Damages soft targets and flees.      |
| Mushroom Gremlin | Steals resources from the base, then runs.                    |

### Prototype subset

Implement **Shadow Imp** only.

*Feature 021:* the **Mushroom Gremlin** is in.
- It runs to the stash (a Storage Crate, else the campfire) and takes up
  to 4 of the most plentiful raw resource.
- Then it flees to its spawn point.
- Caught, it drops the loot as a pickup; escaped, the loot is gone.
- It has 8 HP, is fast, and ignores the kids.
- Waves: nights 1–3 have 0, 1, 1 gremlins, then +1 per night, in the
  first half of the wave.

*Feature 018:* the **Bramble Beast** is in.
- It walks to the nearest building and tears it down (×3 damage), then
  goes for the campfire.
- It ignores the kids unless they come within 2 m, and barely flinches
  when hit.
- It has 40 HP and always drops a Glow Shard.
- Waves: nights 1, 2 and 3 have 0, 1 and 2 beasts, spawned in the second
  half of the wave.

### Mob lifecycle

1. **Spawning** &mdash; appears at a designated edge of the map at night.
2. **Moving to target** &mdash; uses Godot navigation to approach a target
   (closest building, campfire core, or character).
3. **Attacking** &mdash; melee or ranged hit on the current target.
4. **Dying** &mdash; HP at zero plays a short death effect, awards XP and
   possibly drops a resource, then frees the node (or returns it to a
   pool).

### Wave logic

- Night start triggers a `MobSpawner` to begin spawning at intervals.
- A wave is a count, e.g. 6 Shadow Imps over 20 seconds for the first
  night.
- When all mobs in the wave are defeated *or* a wave timer expires, the
  wave ends and `night_ended` is signaled.

## J. XP and leveling

### XP sources

Characters gain XP from:

- Defeating mobs.
- Building structures.
- Crafting items.
- Gathering resources.
- Repairing base objects.
- Surviving nights (lump sum per night survived).

### Leveling rules

- Every character has an XP value and a level.
- When XP reaches a threshold, the character levels up.
- Each level grants at least one stat improvement.
- The XP threshold curve is data-driven via a
  `CharacterStatsDefinition` resource. Starting curve (placeholder):

```
level_1 = 0
level_2 = 100
level_3 = 250
level_4 = 500
level_5 = 900
... (level_n = level_n-1 + 150 * n until rebalanced)
```

- Skill trees are **out of scope** for the first prototype. Stat bumps
  only.

## K. Camera and controls

### Camera

- **Top-down / isometric 3D.** Fixed angle, no free rotation in the
  prototype.
- Camera follows the player with a slight smoothing.
- Optional second mode (debug-only): free fly for development.

### Controls (prototype)

| Action               | Input                  |
|----------------------|------------------------|
| Move boy             | **W / A / S / D**      |
| Sprint               | **Shift** (later)      |
| Interact / gather    | **E** (later)          |
| Attack               | **Left mouse** (later) |
| Toggle build mode    | **B** (later)          |
| Place building       | **Left mouse**         |
| Cancel build         | **Right mouse / Esc**  |
| Select companion     | **Left mouse**         |
| Assign task          | Hotkey / HUD button    |
| Open crafting menu   | **C** (later)          |
| Pause / menu         | **Esc**                |

WASD movement is the default. Click-to-move can be evaluated later if a
more strategic feel is wanted.

## L. Art direction

- **Stylized 3D.** Low-poly, hand-painted-feeling textures, clear
  silhouettes.
- **Strong readability** from the top-down / iso camera: characters and
  mobs stand on a flat plane; key shapes are recognizable in two seconds.
- **Cozy day / spooky night.** The same scene reads as warm and inviting
  by day, tense and dangerous at night. Achieve this with lighting,
  fog, and sound &mdash; not gore.
- **Strong color coding.** Each mob type has a distinct palette; each
  resource has a distinct icon color; buildings read as a team.
- **No copyrighted assets.** League of Legends is a visual *reference*
  only: stylized 3D shapes, polished but non-photorealistic rendering,
  readable colors. No characters, art, names, or assets are copied.

### Placeholder strategy

- Boy = capsule / small box with hat shape.
- Companions = differently colored capsules.
- Mobs = dark cubes or low-poly silhouettes.
- Buildings = simple primitive shapes.
- Resources = colored crystals / cylinders.

## M. Audio direction

Initial audio targets (placeholders welcome):

- Cozy forest ambience during day (birds, wind in leaves).
- Tension layer at sunset (low rumble, less wildlife).
- Night ambient (distant howls, creaking branches, mob hisses).
- Campfire crackle near the core.
- Build / craft feedback chimes.
- Companion confirmation sounds (short, friendly).
- Mob attack and death sounds.

Music can be ambient / atmospheric. No vocals.

*Implemented in feature 016.* Everything is synthesized by `art/audio/`:
- a campfire-guitar day tune and a D-minor night drone with a heartbeat;
- birds and wind by day, crickets by night;
- a 3D crackle at every fire;
- an owl call and a warm screen pulse at sunset;
- one-shots for every gameplay beat.

Deferred: night howls and creaking branches, and imp hisses while they
walk (they have spawn and death sounds only).

## N. First vertical slice definition

A successful first vertical slice means:

- [ ] The player can move the boy around a small test map.
- [ ] The map contains a campfire core.
- [ ] The UI shows time of day, base health, and all 10 resources.
- [ ] The player can gather at least 3 resource types
      (recommended: Wood, Stone, Berries).
- [ ] The player can place at least one Wooden Fence.
- [ ] At least one companion can follow the player or guard the camp.
- [ ] At night, Shadow Imps spawn and attack the campfire or fences.
- [ ] The player and/or companion can defeat mobs.
- [ ] Defeating mobs awards XP.
- [ ] At least one character can level up.
- [ ] The game returns to day after the night ends.

When all of these check boxes are true, the vertical slice is complete and
we move from prototype to focused production.
