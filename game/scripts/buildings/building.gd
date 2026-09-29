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
## Hammer taps (Repair) restore this much HP each; 0 = not repairable
## (traps are rebuilt, not repaired).
@export var repair_per_tap: int = 12
## Optional defensive behaviour (Watch Post): damage the nearest mob in
## range every interval. 0 damage disables it.
@export var auto_attack_damage: int = 0
@export var auto_attack_range: float = 5.0
@export var auto_attack_interval: float = 1.5

var _auto_attack_timer: float = 0.0

var current_hp: int = 0
var _hp_bar: HealthBar3D = null


func _ready() -> void:
	if definition != null:
		current_hp = definition.max_hp
	else:
		push_warning("Building '%s' has no definition" % name)
	if not has_meta(&"build_ghost") and repair_per_tap > 0:
		add_to_group(Repair.GROUP)
	if not has_meta(&"build_ghost"):
		_hp_bar = HealthBar3D.attach(self, hp_label_height, "structure", 1.1)
		_hp_bar.hide_when_full = true
		_refresh_hp_label.call_deferred()
	# The build-mode ghost is a real instance; keep it inert.
	set_physics_process(auto_attack_damage > 0 and not has_meta(&"build_ghost"))


func _physics_process(delta: float) -> void:
	_auto_attack_timer += delta
	if _auto_attack_timer < auto_attack_interval:
		return
	var target: Node3D = null
	var best: float = auto_attack_range
	for node in get_tree().get_nodes_in_group("mobs"):
		var mob: Node3D = node as Node3D
		if mob == null:
			continue
		var d: float = mob.global_position.distance_to(global_position)
		if d < best:
			best = d
			target = mob
	if target != null:
		_auto_attack_timer = 0.0
		target.take_damage(auto_attack_damage, self)


func take_damage(amount: int, _source: Node = null) -> void:
	if amount <= 0 or current_hp <= 0:
		return
	current_hp = max(0, current_hp - amount)
	damaged.emit(current_hp)
	Fx.flash(self)
	if current_hp > 0:
		AudioManager.play_sfx(&"structure_hit", global_position)
	_refresh_hp_label()
	if current_hp == 0:
		Fx.burst(&"build", global_position + Vector3(0, 0.5, 0))
		destroyed.emit()
		PlaytestLog.write("building_destroyed id=%s day=%d" % [
			definition.id if definition != null else &"?", TimeManager.day_number
		])
		queue_free()


func _refresh_hp_label() -> void:
	if _hp_bar == null or definition == null:
		return
	_hp_bar.set_value(current_hp, definition.max_hp)


func get_max_hp() -> int:
	return definition.max_hp if definition != null else current_hp


func get_missing_hp() -> int:
	return maxi(0, get_max_hp() - current_hp) if current_hp > 0 else 0


func repair(amount: int) -> void:
	if amount <= 0 or definition == null:
		return
	if current_hp <= 0:
		return
	current_hp = min(definition.max_hp, current_hp + amount)
	repaired.emit(current_hp)
	_refresh_hp_label()
