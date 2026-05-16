# Coding Standards

**Project:** Campsite Chronicles
**Version:** 0.1
**Date:** 2026-05-16

---

## Language

- All code is written in **GDScript** with static typing enabled where practical.
- Use `class_name` declarations for all custom Resource subclasses and reusable node scripts.
- Avoid C# unless a specific performance bottleneck has been profiled and documented.

---

## Naming Conventions

| Element | Style | Example |
|---------|-------|---------|
| Files (scripts, scenes) | snake_case | `player_controller.gd`, `wooden_fence.tscn` |
| Directories | snake_case | `game_loop/`, `ui/` |
| Variables and function names | snake_case | `current_health`, `get_xp_for_level()` |
| Constants | SCREAMING_SNAKE_CASE | `MAX_LEVEL`, `DEFAULT_GATHER_SPEED` |
| Enums (type name) | PascalCase | `GamePhase`, `PlayerState` |
| Enum values | SCREAMING_SNAKE_CASE | `GamePhase.NIGHT`, `PlayerState.IDLE` |
| Scene root names | PascalCase | `PlayerBoy`, `CampfireCore` |
| Custom Resource class names | PascalCase | `ResourceDefinition`, `MobDefinition` |
| Exported properties | snake_case | `@export var max_health: int = 100` |
| Signals | snake_case past-tense or noun phrases | `mob_defeated`, `resource_changed` |

---

## File Structure

Each script file should follow this order:

```gdscript
class_name MyClass       # if this is a named class
extends SomeBase

# --- signals ---
signal something_happened(param: Type)

# --- enums ---
enum MyState { IDLE, ACTIVE }

# --- constants ---
const MAX_VALUE: int = 100

# --- exported properties ---
@export var speed: float = 5.0

# --- private variables ---
var _current_state: MyState = MyState.IDLE

# --- built-in callbacks ---
func _ready() -> void: pass
func _process(delta: float) -> void: pass
func _physics_process(delta: float) -> void: pass

# --- public methods ---
func do_thing() -> void: pass

# --- private methods ---
func _internal_helper() -> void: pass
```

---

## Typing

- Always declare variable types explicitly: `var speed: float = 5.0`, not `var speed = 5.0`.
- Always declare return types on functions: `func get_level() -> int:`.
- Use `Array[Type]` syntax for typed arrays: `var items: Array[String] = []`.
- Use `Dictionary` for key-value data; document expected key/value types in a comment when not obvious.
- Avoid `Variant` unless genuinely polymorphic.

---

## Script Size and Focus

- Each script has **one clear responsibility**.
- If a script grows past ~200 lines, consider splitting responsibilities.
- Avoid "manager of managers" god objects — each autoload owns a specific domain.
- Helper functions that are reused across multiple scripts belong in `scripts/utilities/`.

---

## Values and Configuration

- **Never hardcode gameplay values** (damage, speed, XP thresholds, costs) inside behavior scripts.
- All tunable values must be:
  - An `@export` property on the node (for per-instance tuning), OR
  - Defined in a `Resource` file (for shared data), OR
  - A constant in a clearly named constants file if truly universal.
- Scripts should read data; they should not contain data.

---

## Signals

- Use signals for communication between systems that should not hold direct references to each other.
- Connect signals in `_ready()` or in the parent scene, not in static code.
- Prefer typed signal parameters: `signal xp_gained(character_id: String, amount: int)`.
- Do not emit a signal if no one is listening is always safe — emit freely.
- Document which autoload emits each signal and who is expected to connect.

---

## Inheritance

- Prefer **flat inheritance** (one level deep) over deep class hierarchies.
- Use composition (adding a child node or script with its own state) instead of deep subclassing.
- Base classes should be abstract and minimal — define the contract, not the implementation.
- Example: `building.gd` is a base script with `health`, `take_damage()`, `on_destroyed()`. Each building type adds its own behavior node.

---

## State Machines

- Use explicit enum-based state machines, not string-based.
- Match on the enum in `_physics_process()` or `_process()`.
- Use `_transition_to(new_state)` method to centralize state-change side effects.
- Never mutate state directly from outside the owning script.

---

## Comments

- Write comments **only when the WHY is not obvious from the code**.
- Acceptable: "NavigationAgent3D cannot be used here because it requires a physics frame delay."
- Not acceptable: "# loop over enemies" above a for loop over enemies.
- No commented-out code in committed files — delete dead code; git history preserves it.
- No TODO comments in committed files — turn TODOs into issues or feature entries.

---

## Placeholder Code

- Placeholder implementations (stubs, mock data) must be simple and clearly marked.
- Use `@warning_ignore` annotations only when a warning is genuinely not actionable.
- Never ship placeholder data as if it were real data.
- Keep placeholders easy to delete — small, self-contained, no deep dependencies.

---

## Scene Design

- Use scenes for all visible or interactive game-world entities.
- Keep scene trees shallow — avoid unnecessary parent nodes.
- Resource nodes (Wood, Stone, etc.) share one base scene (`ResourceNode.tscn`) parameterized by a `ResourceDefinition` property.
- Do not put business logic in `_draw()` — use script-driven mesh/material changes.

---

## Resource Files

- All game data (building definitions, mob stats, resource definitions, crafting recipes) belongs in `.tres` files under `game/resources/`.
- Scripts load these via `@export var definition: BuildingDefinition` or `preload()`.
- Do not hardcode resource paths in multiple places — use `@export` or a central loader.

---

## Testing

- Every significant feature should have a corresponding manual test checklist in `docs/testing/` or `.features/<feature>/test-plan.md`.
- Write automated tests in `game/tests/automated/` as GDScript test scripts when practical.
- Test scripts should be independent and runnable without game state.
- Manual playtest acceptance criteria must be documented before a feature is considered done.

---

## Documentation

- Update `docs/architecture/software-architecture.md` when architectural decisions change.
- Update `.features/<feature>/handoff.md` at the end of every session.
- Update `.features/<feature>/status.md` after completing or changing significant work.
- Add a new `docs/decisions/ADR-####.md` for any significant new decision that will affect multiple systems.
