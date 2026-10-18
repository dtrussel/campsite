class_name Building
extends StaticBody3D

## Building
##
## Shared behaviour for any placed building (Wooden Fence, Watch Post,
## ...). Holds a BuildingDefinition and current HP. Phase 3 ships only
## the public surface (take_damage / repair / destroyed) so Phase 5
## (mobs) and Phase 4 (companion repair) can wire in without touching
## any building scene.
##
## Playtest 1 (feature 044): construction. BuildManager places a
## building as a *blueprint* (meta `blueprint` before it enters the
## tree): it starts sunk into the ground on a marked-out site, with a
## progress bar, and does nothing yet. The hero (and the companion on
## its Repair task) walks over and hammers it up with
## add_build_progress(); complete_construction() then switches it on.
## Subclasses switch themselves on in _on_built(), not _ready().

## Every placed building (not build-mode ghosts); the autosave lists them.
const BUILDINGS_GROUP: StringName = &"buildings"
## Buildings still waiting to be built, oldest first.
const BLUEPRINT_GROUP: StringName = &"blueprints"
## A blueprint stands this much of its height out of the ground at first.
const BLUEPRINT_START_HEIGHT: float = 0.15
## Share of max HP a fresh blueprint has; the rest comes as it is built.
const BLUEPRINT_START_HP: float = 0.2

signal damaged(new_hp: int)
signal repaired(new_hp: int)
signal destroyed
signal construction_finished

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
## 0..1 while a blueprint, 1 once built.
var build_progress: float = 1.0
var _construction_damage: int = 0
var _build_bar: HealthBar3D = null
var _site_marker: MeshInstance3D = null
## Direct children switched off while a blueprint (lights, auras, rings).
var _parked: Array[Node3D] = []


func _ready() -> void:
	if definition != null:
		current_hp = definition.max_hp
	else:
		push_warning("Building '%s' has no definition" % name)
	# The build-mode ghost is a real instance; keep it inert.
	set_physics_process(false)
	if has_meta(&"build_ghost"):
		return
	add_to_group(BUILDINGS_GROUP)
	_hp_bar = HealthBar3D.attach(self, hp_label_height, "structure", 1.1)
	_hp_bar.hide_when_full = true
	_refresh_hp_label.call_deferred()
	if has_meta(&"blueprint"):
		_enter_blueprint(float(get_meta(&"blueprint_progress", 0.0)))
	else:
		_on_built()


## Switches the building on (also right away for a building that was
## never a blueprint). Subclasses call super() and add their groups.
func _on_built() -> void:
	if repair_per_tap > 0:
		add_to_group(Repair.GROUP)
	set_physics_process(auto_attack_damage > 0)


func is_built() -> bool:
	return build_progress >= 1.0


func is_blueprint() -> bool:
	return build_progress < 1.0


## Seconds of hammering it takes from blueprint to building.
func build_seconds() -> float:
	return maxf(definition.build_seconds if definition != null else 2.0, 0.1)


## Hammering: `seconds` of work by `builder`. True once it is finished.
func add_build_progress(seconds: float, builder: Node = null) -> bool:
	if is_built() or current_hp <= 0:
		return is_built()
	build_progress = minf(1.0, build_progress + seconds / build_seconds())
	_refresh_construction()
	if build_progress >= 1.0:
		complete_construction(builder)
	return is_built()


## Finishes a blueprint at once (the builder gets the build XP).
func complete_construction(builder: Node = null) -> void:
	if not has_meta(&"blueprint") and _parked.is_empty() and is_built():
		return
	build_progress = 1.0
	remove_meta(&"blueprint")
	remove_from_group(BLUEPRINT_GROUP)
	current_hp = maxi(1, get_max_hp() - _construction_damage)
	_construction_damage = 0
	var visual: Node3D = get_node_or_null("Visual") as Node3D
	if visual != null:
		visual.position.y = 0.0
	if _site_marker != null:
		_site_marker.queue_free()
		_site_marker = null
	for child in _parked:
		if is_instance_valid(child):
			child.visible = true
			child.process_mode = Node.PROCESS_MODE_INHERIT
	_parked.clear()
	if _build_bar != null:
		_build_bar.queue_free()
		_build_bar = null
	_refresh_hp_label()
	_on_built()
	Fx.burst(&"build", global_position + Vector3(0, 0.4, 0))
	Fx.shake(0.05)
	if definition != null:
		AudioManager.play_sfx(definition.place_sound, global_position)
	BuildManager.on_construction_finished(self, builder)
	construction_finished.emit()


func _enter_blueprint(progress: float) -> void:
	build_progress = clampf(progress, 0.0, 0.999)
	add_to_group(BLUEPRINT_GROUP)
	for child in get_children():
		var node: Node3D = child as Node3D
		if node == null or node.name == &"Visual" or child is CollisionShape3D:
			continue
		if node.visible or node.process_mode != Node.PROCESS_MODE_DISABLED:
			node.visible = false
			node.process_mode = Node.PROCESS_MODE_DISABLED
			_parked.append(node)
	_build_bar = HealthBar3D.attach(self, hp_label_height + 0.3, "build", 0.9)
	_site_marker = _make_site_marker()
	add_child(_site_marker)
	_refresh_construction()


## A pale, staked-out rectangle on the ground under a blueprint.
func _make_site_marker() -> MeshInstance3D:
	var size: Vector3 = definition.footprint_size if definition != null else Vector3.ONE
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(size.x + 0.4, size.z + 0.4)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.93, 0.7, 0.35)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	plane.material = material
	var marker: MeshInstance3D = MeshInstance3D.new()
	marker.name = &"SiteMarker"
	marker.mesh = plane
	marker.position.y = 0.03
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.set_meta(&"stylized", "skip")
	return marker


## Flat distance from `point` to the edge of the footprint (0 inside).
func distance_to_footprint(point: Vector3) -> float:
	var size: Vector3 = definition.footprint_size if definition != null else Vector3.ONE
	var local: Vector3 = global_transform.affine_inverse() * point
	return Vector2(maxf(absf(local.x) - size.x * 0.5, 0.0), maxf(absf(local.z) - size.z * 0.5, 0.0)).length()


## Sinks the model by how far it is built, and scales its HP.
func _refresh_construction() -> void:
	var shown: float = lerpf(BLUEPRINT_START_HEIGHT, 1.0, build_progress)
	var visual: Node3D = get_node_or_null("Visual") as Node3D
	if visual != null:
		var height: float = definition.footprint_size.y if definition != null else 1.0
		visual.position.y = -height * (1.0 - shown)
	if _build_bar != null:
		_build_bar.set_value(int(round(build_progress * 20.0)), 20)
	if is_blueprint():
		var scaled: int = int(round(get_max_hp() * lerpf(BLUEPRINT_START_HP, 1.0, build_progress)))
		current_hp = maxi(1, scaled - _construction_damage)
		_refresh_hp_label()


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
	if is_blueprint():
		_construction_damage += amount
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
