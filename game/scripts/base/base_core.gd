extends StaticBody3D

## BaseCore
##
## Heart of the camp. Mobs prefer this as their final target. When HP
## reaches zero, the campsite is considered lost. Phase 0 left the
## campfire as a visual-only object; this script wires up health and
## the matching signals.

signal damaged(new_hp: int)
signal repaired(new_hp: int)
signal destroyed

@export var max_hp: int = 200

var current_hp: int = 0
var is_destroyed: bool = false


func _ready() -> void:
	current_hp = max_hp


func take_damage(amount: int) -> void:
	if amount <= 0 or is_destroyed:
		return
	current_hp = max(0, current_hp - amount)
	damaged.emit(current_hp)
	if current_hp == 0:
		is_destroyed = true
		destroyed.emit()


func repair(amount: int) -> void:
	if amount <= 0 or is_destroyed:
		return
	current_hp = min(max_hp, current_hp + amount)
	repaired.emit(current_hp)
