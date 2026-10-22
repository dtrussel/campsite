class_name Telegraph
extends Node3D

## Telegraph
##
## A warning drawn on the ground before a big blow lands:
## an outline of the area, and a fill that grows to the edge over the
## windup. The blow lands when the fill reaches the outline, so kids
## who step out of it in time are safe. A full circle is a stomp ring;
## a slice is a sweep.
##
##   Telegraph.show_at(parent, center, radius, windup)            # ring
##   Telegraph.show_at(parent, center, radius, windup, 140.0, yaw) # arc

const COLOR: Color = Color(1.0, 0.35, 0.55, 0.55)
const SEGMENTS: int = 48
const EDGE: float = 0.14

var radius: float = 3.0
var windup: float = 0.9
## Degrees of the slice (360 = a full ring), centred on +Z.
var arc_degrees: float = 360.0

var _fill: MeshInstance3D = null

## Fades both meshes (tweened after the blow lands).
var modulate_alpha: float = 1.0:
	set(value):
		modulate_alpha = value
		for child in get_children():
			var mesh: MeshInstance3D = child as MeshInstance3D
			if mesh != null:
				mesh.transparency = 1.0 - value


static func show_at(parent: Node, center: Vector3, ring_radius: float, seconds: float,
		arc: float = 360.0, yaw: float = 0.0) -> Telegraph:
	var telegraph: Telegraph = Telegraph.new()
	telegraph.radius = ring_radius
	telegraph.windup = seconds
	telegraph.arc_degrees = arc
	parent.add_child(telegraph)
	telegraph.global_position = Vector3(center.x, 0.06, center.z)
	telegraph.rotation.y = yaw
	return telegraph


func _ready() -> void:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = COLOR
	var outline: MeshInstance3D = MeshInstance3D.new()
	outline.mesh = _band(radius - EDGE, radius)
	outline.material_override = material
	outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(outline)
	var fill_material: StandardMaterial3D = material.duplicate() as StandardMaterial3D
	fill_material.albedo_color = Color(COLOR, 0.28)
	_fill = MeshInstance3D.new()
	_fill.mesh = _band(0.0, radius)
	_fill.material_override = fill_material
	_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fill.scale = Vector3(0.05, 1.0, 0.05)
	add_child(_fill)
	var tween: Tween = create_tween()
	tween.tween_property(_fill, "scale", Vector3.ONE, windup)
	tween.tween_property(self, "modulate_alpha", 0.0, 0.25)
	tween.tween_callback(queue_free)


## Whether a point is inside the warned area.
func covers(point: Vector3) -> bool:
	return Telegraph.in_area(global_position, rotation.y, radius, arc_degrees, point)


## The same test without a node: within `area_radius` of `center`, and
## inside the slice of `arc` degrees facing `yaw`.
static func in_area(center: Vector3, yaw: float, area_radius: float, arc: float, point: Vector3) -> bool:
	var offset: Vector3 = point - center
	offset.y = 0.0
	if offset.length() > area_radius:
		return false
	if arc >= 359.0 or offset.length() < 0.3:
		return true
	var forward: Vector3 = Vector3(sin(yaw), 0.0, cos(yaw))
	return rad_to_deg(forward.angle_to(offset)) <= arc * 0.5


## A flat ring band (or disc when inner is 0) over the slice.
func _band(inner: float, outer: float) -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var half: float = deg_to_rad(minf(arc_degrees, 360.0)) * 0.5
	var steps: int = maxi(6, int(SEGMENTS * arc_degrees / 360.0))
	for i in steps:
		var a0: float = -half + 2.0 * half * float(i) / float(steps)
		var a1: float = -half + 2.0 * half * float(i + 1) / float(steps)
		var d0: Vector3 = Vector3(sin(a0), 0.0, cos(a0))
		var d1: Vector3 = Vector3(sin(a1), 0.0, cos(a1))
		vertices.append_array([d0 * inner, d0 * outer, d1 * outer, d0 * inner, d1 * outer, d1 * inner])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
