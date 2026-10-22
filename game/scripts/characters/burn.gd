class_name Burn
extends Node

## Burn
##
## The Ember Stick's burn: a mob a burning hit lands on takes the burn
## tier's `burn_damage` every `burn_tick_seconds`, `burn_ticks` times
## (ToolTier). Lives as a child of the mob and frees itself when done. A
## new burning hit on a burning mob starts the burn over (it never
## stacks).
##
##   Burn.ignite(mob, tier)               # from Hero.on_attack_hit
##   Burn.splash(mob, radius, tier)       # the Blaze Stick: the mobs beside it too
##   Burn.on(mob)                         # the mob's burn, or null

const NODE_NAME: String = "Burn"

## Ticks dealt since the burn (re)started.
var ticks: int = 0
var _elapsed: float = 0.0
var _damage: int = 0
var _tick_seconds: float = 1.0
var _ticks_in_all: int = 0


## Sets `target` burning (or starts its burn over) with the numbers of
## the `tier` that burns. The mob credits the hit that lit it; the ticks
## push nothing back. Ignored for anything that can't take damage or is
## already dead.
static func ignite(target: Node, tier: ToolTier) -> Burn:
	if tier == null or target == null or not is_instance_valid(target) or not target.has_method("take_damage") \
			or not target.is_inside_tree():
		return null
	if target is Mob and not (target as Mob).is_alive():
		return null
	var burn: Burn = on(target)
	if burn == null:
		burn = Burn.new()
		burn.name = NODE_NAME
		target.add_child(burn)
	burn._damage = tier.burn_damage
	burn._tick_seconds = maxf(tier.burn_tick_seconds, 0.01)
	burn._ticks_in_all = tier.burn_ticks
	burn._elapsed = 0.0
	burn.ticks = 0
	return burn


## Sets every living mob within `radius` (flat metres) of `target`
## burning with the `tier` that burns (not `target` itself). Returns how
## many caught.
static func splash(target: Node3D, radius: float, tier: ToolTier) -> int:
	if target == null or not is_instance_valid(target) or not target.is_inside_tree():
		return 0
	var caught: int = 0
	for node in target.get_tree().get_nodes_in_group("mobs"):
		var mob: Node3D = node as Node3D
		if mob == null or mob == target or not is_instance_valid(mob):
			continue
		var offset: Vector3 = mob.global_position - target.global_position
		offset.y = 0.0
		if offset.length() <= radius and ignite(mob, tier) != null:
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
	while ticks < _ticks_in_all and _elapsed >= _tick_seconds * (ticks + 1):
		ticks += 1
		if target is Mob and not (target as Mob).is_alive():
			break
		# No source: a tick pushes nothing back, and the mob still credits
		# the hit that set it burning.
		target.take_damage(_damage, null)
	if ticks >= _ticks_in_all or _elapsed >= _tick_seconds * _ticks_in_all:
		queue_free()
