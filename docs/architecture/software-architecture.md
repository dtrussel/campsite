# Software architecture specification

> Engine: Godot 4.x. Language: GDScript with static typing wherever
> practical. See
> [`docs/adr/0001-engine-and-language-selection.md`](../adr/0001-engine-and-language-selection.md).

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

- Every module that holds run state is a **saving system**: it saves,
  loads and resets its own state. The **run session**
  (`game/scripts/core/run_session.gd`) walks them; the save manager
  (`game/scripts/core/save_manager.gd`) only handles the file.
- Versioned save data with a schema version number.
- Saves plain data (ids, positions, HP, progress), *not* raw scene
  references; spawned objects are rebuilt by their own module.
- See section H for the interface and the restore order.

## B. Proposed autoloads

Each autoload is a single small node script registered in
`game/project.godot` under `[autoload]`. Initial autoloads:

| Autoload             | Role                                                        |
|----------------------|-------------------------------------------------------------|
| `GameManager`        | High-level game state; coordinates day/night transitions.   |
| `TimeManager`        | Drives the day/night cycle and emits time-of-day signals.   |
| `ResourceManager`    | Tracks resource inventory; validates costs; adds/removes.   |
| `BuildManager`       | Handles build mode, placement validation, blueprint spawn and completion. |
| `ProgressionManager` | Handles XP totals and level-up rules.                       |
| `PerkManager`        | Perk cards: deals cards on level-up, opens the picker, answers perk hooks. |
| `SaveManager`        | The save file only: path, version, JSON read and write, parse checks, delete. |
| `RunSession`         | One run's lifecycle: start, continue, reset, the dawn autosave, `restore_finished` (see H). |
| `Profile`            | Keeps a player's progress across runs (see "Profile" under H). |

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
game/scripts/core/save_manager.gd
game/scripts/core/run_session.gd

game/scripts/game_loop/wave_controller.gd      # later

game/scripts/characters/hero.gd               # Hero: what both heroes do in either role
game/scripts/characters/hero_hits.gd           # the perk math under every hero hit
game/scripts/characters/party.gd               # Party: who plays which role

game/scripts/player/player_controller.gd       # the player's hero role (extends Hero)
game/scripts/player/pointer_commands.gd

game/scripts/companions/companion_controller.gd  # the companion role (Companion, extends Hero)

game/scripts/mobs/mob_controller.gd
game/scripts/mobs/mob_spawner.gd
game/scripts/mobs/boss_controller.gd           # the Moon-Eater (038), extends Mob
game/scripts/mobs/moon_eater_visual.gd         # its model (assets/custom/moon_eater.glb) and tween clips
game/scripts/mobs/telegraph.gd                 # ground warnings for big blows

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

### Heroes: the Hero module, the two roles and Party

Leo and Nela are each played in one of two **roles** (see `GLOSSARY.md`).
Everything a hero does whichever role it plays lives in one base class,
`Hero` (`game/scripts/characters/hero.gd`, extends `CharacterBody3D`). The
two role scripts extend it and keep only what differs. Outside code talks
to a hero through the Hero interface, never through a role's private
fields.

- **Health:** `take_damage(amount, source)`, `heal(amount)`, `is_down()`,
  `revive(hp)`, `max_hp` / `current_hp`, `is_invulnerable()`,
  `clear_invulnerability()` and `health_bar()`. Regen and the
  invulnerability window run inside. Signals: `health_changed(hp, max)`
  and `down_changed(is_down)` (the only "downed" signal).
- **Attack:** `attack(target)`, `get_attack_damage()`,
  `get_attack_range()` (reach, after perks), `is_attack_ready()`,
  `is_attacking()`, `get_attack_cooldown_ratio()`, `apply_signature()`
  and the `attacked` signal. Hero owns the cooldown and the melee vs
  pebble branch; the perk effects come from `HeroHits` underneath.
  `tool_tier` and `on_attack_hit(target, damage)` are the (unused) slots
  for tool tiers. The definition's `companion_` reach, cooldown and
  signature factor are read for the companion role.
- **Progress:** each role calls `_setup_progress()` once; on
  ProgressionManager's raw `level_up`, Hero applies the stat bumps and
  then emits `leveled(level)`. PerkManager listens to `leveled`
  (`PerkManager.watch(hero)`), so the picker opens after the new HP shows,
  whatever order the autoloads connected in.
- **Gathering and queries:** `start_gather(node)`, `cancel_gather()`,
  `is_gathering()`, `gather_target()`, the `gather_finished(node)` signal,
  and `nearest_mob(within)`. The node-radius fallback is 0.4.
- **Role hooks** (the role overrides them): `_show_hurt`,
  `_on_down_changed`, `_show_attack`, `_swing`, `_show_level_up` and
  `_on_gather_started`.

**The player's hero** (`player_controller.gd`) adds input, the pointer
commands (`command_move/attack/gather/campfire/repair/build`,
`stop_commands()`, `has_command()`, `is_building()`), the hit feel (the
wind-up, the x1.4 range re-check and the hit-stop), the build and repair
ticks, auto-attack and the hero's actions (`try_place_torch()`,
`try_eat_berries()`, `try_use_bandage()`, `try_feed_lantern()`). When it
is down, GameManager ends the run.

**The companion** (`Companion`, `companion_controller.gd`) adds the task
AI (`set_task(Companion.Task.…)`), the repair and build ticks with its own
constants, the stuck watchdog and the quick sparkle hit. When it is down,
it revives at dawn.

**Party** (`game/scripts/characters/party.gd`, static) answers who is who
in the running camp: `Party.player_hero()`, `Party.companion()`,
`Party.other(hero)`, `Party.heroes()` and `Party.role_of(hero)`
(`Party.PLAYER`, `Party.COMPANION` or `&""`). Use it instead of the
`"player"` / `"companions"` group names; the older group lookups move to
it as they are touched.

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
@export var cost: Dictionary  # { "wood": 4, "stone": 2 } keyed by ResourceDefinition.id
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

```gdscript
# game/scripts/progression/perk_definition.gd (feature 039; data in
# game/resources/perks/*.tres, dealt and applied by PerkManager)
class_name PerkDefinition
extends Resource

@export var id: StringName
@export var pool: StringName         # shared, leo, nela or sibling
@export var effect_kind: StringName  # stat_mult, flag or on_hit
@export var stat: StringName         # for stat_mult (one of STATS)
@export var value: float
@export var stacks: bool = false
@export var player_only: bool = false  # never dealt to the companion
```

Perk effects are read where they apply, through `PerkManager`
(`multiplier(character, stat)`, `has_flag(...)`, `flag_count(...)`,
`on_hit_perks(...)`),
and every hero hit and damage taken goes through `HeroHits`
(`game/scripts/characters/hero_hits.gd`).

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
| `building_placed`        | `BuildManager`       | `(building_node: Node3D)` (a blueprint since 044) |
| `building_completed`     | `BuildManager`       | `(building_node: Node3D)`         |
| `mob_spawned`            | `MobSpawner`         | `(mob_node: Node3D)`              |
| `mob_defeated`           | `MobController`      | `(mob_node: Node3D)`              |
| `xp_gained`              | `ProgressionManager` | `(character: Node, amount: int)`  |
| `level_up`               | `ProgressionManager` | `(character: Node, new_level: int)`|
| `perk_taken`             | `PerkManager`        | `(character: Node, perk: PerkDefinition)`|
| `companion_task_changed` | `CompanionController`| `(companion: Node, task: int)`    |
| `health_changed`         | `Hero`               | `(current_hp: int, max_hp: int)`  |
| `down_changed`           | `Hero`               | `(is_down: bool)`                 |
| `leveled`                | `Hero`               | `(level: int)`, after the stat bumps |
| `gather_finished`        | `Hero`               | `(node: ResourceNode)`            |

Signal names use snake_case and are documented in the script that emits
them.

## G. State machines

Use simple, explicit states. A `State` enum + a `current_state` variable +
a `match` block in `_physics_process` covers the prototype. We do not need
a node-based state machine framework yet.

### Player states

The player's hero has no state enum: it has a pointer **command**
(`NONE`, `MOVE`, `ATTACK`, `GATHER`, `CAMPFIRE`, `REPAIR`, `BUILD`) and,
apart from it, Hero's gathering and down flags. Outside code asks through
`has_command()`, `is_attacking()`, `is_building()`, `is_gathering()` and
`is_down()`, never by the command's number. Its `is_attacking()` is
Hero's (the cooldown after an attack) or an attack command.

### Companion states

The companion's states are its tasks, `Companion.Task`: `IDLE`,
`FOLLOW_PLAYER`, `GUARD_BASE`, `GATHER_NEAREST` and `REPAIR` (which builds
blueprints too). Set them by name (`set_task(Companion.Task.GUARD_BASE)`),
never by number.

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

## H. Save / load architecture

The run save (`user://save.json`) holds one run in progress. It is
written at every dawn and offered as Continue on the title screen; a won
or lost run deletes it, and a new run replaces it. Built by the run
lifecycle spec (`.scratch/run-lifecycle/`).

### Saving systems

A **saving system** is any module that holds run state. It has three
methods:

- `save_state() -> Dictionary`: its own keys, at their place in the
  save file;
- `load_state(data: Dictionary)`: takes the whole save, reads its own
  keys and tolerates missing ones (an older save gets fresh values);
- `reset()`: back to a fresh run.

The saving systems, and what each saves:

| Saving system | Saves |
|---------------|-------|
| `TimeManager` | `"day"` |
| `GameManager` (the run fields) | `"nights_to_win"`, `"party"`, `"stats"`, `"loot_misses"` (the shard pity counter) |
| `ResourceManager` | `"inventory"` |
| `ProgressionManager` | each hero's `"xp"` |
| `PerkManager` | each hero's `"perks"`; the reset zeroes the perk clock and reshuffles the deal |
| `CraftingManager` | nothing; the reset clears the craft in progress |
| `BaseCore` (the campfire) | `"campfire"`: HP and hearth |
| `BuildingSaves` | `"buildings"`: each building or blueprint's type, place, HP, construction progress and paid cost (`Building.save_entry` / `Building.rebuild`) |
| `TorchSaves` | `"torches"`: the Ember Heart torches still burning, with their dawns left and radius (`Torch.save_entry` / `Torch.rebuild`) |
| `MoonLantern` | `"lantern"`: its shards |
| `Hero` (both heroes) | each hero's `"signature"` tool; the companion also saves its `"task"`. The reset restores the base stats, gets a downed hero up without `down_changed`, and registers it with ProgressionManager again |

- **Hero entries are shared.** A hero's keys sit under `"player"` and
  `"sibling"` (`Party.SAVE_KEYS`), and several systems write there.
  `RunSession.merge_state` merges them key by key.
- **Spawned objects are rebuilt by their own module.** Buildings,
  blueprints and torches are listed by `BuildingSaves` / `TorchSaves`,
  which own their legacy fallbacks: a missing `"paid"` in
  `Building.rebuild`, and the old `"stick"` / `"slingshot"` signature
  names in `Hero.LEGACY_SIGNATURE_KEYS`. The old party-less saves are
  Leo with Nela (`GameManager.party_of`). An entry missing its
  position is skipped.
- **Objects refresh themselves.** Each one refreshes its own HP bar after
  it loads; nothing outside calls a private refresh or reads a meta.
- **Not saved:** resource nodes and pickups (they reset), plain torches
  (they burn out at the dawn the save is made on), trap snaps, build
  mode.

A new piece of run state is saved, loaded and reset in the module that
owns it. If that module is not yet a saving system, add it to the
session's list.

### The run session and the run config

`RunSession` (an autoload, last in the list) is the one entry point for
a run's lifecycle:

- `start(config, open_scene)`: resets every saving system, deletes any
  save and opens the gameplay scene, which starts the clock at day 1.
- `continue_from(data, config, open_scene)`: resets, then keeps `data`
  (from `SaveManager.load_save` or `parse`) waiting for the gameplay
  scene. The party and run length come from the save.
- `reset(config)`: every saving system back to a fresh run. It also
  leaves build mode, which is not run state, and applies the config's
  seeds and auto-pick time.
- `snapshot()`: the run as plain data, for the save file. It is `{}`
  when there is no camp to save. `save_now()` writes it.
- `restore_finished`: a continued run is fully back. The perk top-up
  (dealing the cards a level-up still owes) listens here.
  `is_restoring()` is true while the systems load, so replayed level-ups
  skip the fanfare and deal no card.
- **The dawn autosave:** the session saves on `TimeManager.dawn_settled`,
  which fires right after every `dawn_started` handler has run (the win
  check, the companion waking, torches burning out, the night's XP). It
  also deletes the save when a run ends.

A `RunConfig` (`game/scripts/core/run_config.gd`) is what a run starts
from: the hero and companion, the chapter goal (`nights_to_win`), the
seeds of the perk deal and the loot rolls, and the perk auto-pick time.
`RunConfig.current()` gives a config for the next run, with fresh seeds.
A test that passes the same config replays the same deals and drops.

### The restore order

`RunSession.saving_systems()` declares the order, and `restore_pending`
(called by `GameManager.on_game_scene_ready` once the gameplay scene is
up) loads each system in it:

1. `TimeManager`, then `GameManager`'s run fields;
2. `ResourceManager`;
3. `ProgressionManager` (it replays the level-ups quietly);
4. `PerkManager`, then `CraftingManager`;
5. the world: the campfire, the buildings and blueprints, the torches,
   the Moon Lantern;
6. the heroes: the player's hero, then the companion.

Then the clock starts at the morning after the saved day, and
`restore_finished` follows once the scene's `run_started` has gone out.
Nothing depends on the order of autoloads in the project file or on a
deferred call happening to come last.

### The save file

`SaveManager` knows nothing of what is in a run. It holds:

- the path (`set_save_path` lets tests write elsewhere) and `VERSION`
  (2);
- `serialize` and `write`, which stamp the version and write JSON;
- `load_save` and `parse`, which reject a damaged file, another version
  or one missing a required key; Continue is then hidden, never
  half-loaded;
- `delete_save`.

The version changes only when an old save can no longer be read the old
way. Keys added since version 2 are optional, so older saves still load.
`game/tests/fixtures/save_v2_day1.json`, a save from before the run
session, must continue with every field intact (smoke).

### Profile

The run save holds one run; the **profile** holds what a player keeps
across runs (story beats seen, chapters won, records and, later,
badges). It is the `Profile` autoload (`game/scripts/core/profile.gd`)
on its own file, `user://profile.json`, which a run ending never deletes.

- **Interface:** `get_value(key, fallback)`, `set_value(key, value)`
  (saved at once), `has_value`, `record_best(key, value)` (true for a
  new record), `forget(prefix)`, `delete`, `reload`, and
  `set_path(path, old_story_path)` so tests use their own file.
- **Keys:** strings with a dotted owner prefix, such as `story.`,
  `chapters.`, `endless.` and `badges.`; values are JSON-friendly. A
  new kind of progress adds keys rather than a new store.
- **Bad files:** a missing or corrupt file loads as empty and is
  rewritten on the next write.
- **Story beats:** `StoryLibrary.has_seen` / `mark_seen` /
  `forget_progress` read and write `story.<beat>` keys.
- **The old `story.cfg`:** imported once, when a profile that has never
  been created loads. Seen beats are copied, and a seen `intro.c2` or
  `ending.c2` sets `chapters.c2.unlocked`. The import note survives
  `delete`, so it never runs twice; `story.cfg` stays on disk, unused.
- **Not here:** device settings (audio, look, auto-attack) stay in
  `user://settings.cfg`, so deleting a profile never resets them.

## I. Testing strategy

Detailed plan in
[`docs/testing/test-strategy.md`](../testing/test-strategy.md). Summary:

- Most early testing is manual smoke testing: open the project, run the
  main scene, verify the checklist.
- Manual playtest checklists live in the `.scratch/` specs and tickets
  (`ready-for-human` ones for hand play).
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
| `game/scripts/progression/`   | XP, levels, character stats, perk cards.        |
| `game/scripts/ui/`            | UI controllers.                                 |
| `game/scripts/utilities/`     | Math, helpers, reusable bits.                   |
| `game/resources/`             | Data-driven `.tres` content.                    |
| `game/assets/placeholder/`    | Throwaway placeholder art / audio.              |
