class_name Companion
extends CharacterBody3D

## Companion
##
## Task-driven AI used by family / pet companions. Always present in
## the world; the player assigns tasks via hotkeys (see HUD hint).
## Companions are invulnerable in this feature; mobs ignore them.

signal task_changed(new_task: int)

enum Task { IDLE, FOLLOW_PLAYER, GUARD_BASE, GATHER_NEAREST }

@export var definition: CompanionDefinition
@export var follow_distance: float = 2.5
@export var guard_radius: float = 3.5
@export var detection_radius: float = 6.0

var current_task: int = Task.IDLE

@onready var _task_label: Label3D = $TaskLabel

var _player: Node3D = null
var _base_core: Node3D = null
var _attack_cooldown_remaining: float = 0.0
var _active_resource_node: Node = null   # ResourceNode currently being gathered


func _ready() -> void:
	add_to_group("companions")
	_refresh_world_refs()
	_update_task_label()


func set_task(task: int) -> void:
	if task == current_task:
		return
	_abort_active_gather()
	current_task = task
	task_changed.emit(current_task)
	_update_task_label()


func get_task_name() -> String:
	match current_task:
		Task.IDLE: return "Idle"
		Task.FOLLOW_PLAYER: return "Follow Player"
		Task.GUARD_BASE: return "Guard Base"
		Task.GATHER_NEAREST: return "Gather"
	return "?"


func _physics_process(delta: float) -> void:
	if definition == null:
		return
	_attack_cooldown_remaining = max(0.0, _attack_cooldown_remaining - delta)

	if _player == null or _base_core == null:
		_refresh_world_refs()

	match current_task:
		Task.IDLE:
			_tick_idle()
		Task.FOLLOW_PLAYER:
			_tick_follow_player()
		Task.GUARD_BASE:
			_tick_guard_base()
		Task.GATHER_NEAREST:
			_tick_gather_nearest()


func _tick_idle() -> void:
	velocity = Vector3.ZERO
	move_and_slide()


func _tick_follow_player() -> void:
	if _player == null:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	var to_player: Vector3 = _player.global_position - global_position
	to_player.y = 0.0
	var distance: float = to_player.length()
	if distance > follow_distance:
		velocity = to_player.normalized() * definition.move_speed
	else:
		velocity = Vector3.ZERO
	move_and_slide()


func _tick_guard_base() -> void:
	if _base_core == null:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	# First priority: kill nearby mobs.
	var mob: Node3D = _find_nearest_mob(definition.attack_range)
	if mob != null:
		velocity = Vector3.ZERO
		move_and_slide()
		if _attack_cooldown_remaining <= 0.0:
			_attack_mob(mob)
		return
	# Second: move into guard radius if outside.
	var to_base: Vector3 = _base_core.global_position - global_position
	to_base.y = 0.0
	var distance: float = to_base.length()
	if distance > guard_radius:
		velocity = to_base.normalized() * definition.move_speed
	else:
		# Approach the nearest detected mob if any.
		var detected: Node3D = _find_nearest_mob(detection_radius)
		if detected != null:
			var to_mob: Vector3 = detected.global_position - global_position
			to_mob.y = 0.0
			velocity = to_mob.normalized() * definition.move_speed
		else:
			velocity = Vector3.ZERO
	move_and_slide()


func _tick_gather_nearest() -> void:
	# If we're currently gathering a node, wait for it; gather.gd's
	# Timer drives completion. The node calls ResourceManager.add()
	# itself and emits "gathered" — we just need to wait, then look
	# for the next nearest.
	if _active_resource_node != null and is_instance_valid(_active_resource_node):
		# Stand still while gathering.
		velocity = Vector3.ZERO
		move_and_slide()
		return

	var target: Node3D = _find_nearest_resource_node()
	if target == null:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	var to_target: Vector3 = target.global_position - global_position
	to_target.y = 0.0
	var distance: float = to_target.length()
	# Begin gathering when adjacent.
	if distance < 1.8:
		velocity = Vector3.ZERO
		move_and_slide()
		_begin_gather_on(target)
		return
	velocity = to_target.normalized() * definition.move_speed
	move_and_slide()


func _begin_gather_on(node: Node) -> void:
	if not node.has_method("begin_gather"):
		return
	if not node.begin_gather(self):
		return
	_active_resource_node = node
	if node.has_signal("gathered") and not node.gathered.is_connected(_on_resource_gathered):
		node.gathered.connect(_on_resource_gathered)


func _abort_active_gather() -> void:
	if _active_resource_node == null:
		return
	if is_instance_valid(_active_resource_node):
		if _active_resource_node.gathered.is_connected(_on_resource_gathered):
			_active_resource_node.gathered.disconnect(_on_resource_gathered)
		if _active_resource_node.has_method("cancel_gather"):
			_active_resource_node.cancel_gather(self)
	_active_resource_node = null


func _on_resource_gathered(actor: Node, _id: StringName, _amount: int) -> void:
	if actor != self:
		return
	if _active_resource_node != null and is_instance_valid(_active_resource_node):
		if _active_resource_node.gathered.is_connected(_on_resource_gathered):
			_active_resource_node.gathered.disconnect(_on_resource_gathered)
	_active_resource_node = null


func _attack_mob(mob: Node3D) -> void:
	if not mob.has_method("take_damage"):
		return
	mob.take_damage(definition.attack_damage)
	_attack_cooldown_remaining = definition.attack_cooldown_seconds


func _find_nearest_mob(within: float) -> Node3D:
	var best: Node3D = null
	var best_d_sq: float = within * within
	for node in get_tree().get_nodes_in_group("mobs"):
		if node == null or not is_instance_valid(node):
			continue
		var n3d: Node3D = node as Node3D
		if n3d == null:
			continue
		var d_sq: float = n3d.global_position.distance_squared_to(global_position)
		if d_sq < best_d_sq:
			best_d_sq = d_sq
			best = n3d
	return best


func _find_nearest_resource_node() -> Node3D:
	# Resource nodes are on collision_layer 3 (1+2). Walk the scene
	# tree once; this is a prototype with few nodes, so no spatial
	# index needed.
	var best: Node3D = null
	var best_d_sq: float = INF
	var stack: Array = [get_tree().current_scene]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node == null:
			continue
		if node is ResourceNode and (node as ResourceNode).is_gatherable:
			var n3d: Node3D = node as Node3D
			var d_sq: float = n3d.global_position.distance_squared_to(global_position)
			if d_sq < best_d_sq:
				best_d_sq = d_sq
				best = n3d
		for child in node.get_children():
			stack.append(child)
	return best


func _refresh_world_refs() -> void:
	if _player == null:
		var players: Array = get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			_player = players[0] as Node3D
	if _base_core == null:
		var bases: Array = get_tree().get_nodes_in_group("base_core")
		if not bases.is_empty():
			_base_core = bases[0] as Node3D


func _update_task_label() -> void:
	if _task_label != null:
		_task_label.text = get_task_name()
