class_name PebbleShot
extends Node3D

## PebbleShot
##
## A slingshot pebble (feature 034): flies in a short arc from the
## shooter's hand to the target and deals its damage on arrival. If the
## target died or left on the way, the pebble just lands.

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


## Fires a pebble from `shooter` at `target`. Returns the pebble.
static func fire(shooter: Node3D, target: Node3D, damage: int) -> PebbleShot:
	var shot: PebbleShot = PebbleShot.new()
	shot._shooter = shooter
	shot._target = target
	shot._damage = damage
	var facing: Vector3 = target.global_position - shooter.global_position
	facing.y = 0.0
	shot._from = shooter.global_position + Vector3(0, HAND_HEIGHT, 0) + facing.normalized() * 0.3
	shot._to = target.global_position + Vector3(0, TARGET_HEIGHT, 0)
	shooter.get_tree().current_scene.add_child(shot)
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
	tween.tween_method(_fly, 0.0, 1.0, FLIGHT_SECONDS)
	tween.tween_callback(_land)


func _fly(t: float) -> void:
	if _target != null and is_instance_valid(_target):
		_to = _target.global_position + Vector3(0, TARGET_HEIGHT, 0)
	global_position = _from.lerp(_to, t) + Vector3(0, sin(t * PI) * ARC_HEIGHT, 0)


func _land() -> void:
	if _target != null and is_instance_valid(_target) and _target.is_in_group("mobs") and _target.has_method("take_damage"):
		var shooter: Node = _shooter if is_instance_valid(_shooter) else null
		_target.take_damage(_damage, shooter)
		Fx.burst(&"hit", global_position)
	queue_free()
