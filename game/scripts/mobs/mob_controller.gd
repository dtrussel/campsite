class_name Mob
extends CharacterBody3D

## Mob
##
## Shadow Imp (and future) AI. Walks toward the campfire each frame;
## if a slide collision reports a Building or BaseCore in the way, the
## mob switches to ATTACKING that target and damages it on a cooldown
## until it dies, then resumes walking.

signal defeated(mob: Node)

enum State { MOVING_TO_TARGET, ATTACKING, DYING }

@export var definition: MobDefinition

var current_hp: int = 0
var state: int = State.MOVING_TO_TARGET

var _target_position: Vector3 = Vector3.ZERO
var _attack_target: Node = null
var _attack_cooldown_remaining: float = 0.0


func _ready() -> void:
	add_to_group("mobs")
	if definition != null:
		current_hp = definition.max_hp
	else:
		push_warning("Mob '%s' has no definition" % name)
		current_hp = 1
	_refresh_target_position()


func take_damage(amount: int) -> void:
	if amount <= 0 or state == State.DYING:
		return
	current_hp = max(0, current_hp - amount)
	if current_hp == 0:
		state = State.DYING
		defeated.emit(self)
		queue_free()


func _physics_process(delta: float) -> void:
	if state == State.DYING or definition == null:
		return
	_attack_cooldown_remaining = max(0.0, _attack_cooldown_remaining - delta)

	# Always re-acquire the base position (campfire may have moved... it doesn't, but stays robust).
	if _target_position == Vector3.ZERO:
		_refresh_target_position()

	# If the current attack target is gone, reset to walking.
	if state == State.ATTACKING and (
		_attack_target == null or not is_instance_valid(_attack_target)
	):
		_attack_target = null
		state = State.MOVING_TO_TARGET

	# Move toward the campfire each frame regardless of state — when
	# the attack target is destroyed we want to immediately resume
	# walking.
	var to_target: Vector3 = _target_position - global_position
	to_target.y = 0.0
	var distance: float = to_target.length()

	if distance > 0.05:
		var dir: Vector3 = to_target / distance
		velocity = dir * definition.move_speed
	else:
		velocity = Vector3.ZERO
	velocity.y = 0.0

	move_and_slide()

	# After moving, check what we just bumped into.
	var blocker: Node = _find_blocker()
	if blocker != null:
		_attack_target = blocker
		state = State.ATTACKING
		if _attack_cooldown_remaining <= 0.0:
			_attack(blocker)


func _find_blocker() -> Node:
	for i in range(get_slide_collision_count()):
		var collision: KinematicCollision3D = get_slide_collision(i)
		var collider: Object = collision.get_collider()
		if collider is Building:
			return collider as Node
		if collider is Node and (collider as Node).is_in_group("base_core"):
			return collider as Node
	return null


func _attack(target: Node) -> void:
	if definition == null:
		return
	if target.has_method("take_damage"):
		target.take_damage(definition.attack_damage)
	_attack_cooldown_remaining = definition.attack_cooldown_seconds


func _refresh_target_position() -> void:
	var nodes: Array = get_tree().get_nodes_in_group("base_core")
	if nodes.is_empty():
		_target_position = Vector3.ZERO
		return
	var base: Node3D = nodes[0] as Node3D
	if base != null:
		_target_position = base.global_position
