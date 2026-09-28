extends CharacterBody3D

## PlayerController
##
## LoL-style command movement. The pointer (see PointerCommands) issues
## commands: move to a point, attack an imp (walk into range, then
## auto-attack until it dies), gather a resource node (walk to it,
## then gather), or use the campfire (walk to it, open crafting).
## Paths come from the world's navigation mesh; WASD still works as a
## direct override and cancels the current command.
##
## The boy has health: mobs hurt him, he regenerates slowly outside of
## night, eating berries heals, and reaching 0 HP ends the run.

signal health_changed(current_hp: int, max_hp: int)
signal knocked_out
signal command_changed(command: int, target: Node)
signal attacked(target: Node)

enum PlayerState { IDLE, MOVING, GATHERING, KNOCKED_OUT }
enum Command { NONE, MOVE, ATTACK, GATHER, CAMPFIRE }

const TORCH_SCENE: PackedScene = preload("res://scenes/buildings/Torch.tscn")
const TORCH_ITEM_ID: StringName = &"torch"
const BERRY_ITEM_ID: StringName = &"berries"
const BERRIES_PER_MEAL: int = 2
## Distance at which a gather command starts gathering.
const GATHER_REACH: float = 1.5
## Distance at which a campfire command opens crafting.
const CAMPFIRE_REACH: float = 2.6
## Seconds into the swing when damage lands (the "wind-up").
const ATTACK_WINDUP: float = 0.18
const REPATH_SECONDS: float = 0.25

@export var move_speed: float = 5.0
@export var acceleration: float = 30.0
@export var friction: float = 30.0

@export var attack_damage: int = 4
@export var attack_range: float = 2.0
@export var attack_cooldown_seconds: float = 0.5
@export var stats: CharacterStatsDefinition

@export var max_hp: int = 50
@export var regen_per_second: float = 1.5
@export var hurt_invulnerability_seconds: float = 0.6
@export var heal_per_meal: int = 15
## Half-size of the playable square around the campfire; keeps the boy
## inside the area the camera and mob spawns are designed around.
@export var play_area_half_extent: float = 19.0

@onready var _interactor: Node = $GatherInteractor
@onready var _visual: CharacterVisual = $Visual

var current_hp: int = 0
var is_knocked_out: bool = false
var command: int = Command.NONE
var command_target: Node3D = null

var _state: int = PlayerState.IDLE
var _active_node: ResourceNode = null
var _attack_cooldown_remaining: float = 0.0
var _invulnerable_remaining: float = 0.0
var _regen_accumulator: float = 0.0
var _move_goal: Vector3 = Vector3.ZERO
var _repath_timer: float = 0.0
var _agent: NavigationAgent3D = null
var _hp_bar: HealthBar3D = null


func _ready() -> void:
	add_to_group("player")
	if _interactor != null and _interactor.has_signal("interactable_exited"):
		_interactor.interactable_exited.connect(_on_interactor_exited)
	if stats != null:
		attack_damage = stats.base_attack_damage
		max_hp = stats.base_max_health
	current_hp = max_hp
	_agent = NavigationAgent3D.new()
	_agent.radius = 0.35
	_agent.path_desired_distance = 0.4
	_agent.target_desired_distance = 0.3
	_agent.path_max_distance = 2.0
	# The baked surface sits a voxel or two above the ground plane.
	_agent.path_height_offset = 0.5
	add_child(_agent)
	ProgressionManager.register_character(self, stats)
	if not ProgressionManager.level_up.is_connected(_on_level_up):
		ProgressionManager.level_up.connect(_on_level_up)
	_hp_bar = HealthBar3D.attach(self, 2.35, "hero", 1.3)
	health_changed.connect(func(hp: int, max_value: int) -> void: _hp_bar.set_value(hp, max_value))
	_hp_bar.set_value.call_deferred(current_hp, max_hp)


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


# --- Commands (issued by PointerCommands or tests) -------------------

func command_move(point: Vector3) -> void:
	if not _can_command():
		return
	_cancel_active_gather()
	_set_command(Command.MOVE, null)
	_move_goal = Vector3(point.x, global_position.y, point.z)
	_agent.target_position = _move_goal


func command_attack(target: Node3D) -> void:
	if not _can_command() or target == null:
		return
	_cancel_active_gather()
	_set_command(Command.ATTACK, target)
	_repath_timer = 0.0


func command_gather(node: ResourceNode) -> void:
	if not _can_command() or node == null or not node.is_gatherable:
		return
	_cancel_active_gather()
	_set_command(Command.GATHER, node)
	_agent.target_position = node.global_position


func command_campfire(base: Node3D) -> void:
	if not _can_command() or base == null:
		return
	_cancel_active_gather()
	_set_command(Command.CAMPFIRE, base)
	_agent.target_position = base.global_position


func stop_commands() -> void:
	_set_command(Command.NONE, null)


func get_facing() -> Vector3:
	return Vector3(sin(_visual.rotation.y), 0.0, cos(_visual.rotation.y))


# --- Health ------------------------------------------------------------

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
	Fx.shake(0.18)
	if current_hp == 0:
		_cancel_active_gather()
		_set_command(Command.NONE, null)
		_state = PlayerState.KNOCKED_OUT
		is_knocked_out = true
		velocity = Vector3.ZERO
		_visual.play_final(&"death")
		PlaytestLog.write("player_knocked_out day=%d" % TimeManager.day_number)
		knocked_out.emit()
	elif not _visual.is_in_action():
		_visual.play_action(&"hit", 1.4)


func heal(amount: int) -> void:
	if amount <= 0 or _state == PlayerState.KNOCKED_OUT or current_hp >= max_hp:
		return
	current_hp = min(max_hp, current_hp + amount)
	health_changed.emit(current_hp, max_hp)


# --- Per-frame -----------------------------------------------------------

func _physics_process(delta: float) -> void:
	_attack_cooldown_remaining = max(0.0, _attack_cooldown_remaining - delta)
	_invulnerable_remaining = max(0.0, _invulnerable_remaining - delta)
	_tick_regen(delta)
	if _state == PlayerState.KNOCKED_OUT:
		return

	var desired: Vector3 = Vector3.ZERO
	var input_dir: Vector2 = _keyboard_direction()
	if input_dir.length() > 0.0:
		# Keyboard movement overrides (and cancels) pointer commands.
		if command != Command.NONE:
			_set_command(Command.NONE, null)
		_cancel_active_gather()
		desired = Vector3(input_dir.x, 0.0, input_dir.y).normalized() * move_speed
	elif _state == PlayerState.GATHERING:
		desired = Vector3.ZERO
		if _active_node != null and is_instance_valid(_active_node):
			_visual.face(_active_node.global_position - global_position, delta)
			if not _visual.is_in_action():
				_visual.play_action(_active_node.gather_animation, 1.5)
	else:
		desired = _tick_command(delta)

	var rate: float = acceleration if desired.length() > 0.0 else friction
	velocity.x = move_toward(velocity.x, desired.x, rate * delta)
	velocity.z = move_toward(velocity.z, desired.z, rate * delta)
	velocity.y = 0.0
	move_and_slide()
	global_position.x = clampf(global_position.x, -play_area_half_extent, play_area_half_extent)
	global_position.z = clampf(global_position.z, -play_area_half_extent, play_area_half_extent)

	var planar_speed: float = Vector2(velocity.x, velocity.z).length()
	if _state != PlayerState.GATHERING:
		_state = PlayerState.MOVING if planar_speed > 0.2 else PlayerState.IDLE
	_visual.set_locomotion(planar_speed)
	if planar_speed > 0.2 and not _visual.is_in_action():
		_visual.face(velocity, delta)


## Returns the desired velocity for the current command.
func _tick_command(delta: float) -> Vector3:
	match command:
		Command.MOVE:
			if _flat_distance(_move_goal) <= _agent.target_desired_distance + 0.1:
				_set_command(Command.NONE, null)
				return Vector3.ZERO
			return _path_velocity(_move_goal)
		Command.ATTACK:
			if not _is_attackable(command_target):
				_set_command(Command.NONE, null)
				return Vector3.ZERO
			if _flat_distance(command_target.global_position) <= attack_range:
				_visual.face(command_target.global_position - global_position, delta)
				if _attack_cooldown_remaining <= 0.0:
					_perform_attack(command_target)
				return Vector3.ZERO
			_repath_timer -= delta
			if _repath_timer <= 0.0:
				_repath_timer = REPATH_SECONDS
				_agent.target_position = command_target.global_position
			return _path_velocity(command_target.global_position)
		Command.GATHER:
			var node: ResourceNode = command_target as ResourceNode
			if node == null or not is_instance_valid(node) or not node.is_gatherable:
				_set_command(Command.NONE, null)
				return Vector3.ZERO
			if _flat_distance(node.global_position) <= GATHER_REACH + _node_radius(node):
				_set_command(Command.NONE, null)
				_begin_gather_on(node)
				return Vector3.ZERO
			return _path_velocity(node.global_position)
		Command.CAMPFIRE:
			if command_target == null or not is_instance_valid(command_target):
				_set_command(Command.NONE, null)
				return Vector3.ZERO
			if _flat_distance(command_target.global_position) <= CAMPFIRE_REACH:
				_set_command(Command.NONE, null)
				var panel: Node = get_tree().get_first_node_in_group("crafting_panel")
				if panel != null:
					panel.open()
				return Vector3.ZERO
			return _path_velocity(command_target.global_position)
	return Vector3.ZERO


## Velocity toward `goal`, following the nav path when one exists.
func _path_velocity(goal: Vector3) -> Vector3:
	var next: Vector3 = goal
	if _agent != null and NavigationServer3D.map_get_iteration_id(_agent.get_navigation_map()) > 0:
		if not _agent.is_navigation_finished():
			next = _agent.get_next_path_position()
	var to_next: Vector3 = next - global_position
	to_next.y = 0.0
	if to_next.length() < 0.05:
		to_next = goal - global_position
		to_next.y = 0.0
	if to_next.length() < 0.01:
		return Vector3.ZERO
	return to_next.normalized() * move_speed


func _keyboard_direction() -> Vector2:
	return Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	)


func _set_command(new_command: int, target: Node3D) -> void:
	if new_command == command and target == command_target:
		return
	command = new_command
	command_target = target
	command_changed.emit(command, target)


func _can_command() -> bool:
	return _state != PlayerState.KNOCKED_OUT and not BuildManager.is_in_build_mode()


func _flat_distance(point: Vector3) -> float:
	return Vector2(point.x - global_position.x, point.z - global_position.z).length()


func _node_radius(node: Node3D) -> float:
	var shape: CollisionShape3D = node.get_node_or_null("Collision") as CollisionShape3D
	if shape != null and shape.shape is CylinderShape3D:
		return (shape.shape as CylinderShape3D).radius
	if shape != null and shape.shape is SphereShape3D:
		return (shape.shape as SphereShape3D).radius
	return 0.4


func _is_attackable(target: Node3D) -> bool:
	return target != null and is_instance_valid(target) and target.is_in_group("mobs")


# --- Actions ---------------------------------------------------------------

func _perform_attack(target: Node3D) -> void:
	_attack_cooldown_remaining = attack_cooldown_seconds
	_visual.play_action(&"attack", 1.9)
	attacked.emit(target)
	var tween: Tween = create_tween()
	tween.tween_interval(ATTACK_WINDUP)
	tween.tween_callback(func() -> void:
		if _is_attackable(target) and _flat_distance(target.global_position) <= attack_range * 1.4:
			target.take_damage(attack_damage, self)
			Fx.burst(&"hit", target.global_position + Vector3(0, 0.7, 0))
	)


func _try_begin_gather() -> void:
	if _state == PlayerState.GATHERING or _interactor == null:
		return
	var node: ResourceNode = _interactor.get_closest()
	if node == null:
		return
	_set_command(Command.NONE, null)
	_begin_gather_on(node)


func _begin_gather_on(node: ResourceNode) -> void:
	if not node.begin_gather(self):
		return
	_active_node = node
	if not node.gathered.is_connected(_on_node_gathered):
		node.gathered.connect(_on_node_gathered)
	_state = PlayerState.GATHERING
	velocity = Vector3.ZERO
	_visual.face_instantly(node.global_position - global_position)
	_visual.play_action(node.gather_animation, 1.5)


func _cancel_active_gather() -> void:
	if _active_node != null:
		if is_instance_valid(_active_node):
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


## Space: swing at the nearest imp in range (keyboard shortcut).
func _try_attack() -> void:
	if _state == PlayerState.GATHERING or _attack_cooldown_remaining > 0.0:
		return
	var target: Node3D = _find_nearest_mob_in_range()
	if target == null:
		# Swing anyway so the key feels responsive.
		_attack_cooldown_remaining = attack_cooldown_seconds
		_visual.play_action(&"attack", 1.9)
		return
	_visual.face_instantly(target.global_position - global_position)
	command_attack(target)


func _try_place_torch() -> void:
	if _state == PlayerState.GATHERING:
		return
	if not ResourceManager.spend(TORCH_ITEM_ID, 1):
		Fx.float_text(self, "No torch - craft one at the campfire (C)", Color(1, 0.85, 0.5), 2.0)
		return
	var torch: Node3D = TORCH_SCENE.instantiate() as Node3D
	get_tree().current_scene.add_child(torch)
	torch.global_position = global_position + get_facing() * 1.0
	Fx.burst(&"dust", torch.global_position)
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
	Fx.burst(&"heal", global_position)


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
	_hp_bar.set_level(_new_level)
	max_hp += stats.max_health_per_level
	current_hp = min(max_hp, current_hp + stats.max_health_per_level)
	health_changed.emit(current_hp, max_hp)
	Fx.float_text(self, "LEVEL UP!", Color(1.0, 0.85, 0.4), 2.2)
	Fx.burst(&"level_up", global_position)


func _find_nearest_mob_in_range() -> Node3D:
	var best: Node3D = null
	var best_d_sq: float = attack_range * attack_range * 1.44
	for node in get_tree().get_nodes_in_group("mobs"):
		var n3d: Node3D = node as Node3D
		if n3d == null or not is_instance_valid(n3d):
			continue
		var d_sq: float = n3d.global_position.distance_squared_to(global_position)
		if d_sq < best_d_sq:
			best_d_sq = d_sq
			best = n3d
	return best
