class_name CompanionDefinition
extends Resource

## CompanionDefinition
##
## Typed data for one companion archetype (Sibling, Dog, ...). Stored
## as a .tres file under res://resources/companions/.

@export var id: StringName = &""
@export var display_name: String = ""
@export var scene: PackedScene
@export var move_speed: float = 4.5
@export var attack_damage: int = 3
@export var attack_range: float = 2.0
@export var attack_cooldown_seconds: float = 0.6
@export var ui_color: Color = Color(0.6, 0.85, 0.55, 1)
