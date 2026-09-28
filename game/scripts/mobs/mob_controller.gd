class_name Mob
extends CharacterBody3D

## Mob
##
## Shadow Imp (and future) AI. Default behaviour is to walk toward the
## campfire and attack whatever blocks the way (fences first, then the
## campfire itself). If the boy or a companion comes within
## `aggro_radius`, the mob chases and attacks them instead until they
## escape or are knocked out. Lit torches slow mobs down.

signal defeated(mob: Node)

enum State { MOVING_TO_TARGET, ATTACKING, DYING }

const TORCH_GROUP: StringName = &"torches"
const KNOCKBACK_DISTANCE: float = 0.5
const KNOCKBACK_DECAY: float = 10.0
## Extra reach against the campfire, whose collider is wider than a mob.
const CAMPFIRE_REACH_BONUS: float = 0.7

@export var definition: MobDefinition

var current_hp: int = 0
var state: int = State.MOVING_TO_TARGET

var _base: Node3D = null
var _chase_target: Node3D = null
var _attack_target: Node = null
var _attack_cooldown_remaining: float = 0.0
var _last_damage_source: Node = null
var _knockback: Vector3 = Vector3.ZERO


func _ready() -> void:
	add_to_group("mobs")
	if definition != null:
		current_hp = definition.max_hp
	else:
		push_warning("Mob '%s' has no definition" % name)
		current_hp = 1
	_refresh_base()


func take_damage(amount: int, source: Node = null) -> void:
	if amount <= 0 or state == State.DYING:
		return
	if source != null:
		_last_damage_source = source
	current_hp = max(0, current_hp - amount)
	Fx.flash(self, Color(1, 1, 1, 0.8))
	Fx.float_text(self, "-%d" % amount, Color(1, 0.95, 0.6), 1.2)
	var source_3d: Node3D = source as Node3D
	if source_3d != null:
		var away: Vector3 = global_position - source_3d.global_position
		away.y = 0.0
		if away.length() > 0.01:
			_knockback = away.normalized() * KNOCKBACK_DISTANCE * KNOCKBACK_DECAY
	if current_hp == 0:
		_die()


func _die() -> void:
	state = State.DYING
	remove_from_group("mobs")
	collision_layer = 0
	collision_mask = 0
	_award_kill_xp()
	defeated.emit(self)
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector3(1.4, 0.05, 1.4), 0.18)
	tween.tween_callback(queue_free)


func _award_kill_xp() -> void:
	if _last_damage_source == null or not is_instance_valid(_last_damage_source):
		return
	if definition == null or definition.xp_reward <= 0:
		return
	ProgressionManager.award_xp(_last_damage_source, definition.xp_reward, &"kill")
	var killer: Node3D = _last_damage_source as Node3D
	if killer != null:
		Fx.float_text(killer, "+%d XP" % definition.xp_reward, Color(0.6, 0.9, 1.0), 2.0)


func _physics_process(delta: float) -> void:
	if state == State.DYING or definition == null:
		return
	_attack_cooldown_remaining = max(0.0, _attack_cooldown_remaining - delta)
	if _base == null or not is_instance_valid(_base):
		_refresh_base()

	# Drop an attack target that has been destroyed.
	if _attack_target != null and not is_instance_valid(_attack_target):
		_attack_target = null
		state = State.MOVING_TO_TARGET

	_update_chase_target()

	var destination: Vector3 = global_position
	if _chase_target != null:
		destination = _chase_target.global_position
	elif _base != null:
		destination = _base.global_position

	var to_dest: Vector3 = destination - global_position
	to_dest.y = 0.0
	var distance: float = to_dest.length()

	# Close enough to hit a character or the campfire directly?
	var reach: float = definition.attack_range
	var direct_target: Node = null
	if _chase_target != null and distance <= reach:
		direct_target = _chase_target
	elif _chase_target == null and _base != null and distance <= reach + CAMPFIRE_REACH_BONUS:
		direct_target = _base

	if direct_target != null:
		velocity = _knockback
		move_and_slide()
		_try_attack(direct_target)
	else:
		var speed: float = definition.move_speed * _torch_slow_factor()
		velocity = (to_dest / distance) * speed if distance > 0.05 else Vector3.ZERO
		velocity += _knockback
		velocity.y = 0.0
		move_and_slide()
		# Bumped into a fence / the campfire on the way? Chew through it.
		var blocker: Node = _find_blocker()
		if blocker != null:
			_try_attack(blocker)
		elif state == State.ATTACKING:
			state = State.MOVING_TO_TARGET
			_attack_target = null

	_knockback = _knockback.move_toward(Vector3.ZERO, KNOCKBACK_DECAY * KNOCKBACK_DISTANCE * delta * 4.0)


func _try_attack(target: Node) -> void:
	_attack_target = target
	state = State.ATTACKING
	if _attack_cooldown_remaining > 0.0:
		return
	if target.has_method("take_damage"):
		target.take_damage(definition.attack_damage, self)
	_attack_cooldown_remaining = definition.attack_cooldown_seconds


func _update_chase_target() -> void:
	# Keep chasing the current target until it escapes (with some
	# hysteresis so targets do not flicker at the aggro edge).
	if _chase_target != null:
		if not _is_valid_character(_chase_target):
			_chase_target = null
		else:
			var d: float = _chase_target.global_position.distance_to(global_position)
			if d > definition.aggro_radius * 1.6:
				_chase_target = null
	if _chase_target != null:
		return
	var best: Node3D = null
	var best_d: float = definition.aggro_radius
	for group in [&"player", &"companions"]:
		for node in get_tree().get_nodes_in_group(group):
			var candidate: Node3D = node as Node3D
			if not _is_valid_character(candidate):
				continue
			var d: float = candidate.global_position.distance_to(global_position)
			if d < best_d:
				best_d = d
				best = candidate
	_chase_target = best


func _is_valid_character(node: Node3D) -> bool:
	if node == null or not is_instance_valid(node) or not node.is_inside_tree():
		return false
	# Player and companions both expose an is_knocked_out property.
	return node.get("is_knocked_out") != true


func _torch_slow_factor() -> float:
	for node in get_tree().get_nodes_in_group(TORCH_GROUP):
		if node.has_method("affects") and node.affects(global_position):
			return node.slow_factor
	return 1.0


func _find_blocker() -> Node:
	for i in range(get_slide_collision_count()):
		var collision: KinematicCollision3D = get_slide_collision(i)
		var collider: Object = collision.get_collider()
		if collider is Building:
			return collider as Node
		if collider is Node and (collider as Node).is_in_group("base_core"):
			return collider as Node
	return null


func _refresh_base() -> void:
	var nodes: Array = get_tree().get_nodes_in_group("base_core")
	_base = nodes[0] as Node3D if not nodes.is_empty() else null
