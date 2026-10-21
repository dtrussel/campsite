class_name PebbleShot
extends Node3D

## PebbleShot
##
## A slingshot pebble (feature 034): flies in a short arc from the
## shooter's hand to the target and deals its damage on arrival. If the
## target died or left on the way, the pebble just lands. The damage goes
## through HeroHits.strike, and Ricochet (perk cards) bounces a hit on to
## the next mob. With the Glow Sling's `pierce` tier the pebble flies on
## through its target to the next mob in its line (pierce_target).

const FLIGHT_SECONDS: float = 0.2
const ARC_HEIGHT: float = 0.45
const HAND_HEIGHT: float = 0.85
const TARGET_HEIGHT: float = 0.6

static var _mesh: SphereMesh = null

var _shooter: Node = null
var _target: Node3D = null
var _damage: int = 0
var _from: Vector3 = Vector3.ZERO
var _to: Vector3 = Vector3.ZERO
## A bounce (Ricochet) or a pierced pebble never bounces or pierces again.
var _is_bounce: bool = false
## Seconds before the flight starts.
var _delay: float = 0.0


## Fires a pebble from `shooter` at `target`. Returns the pebble. A
## `delay` holds it in the hand that long before it flies (the Double
## Sling's second pebble).
static func fire(shooter: Node3D, target: Node3D, damage: int, delay: float = 0.0) -> PebbleShot:
	var facing: Vector3 = target.global_position - shooter.global_position
	facing.y = 0.0
	var from: Vector3 = shooter.global_position + Vector3(0, HAND_HEIGHT, 0) + facing.normalized() * 0.3
	return _launch(shooter, from, target, damage, false, delay)


## Bounces a pebble that hit at `from` on to `target` (Ricochet).
static func bounce(shooter: Node, from: Vector3, target: Node3D, damage: int) -> PebbleShot:
	return _launch(shooter, from, target, damage, true)


static func _launch(shooter: Node, from: Vector3, target: Node3D, damage: int, is_bounce: bool, delay: float = 0.0) -> PebbleShot:
	var shot: PebbleShot = PebbleShot.new()
	shot._delay = delay
	shot._shooter = shooter
	shot._target = target
	shot._damage = damage
	shot._is_bounce = is_bounce
	shot._from = from
	shot._to = target.global_position + Vector3(0, TARGET_HEIGHT, 0)
	target.get_tree().current_scene.add_child(shot)
	shot.global_position = shot._from
	return shot


func _ready() -> void:
	if _mesh == null:
		_mesh = SphereMesh.new()
		_mesh.radius = 0.08
		_mesh.height = 0.14
		_mesh.radial_segments = 8
		_mesh.rings = 4
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = Color(0.62, 0.56, 0.5)
		material.roughness = 0.9
		_mesh.material = material
	var stone: MeshInstance3D = MeshInstance3D.new()
	stone.mesh = _mesh
	stone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(stone)
	var tween: Tween = create_tween()
	if _delay > 0.0:
		stone.visible = false
		tween.tween_interval(_delay)
		tween.tween_callback(stone.show)
	tween.tween_method(_fly, 0.0, 1.0, FLIGHT_SECONDS)
	tween.tween_callback(_land)


func _fly(t: float) -> void:
	if _target != null and is_instance_valid(_target):
		_to = _target.global_position + Vector3(0, TARGET_HEIGHT, 0)
	global_position = _from.lerp(_to, t) + Vector3(0, sin(t * PI) * ARC_HEIGHT, 0)


func _land() -> void:
	if _target != null and is_instance_valid(_target) and _target.is_in_group("mobs") and _target.has_method("take_damage"):
		var shooter: Node = _shooter if is_instance_valid(_shooter) else null
		HeroHits.strike(shooter, _target, _damage)
		Fx.burst(&"hit", global_position)
		if not _is_bounce:
			for next in HeroHits.extra_targets(shooter, _target, &"pebble"):
				PebbleShot.bounce(shooter, global_position, next, _damage)
			var pierce: ToolTier = (shooter as Hero).tool_effect_tier(&"pierce") if shooter is Hero else null
			if pierce != null:
				var behind: Node3D = pierce_target(_target, _to - _from, pierce.pierce_reach, pierce.pierce_width)
				if behind != null:
					PebbleShot.bounce(shooter, global_position, behind, _damage)
	queue_free()


## The mob a pebble flying along `direction` meets next after `hit`: the
## nearest living mob ahead of `hit` along that line, within `reach`
## and no more than `width` off it (flat metres). Null if there is none.
static func pierce_target(hit: Node3D, direction: Vector3, reach: float, width: float) -> Node3D:
	direction.y = 0.0
	if hit == null or not is_instance_valid(hit) or not hit.is_inside_tree() or direction.length_squared() < 0.0001:
		return null
	direction = direction.normalized()
	var best: Node3D = null
	var best_along: float = INF
	for node in hit.get_tree().get_nodes_in_group("mobs"):
		var mob: Mob = node as Mob
		if mob == null or mob == hit or not is_instance_valid(mob) or not mob.is_alive():
			continue
		var offset: Vector3 = mob.global_position - hit.global_position
		offset.y = 0.0
		var along: float = offset.dot(direction)
		if along <= 0.0 or along > reach or (offset - direction * along).length() > width:
			continue
		if along < best_along:
			best = mob
			best_along = along
	return best
