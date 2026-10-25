class_name HeadLook
extends RefCounted

## HeadLook
##
## What a hero looks at: the head look-at's target order, the same for
## the player's hero and the companion. The hero picks a focus with it
## every frame and hands it to its visual (`CharacterVisual.set_look_focus`),
## whose HeadLookModifier turns the head and chest.
##
##   1. the attack target while fighting;
##   2. the resource or building being worked on (gathering, building,
##      repairing);
##   3. the nearest mob within MOB_WATCH_RADIUS while idle at night;
##   4. otherwise the other hero, while a glance is due (`Glance`).

## How near a mob must be to draw an idle hero's look at night (metres).
const MOB_WATCH_RADIUS: float = 6.0


## The node to look at, or null for straight ahead. `hero_position` is
## the hero's; `mobs` the mobs to watch; `glancing` is true while a
## glance at `other_hero` is due. Freed nodes are skipped (untyped, so a
## freed node can be passed).
static func pick(hero_position: Vector3, fight_target: Variant, work_target: Variant, idle_at_night: bool,
		mobs: Array, other_hero: Variant, glancing: bool) -> Node3D:
	if is_instance_valid(fight_target):
		return fight_target
	if is_instance_valid(work_target):
		return work_target
	if idle_at_night:
		var best: Node3D = null
		var best_d_sq: float = MOB_WATCH_RADIUS * MOB_WATCH_RADIUS
		for mob in mobs:
			if not is_instance_valid(mob) or not mob is Node3D:
				continue
			var d_sq: float = _where(mob as Node3D).distance_squared_to(hero_position)
			if d_sq < best_d_sq:
				best_d_sq = d_sq
				best = mob as Node3D
		if best != null:
			return best
	if glancing and is_instance_valid(other_hero):
		return other_hero
	return null


## Where `node` is: its global position, or its own position while it is
## outside the tree (the unit tests).
static func _where(node: Node3D) -> Vector3:
	return node.global_position if node.is_inside_tree() else node.position


## The "now and then" of glancing at the other hero: a glance of
## GLANCE_SECONDS every GAP_MIN..GAP_MAX seconds.
class Glance:
	extends RefCounted

	const GAP_MIN: float = 5.0
	const GAP_MAX: float = 11.0
	const GLANCE_SECONDS: float = 1.4

	var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var _until_next: float = 0.0
	var _left: float = 0.0

	func _init() -> void:
		_rng.randomize()
		_until_next = _rng.randf_range(GAP_MIN, GAP_MAX)

	## Advances the schedule; true while a glance is due.
	func tick(delta: float) -> bool:
		if _left > 0.0:
			_left -= delta
			return _left > 0.0
		_until_next -= delta
		if _until_next <= 0.0:
			_until_next = _rng.randf_range(GAP_MIN, GAP_MAX)
			_left = GLANCE_SECONDS
			return true
		return false
