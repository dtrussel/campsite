# Software Architecture Specification

**Project:** Campsite Chronicles
**Version:** 0.1 (Bootstrap)
**Date:** 2026-05-16
**Engine:** Godot 4.x + GDScript

---

## Guiding Principles

- Prefer Godot-native patterns over custom frameworks.
- Keep scripts small, focused, and easy to delete or replace.
- Use signals for cross-system communication.
- Avoid deep inheritance; prefer composition where possible.
- Use Resource files for game data (buildings, mobs, recipes, items).
- Autoload singletons only for truly global services.
- Keep state explicit; avoid implicit global mutation.
- Design for future coding agents: readable names, clear responsibilities.

---

## A. Layer Overview

```
┌────────────────────────────────────────────────────────────┐
│  Presentation / Scene Layer                                │
│  Godot scenes, nodes, animations, meshes, UI, particles    │
├────────────────────────────────────────────────────────────┤
│  Gameplay Logic Layer                                      │
│  Player movement, companion behavior, mob AI,              │
│  gathering, building placement, combat, crafting           │
├────────────────────────────────────────────────────────────┤
│  Game State Layer (Autoloads)                              │
│  Current day, time, resource inventory, base health,       │
│  character progression, wave state                         │
├────────────────────────────────────────────────────────────┤
│  Data Layer (Resource files)                               │
│  ResourceDefinition, BuildingDefinition, CraftingRecipe,   │
│  MobDefinition, CharacterStatsDefinition                   │
├────────────────────────────────────────────────────────────┤
│  Persistence Layer                                         │
│  Save/load game state, versioned data, no raw node refs    │
└────────────────────────────────────────────────────────────┘
```

Each layer only depends on layers below it. Gameplay Logic reads Data Layer resources; it uses Autoloads via signals or method calls; it does not depend on the Presentation Layer directly.

---

## B. Autoload Singletons

Autoloads are registered in `project.godot`. Only use autoloads for services that genuinely must be globally accessible.

### GameManager (`scripts/core/game_manager.gd`)
**Responsibility:** Owns top-level game state. Coordinates phase transitions.

```gdscript
# Key state:
var current_day: int
var game_phase: GamePhase  # DAY, SUNSET, NIGHT, DAWN

# Key signals:
signal game_phase_changed(new_phase: GamePhase)

# Key methods:
func start_new_day() -> void
func trigger_sunset() -> void
func trigger_night() -> void
func trigger_dawn() -> void
func handle_game_over() -> void
```

### TimeManager (`scripts/game_loop/time_manager.gd`)
**Responsibility:** Advances time of day. Emits phase transition signals. Drives GameManager transitions.

```gdscript
# Key state:
var time_of_day: float       # 0.0 = midnight, 0.5 = noon, 1.0 = midnight again
var day_duration_seconds: float = 300.0  # 5 minutes per full day by default

# Key signals:
signal day_started
signal sunset_warning(seconds_remaining: float)
signal night_started
signal dawn_started
signal time_updated(normalized_time: float)
```

### ResourceManager (`scripts/core/resource_manager.gd`)
**Responsibility:** Single source of truth for global resource inventory. No resources are stored on scene nodes.

```gdscript
# Key state:
var inventory: Dictionary  # resource_id (String) -> amount (int)

# Key signals:
signal resource_changed(resource_id: String, new_amount: int)

# Key methods:
func add(resource_id: String, amount: int) -> void
func remove(resource_id: String, amount: int) -> bool  # returns false if insufficient
func has_amount(resource_id: String, amount: int) -> bool
func get_amount(resource_id: String) -> int
func can_afford(costs: Dictionary) -> bool  # costs = {resource_id: amount}
func spend(costs: Dictionary) -> bool       # returns false if cannot afford
```

### BuildManager (`scripts/core/build_manager.gd`)
**Responsibility:** Handles build mode state. Validates and executes building placement.

```gdscript
# Key state:
var in_build_mode: bool
var selected_building_def: BuildingDefinition
var placement_ghost: Node3D

# Key signals:
signal build_mode_entered(building_def: BuildingDefinition)
signal build_mode_exited
signal building_placed(building_def: BuildingDefinition, position: Vector3)

# Key methods:
func enter_build_mode(building_def: BuildingDefinition) -> void
func exit_build_mode() -> void
func try_place_at(world_position: Vector3) -> bool
func is_valid_placement(world_position: Vector3) -> bool
```

### ProgressionManager (`scripts/core/progression_manager.gd`)
**Responsibility:** Tracks XP and levels for all characters. Fires level-up events.

```gdscript
# Key signals:
signal xp_gained(character_id: String, amount: int, new_total: int)
signal level_up(character_id: String, new_level: int)

# Key methods:
func award_xp(character_id: String, amount: int) -> void
func get_level(character_id: String) -> int
func get_xp(character_id: String) -> int
func get_xp_to_next_level(character_id: String) -> int
```

### SaveManager (`scripts/save/save_manager.gd`)
**Responsibility:** Serializes and deserializes save data.

```gdscript
# Key methods:
func save_game(slot: int = 0) -> void
func load_game(slot: int = 0) -> bool
func has_save(slot: int = 0) -> bool

# Save data format: Dictionary → JSON file on disk
# Versioned with a "save_version" key for forward compatibility
```

---

## C. Scene Conventions

### Scene Hierarchy

```
Main.tscn
├── World/
│   └── TestWorld.tscn (instanced)
│       ├── Terrain (MeshInstance3D or CSGBox3D placeholder)
│       ├── ResourceNodes/
│       │   ├── WoodNode x3
│       │   ├── StoneNode x2
│       │   └── BerryBush x2
│       ├── SpawnPoints/ (empty Node3D markers at map edges)
│       └── Buildings/ (dynamic — populated at runtime)
├── Characters/
│   ├── PlayerBoy.tscn (instanced)
│   └── Companions/ (instanced at runtime or pre-placed)
├── Mobs/ (instanced at runtime during night)
├── Camera3D (or CameraRig)
└── HUD.tscn (instanced, on CanvasLayer)
```

### Scene File Locations

| Scene | Path |
|-------|------|
| Main | `scenes/main/Main.tscn` |
| Test World | `scenes/world/TestWorld.tscn` |
| Player Boy | `scenes/player/PlayerBoy.tscn` |
| Companion (base) | `scenes/companions/Companion.tscn` |
| Shadow Imp | `scenes/mobs/ShadowImp.tscn` |
| Campfire Core | `scenes/base/CampfireCore.tscn` |
| Wooden Fence | `scenes/buildings/WoodenFence.tscn` |
| Watch Post | `scenes/buildings/WatchPost.tscn` |
| HUD | `scenes/ui/HUD.tscn` |
| Resource Node | `scenes/resources/ResourceNode.tscn` |

---

## D. Script Conventions

### Script File Locations

| Script | Path | Attached To |
|--------|------|-------------|
| game_manager.gd | `scripts/core/game_manager.gd` | Autoload |
| resource_manager.gd | `scripts/core/resource_manager.gd` | Autoload |
| build_manager.gd | `scripts/core/build_manager.gd` | Autoload |
| progression_manager.gd | `scripts/core/progression_manager.gd` | Autoload |
| save_manager.gd | `scripts/save/save_manager.gd` | Autoload |
| time_manager.gd | `scripts/game_loop/time_manager.gd` | Autoload |
| player_controller.gd | `scripts/player/player_controller.gd` | PlayerBoy root node |
| companion_controller.gd | `scripts/companions/companion_controller.gd` | Companion root node |
| mob_controller.gd | `scripts/mobs/mob_controller.gd` | Mob root node |
| base_core.gd | `scripts/base/base_core.gd` | CampfireCore root node |
| building.gd | `scripts/buildings/building.gd` | Building root node (base class) |
| resource_node.gd | `scripts/resources/resource_node.gd` | ResourceNode root node |
| hud_controller.gd | `scripts/ui/hud_controller.gd` | HUD root node |
| wave_manager.gd | `scripts/game_loop/wave_manager.gd` | Node in Main or World |

---

## E. Data-Driven Resources

All game balance values live in Godot `.tres` resource files, not in scripts. Scripts load and read these; they do not hardcode values.

### Resource Class Definitions

#### ResourceDefinition (`scripts/core/resource_definition.gd`)
```gdscript
class_name ResourceDefinition
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var icon: Texture2D
@export var rarity: int = 0  # 0=common, 1=uncommon, 2=rare
@export var max_stack: int = 999
```

#### BuildingDefinition (`scripts/buildings/building_definition.gd`)
```gdscript
class_name BuildingDefinition
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var scene: PackedScene
@export var cost: Dictionary = {}  # {resource_id: amount}
@export var max_health: int = 100
@export var description: String = ""
```

#### CraftingRecipe (`scripts/crafting/crafting_recipe.gd`)
```gdscript
class_name CraftingRecipe
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var ingredients: Dictionary = {}  # {resource_id: amount}
@export var output_building: BuildingDefinition  # if it places a building
@export var output_item: String = ""             # future: item id
@export var xp_reward: int = 0
```

#### MobDefinition (`scripts/mobs/mob_definition.gd`)
```gdscript
class_name MobDefinition
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var scene: PackedScene
@export var max_health: int = 30
@export var move_speed: float = 3.5
@export var attack_power: int = 5
@export var attack_rate: float = 1.5
@export var xp_reward: int = 10
@export var loot_table: Dictionary = {}  # {resource_id: drop_chance}
```

#### CharacterStatsDefinition (`scripts/progression/character_stats_definition.gd`)
```gdscript
class_name CharacterStatsDefinition
extends Resource

@export var character_id: String = ""
@export var base_health: int = 80
@export var base_stamina: int = 100
@export var base_courage: int = 10
@export var base_build_speed: float = 1.0
@export var base_gather_speed: float = 1.0
@export var base_attack_power: int = 8
@export var base_crafting_skill: int = 1
@export var xp_thresholds: Array[int] = [0, 100, 250, 500, 900]
```

---

## F. Signal Architecture

Signals are the primary mechanism for cross-system communication. No direct method calls from one manager to another where a signal is sufficient.

### Global Signals (on Autoloads)

| Signal | Source | Listeners |
|--------|--------|-----------|
| `resource_changed(id, amount)` | ResourceManager | HUD, BuildManager |
| `day_started` | TimeManager | GameManager, WaveManager, HUD |
| `sunset_warning(seconds)` | TimeManager | HUD, GameManager |
| `night_started` | TimeManager | GameManager, WaveManager, HUD |
| `dawn_started` | TimeManager | GameManager, WaveManager, HUD |
| `game_phase_changed(phase)` | GameManager | World environment, HUD |
| `building_placed(def, pos)` | BuildManager | ProgressionManager, HUD |
| `xp_gained(char_id, amount, total)` | ProgressionManager | HUD, Character |
| `level_up(char_id, level)` | ProgressionManager | HUD, Character |

### Local Signals (on Scene Nodes)

| Signal | Source | Listeners |
|--------|--------|-----------|
| `mob_defeated(mob_def)` | MobController | WaveManager, ProgressionManager |
| `base_damaged(amount, new_health)` | BaseCoreController | HUD, GameManager |
| `resource_gathered(resource_id, amount)` | ResourceNode | ResourceManager |
| `companion_task_changed(task)` | CompanionController | HUD |
| `building_damaged(amount, new_health)` | Building | HUD (optional) |
| `player_health_changed(new_health)` | PlayerController | HUD |

---

## G. State Machines

Each entity with complex behavior uses a simple explicit state enum + `_update_state()` pattern. No external state machine plugin required.

### Player States
```gdscript
enum PlayerState { IDLE, MOVING, GATHERING, BUILDING, ATTACKING, INCAPACITATED }
```

### Companion States
```gdscript
enum CompanionState { IDLE, FOLLOWING, GATHERING, GUARDING, REPAIRING, CRAFTING, SCOUTING, SUPPORTING }
```

### Mob States
```gdscript
enum MobState { SPAWNING, MOVING_TO_TARGET, ATTACKING, DYING }
```

### Game Time States
```gdscript
enum GamePhase { DAY, SUNSET, NIGHT, DAWN }
```

### State Machine Pattern (example)
```gdscript
var state: PlayerState = PlayerState.IDLE

func _physics_process(delta: float) -> void:
    match state:
        PlayerState.IDLE:      _state_idle(delta)
        PlayerState.MOVING:    _state_moving(delta)
        PlayerState.GATHERING: _state_gathering(delta)
        # ...

func _transition_to(new_state: PlayerState) -> void:
    state = new_state
    # Optional: emit signal or play animation
```

---

## H. Directory Structure Summary

```
game/
├── project.godot
├── scenes/
│   ├── main/Main.tscn
│   ├── world/TestWorld.tscn
│   ├── player/PlayerBoy.tscn
│   ├── companions/Companion.tscn
│   ├── mobs/ShadowImp.tscn
│   ├── base/CampfireCore.tscn
│   ├── buildings/WoodenFence.tscn, WatchPost.tscn
│   ├── resources/ResourceNode.tscn
│   └── ui/HUD.tscn
├── scripts/
│   ├── core/game_manager.gd, resource_manager.gd, build_manager.gd,
│   │        progression_manager.gd, resource_definition.gd
│   ├── game_loop/time_manager.gd, wave_manager.gd
│   ├── player/player_controller.gd
│   ├── companions/companion_controller.gd
│   ├── mobs/mob_controller.gd, mob_definition.gd
│   ├── base/base_core.gd
│   ├── buildings/building.gd, building_definition.gd
│   ├── resources/resource_node.gd
│   ├── crafting/crafting_recipe.gd, crafting_manager.gd
│   ├── progression/character_stats_definition.gd
│   ├── ui/hud_controller.gd
│   └── save/save_manager.gd
├── assets/
│   ├── placeholder/  (temporary geometry and textures)
│   ├── art/
│   ├── audio/
│   ├── materials/
│   └── fonts/
└── resources/
    ├── game_data/  (ResourceDefinition .tres files)
    ├── buildings/  (BuildingDefinition .tres files)
    ├── items/
    ├── mobs/       (MobDefinition .tres files)
    └── companions/ (CharacterStatsDefinition .tres files)
```

---

## I. Key Architectural Decisions and Rationale

| Decision | Rationale |
|----------|-----------|
| Autoloads only for global services | Prevents coupling; keeps scene graphs clean |
| Signals for cross-system comms | Loose coupling; easy to add/remove listeners |
| Resource files for game data | Data-driven; editable in Godot inspector; no recompile |
| Simple state enums (not plugin) | Readable, agent-friendly, no external dependency |
| Single global resource inventory | Avoids per-character inventory sync complexity in prototype |
| No raw node references in save data | Prevents serialization bugs and scene-coupling |
| Static typing in GDScript | Catches errors early; improves editor hints; aids agents |

---

## J. Future Architecture Considerations

These are not to be implemented now, but should inform decisions made during the prototype:

- **Object pooling for mobs:** If more than ~50 mobs are active, instantiation/deletion overhead becomes measurable. A simple pool in WaveManager can address this.
- **Navigation mesh:** Simple direct movement works for prototype. Godot's NavigationServer3D should be added in Phase 5 for mobs to path around buildings.
- **Companion path following:** Use NavigationAgent3D in companion scene when proper pathfinding is needed.
- **Modular building data:** BuildingDefinition `.tres` files make it easy to add new building types without code changes.
- **Save data versioning:** Add a `"save_version": 1` key from day one so future migration functions can handle old saves.
- **Multiplayer:** Current architecture (manager autoloads, signal-driven state) is compatible with future network sync, but would require significant additional work. Not in scope.
