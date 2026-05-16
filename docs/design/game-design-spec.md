# Game Design Specification

**Project:** Campsite Chronicles
**Version:** 0.1 (Bootstrap)
**Date:** 2026-05-16
**Status:** Draft

---

## A. High-Level Pitch

A 7-year-old boy must protect his family campsite from evil forest mobs by gathering resources, crafting tools, building defenses, assigning companions, and surviving increasingly dangerous nights. By day the camp is cozy and safe; by night the forest comes alive with shadowy creatures that want to snuff out the campfire.

**Genre:** Stylized 3D base-builder / survival defense
**Camera:** Top-down or isometric 3D (fixed angle or slight adjustments)
**Controls:** Mouse + keyboard (WASD movement, mouse for build/select)
**Art direction:** Stylized, readable, colorful by day — dark, contrasty, spooky by night

---

## B. Core Gameplay Loop

### Day Phase

```
Wake up at camp
  → Review base damage and resource stockpile
  → Plan the day
  → Explore nearby woods
  → Gather resources (player + companions)
  → Assign companions to tasks
  → Craft items / build or repair defenses
  → Sunset warning fires — final preparations
```

### Night Phase

```
Mobs emerge from forest edges
  → Base comes under attack
  → Player directly controls the boy
  → Companions execute their assigned roles
  → Defend the campfire / base core
  → Defeat mobs with player action and companion support
  → Earn XP and loot from defeated mobs
  → Survive until dawn
```

### Meta-Progression (Between Nights)

```
Level up characters (boy + companions)
  → Unlock stronger buildings, crafting recipes, defenses
  → Improve base layout
  → Survive stronger night waves
  → Explore deeper forest areas
  → Repeat with escalating challenge
```

---

## C. Player Character — The Boy

### Characterization
- Brave but small — not overpowered
- Fast and flexible — nimble enough to avoid mobs, gather quickly
- Resourceful — crafts and builds from whatever's available
- Protector — motivated by protecting family, not just survival
- Tone: determined, slightly scared, but never giving up

### Initial Stats

| Stat | Description | Starting Value |
|------|-------------|---------------|
| Health | Hit points before incapacitation | 80 |
| Stamina | Governs running, heavy actions | 100 |
| Courage | Reduces fear-based debuffs near mobs | 10 |
| Build Speed | How fast the boy places buildings | 1.0x |
| Gather Speed | How fast resources are collected | 1.0x |
| Attack Power | Damage dealt to mobs | 8 |
| Crafting Skill | Bonus output or speed for crafting | 1 |

### Leveling
- XP is earned from: gathering, building, crafting, defeating mobs, surviving nights.
- Each level increases 1–2 stats.
- No complex skill tree in the prototype.
- The boy does not die permanently — on reaching 0 HP, he retreats to the campfire and temporarily loses control (recovery mechanic TBD per OQ-04).

---

## D. Companions

Companions are NPCs who follow orders, execute tasks, and can fight, gather, or support autonomously. They are not directly player-controlled.

### Companion Archetypes

#### Parent Companion
- **Role:** Defender / Repairman
- **Strengths:** High durability, good repair speed, calms other companions
- **Weaknesses:** Slower movement, lower gather speed
- **Personality:** Calm, protective, methodical
- **Placeholder art:** Tall figure, warm colors

#### Sibling Companion
- **Role:** Gatherer / Scout
- **Strengths:** Fast movement, high gather speed
- **Weaknesses:** Lower health, less effective in direct combat
- **Personality:** Energetic, curious, competitive
- **Placeholder art:** Smaller figure, bright colors

#### Dog Companion
- **Role:** Scout / Harasser
- **Strengths:** Early mob detection (warning radius), can distract small mobs
- **Weaknesses:** Cannot repair or craft; easily overwhelmed by groups
- **Personality:** Loyal, excitable, alert
- **Placeholder art:** Four-legged, low to ground, wagging tail indicator

#### Cat Companion
- **Role:** Stealthy Scout / Rare Finder
- **Strengths:** Finds rare resources (Glow Shards, Resin), avoids mob aggro
- **Weaknesses:** Will not engage in combat; limited direct utility
- **Personality:** Independent, mysterious, occasionally useful
- **Placeholder art:** Small, sleek, moves quietly

**Prototype scope:** Implement two companions (recommended: Parent + Dog, or Parent + Sibling). Define all four in data.

---

## E. Companion Task System

### Task Definitions

| Task | Description | Valid Companions |
|------|-------------|-----------------|
| Idle | Stand still at last position | All |
| Follow Player | Stay near the player, assist if attacked | All |
| Gather Resource | Go to nearest resource node of assigned type and gather | Sibling, Parent (slow), Dog (limited) |
| Guard Base | Patrol campfire perimeter; attack approaching mobs | Parent, Dog |
| Repair Building | Find most-damaged building and repair it | Parent |
| Craft Item | Go to crafting station and produce assigned recipe | Parent, Sibling |
| Scout Area | Move outward in a sector and return with info on nearby resources/mobs | Dog, Cat, Sibling |
| Support Combat | Follow player into combat; attack engaged mobs | Parent, Sibling, Dog |

### Task Assignment UI (Prototype)
- Click/select a companion → opens a simple task panel
- Task panel shows 2–4 available tasks for that companion type
- One task is active at a time per companion
- Visual indicator above companion shows current task icon

### First Prototype Tasks to Implement
1. **Follow Player** — companion navigates to stay within range of the player
2. **Guard Base** — companion navigates to campfire, patrols a small radius, attacks mobs in range
3. **Gather Resource** — companion navigates to nearest node of target type, gathers, returns (bonus task)

---

## F. Resource System

### Resource Definitions

| # | Name | Rarity | Primary Uses | Sources | Notes |
|---|------|--------|-------------|---------|-------|
| 1 | Wood | Common | Fences, buildings, crafting, torches | Trees, fallen logs | Most versatile resource |
| 2 | Stone | Common | Stronger walls, paths, foundations | Rock outcroppings | Heavy — may require cart upgrade later |
| 3 | Berries | Common | Food, basic healing | Berry bushes | Respawns slowly |
| 4 | Fiber | Common | Ropes, traps, simple tools | Tall grass, plants | Used in most recipes |
| 5 | Mushrooms | Uncommon | Potions, special recipes, risky food | Shaded forest floor | Some types may have negative effects |
| 6 | Clay | Uncommon | Walls, ovens, reinforced structures | Near streams, ponds | Slow to gather; yields sturdy outputs |
| 7 | Leaves | Common | Camouflage, bedding, simple roofs | Trees, bushes | Seasonal availability (future feature) |
| 8 | Resin | Uncommon | Glue, torches, fire upgrades | Wounded trees, pine areas | Key for fire-based defenses |
| 9 | Scrap | Rare | Advanced improvised tools | Abandoned picnic sites, old camp spots | Limited world supply |
| 10 | Glow Shards | Rare | Magical upgrades, night defenses | Deep forest, mob drops | Primary late-game material |

### Stack Behavior
- All resources are integers (no fractional amounts).
- Global inventory; no per-character carrying limit in prototype.
- Display cap for UI: show actual value up to 999, then "999+".

---

## G. Building System

### Building Definitions

#### Campfire Core
- **Role:** Central base object; primary target for mobs
- **HP:** 200
- **Cost:** None (pre-placed in world)
- **Function:** Provides a light/safety radius; companions regenerate health near it; mobs are drawn to destroy it
- **Effect:** Campfire destroyed = game over condition (or last-stand)
- **Placeholder:** Orange glowing cylinder or cone

#### Wooden Fence
- **Role:** Basic barrier
- **HP:** 50
- **Cost:** 3 Wood + 2 Fiber
- **Function:** Blocks mob movement along the fence line; slows mobs that try to path around it
- **Note:** Cheap and fast to build; expected to need repair each night
- **Placeholder:** Brown box-like barrier segment

#### Watch Post
- **Role:** Elevated companion station
- **HP:** 80
- **Cost:** 4 Wood + 2 Stone + 2 Fiber
- **Function:** Companion assigned here gets increased attack range and detection radius
- **Note:** Only one companion occupies a Watch Post at a time
- **Placeholder:** Tall narrow box with a platform top

#### Storage Crate *(optional for prototype)*
- **Role:** Resource storage expansion
- **HP:** 60
- **Cost:** 3 Wood + 1 Fiber
- **Function:** Increases maximum storable resources

#### Crafting Table *(optional for prototype)*
- **Role:** Crafting station
- **HP:** 70
- **Cost:** 4 Wood + 1 Stone
- **Function:** Unlocks additional crafting recipes

### Placement Rules
- Buildings must be placed on flat, valid terrain (no water, no rocks).
- Buildings cannot overlap each other or the base core.
- Ghost preview appears when in build mode; green = valid, red = invalid.
- Placement costs are deducted immediately on confirm.

---

## H. Crafting System

### Recipe Format
Each recipe has: name, ingredient list (resource + amount), output (item or building unlock), XP award.

### Initial Recipes

| Recipe | Ingredients | Output | XP |
|--------|-------------|--------|----|
| Wooden Fence | 3 Wood + 2 Fiber | Places Wooden Fence | 5 |
| Watch Post | 4 Wood + 2 Stone + 2 Fiber | Places Watch Post | 10 |
| Torch | 1 Wood + 1 Resin + 2 Leaves | Torch item (lighting, mob repellent) | 5 |
| Berry Snack | 3 Berries + 1 Leaves | Consumable: heal 20 HP | 3 |
| Simple Trap | 2 Wood + 3 Fiber + 1 Scrap | Trap building: damages mobs that walk over | 8 |

**First prototype:** Implement one recipe (Wooden Fence or Berry Snack recommended as the simplest).

### Crafting Flow
1. Player opens crafting menu (key press or crafting table interaction).
2. Available recipes shown with current resource counts and costs.
3. Recipes the player cannot afford are shown grayed out.
4. Player confirms recipe → resources deducted → output placed or added to inventory → XP awarded.

---

## I. Mob System

### Mob Definitions

#### Shadow Imp *(Prototype mob)*
- **Role:** Basic attacker
- **HP:** 30
- **Speed:** 3.5 m/s
- **Attack Power:** 5 per hit
- **Attack Rate:** Once per 1.5 seconds
- **Target Priority:** Wooden Fences > Campfire Core > Player > Companion
- **XP on Death:** 10 XP
- **Loot:** Occasionally drops 1 Scrap or 1 Glow Shard
- **Behavior:** Walks straight toward nearest valid target; no pathfinding around obstacles in prototype (simple direct movement)
- **Placeholder:** Small dark sphere or capsule with glowing eyes

#### Bramble Beast *(Future)*
- Slow, high HP, high damage; pushes through fences
- **Placeholder art:** Large spiky silhouette

#### Night Crow *(Future)*
- Flies over fences; harasses companions; does not target buildings
- **Placeholder art:** Dark winged shape

#### Mushroom Gremlin *(Future)*
- Steals resources from stockpile; does not fight buildings directly
- **Placeholder art:** Hunched, spotted silhouette

### Spawn System
- Mobs spawn at world edges (spawn points around the map perimeter) when night begins.
- Wave size increases by day/night count.
- First wave: 5 Shadow Imps.
- Wave formula (prototype): `mob_count = 3 + (day_number * 2)`
- Spawn interval: staggered over 10–20 seconds so mobs do not all arrive simultaneously.

---

## J. XP and Leveling

### XP Sources

| Action | XP Awarded | Who Receives |
|--------|-----------|--------------|
| Gathering 1 resource | 1 XP | Gathering character |
| Placing a building | 5 XP | Builder character |
| Crafting a recipe | 3–10 XP (by recipe) | Crafting character |
| Defeating a mob | 10–30 XP (by mob type) | Nearby player/companions |
| Repairing a building | 2 XP | Repairing character |
| Surviving a night | 20 XP | All active characters |

### Level Thresholds (Prototype Table)

| Level | Total XP Required | Stat Bonus |
|-------|------------------|-----------|
| 1 | 0 | Starting stats |
| 2 | 100 | +10 HP or +1 Attack Power |
| 3 | 250 | +10 HP, +0.1x Gather Speed |
| 4 | 500 | +1 Attack Power, +0.1x Build Speed |
| 5 | 900 | Unlock one new ability (TBD) |

*Cap at level 5 for prototype; expand later.*

---

## K. Camera and Controls

### Camera
- **Style:** Fixed isometric or slightly rotatable top-down 3D
- **Position:** ~60° angle from horizontal; elevated above the play area
- **Follow:** Camera follows the player character with smooth lag
- **Zoom:** Optional zoom in/out (mouse wheel) within a limited range
- **Rotation:** Disabled in prototype (add as optional comfort feature later)

### Keyboard Controls

| Key | Action |
|-----|--------|
| W/A/S/D | Move player |
| Shift + WASD | Sprint (stamina cost) |
| E | Interact (gather, open menu) |
| B | Toggle build mode |
| Tab | Cycle selected companion |
| T | Open companion task panel |
| Escape | Cancel / close menu |
| F5 | Quick save (stretch) |

### Mouse Controls

| Input | Action |
|-------|--------|
| Left click | Interact / confirm placement |
| Right click | Cancel placement |
| Mouse wheel | Zoom (optional) |
| Left click on companion | Select companion |

### Build Mode
- Press B to enter build mode.
- Select building type from a radial or list panel.
- A ghost/preview object follows the mouse.
- Green tint = valid placement; red tint = invalid.
- Left click to confirm; Escape/Right click to cancel.
- Resources deducted on placement.

---

## L. Art Direction

### Visual Style
- **Renderer:** Godot 4 Forward+ (stylized, non-photorealistic)
- **Shape language:** Strong, readable silhouettes; chunky proportions; exaggerated features for readability
- **Color palette:** Warm campfire ambers/oranges/yellows during day; cold blue-purples and dark greens at night
- **Characters:** Stylized, slightly exaggerated proportions (large heads, clear silhouettes per character type)
- **Mobs:** High contrast dark shapes against camp lighting; glowing eyes for readability

### Day vs Night Mood

| Phase | Lighting | Palette | Feel |
|-------|---------|---------|------|
| Day | Bright, warm sunlight; dappled forest shade | Greens, yellows, warm browns | Cozy, safe, productive |
| Sunset | Golden-orange long shadows | Amber, deep orange, purple hints | Anticipation, urgency |
| Night | Dark; campfire glow is primary light source | Black, deep blue, orange halo from camp | Tense, spooky, dynamic |
| Dawn | Soft pink/lavender light returning | Rose, pale blue, warm gold | Relief, hope |

### Readability Rules
- The player character must always be clearly distinguishable (bright clothing or aura).
- Each companion type has a distinct silhouette AND color.
- Each mob type has a distinct silhouette.
- Buildings must read clearly as blockers or towers.
- Resources must be distinguishable from terrain at a glance.
- The campfire glow is the visual anchor of the entire play area.

### Reference Style (Inspiration Only)
The following games are used for visual readability reference only — no assets, characters, or IP are copied:
- Stylized 3D readability similar to League of Legends (top-down)
- Cozy color palette inspired by games like Stardew Valley or A Short Hike
- Mob spookiness inspired by Don't Starve's creature silhouettes

---

## M. Audio Direction

### Day Ambience
- Gentle forest sounds: birdsong, rustling leaves, distant stream
- Campfire crackling (always audible near base)
- Light, upbeat background music (acoustic/folksy, optional)

### Sunset / Preparation
- Music transitions to more tense, minor-key variation
- Wind picks up in sound design
- Distant owl hoots

### Night / Attack
- Tense, rhythmic background music
- Mob movement and attack sounds
- Player and companion combat sounds
- Campfire crackling becomes more prominent as anchor sound

### UI / Interaction Feedback
- Satisfying click for building placement
- Distinct sound for gathering each resource type
- Level-up jingle
- Companion confirmation bark/sound on task assignment
- Night warning bell/horn sound at sunset

---

## N. First Vertical Slice Definition

A successful first vertical slice is defined as:

| # | Requirement | Priority |
|---|-------------|---------|
| VS-01 | Player can move the boy around a small test map | Must |
| VS-02 | The map contains a campfire core | Must |
| VS-03 | The HUD shows time of day | Must |
| VS-04 | The HUD shows base (campfire) health | Must |
| VS-05 | The HUD shows all 10 resource types with counts | Must |
| VS-06 | Player can gather at least 3 resource types | Must |
| VS-07 | Player can place a wooden fence (spends resources) | Must |
| VS-08 | At least one companion can follow the player | Must |
| VS-09 | At least one companion can guard the base | Must |
| VS-10 | At night, Shadow Imps spawn and attack campfire or fence | Must |
| VS-11 | Player and/or companion can defeat mobs | Must |
| VS-12 | XP is awarded on mob defeat | Must |
| VS-13 | A character can reach level 2 | Must |
| VS-14 | The game returns to day after surviving the night | Must |
| VS-15 | At least one crafting recipe can be executed | Should |
| VS-16 | Basic save/load of resource inventory and day count | Could |
