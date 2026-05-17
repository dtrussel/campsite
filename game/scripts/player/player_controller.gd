extends CharacterBody3D

## PlayerController
##
## WASD movement plus a simple IDLE / MOVING / GATHERING state
## machine. When `interact` is pressed and the GatherInteractor has
## a ResourceNode in range, the player enters GATHERING, freezes in
## place, and waits for the node's `gathered` signal. Movement input
## or losing the node mid-gather cancels.

enum PlayerState { IDLE, MOVING, GATHERING }

@export var move_speed: float = 5.0
@export var acceleration: float = 20.0
@export var friction: float = 18.0

@export var attack_damage: int = 4
@export var attack_range: float = 1.8
@export var attack_cooldown_seconds: float = 0.4
@export var stats: CharacterStatsDefinition

@onready var _interactor: Node = $GatherInteractor

var _state: int = PlayerState.IDLE
var _active_node: ResourceNode = null
var _attack_cooldown_remaining: float = 0.0


func _ready() -> void:
	add_to_group("player")
	if _interactor != null and _interactor.has_signal("interactable_exited"):
		_interactor.interactable_exited.connect(_on_interactor_exited)
	if stats != null:
		attack_damage = stats.base_attack_damage
	ProgressionManager.register_character(self, stats)
	if not ProgressionManager.level_up.is_connected(_on_level_up):
		ProgressionManager.level_up.connect(_on_level_up)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if BuildManager.is_in_build_mode():
			return
		_try_begin_gather()
	elif event.is_action_pressed("attack"):
		if BuildManager.is_in_build_mode():
			return
		_try_attack()


func _physics_process(delta: float) -> void:
	_attack_cooldown_remaining = max(0.0, _attack_cooldown_remaining - delta)
	if _state == PlayerState.GATHERING:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	var input_dir: Vector2 = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	)

	var target_velocity: Vector3 = Vector3.ZERO
	if input_dir.length() > 0.0:
		input_dir = input_dir.normalized()
		target_velocity = Vector3(input_dir.x, 0.0, input_dir.y) * move_speed
		_state = PlayerState.MOVING
	else:
		_state = PlayerState.IDLE

	var rate: float = acceleration if target_velocity.length() > 0.0 else friction
	velocity.x = move_toward(velocity.x, target_velocity.x, rate * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, rate * delta)
	velocity.y = 0.0
	move_and_slide()


func _try_begin_gather() -> void:
	if _state == PlayerState.GATHERING:
		return
	if _interactor == null:
		return
	var node: ResourceNode = _interactor.get_closest()
	if node == null:
		return
	if not node.begin_gather(self):
		return
	_active_node = node
	if not node.gathered.is_connected(_on_node_gathered):
		node.gathered.connect(_on_node_gathered)
	_state = PlayerState.GATHERING
	velocity = Vector3.ZERO


func _cancel_active_gather() -> void:
	if _active_node != null:
		if _active_node.gathered.is_connected(_on_node_gathered):
			_active_node.gathered.disconnect(_on_node_gathered)
		_active_node.cancel_gather(self)
		_active_node = null
	if _state == PlayerState.GATHERING:
		_state = PlayerState.IDLE


func _on_node_gathered(actor: Node, _id: StringName, _amount: int) -> void:
	if actor != self:
		return
	if _active_node != null and _active_node.gathered.is_connected(_on_node_gathered):
		_active_node.gathered.disconnect(_on_node_gathered)
	_active_node = null
	_state = PlayerState.IDLE


func _on_interactor_exited(node: ResourceNode) -> void:
	if node == _active_node:
		_cancel_active_gather()


func _process(_delta: float) -> void:
	if _state != PlayerState.GATHERING:
		return
	var input_dir: Vector2 = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	)
	if input_dir.length() > 0.0:
		_cancel_active_gather()


func _try_attack() -> void:
	if _state == PlayerState.GATHERING:
		return
	if _attack_cooldown_remaining > 0.0:
		return
	var target: Node3D = _find_nearest_mob_in_range()
	if target == null:
		return
	if target.has_method("take_damage"):
		target.take_damage(attack_damage, self)
		_attack_cooldown_remaining = attack_cooldown_seconds


func _on_level_up(character: Node, _new_level: int) -> void:
	if character != self or stats == null:
		return
	attack_damage += stats.attack_damage_per_level


func _find_nearest_mob_in_range() -> Node3D:
	var best: Node3D = null
	var best_d_sq: float = attack_range * attack_range
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
