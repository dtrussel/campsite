class_name Building
extends StaticBody3D

## Building
##
## Shared behaviour for any placed building (Wooden Fence, Watch Post,
## ...). Holds a BuildingDefinition and current HP. Phase 3 ships only
## the public surface (take_damage / repair / destroyed) so Phase 5
## (mobs) and Phase 4 (companion repair) can wire in without touching
## any building scene.

signal damaged(new_hp: int)
signal repaired(new_hp: int)
signal destroyed

@export var definition: BuildingDefinition

var current_hp: int = 0


func _ready() -> void:
	if definition != null:
		current_hp = definition.max_hp
	else:
		push_warning("Building '%s' has no definition" % name)


func take_damage(amount: int) -> void:
	if amount <= 0 or current_hp <= 0:
		return
	current_hp = max(0, current_hp - amount)
	damaged.emit(current_hp)
	if current_hp == 0:
		destroyed.emit()
		queue_free()


func repair(amount: int) -> void:
	if amount <= 0 or definition == null:
		return
	if current_hp <= 0:
		return
	current_hp = min(definition.max_hp, current_hp + amount)
	repaired.emit(current_hp)
