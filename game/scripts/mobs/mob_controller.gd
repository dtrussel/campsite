class_name Mob
extends CharacterBody3D

## Mob
##
## Shadow Imp (and future) AI. Default behaviour is to walk toward the
## campfire and attack whatever blocks the way (fences first, then the
## campfire itself). If the boy or a companion comes within
## `aggro_radius`, the mob chases and attacks them instead until they
## escape or are knocked out. Lit torches slow mobs down.
##
## Mobs rise out of the ground when spawned (they cannot move or be
## targeted by their own AI until the rise finishes) and collapse into
## purple smoke when defeated.

signal defeated(mob: Node)
## A thief grabbed loot from the stash, or got away with it.
signal stole(mob: Node3D, item_id: StringName, amount: int)
signal escaped(mob: Node3D, item_id: StringName, amount: int)

enum State { MOVING_TO_TARGET, ATTACKING, DYING }

const TORCH_GROUP: StringName = &"torches"
const KNOCKBACK_DISTANCE: float = 0.5
const KNOCKBACK_DECAY: float = 10.0
## Extra reach against the campfire, whose collider is wider than a mob.
const CAMPFIRE_REACH_BONUS: float = 0.7
## Seconds a defeated mob lingers for its collapse animation.
const CORPSE_SECONDS: float = 1.4
## How far past attack_range a telegraphed blow still reaches a kid.
const DODGE_MARGIN: float = 0.4
const PICKUP_SCENE: PackedScene = preload("res://scenes/world/ItemPickup.tscn")

@export var definition: MobDefinition
## Height of the overhead HP bar (bigger mobs need it higher).
@export var hp_bar_height: float = 1.75

var current_hp: int = 0
var state: int = State.MOVING_TO_TARGET

var _base: Node3D = null
var _chase_target: Node3D = null
var _attack_target: Node = null
var _attack_cooldown_remaining: float = 0.0
var _last_damage_source: Node = null
var _knockback: Vector3 = Vector3.ZERO
var _spawn_remaining: float = 0.0
var _stun_remaining: float = 0.0
# Thief state (feature 021).
var loot_id: StringName = &""
var loot_amount: int = 0
var is_fleeing: bool = false
var _home: Vector3 = Vector3.ZERO
var _home_set: bool = false

var _hp_bar: HealthBar3D = null

@onready var _visual: CharacterVisual = get_node_or_null("Visual") as CharacterVisual


func _ready() -> void:
	add_to_group("mobs")
	if definition != null:
		current_hp = definition.max_hp
	else:
		push_warning("Mob '%s' has no definition" % name)
		current_hp = 1
	_refresh_base()
	_hp_bar = HealthBar3D.attach(self, hp_bar_height, "enemy", 0.9)
	_hp_bar.set_value.call_deferred(current_hp, current_hp)
	if _visual != null:
		if _base != null:
			_visual.face_instantly(_base.global_position - global_position)
		_spawn_remaining = minf(_visual.play_action(&"spawn", 1.6), 2.0)
	# Deferred: the spawner positions us right after add_child.
	_play_spawn_fx.call_deferred()


func _play_spawn_fx() -> void:
	Fx.burst(definition.spawn_burst if definition != null else &"shadow_spawn", global_position)
	if _visual != null and _base != null:
		_visual.face_instantly(_base.global_position - global_position)


func take_damage(amount: int, source: Node = null) -> void:
	if amount <= 0 or state == State.DYING:
		return
	if source != null:
		_last_damage_source = source
	current_hp = max(0, current_hp - amount)
	if _hp_bar != null and definition != null:
		_hp_bar.set_value(current_hp, definition.max_hp)
	Fx.flash(self, Color(1, 1, 1, 0.8))
	Fx.float_text(self, "-%d" % amount, Color(1, 0.95, 0.6), 1.2)
	if _visual != null and current_hp > 0 and _spawn_remaining <= 0.0 and not _visual.is_in_action():
		_visual.play_action(&"hit", 1.5)
	var source_3d: Node3D = source as Node3D
	if source_3d != null:
		var away: Vector3 = global_position - source_3d.global_position
		away.y = 0.0
		if away.length() > 0.01:
			var push: float = definition.knockback_scale if definition != null else 1.0
			_knockback = away.normalized() * KNOCKBACK_DISTANCE * KNOCKBACK_DECAY * push
	if current_hp == 0:
		_die()


func _die() -> void:
	state = State.DYING
	remove_from_group("mobs")
	collision_layer = 0
	collision_mask = 0
	_award_kill_xp()
	GameManager.record(&"kills")
	_maybe_drop_loot()
	defeated.emit(self)
	if _hp_bar != null:
		_hp_bar.visible = false
	Fx.burst(definition.death_burst if definition != null else &"shadow_death", global_position + Vector3(0, 0.5, 0))
	_drop_loot()
	if _visual != null:
		_visual.play_final(&"death")
	var tween: Tween = create_tween()
	tween.tween_interval(CORPSE_SECONDS * 0.6)
	tween.tween_property(self, "scale", Vector3(1.0, 0.02, 1.0), CORPSE_SECONDS * 0.4) \
		.set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


# --- Thief (Mushroom Gremlin) ----------------------------------------------

const THIEF_ESCAPE_DISTANCE: float = 0.9


func _tick_thief(delta: float) -> void:
	if not _home_set:
		_home = global_position
		_home_set = true
	var target: Vector3
	if is_fleeing:
		target = _home
		if _flat_to(target).length() <= THIEF_ESCAPE_DISTANCE:
			_escape()
			return
	else:
		var stash: Node3D = _find_stash()
		if stash == null:
			is_fleeing = true
			return
		target = stash.global_position
		if _flat_to(target).length() <= definition.attack_range + _footprint_radius(stash):
			_steal()
			is_fleeing = true
			if _visual != null:
				_visual.set_move_clip(&"flee")
			return
	var to_target: Vector3 = _flat_to(target)
	var speed: float = definition.move_speed * _torch_slow_factor()
	velocity = to_target.normalized() * speed + _knockback
	velocity.y = 0.0
	move_and_slide()
	_knockback = _knockback.move_toward(Vector3.ZERO, KNOCKBACK_DECAY * KNOCKBACK_DISTANCE * delta * 4.0)
	if _visual != null:
		_visual.set_locomotion(Vector2(velocity.x, velocity.z).length())
		_visual.face(velocity, delta)


func _flat_to(point: Vector3) -> Vector3:
	var offset: Vector3 = point - global_position
	offset.y = 0.0
	return offset


## The camp's stash: the nearest Storage Crate, else the campfire.
func _find_stash() -> Node3D:
	var best: Node3D = null
	var best_d: float = INF
	for node in get_tree().get_nodes_in_group(ResourceManager.STORAGE_GROUP):
		var crate: Node3D = node as Node3D
		var d: float = crate.global_position.distance_squared_to(global_position)
		if d < best_d:
			best_d = d
			best = crate
	return best if best != null else _base


## Grabs up to steal_amount of the camp's most plentiful resource.
func _steal() -> void:
	var best: StringName = &""
	var best_count: int = 0
	for item in ResourceManager.get_definitions():
		if item.base_cap <= 0:
			continue  # crafted things (torches, snacks) are left alone
		var count: int = ResourceManager.get_count(item.id)
		if count > best_count:
			best_count = count
			best = item.id
	if best == &"":
		Fx.float_text(self, "?", Color(0.9, 0.8, 1.0), 1.4)
		return
	var amount: int = mini(definition.steal_amount, best_count)
	ResourceManager.spend(best, amount)
	loot_id = best
	loot_amount = amount
	var item_def: ResourceDefinition = ResourceManager.get_definition(best)
	Fx.icon_popup(self, item_def.icon if item_def != null else null, "-%d" % amount, Color(1.0, 0.5, 0.45))
	AudioManager.play_sfx(&"gremlin_steal", global_position)
	GameManager.record(&"stolen", amount)
	PlaytestLog.write("gremlin_stole id=%s amount=%d day=%d" % [best, amount, TimeManager.day_number])
	if _visual != null:
		_visual.play_action(&"steal", 1.4)
	stole.emit(self, best, amount)


## Reached the forest edge: gone, with whatever it carries.
func _escape() -> void:
	state = State.DYING
	remove_from_group("mobs")
	if loot_amount > 0:
		GameManager.record(&"stolen_lost", loot_amount)
		escaped.emit(self, loot_id, loot_amount)
	Fx.burst(definition.spawn_burst, global_position)
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector3(0.05, 0.05, 0.05), 0.3)
	tween.tween_callback(queue_free)


## Caught: the loot spills out as a pickup (walk over it to get it back).
func _drop_loot() -> void:
	if loot_amount <= 0:
		return
	var pickup: Node3D = PICKUP_SCENE.instantiate() as Node3D
	pickup.set("item_id", loot_id)
	pickup.set("amount", loot_amount)
	get_tree().current_scene.add_child(pickup)
	pickup.global_position = Vector3(global_position.x, 0.0, global_position.z)
	loot_amount = 0


## Holds the mob in place (snap traps). Longer stuns replace shorter.
func stun(seconds: float) -> void:
	_stun_remaining = maxf(_stun_remaining, seconds)


func is_stunned() -> bool:
	return _stun_remaining > 0.0


## Predictable loot for young players: every Nth kill drops a pickup.
func _maybe_drop_loot() -> void:
	if definition == null or definition.drop_item == &"" or definition.drop_every_n_kills <= 0:
		return
	if int(GameManager.stats.get(&"kills", 0)) % definition.drop_every_n_kills != 0:
		return
	var pickup: Node3D = PICKUP_SCENE.instantiate() as Node3D
	pickup.set("item_id", definition.drop_item)
	get_tree().current_scene.add_child(pickup)
	pickup.global_position = Vector3(global_position.x, 0.0, global_position.z)


func _award_kill_xp() -> void:
	if _last_damage_source == null or not is_instance_valid(_last_damage_source):
		return
	if definition == null or definition.xp_reward <= 0:
		return
	ProgressionManager.award_xp(_last_damage_source, definition.xp_reward, &"kill")
	var killer: Node3D = _last_damage_source as Node3D
	if killer != null:
		Fx.burst(&"sparkle", killer.global_position + Vector3(0, 1.6, 0))


func _physics_process(delta: float) -> void:
	if state == State.DYING or definition == null:
		return
	_attack_cooldown_remaining = max(0.0, _attack_cooldown_remaining - delta)
	if _spawn_remaining > 0.0:
		# Still clawing out of the ground.
		_spawn_remaining -= delta
		return
	if _stun_remaining > 0.0:
		# Held by a snap trap: no moving, no attacking.
		_stun_remaining -= delta
		velocity = Vector3.ZERO
		if _visual != null:
			_visual.set_locomotion(0.0)
		return
	if _base == null or not is_instance_valid(_base):
		_refresh_base()
	if definition.steals_resources:
		_tick_thief(delta)
		return

	# Drop an attack target that has been destroyed.
	if _attack_target != null and not is_instance_valid(_attack_target):
		_attack_target = null
		state = State.MOVING_TO_TARGET

	_update_chase_target()

	var destination: Vector3 = global_position
	var siege_target: Node3D = null
	if _chase_target == null and definition.prefers_buildings:
		siege_target = _find_siege_target()
	if _chase_target != null:
		destination = _chase_target.global_position
	elif siege_target != null:
		destination = siege_target.global_position
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
	elif siege_target != null and distance <= reach + _footprint_radius(siege_target):
		direct_target = siege_target
	elif _chase_target == null and siege_target == null and _base != null and distance <= reach + CAMPFIRE_REACH_BONUS:
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

	if _visual != null:
		var planar_speed: float = Vector2(velocity.x, velocity.z).length()
		_visual.set_locomotion(planar_speed)
		if direct_target is Node3D:
			_visual.face((direct_target as Node3D).global_position - global_position, delta)
		elif planar_speed > 0.2:
			_visual.face(velocity, delta)


func _try_attack(target: Node) -> void:
	_attack_target = target
	state = State.ATTACKING
	if _attack_cooldown_remaining > 0.0:
		return
	if _visual != null:
		_visual.play_action(&"attack", 1.6)
	if definition.attack_hit_delay > 0.0:
		# Telegraphed (feature 026): the blow lands at the clip's impact.
		get_tree().create_timer(definition.attack_hit_delay, false).timeout.connect(_land_attack.bind(target))
	else:
		_land_attack(target)
	_attack_cooldown_remaining = definition.attack_cooldown_seconds


func _land_attack(target: Node) -> void:
	if state == State.DYING or not is_instance_valid(target) or not target.has_method("take_damage"):
		return
	var delayed: bool = definition.attack_hit_delay > 0.0
	if delayed:
		var target_3d: Node3D = target as Node3D
		var toward: Vector3 = Vector3.ZERO
		if target_3d != null:
			toward = target_3d.global_position - global_position
			toward.y = 0.0
		var impact: Vector3 = global_position + toward.limit_length(definition.attack_range * 0.8)
		if definition.impact_burst != &"":
			Fx.burst(definition.impact_burst, impact)
			Fx.shake(0.25)
		# Kids can dodge the windup by stepping away.
		if _is_character(target) and toward.length() > definition.attack_range + DODGE_MARGIN:
			PlaytestLog.write("attack_dodged mob=%s" % definition.id)
			return
	var damage: int = definition.attack_damage
	if target is Building:
		damage = int(round(damage * definition.building_damage_multiplier))
	target.take_damage(damage, self)
	# A beast that flattens a building beats its chest (feature 026).
	if delayed and target is Building and (target as Building).current_hp <= 0 and _visual != null:
		_visual.play_action(&"roar", 1.2)


func _is_character(node: Node) -> bool:
	return node.is_in_group(&"player") or node.is_in_group(&"companions")


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


## The nearest standing building a siege mob should tear down (traps
## are flat on the ground and ignored). Sticks with its current one.
func _find_siege_target() -> Node3D:
	var current: Building = _attack_target as Building
	if current != null and is_instance_valid(current) and current.current_hp > 0 and current.collision_layer != 0:
		return current
	var best: Node3D = null
	var best_d: float = INF
	for node in get_tree().get_nodes_in_group(Repair.GROUP):
		var building: Building = node as Building
		if building == null or building.current_hp <= 0 or building.collision_layer == 0:
			continue
		var d: float = building.global_position.distance_squared_to(global_position)
		if d < best_d:
			best_d = d
			best = building
	return best


func _footprint_radius(node: Node3D) -> float:
	var shape: CollisionShape3D = node.get_node_or_null("Collision") as CollisionShape3D
	if shape != null and shape.shape is BoxShape3D:
		var box: Vector3 = (shape.shape as BoxShape3D).size
		return maxf(box.x, box.z) * 0.5
	return 0.6


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
