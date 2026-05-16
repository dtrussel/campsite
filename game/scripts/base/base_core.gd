extends Node3D

## The campfire/camp core. Primary target for mobs. Broadcasts damage to HUD.

signal base_damaged(damage: int, new_health: int)
signal base_destroyed

@export var max_health: int = 200
@export var display_name_text: String = "Campsite Core"

var _current_health: int

func _ready() -> void:
	_current_health = max_health
	add_to_group("base_core")
	base_damaged.emit(0, _current_health)

func take_damage(amount: int) -> void:
	_current_health = maxi(0, _current_health - amount)
	base_damaged.emit(amount, _current_health)
	if _current_health <= 0:
		base_destroyed.emit()
		GameManager.trigger_game_over()

func repair(amount: int) -> void:
	_current_health = mini(max_health, _current_health + amount)
	base_damaged.emit(0, _current_health)

func get_health() -> int:
	return _current_health

func get_max_health() -> int:
	return max_health
