class_name Hero
extends CharacterBody3D

## Hero
##
## Everything Leo or Nela does whichever role they play (hero-core spec).
## The two role scripts extend it and add only what differs:
## - the player's hero (`player_controller.gd`): input, pointer commands
##   and the hit feel. Being down ends the run (GameManager listens).
## - the companion (`Companion`): the task AI and the stuck watchdog.
##   Being down lasts until dawn.
##
## Outside code talks to a hero through this interface only: never read
## a role's private fields by name.
##
## The script is split into sections, one per part of the hero:
## Health, Attack, Progress, and Gathering with the shared queries.

## HP changed (a hit, a heal, regen, a level-up or a revive).
signal health_changed(current_hp: int, max_hp: int)
## The hero went down at 0 HP (true) or got back up (false).
signal down_changed(is_down: bool)

## The hero played in this role; each role fills an empty one from the
## party in `_enter_tree`.
@export var hero: HeroDefinition
@export var stats: CharacterStatsDefinition

@onready var _visual: CharacterVisual = $Visual


# --- Health --------------------------------------------------------------
# Hits, heals, regen, the invulnerability window and being down. The
# role decides what being down means (`_on_down_changed`) and how a hit
# looks and sounds (`_show_hurt`).

## Overwritten by the stats' base health. The role sets its own default.
@export var max_hp: int = 50
## HP regained per second outside the night.
@export var regen_per_second: float = 1.2
## After a hit, further hits are ignored this long, so a crowd of mobs
## cannot delete a hero in one frame.
@export var hurt_invulnerability_seconds: float = 0.6

var current_hp: int = 0
var _down: bool = false
var _invulnerable_remaining: float = 0.0
var _regen_accumulator: float = 0.0


## True from reaching 0 HP until `revive`.
func is_down() -> bool:
	return _down


## True while the window after a hit ignores further hits.
func is_invulnerable() -> bool:
	return _invulnerable_remaining > 0.0


## Ends the invulnerability window now (tests and scripted hits).
func clear_invulnerability() -> void:
	_invulnerable_remaining = 0.0


## Mobs call this. Damage-taken perks (Stand Firm) apply here, in both
## roles. Ignored while down or inside the invulnerability window.
func take_damage(amount: int, _source: Node = null) -> void:
	if amount <= 0 or _down or _invulnerable_remaining > 0.0:
		return
	_invulnerable_remaining = hurt_invulnerability_seconds
	amount = HeroHits.damage_taken(self, amount)
	current_hp = maxi(0, current_hp - amount)
	health_changed.emit(current_hp, max_hp)
	_show_hurt(amount)
	if current_hp == 0:
		_set_down(true)
	elif not _visual.is_in_action():
		_visual.play_action(&"hit", 1.4)


## Heals `amount` HP, up to max. Not while down.
func heal(amount: int) -> void:
	if amount <= 0 or _down or current_hp >= max_hp:
		return
	current_hp = mini(max_hp, current_hp + amount)
	health_changed.emit(current_hp, max_hp)


## Gets a downed hero back up with `hp` HP (at least 1, at most max).
func revive(hp: int) -> void:
	if not _down:
		return
	current_hp = clampi(hp, 1, max_hp)
	_set_down(false)
	health_changed.emit(current_hp, max_hp)


## The role calls this every physics frame: it runs the invulnerability
## window and regen (none at night or while down).
func _tick_health(delta: float) -> void:
	_invulnerable_remaining = maxf(0.0, _invulnerable_remaining - delta)
	if _down or TimeManager.is_night() or current_hp >= max_hp:
		_regen_accumulator = 0.0
		return
	_regen_accumulator += regen_per_second * delta
	if _regen_accumulator >= 1.0:
		var whole: int = int(_regen_accumulator)
		_regen_accumulator -= whole
		heal(whole)


func _set_down(value: bool) -> void:
	if _down == value:
		return
	_down = value
	if value:
		velocity = Vector3.ZERO
		_visual.play_final(&"death")
	else:
		_visual.unlock(&"getup")
	_on_down_changed(value)
	down_changed.emit(value)


## Role hook: the hit's feedback (flash, number, sound).
func _show_hurt(_amount: int) -> void:
	pass


## Role hook: what going down (or back up) means for this role, run
## before `down_changed` is emitted.
func _on_down_changed(_is_down: bool) -> void:
	pass


# --- Attack --------------------------------------------------------------
# hero-core 02: attack, reach, readiness, damage, the signature tool.


# --- Progress ------------------------------------------------------------
# hero-core 03: stats from the definition, level-up and `leveled`.


# --- Gathering and shared queries ----------------------------------------
# One gather path for both roles: start on a resource node, cancel, ask
# whether it is running, and hear when it finished. The node's own timer
# runs the gather; the role decides how it looks (`_on_gather_started`).

## The hero finished gathering `node` (the node paid out).
signal gather_finished(node: ResourceNode)

var _gather_node: ResourceNode = null


## Starts gathering `node` now (the hero should be next to it). Any other
## gather is cancelled first. False if the node won't have the hero: it
## is depleted, someone else is on it, or the stash is full.
func start_gather(node: ResourceNode) -> bool:
	if node == null or not is_instance_valid(node) or _down:
		return false
	if node == gather_target():
		return true
	cancel_gather()
	if not node.begin_gather(self):
		return false
	_gather_node = node
	if not node.gathered.is_connected(_on_gather_node_gathered):
		node.gathered.connect(_on_gather_node_gathered)
	_on_gather_started(node)
	return true


## Stops the current gather, if any; the node gives nothing for it.
func cancel_gather() -> void:
	var node: ResourceNode = _gather_node
	_gather_node = null
	if node == null or not is_instance_valid(node):
		return
	if node.gathered.is_connected(_on_gather_node_gathered):
		node.gathered.disconnect(_on_gather_node_gathered)
	node.cancel_gather(self)


## True while a gather runs on a node that still exists.
func is_gathering() -> bool:
	return _gather_node != null and is_instance_valid(_gather_node)


## The node being gathered, or null.
func gather_target() -> ResourceNode:
	return _gather_node if is_gathering() else null


func _on_gather_node_gathered(actor: Node, _id: StringName, _amount: int) -> void:
	if actor != self:
		return
	var node: ResourceNode = _gather_node
	if is_instance_valid(node) and node.gathered.is_connected(_on_gather_node_gathered):
		node.gathered.disconnect(_on_gather_node_gathered)
	_gather_node = null
	gather_finished.emit(node)


## Role hook: how starting a gather on `node` looks.
func _on_gather_started(_node: ResourceNode) -> void:
	pass


## The nearest mob within `within` metres (straight-line), or null.
func nearest_mob(within: float) -> Node3D:
	var best: Node3D = null
	var best_d_sq: float = within * within
	for node in get_tree().get_nodes_in_group("mobs"):
		var mob: Node3D = node as Node3D
		if mob == null or not is_instance_valid(mob):
			continue
		var d_sq: float = mob.global_position.distance_squared_to(global_position)
		if d_sq < best_d_sq:
			best_d_sq = d_sq
			best = mob
	return best


## Distance to `point` on the ground plane (height ignored).
func _flat_distance(point: Vector3) -> float:
	return Vector2(point.x - global_position.x, point.z - global_position.z).length()


## How far `node`'s collision reaches out from its centre, for "close
## enough to gather, repair or use". Settled drift (hero-core): a node
## without a cylinder, sphere or box shape counts as 0.4 m, the player's
## old value (the companion used 0.5).
static func _node_radius(node: Node3D) -> float:
	var shape: CollisionShape3D = node.get_node_or_null("Collision") as CollisionShape3D
	if shape != null and shape.shape is CylinderShape3D:
		return (shape.shape as CylinderShape3D).radius
	if shape != null and shape.shape is SphereShape3D:
		return (shape.shape as SphereShape3D).radius
	if shape != null and shape.shape is BoxShape3D:
		var box: Vector3 = (shape.shape as BoxShape3D).size
		return maxf(box.x, box.z) * 0.5
	return 0.4
