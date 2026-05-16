class_name Building
extends Node3D

## Base script for all placeable buildings. Attach to a building scene root.

signal building_damaged(damage: int, new_health: int)
signal building_destroyed(building: Building)
signal building_repaired(amount: int, new_health: int)

@export var definition: BuildingDefinition
@export var max_health: int = 100

var _current_health: int

func _ready() -> void:
	if definition:
		max_health = definition.max_health
	_current_health = max_health

func take_damage(amount: int) -> void:
	_current_health = maxi(0, _current_health - amount)
	building_damaged.emit(amount, _current_health)
	if _current_health <= 0:
		building_destroyed.emit(self)
		_on_destroyed()

func repair(amount: int) -> void:
	_current_health = mini(max_health, _current_health + amount)
	building_repaired.emit(amount, _current_health)

func get_health() -> int:
	return _current_health

func get_health_percent() -> float:
	return float(_current_health) / float(max_health)

func _on_destroyed() -> void:
	queue_free()
