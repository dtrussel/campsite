class_name Burn
extends Node

## Burn
##
## The Ember Stick's burn (tool tiers): a mob a burning hit lands on
## takes DAMAGE every TICK_SECONDS for SECONDS, so TICKS ticks in all.
## Lives as a child of the mob and frees itself when done. A new burning
## hit on a burning mob starts the burn over (it never stacks).
##
##   Burn.ignite(mob)          # from Hero.on_attack_hit
##   Burn.splash(mob)          # the Blaze Stick: the mobs beside it too
##   Burn.on(mob)              # the mob's burn, or null

const NODE_NAME: String = "Burn"
const DAMAGE: int = 1
const TICK_SECONDS: float = 1.0
const SECONDS: float = 3.0
const TICKS: int = 3
## How close (flat metres) a mob must stand to a burning hit's target for
## the Blaze Stick's burn to splash onto it.
const SPLASH_RADIUS: float = 1.6

## Ticks dealt since the burn (re)started.
var ticks: int = 0
var _elapsed: float = 0.0


## Sets `target` burning (or starts its burn over). The mob credits the
## hit that lit it; the ticks push nothing back. Ignored for anything that can't
## take damage or is already dead.
static func ignite(target: Node) -> Burn:
	if target == null or not is_instance_valid(target) or not target.has_method("take_damage") or not target.is_inside_tree():
		return null
	if target.get("current_hp") != null and int(target.get("current_hp")) <= 0:
		return null
	var burn: Burn = on(target)
	if burn == null:
		burn = Burn.new()
		burn.name = NODE_NAME
		target.add_child(burn)
	burn._elapsed = 0.0
	burn.ticks = 0
	return burn


## Sets every living mob within SPLASH_RADIUS of `target` burning (not
## `target` itself). Returns how many caught.
static func splash(target: Node3D) -> int:
	if target == null or not is_instance_valid(target) or not target.is_inside_tree():
		return 0
	var caught: int = 0
	for node in target.get_tree().get_nodes_in_group("mobs"):
		var mob: Node3D = node as Node3D
		if mob == null or mob == target or not is_instance_valid(mob):
			continue
		var offset: Vector3 = mob.global_position - target.global_position
		offset.y = 0.0
		if offset.length() <= SPLASH_RADIUS and ignite(mob) != null:
			caught += 1
	return caught


## The burn on `target`, or null.
static func on(target: Node) -> Burn:
	if target == null or not is_instance_valid(target):
		return null
	return target.get_node_or_null(NODE_NAME) as Burn


func _physics_process(delta: float) -> void:
	_elapsed += delta
	var target: Node = get_parent()
	while ticks < TICKS and _elapsed >= TICK_SECONDS * (ticks + 1):
		ticks += 1
		if target != null and target.get("current_hp") != null and int(target.get("current_hp")) <= 0:
			break
		# No source: a tick pushes nothing back, and the mob still credits
		# the hit that set it burning.
		target.take_damage(DAMAGE, null)
	if ticks >= TICKS or _elapsed >= SECONDS:
		queue_free()
