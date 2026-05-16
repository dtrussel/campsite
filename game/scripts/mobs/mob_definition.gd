class_name MobDefinition
extends Resource

## MobDefinition
##
## Typed data for one mob species (Shadow Imp, Bramble Beast, ...).
## Stored as a .tres file under res://resources/mobs/.

@export var id: StringName = &""
@export var display_name: String = ""
@export var scene: PackedScene
@export var max_hp: int = 6
@export var move_speed: float = 2.2
@export var attack_damage: int = 3
@export var attack_range: float = 1.2
@export var attack_cooldown_seconds: float = 1.0
@export var xp_reward: int = 5
@export var ui_color: Color = Color(0.6, 0.4, 0.7, 1)
