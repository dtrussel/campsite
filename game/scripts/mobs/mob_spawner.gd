extends Node3D

## MobSpawner
##
## Lives in the world scene. On TimeManager.night_started, spawns a
## wave of mobs from this node's Marker3D children (random pick per
## spawn). Stops if BaseCore is destroyed.

signal wave_started(night_number: int)
signal wave_ended

@export var mob_definition: MobDefinition
@export var base_spawn_count: int = 4
@export var per_night_extra: int = 1
@export var spawn_interval_seconds: float = 4.0
@export var initial_delay_seconds: float = 2.0

var _spawn_points: Array[Marker3D] = []
var _alive_mobs: Array[Node] = []
var _wave_active: bool = false
var _remaining_to_spawn: int = 0
var _next_spawn_in: float = 0.0
var _base_destroyed: bool = false


func _ready() -> void:
	for child in get_children():
		if child is Marker3D:
			_spawn_points.append(child)
	if _spawn_points.is_empty():
		push_warning("MobSpawner has no Marker3D children; using own position")
	if TimeManager and not TimeManager.night_started.is_connected(_on_night_started):
		TimeManager.night_started.connect(_on_night_started)
	if TimeManager and not TimeManager.dawn_started.is_connected(_on_dawn_started):
		TimeManager.dawn_started.connect(_on_dawn_started)
	# Connect to base core's destroyed signal once it's available.
	call_deferred("_connect_to_base_core")


func _process(delta: float) -> void:
	if not _wave_active:
		return
	if _base_destroyed:
		return
	if _remaining_to_spawn > 0:
		_next_spawn_in -= delta
		if _next_spawn_in <= 0.0:
			_spawn_one()
			_remaining_to_spawn -= 1
			_next_spawn_in = spawn_interval_seconds
	else:
		_alive_mobs = _alive_mobs.filter(func(m): return m != null and is_instance_valid(m))
		if _alive_mobs.is_empty():
			_end_wave()


func _on_night_started(day_number: int) -> void:
	if _base_destroyed or mob_definition == null:
		return
	_wave_active = true
	_remaining_to_spawn = base_spawn_count + per_night_extra * max(0, day_number - 1)
	_next_spawn_in = initial_delay_seconds
	_alive_mobs.clear()
	wave_started.emit(day_number)


func _on_dawn_started(_day_number: int) -> void:
	if not _wave_active:
		return
	# Cleanup: free any leftover mobs at dawn so day starts fresh.
	for mob in _alive_mobs:
		if mob != null and is_instance_valid(mob):
			mob.queue_free()
	_alive_mobs.clear()
	_remaining_to_spawn = 0
	_end_wave()


func _spawn_one() -> void:
	if mob_definition == null or mob_definition.scene == null:
		return
	var parent: Node = get_tree().current_scene
	if parent == null:
		return
	var instance: Node = mob_definition.scene.instantiate()
	var mob: Node3D = instance as Node3D
	if mob == null:
		instance.queue_free()
		return
	mob.global_position = _pick_spawn_position()
	parent.add_child(mob)
	_alive_mobs.append(mob)
	if instance.has_signal("defeated"):
		instance.defeated.connect(_on_mob_defeated)


func _pick_spawn_position() -> Vector3:
	if _spawn_points.is_empty():
		return global_position
	var point: Marker3D = _spawn_points[randi() % _spawn_points.size()]
	return point.global_position


func _on_mob_defeated(mob: Node) -> void:
	_alive_mobs.erase(mob)


func _end_wave() -> void:
	if not _wave_active:
		return
	_wave_active = false
	wave_ended.emit()


func _connect_to_base_core() -> void:
	var nodes: Array = get_tree().get_nodes_in_group("base_core")
	for node in nodes:
		if node.has_signal("destroyed") and not node.destroyed.is_connected(_on_base_destroyed):
			node.destroyed.connect(_on_base_destroyed)


func _on_base_destroyed() -> void:
	_base_destroyed = true
	for mob in _alive_mobs:
		if mob != null and is_instance_valid(mob):
			mob.queue_free()
	_alive_mobs.clear()
	_remaining_to_spawn = 0
	_end_wave()
