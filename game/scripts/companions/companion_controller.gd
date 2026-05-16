extends CharacterBody3D

## Controls a companion NPC. Manages task states and autonomous behavior.

enum CompanionState { IDLE, FOLLOWING, GATHERING, GUARDING, REPAIRING, CRAFTING, SCOUTING, SUPPORTING }

signal companion_task_changed(task: CompanionState)

@export var companion_id: String = "companion_01"
@export var move_speed: float = 4.0
@export var follow_distance: float = 3.0
@export var guard_patrol_radius: float = 4.0

var state: CompanionState = CompanionState.IDLE
var _target_node: Node3D = null
var _patrol_angle: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta

	match state:
		CompanionState.IDLE:        _state_idle(delta)
		CompanionState.FOLLOWING:   _state_follow(delta)
		CompanionState.GUARDING:    _state_guard(delta)

	move_and_slide()

func assign_task(new_task: CompanionState) -> void:
	state = new_task
	companion_task_changed.emit(state)

func set_follow_target(target: Node3D) -> void:
	_target_node = target
	assign_task(CompanionState.FOLLOWING)

func set_guard_target(base_position: Vector3) -> void:
	assign_task(CompanionState.GUARDING)

func _state_idle(_delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, move_speed)
	velocity.z = move_toward(velocity.z, 0.0, move_speed)

func _state_follow(delta: float) -> void:
	if not _target_node:
		return
	var diff: Vector3 = _target_node.global_position - global_position
	diff.y = 0.0
	if diff.length() > follow_distance:
		var dir: Vector3 = diff.normalized()
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)

func _state_guard(delta: float) -> void:
	# Simple patrol around origin (Phase 4 will add proper target tracking)
	_patrol_angle += delta * 0.5
	var target_x: float = cos(_patrol_angle) * guard_patrol_radius
	var target_z: float = sin(_patrol_angle) * guard_patrol_radius
	var target_pos: Vector3 = Vector3(target_x, global_position.y, target_z)
	var diff: Vector3 = target_pos - global_position
	diff.y = 0.0
	if diff.length() > 0.5:
		var dir: Vector3 = diff.normalized()
		velocity.x = dir.x * (move_speed * 0.5)
		velocity.z = dir.z * (move_speed * 0.5)

func get_task_name() -> String:
	match state:
		CompanionState.IDLE:       return "Idle"
		CompanionState.FOLLOWING:  return "Following"
		CompanionState.GATHERING:  return "Gathering"
		CompanionState.GUARDING:   return "Guarding"
		CompanionState.REPAIRING:  return "Repairing"
		CompanionState.CRAFTING:   return "Crafting"
		CompanionState.SCOUTING:   return "Scouting"
		CompanionState.SUPPORTING: return "Supporting"
	return "Unknown"
