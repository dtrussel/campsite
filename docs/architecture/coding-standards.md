# Coding standards

> Applies to all GDScript code, scene files, and `.tres` data in this
> repository. Companion to
> [`software-architecture.md`](software-architecture.md).

## Language and typing

- **GDScript only.** No C# unless re-discussed in a new ADR.
- **Use static typing wherever practical.** Examples:
  ```gdscript
  var hp: int = 50
  var move_speed: float = 4.0
  func take_damage(amount: int) -> void:
      hp -= amount
  ```
  Static types help the editor, the agents, and the next reader.
- Use untyped variables only when the type is genuinely dynamic and the
  cost of typing exceeds the benefit (e.g. interop with engine APIs that
  return `Variant`).

## Naming

- **snake_case** for: files, directories, variables, function names,
  signal names, autoload script names.
- **PascalCase** for: scene files (`PlayerBoy.tscn`), `class_name`
  declarations, custom resource classes (`ResourceDefinition`),
  autoload *node* names registered in `project.godot`.
- **SCREAMING_SNAKE_CASE** for: constants and enum entries.
- Prefer **clear, longer names** over short ones. `gather_speed` beats
  `gs`. `current_state` beats `cs`.
- Boolean variables should read as questions: `is_attacking`, `has_target`,
  `can_repair`.

## File and folder organization

- One responsibility per script. Long scripts are a smell; split when the
  file approaches a few hundred lines or covers more than one concern.
- Each scene&rsquo;s primary behavior script lives in a matching folder
  under `game/scripts/`. Example:
  - `game/scenes/mobs/ShadowImp.tscn`
  - `game/scripts/mobs/mob_controller.gd`
- Helper scripts that are not attached to a scene go to
  `game/scripts/utilities/` unless they belong to a clear subsystem
  folder.

## Scene and node design

- Scene roots own a script that controls the scene&rsquo;s behavior.
- Use `@export` for any value a designer / agent might want to tweak from
  the editor.
- Avoid `get_node("../../Foo")` paths. Use `@onready` references with
  exported node paths or use `find_child` only as a fallback in tooling.
- Avoid `_process` work unless something genuinely needs to run every
  frame. Prefer signals, `Timer` nodes, and physics step.
- Use `@onready` variables to cache child node references:
  ```gdscript
  @onready var mesh: MeshInstance3D = $Mesh
  @onready var collision: CollisionShape3D = $Collision
  ```

## Signals and decoupling

- Use **signals** for state announcements and cross-system events.
- Use direct method calls on autoloads for **actions** (e.g.
  `ResourceManager.spend({"wood": 2})`).
- Signal names are snake_case, past tense or descriptive:
  `building_placed`, `night_started`, `xp_gained`.
- Document each signal with a one-line comment above the declaration:
  ```gdscript
  ## Emitted when a player gathers enough XP to reach a new level.
  signal level_up(character: Node, new_level: int)
  ```

## Inheritance vs composition

- **Avoid deep inheritance trees.** Two levels deep is usually enough.
- Prefer composition: a mob has-a `HealthComponent` rather than extending
  some `Damageable` base class.
- Common interfaces are encoded with **duck typing on signals and methods**,
  not abstract base classes.

## Data-driven design

- **No hardcoded gameplay numbers in behavior scripts.** Move them to
  `@export` properties or to `.tres` resource definitions.
- Example acceptable:
  ```gdscript
  @export var max_hp: int = 50
  ```
- Example unacceptable inside `mob_controller.gd`:
  ```gdscript
  if hp <= 0:
      pass
  func _ready():
      hp = 17  # magic
  ```
- Game balance lives in `game/resources/` and is reviewed separately from
  code changes.

## Comments

- Default to **no comments**. Names should carry meaning.
- Write a comment when it explains **why**, not **what**:
  - &ldquo;Sunset warning fires 10s before night to give the player time
    to retreat.&rdquo;
  - &ldquo;Mob navigation re-paths every 0.5s instead of every frame to
    keep frame time stable.&rdquo;
- Multi-paragraph docstrings are not used. One-line `##` above a public
  method is fine when the contract is non-obvious.
- Do **not** add comments that reference task IDs, PRs, or commit
  history. Those belong in the commit log.

## Error handling

- Trust internal code and engine guarantees.
- Validate only at boundaries: user input, save/load, file I/O,
  data-resource lookups that could miss.
- Use `assert` for invariants in development; the editor will catch
  failures.

## Placeholder content

- Placeholder code, art, and audio belongs in `game/assets/placeholder/`
  or is clearly named with a `placeholder_` prefix.
- Keep placeholder code **simple and easy to delete**. Do not build
  abstractions on top of it.

## Documentation discipline

- When architecture changes, update
  [`software-architecture.md`](software-architecture.md) and add an ADR if
  the change is significant.
- When a system&rsquo;s public API changes, update the matching design
  section and any `.features/*/handoff.md` notes.
- When a new resource type, mob type, or building type is added, update
  the design spec and the relevant `.tres` files.

## Performance discipline

- Keep `_process` and `_physics_process` light.
- Avoid creating `Dictionary`, `Array`, or `Node` instances per frame in
  hot paths.
- Reuse arrays; clear them instead of reallocating.
- Don&rsquo;t profile prematurely. Don&rsquo;t skip profiling forever.

## Git hygiene

- One logical change per commit when reasonable.
- Commit messages: short imperative summary, optional body.
- The branch for the bootstrap feature is `claude/bootstrap-godot-game-TEdp5`.
- Feature branches generally follow `feature/<id>-<slug>` or
  `agent/<short-name>`.
