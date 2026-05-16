# Requirements Specification

**Project:** Campsite Chronicles
**Version:** 0.1 (Bootstrap)
**Date:** 2026-05-16
**Status:** Draft

---

## A. Product Vision

A stylized 3D survival and base-building defense game about a child protecting and improving a family campsite against nightly forest mobs. The player controls a brave 7-year-old boy who gathers resources, crafts tools, builds defenses, and commands companions (family members and pets) to survive increasingly dangerous nights in the woods.

**Core fantasy:** Survive the night, improve the camp, protect your family, and turn a fragile campsite into a magical woodland fortress.

---

## B. Target Audience

| Segment | Description |
|---------|-------------|
| Survival crafters | Players who enjoy gathering, resource management, and crafting loops |
| Base builders | Players who enjoy placing, upgrading, and defending a home base |
| Light tacticians | Players who enjoy simple strategic decisions (task assignment, defense placement) |
| Cozy-danger fans | Players who enjoy a tone that is adventurous and occasionally spooky, but not horror-gory |

**Tone target:** Adventurous, whimsical, slightly spooky woodland adventure. Think "cozy campfire" during the day, "tense forest darkness" at night. The tone should be accessible and not frightening for the protagonist's age, but dangerous enough to feel meaningful.

---

## C. Target Platform

| Platform | Priority |
|----------|---------|
| Windows desktop | Primary — prototype and vertical slice target |
| macOS / Linux desktop | Secondary — Godot supports these, defer post-prototype |
| Web | Tertiary — possible, defer post-prototype |
| Mobile | Out of scope |
| Console | Out of scope for now |

---

## D. Game Pillars

1. **Build and improve a campsite base** — The camp is home, and improving it is deeply satisfying.
2. **Survive nightly mob attacks** — Night is dangerous; preparation is the key to survival.
3. **Gather and manage resources** — The day is your resource runway.
4. **Craft useful tools, defenses, and upgrades** — Crafting converts resources into power.
5. **Command companions with simple tasks** — Family and pets multiply your capabilities.
6. **Level up characters through meaningful actions** — Growth rewards engagement.
7. **Balance cozy camping fantasy with danger and defense** — Both moods must coexist.
8. **Maintain strong visual clarity from a top-down/isometric camera** — Readability is a hard constraint.

---

## E. Functional Requirements

### E.1 Player (The Boy)

| ID | Requirement |
|----|-------------|
| PLR-01 | The player shall directly control the boy character. |
| PLR-02 | The boy shall be able to move around the game world. |
| PLR-03 | The boy shall be able to gather resources from resource nodes. |
| PLR-04 | The boy shall be able to build campsite structures by spending resources. |
| PLR-05 | The boy shall be able to craft basic items using resources. |
| PLR-06 | The boy shall gain experience (XP) from slaying mobs, building, crafting, gathering, and helping companions. |
| PLR-07 | The boy shall level up when sufficient XP is accumulated. |
| PLR-08 | Leveling up shall improve one or more stats or unlock an ability. |

### E.2 Companions

| ID | Requirement |
|----|-------------|
| CMP-01 | The game shall support companion characters alongside the player. |
| CMP-02 | Companions may include family members (parent, sibling) and pets (dog, cat). |
| CMP-03 | Companions shall be assignable to tasks by the player. |
| CMP-04 | Valid companion tasks shall include: Idle, Follow Player, Gather Resource, Guard Base, Repair Building, Craft Item, Scout Area, Support Combat. |
| CMP-05 | Companions shall execute their assigned task autonomously. |
| CMP-06 | Companions shall gain XP from successfully completing tasks. |
| CMP-07 | Companions shall be able to level up. |
| CMP-08 | Companions shall have simple roles or trait modifiers (e.g., fast gatherer, durable defender). |

### E.3 Base

| ID | Requirement |
|----|-------------|
| BAS-01 | The player shall be able to build and improve a camping base. |
| BAS-02 | The base shall include a central campsite core object (campfire or tent). |
| BAS-03 | Evil mobs shall attempt to damage or destroy the base core and buildings at night. |
| BAS-04 | The base core and buildings shall have health values. |
| BAS-05 | A building placed in the world shall be damageable by mobs. |
| BAS-06 | Buildings shall require resources to construct. |
| BAS-07 | Buildings shall only be placeable on valid terrain. |
| BAS-08 | Each building type shall provide a useful gameplay function. |
| BAS-09 | The base core's destruction shall trigger a game-over or recovery condition. |

### E.4 Day/Night Cycle

| ID | Requirement |
|----|-------------|
| DNC-01 | The game shall have a day/night cycle that advances automatically. |
| DNC-02 | During the day, gathering, building, crafting, and task assignment shall be the primary activities. |
| DNC-03 | During the night, mobs shall attack the base. |
| DNC-04 | The game shall display time of day in the UI. |
| DNC-05 | The game shall warn the player before night begins (sunset phase). |
| DNC-06 | The danger level shall increase across days/nights (escalating difficulty). |

### E.5 Mobs

| ID | Requirement |
|----|-------------|
| MOB-01 | The game shall support evil forest mobs. |
| MOB-02 | Mobs shall spawn outside the base perimeter at night. |
| MOB-03 | Mobs shall navigate toward the base core, buildings, player, or companions. |
| MOB-04 | Mobs shall attack their target when in range. |
| MOB-05 | Mobs shall have health and shall die when health reaches zero. |
| MOB-06 | Defeating mobs shall award XP and/or resources to nearby characters. |
| MOB-07 | Multiple mob types shall exist, each with different stats and behavior. |

### E.6 Resources

The game shall support exactly 10 base resource types:

| # | Resource | Primary Use |
|---|----------|-------------|
| 1 | Wood | Basic construction, crafting |
| 2 | Stone | Stronger structures |
| 3 | Berries | Food, basic healing |
| 4 | Fiber | Ropes, traps, simple tools |
| 5 | Mushrooms | Potions, special crafting |
| 6 | Clay | Walls, ovens, reinforced structures |
| 7 | Leaves | Camouflage, bedding, simple roofs |
| 8 | Resin | Glue, torches, fire upgrades |
| 9 | Scrap | Advanced improvised tools |
| 10 | Glow Shards | Magical upgrades, night defenses |

| ID | Requirement |
|----|-------------|
| RES-01 | The game shall support all 10 resource types in its data model. |
| RES-02 | The player shall be able to gather resources from resource nodes in the world. |
| RES-03 | Resources shall be stored in a global/base inventory. |
| RES-04 | Resources shall be consumable by building, crafting, and upgrades. |
| RES-05 | All 10 resource types shall be displayed in the HUD. |
| RES-06 | Resource counts shall update in real time. |

### E.7 Crafting

| ID | Requirement |
|----|-------------|
| CRF-01 | The game shall support crafting recipes. |
| CRF-02 | Each recipe shall specify one or more resource costs. |
| CRF-03 | Crafting shall consume the specified resources from the inventory. |
| CRF-04 | Crafting shall produce an item, tool, defense object, or upgrade. |
| CRF-05 | Crafting shall grant XP to the crafting character. |
| CRF-06 | The player shall not be able to craft without sufficient resources. |

### E.8 Progression

| ID | Requirement |
|----|-------------|
| PRG-01 | All player-controlled and companion characters shall have an XP counter. |
| PRG-02 | XP shall be awarded for: defeating mobs, building, crafting, gathering, repairing, and surviving nights. |
| PRG-03 | Each character shall level up when their XP reaches the threshold for the next level. |
| PRG-04 | Leveling up shall produce a meaningful improvement (stat increase or ability unlock). |
| PRG-05 | The progression system shall use a simple, externally-defined XP table. |
| PRG-06 | No complex skill tree is required in the first prototype. |

### E.9 UI

| ID | Requirement |
|----|-------------|
| UI-01 | The HUD shall display counts for all 10 resource types. |
| UI-02 | The HUD shall display the current time of day. |
| UI-03 | The HUD shall display the base core's current health. |
| UI-04 | The HUD shall display selected character or building information. |
| UI-05 | The HUD shall display companion task status. |
| UI-06 | The HUD shall display a night attack warning during the sunset phase. |
| UI-07 | Build mode shall display a placement ghost and validity indicator. |

---

## F. Non-Functional Requirements

| ID | Requirement |
|----|-------------|
| NFR-01 | The prototype shall run at ≥30 FPS on a typical mid-range Windows PC (circa 2022). |
| NFR-02 | The codebase shall be easy to extend by new coding agents with no prior project context. |
| NFR-03 | Game data (buildings, mobs, resources, recipes) shall be data-driven using Godot Resource files or equivalent. |
| NFR-04 | Hardcoded gameplay values shall not appear in behavior scripts; they belong in exported properties or resource files. |
| NFR-05 | The project shall use GDScript with static typing where practical. |
| NFR-06 | The visual style shall prioritize readability over photorealism. |
| NFR-07 | Systems shall be loosely coupled through signals where practical. |
| NFR-08 | The project shall be free/open-source-friendly (no proprietary or licensed asset dependencies). |

---

## G. First Prototype Scope

The first vertical slice shall include:

- [ ] One playable boy character with basic movement
- [ ] One small test map (flat terrain, static environment)
- [ ] One campfire core building (base)
- [ ] Three gatherable resource node types (Wood, Stone, Berries)
- [ ] All 10 resources represented in data and HUD
- [ ] Two companion prototypes (placeholder behavior)
- [ ] Two assignable companion tasks (Follow Player, Guard Base)
- [ ] Three building types (Campfire Core, Wooden Fence, Watch Post)
- [ ] One crafting recipe (Wooden Fence: Wood + Fiber)
- [ ] One mob type (Shadow Imp)
- [ ] One basic night attack wave
- [ ] Basic character XP tracking
- [ ] Basic level-up trigger
- [ ] Basic building placement with resource cost validation
- [ ] Basic save/load (optional stretch goal)

---

## H. Out of Scope for First Prototype

- Multiplayer of any kind
- Procedural world generation
- Full campaign or story progression
- Complex dialogue or cutscene system
- Advanced mob AI (pathfinding beyond simple navigation mesh)
- Large tech tree or skill trees
- Final art assets (placeholder geometry is acceptable)
- Full controller support
- Advanced combat abilities or special moves
- Online services, analytics, or telemetry
- Achievement systems
- Localization

---

## I. Open Questions

These questions are unresolved and require design decisions before or during Phase 1:

| # | Question |
|---|----------|
| OQ-01 | Is the tone primarily cozy, spooky, funny, or heroic? Is there a blend? |
| OQ-02 | Does the boy fight directly (melee/ranged attacks), command companions to fight, or both? |
| OQ-03 | If a companion is reduced to zero health: can they be defeated permanently, temporarily incapacitated, or only scared away? |
| OQ-04 | Does the base core's health reaching zero trigger an instant game-over, or a recovery/last-stand scenario? |
| OQ-05 | Do pets fight, gather, scout, or provide passive buffs only? |
| OQ-06 | Should the world be handcrafted, procedurally generated, or a hybrid (handcrafted layout with procedural content)? |
| OQ-07 | Is the game purely real-time, or can the player pause during planning phases? |
| OQ-08 | Should day length be adjustable by the player (difficulty setting)? |
| OQ-09 | Should resource nodes respawn, regenerate slowly, or be permanently depleted? |
| OQ-10 | Is there a maximum base area, or can the player expand indefinitely? |
