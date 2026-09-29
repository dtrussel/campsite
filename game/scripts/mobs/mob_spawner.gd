extends Node3D

## MobSpawner
##
## Lives in the world scene. On TimeManager.night_started, spawns a
## wave of mobs from this node's Marker3D children (random pick per
## spawn). Stops if BaseCore is destroyed. A wave is `get_wave_size()`
## imps with `get_heavy_count()` heavy mobs (Bramble Beasts, feature
## 018) mixed into its second half.

signal wave_started(night_number: int, mob_count: int)
signal wave_ended
signal mob_spawned(mob: Node3D, definition: MobDefinition)

@export var mob_definition: MobDefinition
## Mobs per night, indexed by night - 1. Nights past the end of the
## list reuse the last entry plus per_night_extra for each extra night.
@export var wave_sizes: PackedInt32Array = PackedInt32Array([4, 7, 11])
@export var per_night_extra: int = 2
## Heavy mobs per night (index = night - 1); nights past the list add
## heavy_per_night_extra each.
@export var heavy_definition: MobDefinition
@export var heavy_counts: PackedInt32Array = PackedInt32Array([0, 1, 2])
@export var heavy_per_night_extra: int = 1
@export var spawn_interval_seconds: float = 4.0
@export var initial_delay_seconds: float = 2.0

var _spawn_points: Array[Marker3D] = []
var _alive_mobs: Array[Node] = []
var _wave_active: bool = false
var _remaining_to_spawn: int = 0
var _queue: Array[MobDefinition] = []
var _next_spawn_in: float = 0.0
var _base_destroyed: bool = false


func _ready() -> void:
	add_to_group("mob_spawner")
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
			_spawn_one(_queue.pop_front() if not _queue.is_empty() else mob_definition)
			_remaining_to_spawn -= 1
			_next_spawn_in = spawn_interval_seconds
	else:
		_alive_mobs = _alive_mobs.filter(func(m): return m != null and is_instance_valid(m))
		if _alive_mobs.is_empty():
			_end_wave()
			# Whole wave defeated: dawn comes early (roadmap Phase 5 rule).
			if TimeManager.is_night():
				TimeManager.skip_phase()


func _on_night_started(day_number: int) -> void:
	if _base_destroyed or mob_definition == null:
		return
	_wave_active = true
	_queue = build_wave(day_number)
	_remaining_to_spawn = _queue.size()
	_next_spawn_in = initial_delay_seconds
	_alive_mobs.clear()
	PlaytestLog.write("wave_started night=%d mobs=%d" % [day_number, _remaining_to_spawn])
	wave_started.emit(day_number, _remaining_to_spawn)


func get_wave_size(night: int) -> int:
	if wave_sizes.is_empty():
		return 3
	var index: int = night - 1
	if index < wave_sizes.size():
		return wave_sizes[max(0, index)]
	return wave_sizes[wave_sizes.size() - 1] + per_night_extra * (index - wave_sizes.size() + 1)


func get_heavy_count(night: int) -> int:
	if heavy_definition == null or heavy_counts.is_empty():
		return 0
	var index: int = night - 1
	if index < heavy_counts.size():
		return heavy_counts[max(0, index)]
	return heavy_counts[heavy_counts.size() - 1] + heavy_per_night_extra * (index - heavy_counts.size() + 1)


## The spawn order for a night: imps first, heavies spread through the
## second half, so the camp gets a few easy imps before the big one.
func build_wave(night: int) -> Array[MobDefinition]:
	var wave: Array[MobDefinition] = []
	for i in get_wave_size(night):
		wave.append(mob_definition)
	var heavies: int = get_heavy_count(night)
	for k in heavies:
		var at: int = wave.size() / 2 + int(float(k) * wave.size() / float(heavies * 2))
		wave.insert(clampi(at, 0, wave.size()), heavy_definition)
	return wave


func _on_dawn_started(_day_number: int) -> void:
	if not _wave_active:
		return
	# Cleanup: free any leftover mobs at dawn so day starts fresh.
	for mob in _alive_mobs:
		if mob != null and is_instance_valid(mob):
			mob.queue_free()
	_alive_mobs.clear()
	_remaining_to_spawn = 0
	_queue.clear()
	_end_wave()


func _spawn_one(definition: MobDefinition) -> void:
	if definition == null or definition.get_scene() == null:
		return
	var parent: Node = get_tree().current_scene
	if parent == null:
		return
	var instance: Node = definition.get_scene().instantiate()
	var mob: Node3D = instance as Node3D
	if mob == null:
		instance.queue_free()
		return
	parent.add_child(mob)
	mob.global_position = _pick_spawn_position()
	_alive_mobs.append(mob)
	mob_spawned.emit(mob, definition)
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
	PlaytestLog.write("wave_ended")
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
	_queue.clear()
	_end_wave()
