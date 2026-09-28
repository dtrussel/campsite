extends CharacterBody3D

## PlayerController
##
## WASD movement plus a simple IDLE / MOVING / GATHERING / KNOCKED_OUT
## state machine. When `interact` is pressed and the GatherInteractor
## has a ResourceNode in range, the player enters GATHERING, freezes
## in place, and waits for the node's `gathered` signal. Movement
## input or losing the node mid-gather cancels.
##
## The boy has health: mobs hurt him, he regenerates slowly outside
## of night, eating berries heals, and reaching 0 HP ends the run.

signal health_changed(current_hp: int, max_hp: int)
signal knocked_out

enum PlayerState { IDLE, MOVING, GATHERING, KNOCKED_OUT }

const TORCH_SCENE: PackedScene = preload("res://scenes/buildings/Torch.tscn")
const TORCH_ITEM_ID: StringName = &"torch"
const BERRY_ITEM_ID: StringName = &"berries"
const BERRIES_PER_MEAL: int = 2

@export var move_speed: float = 5.0
@export var acceleration: float = 20.0
@export var friction: float = 18.0

@export var attack_damage: int = 4
@export var attack_range: float = 2.2
@export var attack_cooldown_seconds: float = 0.4
@export var stats: CharacterStatsDefinition

@export var max_hp: int = 50
@export var regen_per_second: float = 1.5
@export var hurt_invulnerability_seconds: float = 0.6
@export var heal_per_meal: int = 15

@onready var _interactor: Node = $GatherInteractor

var _state: int = PlayerState.IDLE
var _active_node: ResourceNode = null
var _attack_cooldown_remaining: float = 0.0
var current_hp: int = 0
var is_knocked_out: bool = false
var _invulnerable_remaining: float = 0.0
var _regen_accumulator: float = 0.0
var _facing: Vector3 = Vector3(0, 0, 1)
var _swing: MeshInstance3D = null


func _ready() -> void:
	add_to_group("player")
	if _interactor != null and _interactor.has_signal("interactable_exited"):
		_interactor.interactable_exited.connect(_on_interactor_exited)
	if stats != null:
		attack_damage = stats.base_attack_damage
		max_hp = stats.base_max_health
	current_hp = max_hp
	_swing = _make_swing_mesh()
	ProgressionManager.register_character(self, stats)
	if not ProgressionManager.level_up.is_connected(_on_level_up):
		ProgressionManager.level_up.connect(_on_level_up)


func _unhandled_input(event: InputEvent) -> void:
	if _state == PlayerState.KNOCKED_OUT or BuildManager.is_in_build_mode():
		return
	if event.is_action_pressed("interact"):
		_try_begin_gather()
	elif event.is_action_pressed("attack"):
		_try_attack()
	elif event.is_action_pressed("place_torch"):
		_try_place_torch()
	elif event.is_action_pressed("eat_berries"):
		_try_eat_berries()


## Mobs call this. Returns early while briefly invulnerable after a hit
## so a crowd of imps cannot delete the boy in one frame.
func take_damage(amount: int, _source: Node = null) -> void:
	if amount <= 0 or _state == PlayerState.KNOCKED_OUT:
		return
	if _invulnerable_remaining > 0.0:
		return
	_invulnerable_remaining = hurt_invulnerability_seconds
	current_hp = max(0, current_hp - amount)
	health_changed.emit(current_hp, max_hp)
	Fx.flash(self)
	Fx.float_text(self, "-%d" % amount, Color(1, 0.45, 0.4))
	if current_hp == 0:
		_cancel_active_gather()
		_state = PlayerState.KNOCKED_OUT
		is_knocked_out = true
		velocity = Vector3.ZERO
		rotation_degrees.z = 80.0  # topple over; placeholder "down" pose
		PlaytestLog.write("player_knocked_out day=%d" % TimeManager.day_number)
		knocked_out.emit()


func heal(amount: int) -> void:
	if amount <= 0 or _state == PlayerState.KNOCKED_OUT or current_hp >= max_hp:
		return
	current_hp = min(max_hp, current_hp + amount)
	health_changed.emit(current_hp, max_hp)


func _physics_process(delta: float) -> void:
	_attack_cooldown_remaining = max(0.0, _attack_cooldown_remaining - delta)
	_invulnerable_remaining = max(0.0, _invulnerable_remaining - delta)
	_tick_regen(delta)
	if _state == PlayerState.KNOCKED_OUT:
		return
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
		_facing = Vector3(input_dir.x, 0.0, input_dir.y)
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
	# Always swing (and pay the cooldown) so the button feels responsive
	# even when nothing is in reach.
	_attack_cooldown_remaining = attack_cooldown_seconds
	_play_swing()
	var target: Node3D = _find_nearest_mob_in_range()
	if target != null and target.has_method("take_damage"):
		target.take_damage(attack_damage, self)


func _try_place_torch() -> void:
	if _state == PlayerState.GATHERING:
		return
	if not ResourceManager.spend(TORCH_ITEM_ID, 1):
		Fx.float_text(self, "No torch - craft one at the campfire (C)", Color(1, 0.85, 0.5), 2.0)
		return
	var torch: Node3D = TORCH_SCENE.instantiate() as Node3D
	get_tree().current_scene.add_child(torch)
	torch.global_position = global_position + _facing.normalized() * 1.0
	GameManager.record(&"torches_placed")
	PlaytestLog.write("torch_placed day=%d phase=%s" % [TimeManager.day_number, TimeManager.get_phase_name()])


func _try_eat_berries() -> void:
	if current_hp >= max_hp:
		Fx.float_text(self, "Not hungry", Color(0.9, 0.9, 0.9), 2.0)
		return
	if not ResourceManager.spend(BERRY_ITEM_ID, BERRIES_PER_MEAL):
		Fx.float_text(self, "Need %d berries" % BERRIES_PER_MEAL, Color(1, 0.85, 0.5), 2.0)
		return
	heal(heal_per_meal)
	Fx.float_text(self, "+%d HP" % heal_per_meal, Color(0.5, 1, 0.5))


func _tick_regen(delta: float) -> void:
	if _state == PlayerState.KNOCKED_OUT or TimeManager.is_night() or current_hp >= max_hp:
		_regen_accumulator = 0.0
		return
	_regen_accumulator += regen_per_second * delta
	if _regen_accumulator >= 1.0:
		var whole: int = int(_regen_accumulator)
		_regen_accumulator -= whole
		heal(whole)


func _on_level_up(character: Node, _new_level: int) -> void:
	if character != self or stats == null:
		return
	attack_damage += stats.attack_damage_per_level
	max_hp += stats.max_health_per_level
	current_hp = min(max_hp, current_hp + stats.max_health_per_level)
	health_changed.emit(current_hp, max_hp)
	Fx.float_text(self, "LEVEL UP!", Color(0.6, 1, 0.6), 2.2)


func _make_swing_mesh() -> MeshInstance3D:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = attack_range - 0.15
	torus.outer_radius = attack_range
	mesh.mesh = torus
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1, 1, 0.8, 0.6)
	mesh.material_override = material
	mesh.position = Vector3(0, 0.1, 0)
	mesh.visible = false
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	return mesh


func _play_swing() -> void:
	if _swing == null:
		return
	_swing.visible = true
	_swing.scale = Vector3.ONE * 0.5
	var tween: Tween = create_tween()
	tween.tween_property(_swing, "scale", Vector3.ONE, 0.12)
	tween.tween_callback(func() -> void: _swing.visible = false)


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
