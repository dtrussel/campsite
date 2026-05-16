# Software architecture specification

> Engine: Godot 4.x. Language: GDScript with static typing wherever
> practical. See
> [`docs/decisions/ADR-0001-engine-and-language-selection.md`](../decisions/ADR-0001-engine-and-language-selection.md).

## Guiding principles

This architecture is deliberately simple. It is sized for an indie
prototype that needs to grow incrementally, be modified by coding agents,
and stay debuggable by humans.

**Avoid:**

- Custom ECS frameworks.
- Custom engine-on-top-of-Godot frameworks.
- Dependency injection containers.
- Excessive class inheritance.
- Premature optimization.
- Abstractions invented for needs that do not exist yet.

**Prefer:**

- **Scenes** for anything that has a visible presence in the world (a
  player, a mob, a fence, a resource node, the HUD).
- **Scripts** for behavior, attached to scenes.
- **Resource files (`.tres`)** for game data (recipes, building specs,
  mob stats, resource definitions).
- **Autoload singletons** for genuinely global services (game manager,
  time manager, resource inventory, save manager).
- **Signals** for cross-system communication so systems stay decoupled.
- **Simple, explicit state machines** for player, companion, mob, and
  day/night cycle. Plain `match` on a `State` enum is enough.

## A. Layer overview

The codebase is conceptually split into five layers. The boundaries are
guidelines, not enforced separations.

### 1. Presentation / Scene layer

- Godot scenes, nodes, animations, particles, UI controls.
- Lives under `game/scenes/` and `game/assets/`.
- Knows about the visuals; should not own gameplay state.

### 2. Gameplay logic layer

- Player movement, companion behavior, mob behavior, building placement,
  resource gathering, combat, crafting, XP/leveling.
- Lives under `game/scripts/{player,companions,mobs,base,buildings,resources,crafting,progression}/`.
- Each script is attached to a scene or owns a small subsystem.

### 3. Game state layer

- Current day number, time of day, resource inventory, base health,
  active buildings list, character progression data, current wave state.
- Lives under `game/scripts/core/` (autoloads).
- Other layers read state via signals or singleton method calls. They do
  not store their own copies.

### 4. Data layer

- `ResourceDefinition`, `BuildingDefinition`, `CraftingRecipe`,
  `MobDefinition`, `CharacterStatsDefinition`.
- Stored as `.tres` files under `game/resources/`.
- Loaded once at startup and referenced by id throughout the runtime.

### 5. Persistence layer

- Save / load logic in `game/scripts/save/`.
- Versioned save data with a schema version number.
- Saves the game state layer plus a snapshot of placed buildings, *not*
  raw scene references.
- Reload reconstructs scenes from saved data and the data layer.

## B. Proposed autoloads

Each autoload is a single small node script registered in
`game/project.godot` under `[autoload]`. Initial autoloads:

| Autoload             | Role                                                        |
|----------------------|-------------------------------------------------------------|
| `GameManager`        | High-level game state; coordinates day/night transitions.   |
| `TimeManager`        | Drives the day/night cycle and emits time-of-day signals.   |
| `ResourceManager`    | Tracks resource inventory; validates costs; adds/removes.   |
| `BuildManager`       | Handles build mode, placement validation, building spawn.   |
| `ProgressionManager` | Handles XP totals and level-up rules.                       |
| `SaveManager`        | Serializes and deserializes save data.                      |

### Autoload contract

- Autoloads expose **clear public methods** and emit **named signals**.
- Autoloads do **not** hold references to specific scene instances unless
  necessary (e.g. `BuildManager` may briefly hold a placement ghost).
- Game scripts subscribe to autoload signals rather than polling.

### Minimal stubs first

For Phase 0 only `GameManager` and `TimeManager` ship as real scripts.
The others (`ResourceManager`, `BuildManager`, `ProgressionManager`,
`SaveManager`) are intentionally **not yet autoloaded** until they have
real behavior. The architecture below describes them so future agents know
where to add them.

## C. Scene conventions

Each scene name is PascalCase; the file path is snake_case for directories
and PascalCase for the scene file itself to match Godot defaults.

Recommended scenes (current and planned):

```
game/scenes/main/Main.tscn                  # Entry scene
game/scenes/world/TestWorld.tscn            # Small test map
game/scenes/player/PlayerBoy.tscn           # The boy
game/scenes/companions/Companion.tscn       # Generic companion
game/scenes/mobs/ShadowImp.tscn             # First mob
game/scenes/base/CampfireCore.tscn          # Base core
game/scenes/buildings/WoodenFence.tscn      # First built structure
game/scenes/ui/HUD.tscn                     # Heads-up display
```

### Scene composition rules

- A scene&rsquo;s root node carries the script that owns that scene&rsquo;s
  behavior.
- Children represent visual or sub-behavior pieces (e.g. `MeshInstance3D`,
  `CollisionShape3D`, `AnimationPlayer`).
- Scenes never hard-code references to other scenes by path inside their
  scripts. They use `@export` properties for required dependencies so
  scenes stay reusable and refactor-safe.

## D. Script conventions

Recommended scripts (current and planned):

```
game/scripts/core/game_manager.gd
game/scripts/core/time_manager.gd
game/scripts/core/resource_manager.gd          # later
game/scripts/core/build_manager.gd             # later
game/scripts/core/progression_manager.gd       # later
game/scripts/save/save_manager.gd              # later

game/scripts/game_loop/wave_controller.gd      # later

game/scripts/player/player_controller.gd
game/scripts/player/player_state_machine.gd    # later

game/scripts/companions/companion_controller.gd
game/scripts/companions/companion_tasks.gd

game/scripts/mobs/mob_controller.gd
game/scripts/mobs/mob_spawner.gd               # later

game/scripts/base/base_core.gd

game/scripts/buildings/building.gd
game/scripts/buildings/wooden_fence.gd         # later

game/scripts/resources/resource_node.gd
game/scripts/resources/resource_definitions.gd # data class

game/scripts/crafting/crafting_recipe.gd       # data class
game/scripts/crafting/crafting_controller.gd   # later

game/scripts/progression/character_stats.gd    # data class

game/scripts/ui/hud.gd
game/scripts/ui/resource_panel.gd              # later

game/scripts/utilities/math_utils.gd           # as needed
```

### Style rules (see `coding-standards.md` for the full list)

- Static typing where it does not fight the language: `func foo(x: int) -> bool:`.
- snake_case for variables, functions, files.
- PascalCase for class names, scene names, custom resource classes.
- Avoid `_process` work unless needed; prefer signals and timers.

## E. Data-driven resources

Custom resource classes act as typed configuration. The recommended
pattern is to declare a `class_name` on a script extending `Resource` and
then create `.tres` instances under `game/resources/`.

### Sketches

```gdscript
# game/scripts/resources/resource_definitions.gd
class_name ResourceDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export var description: String
@export var icon: Texture2D
@export var rarity: int = 1
@export var max_stack: int = 99
```

```gdscript
# game/scripts/buildings/building_definition.gd
class_name BuildingDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export var scene: PackedScene
@export var cost: Dictionary  # { "wood": 2, "fiber": 1 } keyed by ResourceDefinition.id
@export var max_hp: int = 50
```

```gdscript
# game/scripts/crafting/crafting_recipe.gd
class_name CraftingRecipe
extends Resource

@export var id: StringName
@export var display_name: String
@export var inputs: Dictionary
@export var output_id: StringName
@export var output_count: int = 1
@export var craft_time_seconds: float = 1.0
@export var xp_award: int = 5
```

```gdscript
# game/scripts/mobs/mob_definition.gd
class_name MobDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export var scene: PackedScene
@export var max_hp: int = 10
@export var move_speed: float = 3.0
@export var attack_damage: int = 2
@export var xp_reward: int = 5
@export var resource_drops: Dictionary
```

```gdscript
# game/scripts/progression/character_stats.gd
class_name CharacterStatsDefinition
extends Resource

@export var base_health: int = 50
@export var base_attack: int = 5
@export var base_move_speed: float = 4.0
@export var xp_table: PackedInt32Array  # threshold per level
```

For Phase 0 **only the script declarations are introduced as stubs** if
needed at all. The actual `.tres` assets are created in later phases as
features are built.

## F. Event / signal architecture

Signals are the default cross-system communication channel. Direct method
calls on autoloads are fine for actions (&ldquo;spend 5 wood&rdquo;);
state changes are announced via signals.

Initial signal vocabulary (declared on the relevant autoload or scene):

| Signal name              | Emitted by           | Payload (suggested)              |
|--------------------------|----------------------|-----------------------------------|
| `resource_changed`       | `ResourceManager`    | `(id: StringName, new_value: int)`|
| `day_started`            | `TimeManager`        | `(day_number: int)`               |
| `night_started`          | `TimeManager`        | `(day_number: int)`               |
| `sunset_warning`         | `TimeManager`        | `(seconds_until_night: float)`    |
| `base_damaged`           | `BaseCore`           | `(new_hp: int)`                   |
| `building_placed`        | `BuildManager`       | `(building_node: Node3D)`         |
| `mob_spawned`            | `MobSpawner`         | `(mob_node: Node3D)`              |
| `mob_defeated`           | `MobController`      | `(mob_node: Node3D)`              |
| `xp_gained`              | `ProgressionManager` | `(character: Node, amount: int)`  |
| `level_up`               | `ProgressionManager` | `(character: Node, new_level: int)`|
| `companion_task_changed` | `CompanionController`| `(companion: Node, task: int)`    |

Signal names use snake_case and are documented in the script that emits
them.

## G. State machines

Use simple, explicit states. A `State` enum + a `current_state` variable +
a `match` block in `_physics_process` covers the prototype. We do not need
a node-based state machine framework yet.

### Player states

```
idle
moving
gathering
building
attacking
```

### Companion states

```
idle
following
gathering
guarding
repairing
supporting
```

### Mob states

```
spawning
moving_to_target
attacking
dying
```

### Game time states

```
day
sunset
night
dawn
```

Each transition is a single function call (`_change_state(NEW_STATE)`)
that runs an exit hook for the old state, sets `current_state`, then runs
an enter hook for the new state. No framework needed.

## H. Save / load architecture (forward-looking)

Not implemented in Phase 0. Planned shape:

- A `SaveManager` autoload owns a versioned save schema.
- Game state is captured into a plain `Dictionary` that can be turned into
  JSON.
- Placed buildings are saved as `(building_id, position, rotation, hp)`
  tuples, not as scene references.
- On load, the world is wiped and rebuilt from the dictionary using
  `BuildingDefinition` lookups.
- Player and companion state is saved similarly.
- `schema_version` lets future versions migrate old saves.

## I. Testing strategy

Detailed plan in
[`docs/testing/test-strategy.md`](../testing/test-strategy.md). Summary:

- Most early testing is manual smoke testing: open the project, run the
  main scene, verify the checklist.
- Per-phase manual playtest checklists live alongside each `.features/`
  folder&rsquo;s `test-plan.md`.
- Data validation checks ensure required `.tres` files have valid IDs and
  references (later).
- Script-level tests (e.g. via [GUT](https://github.com/bitwes/Gut)) are
  introduced when systems stabilize. Not in Phase 0.

## J. Performance guardrails

- Keep mob counts in tens, not thousands, until profiled.
- Pool mobs when wave counts climb (later phase).
- Avoid per-frame allocations in hot paths (mob `_physics_process`).
- Avoid `find_node` / dynamic path resolution in hot loops.
- Use `@onready` references and exported scene references instead.
- If GDScript becomes a real bottleneck, move the offending subsystem
  behind a service interface so it can be replaced with `GDExtension` (C++)
  later without rewriting game logic.

## K. Folder ownership cheat sheet

| Path                          | Owner concept                                  |
|-------------------------------|-------------------------------------------------|
| `game/scenes/main/`           | App entry point.                                |
| `game/scenes/world/`          | World / map content.                            |
| `game/scenes/player/`         | Player scenes.                                  |
| `game/scenes/companions/`     | Companion scenes.                               |
| `game/scenes/mobs/`           | Mob scenes.                                     |
| `game/scenes/base/`           | Base core / campsite hub scenes.                |
| `game/scenes/buildings/`      | Buildable structures.                           |
| `game/scenes/resources/`      | Resource nodes in world.                        |
| `game/scenes/ui/`             | HUD, menus, overlays.                           |
| `game/scripts/core/`          | Autoloads and global services.                  |
| `game/scripts/game_loop/`     | Day/night and wave logic.                       |
| `game/scripts/player/`        | Player behavior.                                |
| `game/scripts/companions/`    | Companion behavior and task system.             |
| `game/scripts/mobs/`          | Mob behavior and spawner.                       |
| `game/scripts/base/`          | Base core, base health.                         |
| `game/scripts/buildings/`     | Building behavior and definitions.              |
| `game/scripts/resources/`     | Gathering and resource definitions.             |
| `game/scripts/crafting/`      | Recipes and crafting flow.                      |
| `game/scripts/progression/`   | XP, levels, character stats.                    |
| `game/scripts/ui/`            | UI controllers.                                 |
| `game/scripts/save/`          | Save / load.                                    |
| `game/scripts/utilities/`     | Math, helpers, reusable bits.                   |
| `game/resources/`             | Data-driven `.tres` content.                    |
| `game/assets/placeholder/`    | Throwaway placeholder art / audio.              |
