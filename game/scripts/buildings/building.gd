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

## Height of the overhead HP label; set per scene.
@export var hp_label_height: float = 1.6

var current_hp: int = 0
var _hp_label: Label3D = null


func _ready() -> void:
	if definition != null:
		current_hp = definition.max_hp
	else:
		push_warning("Building '%s' has no definition" % name)
	_hp_label = Fx.make_hp_label(self, hp_label_height)
	_refresh_hp_label()


func take_damage(amount: int, _source: Node = null) -> void:
	if amount <= 0 or current_hp <= 0:
		return
	current_hp = max(0, current_hp - amount)
	damaged.emit(current_hp)
	Fx.flash(self)
	_refresh_hp_label()
	if current_hp == 0:
		destroyed.emit()
		PlaytestLog.write("building_destroyed id=%s day=%d" % [
			definition.id if definition != null else &"?", TimeManager.day_number
		])
		queue_free()


func _refresh_hp_label() -> void:
	if _hp_label == null or definition == null:
		return
	# Only show the bar once the building has been hit.
	_hp_label.visible = current_hp < definition.max_hp
	_hp_label.text = Fx.hp_bar_text(current_hp, definition.max_hp)
	_hp_label.modulate = Fx.hp_color(current_hp, definition.max_hp)


func repair(amount: int) -> void:
	if amount <= 0 or definition == null:
		return
	if current_hp <= 0:
		return
	current_hp = min(definition.max_hp, current_hp + amount)
	repaired.emit(current_hp)
	_refresh_hp_label()
