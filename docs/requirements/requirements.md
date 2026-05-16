# Requirements specification

> **Status:** Draft, locked-in for Phase 0 bootstrap.
> Future changes require updating this file and adding an ADR if the impact
> is architectural.

## A. Product vision

A stylized 3D survival / base-building defense game about a 7-year-old boy
who must protect and improve a family campsite against nightly forest mobs.
By day the world is cozy and exploratory; by night it is dangerous and
demands preparation, defense, and teamwork with companions.

The long-term fantasy: **&ldquo;Survive the night, improve the camp, protect
your family, and turn a fragile campsite into a magical woodland
fortress.&rdquo;**

## B. Target audience

- Players who enjoy survival crafting games (Don&rsquo;t Starve, Valheim
  style at a softer scale).
- Players who enjoy base-building (They Are Billions, Stranded Deep style
  at smaller scope).
- Players who enjoy light tactical defense / wave defense.
- Players who like cozy-but-dangerous woodland themes (Hello Neighbor cozy
  side, Wytchwood cozy side, but family-friendly).
- Tone target: **adventurous, slightly spooky, but not horror-gory.**

## C. Target platform

- **Primary:** Windows desktop (Windows 10 / 11, mid-range PC).
- Linux and macOS are likely free side effects of Godot but not promised.
- Console / mobile are out of scope until after the first vertical slice.

## D. Game pillars

These pillars guide every design and engineering decision. When in doubt,
choose the option that best serves them.

1. **Build and improve a campsite base.**
2. **Survive nightly mob attacks.**
3. **Gather and manage resources.**
4. **Craft useful tools, defenses, and camp upgrades.**
5. **Command companions with simple tasks.**
6. **Level up characters through useful actions.**
7. **Balance cozy camping fantasy with danger and defense.**
8. **Maintain strong visual clarity from a top-down / isometric camera.**

## E. Functional requirements

> Wording note: &ldquo;shall&rdquo; = mandatory, &ldquo;may&rdquo; =
> optional / variant allowed. Each requirement is given an ID for traceability.

### Player

- **FR-PLAYER-1** The player shall directly control the boy character.
- **FR-PLAYER-2** The boy shall be able to move around the world.
- **FR-PLAYER-3** The boy shall be able to gather resources from valid
  resource nodes.
- **FR-PLAYER-4** The boy shall be able to build campsite structures using
  resources.
- **FR-PLAYER-5** The boy shall be able to craft basic items using
  resources.
- **FR-PLAYER-6** The boy shall gain experience from useful actions
  including slaying mobs, building, crafting, and assisting companions.
- **FR-PLAYER-7** The boy shall level up when he reaches an XP threshold,
  improving at least one stat per level.

### Companions

- **FR-COMP-1** The game shall support companion characters.
- **FR-COMP-2** Companions may include family members and pets.
- **FR-COMP-3** Companions shall be assignable to tasks by the player.
- **FR-COMP-4** Initial supported task types shall include:
  *gather wood, gather stone, collect food, guard base, repair structures,
  craft supplies, scout nearby area, support the player in combat.*
- **FR-COMP-5** Companions shall be able to gain experience from their
  actions.
- **FR-COMP-6** Companions shall be able to level up.
- **FR-COMP-7** Companions shall have simple roles, strengths, or traits
  that differentiate them.

### Base

- **FR-BASE-1** The player shall be able to build and improve a camping
  base.
- **FR-BASE-2** The base shall include a central camp object (tent,
  campfire, or family campsite core).
- **FR-BASE-3** Evil mobs shall attempt to damage or destroy the camping
  base at night.
- **FR-BASE-4** The base shall have health or integrity that can decrease
  from mob damage and increase from repairs.
- **FR-BASE-5** Buildings shall require resources to construct.
- **FR-BASE-6** Buildings shall be placeable only on valid terrain.
- **FR-BASE-7** Buildings shall provide useful functions (defense,
  storage, crafting, light, vision, etc.).

### Day / night loop

- **FR-LOOP-1** The game shall have a day/night cycle.
- **FR-LOOP-2** During the day the player shall be able to gather, build,
  craft, assign tasks, and prepare.
- **FR-LOOP-3** During the night, mobs shall attack the base.
- **FR-LOOP-4** The danger level shall increase over time (more mobs,
  stronger mobs, or both).

### Mobs

- **FR-MOB-1** The game shall support evil forest mobs.
- **FR-MOB-2** Mobs shall spawn at night.
- **FR-MOB-3** Mobs shall move toward the base, the player, or
  companions.
- **FR-MOB-4** Mobs shall attack buildings, the base core, the player, or
  companions.
- **FR-MOB-5** Mobs shall grant experience or resources when defeated.

### Resources

The game starts with **exactly 10 initial resource types**:

| ID  | Name        | Short description                                      |
|-----|-------------|--------------------------------------------------------|
| 1   | Wood        | Basic construction material.                           |
| 2   | Stone       | Stronger structures.                                   |
| 3   | Berries     | Food and healing.                                      |
| 4   | Fiber       | Ropes, traps, simple tools.                            |
| 5   | Mushrooms   | Potions, special crafting, risky food.                 |
| 6   | Clay        | Walls, ovens, reinforced structures.                   |
| 7   | Leaves      | Camouflage, bedding, simple roofs.                     |
| 8   | Resin       | Glue, torches, fire upgrades.                          |
| 9   | Scrap       | Advanced improvised tools.                             |
| 10  | Glow Shards | Rare magical / night defense upgrades.                 |

- **FR-RES-1** The game shall support resource gathering, storage,
  spending, and display in the UI for all 10 resources.
- **FR-RES-2** All 10 resources shall be represented in data and in the UI
  from the first prototype on, even if not all are gatherable yet.

### Crafting

- **FR-CRAFT-1** The game shall support crafting recipes.
- **FR-CRAFT-2** Recipes shall consume resources.
- **FR-CRAFT-3** Recipes shall produce items, tools, defenses, or
  upgrades.
- **FR-CRAFT-4** Crafting shall grant experience where appropriate.

### Progression

- **FR-PROG-1** Characters shall gain experience from relevant actions.
- **FR-PROG-2** Characters shall level up.
- **FR-PROG-3** Level-ups shall improve useful stats or unlock abilities.
- **FR-PROG-4** Base progression shall unlock stronger buildings,
  defenses, or crafting recipes.

### UI

- **FR-UI-1** The UI shall show core resources.
- **FR-UI-2** The UI shall show time of day.
- **FR-UI-3** The UI shall show base health.
- **FR-UI-4** The UI shall show selected character or building
  information.
- **FR-UI-5** The UI shall show companion task status.
- **FR-UI-6** The UI shall show night attack warnings.

## F. Non-functional requirements

- **NFR-1** The prototype shall run smoothly (target 60 FPS) on a typical
  mid-range Windows PC (e.g. 4-core CPU, integrated or modest discrete
  GPU, 16 GB RAM).
- **NFR-2** The game shall be easy to extend by coding agents working from
  the documentation in this repository.
- **NFR-3** Game data shall be data-driven where practical
  (`.tres` Resources for items, buildings, mobs, recipes).
- **NFR-4** Hardcoded gameplay values shall be avoided in behavior
  scripts; tunable values shall live in exported properties or data
  resources.
- **NFR-5** The project shall favor simple, readable GDScript over clever
  abstractions.
- **NFR-6** The visual style shall prioritize readability over realism.
- **NFR-7** Systems shall be loosely coupled where practical; signals are
  the preferred cross-system communication mechanism.

## G. First prototype scope (vertical slice)

The first vertical slice shall include:

- One playable boy character.
- One small test map.
- One campsite core.
- Three gatherable resource node types.
- All 10 resources represented in data / UI even if only some are
  gatherable at first.
- Two companion prototypes.
- Two assignable companion tasks.
- Three building types.
- One crafting recipe.
- One mob type.
- One basic night attack wave.
- Basic character XP and level-up.
- Basic building placement.
- Basic save/load prototype if feasible.

## H. Out of scope (for the first prototype)

- Multiplayer (local or networked).
- Procedural world generation.
- Full campaign / story content.
- Complex branching dialogue system.
- Advanced / learning AI.
- Large tech tree.
- Final / production art assets.
- Full controller support.
- Advanced combat abilities (combos, dodges, special moves).
- Online services (leaderboards, accounts, cloud saves).

## I. Open questions

These are tracked deliberately as open. They must be answered before they
block design or implementation; until then they are documented assumptions
the team will revisit.

- **OQ-TONE.** Is the tone more cozy, spooky, funny, or heroic?
  *Working assumption: adventurous + slightly spooky, kid-friendly. Cozy by
  day, tense at night.*
- **OQ-COMBAT-ROLE.** Should the boy fight directly, command companions,
  or both?
  *Working assumption: both. The boy can fight (with weak attacks) but is
  more effective when companions help.*
- **OQ-COMP-DEATH.** Can companions be defeated, injured, scared, or only
  temporarily disabled?
  *Working assumption: companions are knocked out (not killed) and recover
  by day. Reduces emotional weight in a kid-fronted game.*
- **OQ-BASE-DEATH.** Is the camp destroyed immediately on base health
  reaching zero, or does the player get recovery chances?
  *Working assumption: a grace period: when the core hits zero, a short
  &ldquo;last stand&rdquo; window starts; if mobs continue beating on the
  core during that window, the run ends.*
- **OQ-PETS.** Should pets fight, gather, scout, or mainly provide buffs?
  *Working assumption: pets scout and distract, with minor combat. They do
  not gather heavy resources.*
- **OQ-WORLD-GEN.** Should the world be handcrafted, procedural, or
  hybrid?
  *Working assumption: handcrafted for the prototype; revisit hybrid later.*
- **OQ-TIME-CONTROL.** Should the game be real-time only, or pause / slow
  down during planning?
  *Working assumption: real-time, but the day phase is long enough not to
  feel rushed. We may add an optional slow-time during build mode later.*
