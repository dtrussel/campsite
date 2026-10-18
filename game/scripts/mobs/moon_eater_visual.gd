class_name MoonEaterVisual
extends Node3D

## MoonEaterVisual
##
## The Moon-Eater's code-built stand-in (feature 038) until the team's
## concept art and animations arrive: a huge, hunched, moon-dark shadow
## with glowing eyes, a hollow belly where the swallowed moonlight
## shines through, and lost things caught in its body (a teddy, a boot,
## branches). Its clips are tweens on a few pivots and share
## CharacterVisual's calls, so BossController drives either one:
##   rise, idle, move, stomp, sweep, summon, stagger, reach, shrink.
## `reach` holds its pose until another clip (or `idle`) plays.
## Front is +Z, like the imported models.

const BODY_COLOR: Color = Color(0.13, 0.12, 0.24)
const WARM_COLOR: Color = Color(0.42, 0.26, 0.2)
const EYE_COLOR: Color = Color(1.0, 0.86, 0.5)
## How far below the ground it starts its rise.
const RISE_DEPTH: float = 5.2
const TURN_SPEED: float = 2.5

## The stand-in is ~5 m tall at scale 1 (the scene uses 0.72).
@export var model_scale: float = 1.0

var _rig: Node3D = null
var _head: Node3D = null
var _arm_l: Node3D = null
var _arm_r: Node3D = null
var _body_material: StandardMaterial3D = null
## The painted shader Stylize made from _body_material (the shrink warms it).
var _body_shader: ShaderMaterial = null
var _eye_material: StandardMaterial3D = null
var _belly_material: StandardMaterial3D = null
var _belly_light: OmniLight3D = null
var _wisps: CPUParticles3D = null
var _action: Tween = null
var _action_left: float = 0.0
var _locked: bool = false
var _hold: StringName = &""
var _speed: float = 0.0
var _time: float = 0.0
var _belly: float = 1.0


func _ready() -> void:
	_build()
	scale = Vector3.ONE * model_scale


## Smoothly turns toward a planar direction (slow: it is huge).
func face(direction: Vector3, delta: float) -> void:
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return
	rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), clampf(TURN_SPEED * delta, 0.0, 1.0))


func face_instantly(direction: Vector3) -> void:
	direction.y = 0.0
	if direction.length_squared() > 0.0001:
		rotation.y = atan2(direction.x, direction.z)


func set_locomotion(speed: float) -> void:
	_speed = speed


func is_in_action() -> bool:
	return _action_left > 0.0 or _locked or _hold != &""


## How bright the swallowed moonlight in its belly shines (0..1).
func set_belly(glow: float) -> void:
	_belly = clampf(glow, 0.0, 1.0)
	_belly_material.emission_energy_multiplier = 0.4 + 2.2 * _belly
	_belly_light.light_energy = 0.3 + 1.6 * _belly


## Plays a clip; returns how long it lasts. `windup` is the seconds
## before the blow lands (stomp, sweep).
func play_action(state: StringName, windup: float = 0.9) -> float:
	if _locked:
		return 0.0
	_end_action()
	_hold = &""
	var seconds: float = 0.0
	match state:
		&"rise":
			seconds = _rise()
		&"stomp":
			seconds = _stomp(windup)
		&"sweep":
			seconds = _sweep(windup)
		&"summon":
			seconds = _summon()
		&"stagger", &"hit":
			seconds = _stagger(1.0 if state == &"stagger" else 0.35)
		&"reach":
			seconds = _reach()
		&"idle":
			seconds = _rest()
	_action_left = seconds
	return seconds


## The last clip (the shrink ending); nothing plays after it.
func play_final(state: StringName) -> float:
	var seconds: float = 0.0
	if state == &"shrink":
		_end_action()
		seconds = _shrink()
	_locked = true
	return seconds


func _process(delta: float) -> void:
	_time += delta
	_action_left = maxf(0.0, _action_left - delta)
	if _rig == null or is_in_action():
		return
	# Idle: a slow, heavy breath; walking: a lumbering side-to-side sway.
	var walk: float = clampf(_speed / 1.2, 0.0, 1.0)
	var breath: float = sin(_time * TAU * 0.3)
	_rig.scale = Vector3(1.0 - 0.015 * breath, 1.0 + 0.025 * breath, 1.0)
	_rig.rotation.z = sin(_time * TAU * 0.55) * 0.07 * walk
	_rig.position.y = absf(sin(_time * TAU * 0.55)) * 0.12 * walk
	_arm_l.rotation = Vector3(sin(_time * TAU * 0.55) * 0.25 * walk + 0.05 * breath, 0.0, -0.12)
	_arm_r.rotation = Vector3(-sin(_time * TAU * 0.55) * 0.25 * walk + 0.05 * breath, 0.0, 0.12)
	_head.rotation = Vector3(0.05 * breath, sin(_time * 0.4) * 0.15, 0.0)


# --- Clips -------------------------------------------------------------------

func _tween() -> Tween:
	_action = create_tween()
	return _action


func _end_action() -> void:
	if _action != null and _action.is_valid():
		_action.kill()
	_action = null
	_action_left = 0.0


func _rise() -> float:
	var seconds: float = 2.6
	_rig.position.y = -RISE_DEPTH
	var tween: Tween = _tween()
	tween.tween_property(_rig, "position:y", 0.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_arm_l, "rotation", Vector3(-2.4, 0, -0.5), seconds * 0.6)
	tween.parallel().tween_property(_arm_r, "rotation", Vector3(-2.4, 0, 0.5), seconds * 0.6)
	tween.tween_property(_arm_l, "rotation", Vector3(0, 0, -0.12), 0.5)
	tween.parallel().tween_property(_arm_r, "rotation", Vector3(0, 0, 0.12), 0.5)
	return seconds + 0.5


## Both fists high over its head, then down on the ring.
func _stomp(windup: float) -> float:
	var tween: Tween = _tween()
	tween.tween_property(_arm_l, "rotation", Vector3(-2.8, 0, -0.25), windup).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(_arm_r, "rotation", Vector3(-2.8, 0, 0.25), windup).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(_rig, "rotation:x", -0.12, windup)
	tween.parallel().tween_property(_rig, "position:y", 0.45, windup)
	tween.tween_property(_arm_l, "rotation", Vector3(-0.6, 0, -0.1), 0.12).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_arm_r, "rotation", Vector3(-0.6, 0, 0.1), 0.12).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_rig, "rotation:x", 0.22, 0.12)
	tween.parallel().tween_property(_rig, "position:y", -0.15, 0.12)
	tween.parallel().tween_property(_rig, "scale", Vector3(1.08, 0.9, 1.08), 0.12)
	tween.tween_interval(0.35)
	tween.tween_property(_rig, "rotation:x", 0.0, 0.5)
	tween.parallel().tween_property(_rig, "position:y", 0.0, 0.5)
	tween.parallel().tween_property(_rig, "scale", Vector3.ONE, 0.5)
	return windup + 0.12 + 0.35 + 0.5


## The right arm swings back, then across the front.
func _sweep(windup: float) -> float:
	var tween: Tween = _tween()
	tween.tween_property(_arm_r, "rotation", Vector3(-1.3, -1.2, 1.0), windup).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(_rig, "rotation:y", -0.5, windup)
	tween.tween_property(_arm_r, "rotation", Vector3(-1.4, 1.4, -0.4), 0.22).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_rig, "rotation:y", 0.6, 0.22)
	tween.tween_interval(0.25)
	tween.tween_property(_arm_r, "rotation", Vector3(0, 0, 0.12), 0.55)
	tween.parallel().tween_property(_rig, "rotation:y", 0.0, 0.55)
	return windup + 0.22 + 0.25 + 0.55


## Arms wide, head back, the belly flaring: it calls the lost things.
func _summon() -> float:
	var tween: Tween = _tween()
	tween.tween_property(_arm_l, "rotation", Vector3(-0.4, 0, -1.6), 0.5)
	tween.parallel().tween_property(_arm_r, "rotation", Vector3(-0.4, 0, 1.6), 0.5)
	tween.parallel().tween_property(_head, "rotation:x", -0.5, 0.5)
	tween.parallel().tween_property(_rig, "scale", Vector3(1.06, 1.06, 1.06), 0.5)
	tween.tween_interval(0.8)
	tween.tween_property(_arm_l, "rotation", Vector3(0, 0, -0.12), 0.5)
	tween.parallel().tween_property(_arm_r, "rotation", Vector3(0, 0, 0.12), 0.5)
	tween.parallel().tween_property(_head, "rotation:x", 0.0, 0.5)
	tween.parallel().tween_property(_rig, "scale", Vector3.ONE, 0.5)
	return 1.8


func _stagger(seconds: float) -> float:
	var tween: Tween = _tween()
	var steps: int = maxi(1, int(seconds / 0.2))
	for i in steps:
		var side: float = 1.0 if i % 2 == 0 else -1.0
		var amount: float = 0.2 * (1.0 - float(i) / float(steps))
		tween.tween_property(_rig, "rotation:z", side * amount, seconds / float(steps + 1))
		tween.parallel().tween_property(_rig, "rotation:x", -amount * 0.6, seconds / float(steps + 1))
	tween.tween_property(_rig, "rotation", Vector3.ZERO, seconds / float(steps + 1))
	return seconds


## Bent over, both hands cupped forward round the Moon Lantern. Holds
## until the next clip.
func _reach() -> float:
	_hold = &"reach"
	var tween: Tween = _tween()
	tween.tween_property(_rig, "rotation:x", 0.35, 0.8).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(_arm_l, "rotation", Vector3(-1.2, 0.35, -0.1), 0.8)
	tween.parallel().tween_property(_arm_r, "rotation", Vector3(-1.2, -0.35, 0.1), 0.8)
	tween.parallel().tween_property(_head, "rotation:x", 0.3, 0.8)
	return 0.8


## Back to standing from a held pose.
func _rest() -> float:
	var tween: Tween = _tween()
	tween.tween_property(_rig, "rotation", Vector3.ZERO, 0.5)
	tween.parallel().tween_property(_arm_l, "rotation", Vector3(0, 0, -0.12), 0.5)
	tween.parallel().tween_property(_arm_r, "rotation", Vector3(0, 0, 0.12), 0.5)
	tween.parallel().tween_property(_head, "rotation", Vector3.ZERO, 0.5)
	return 0.5


## It lets the moon go: the belly light streams up, and it shrinks into
## a small, warm shadow.
func _shrink() -> float:
	var tween: Tween = _tween()
	tween.tween_property(_rig, "rotation", Vector3(-0.25, 0, 0), 0.8)
	tween.parallel().tween_property(_arm_l, "rotation", Vector3(-0.5, 0, -1.2), 0.8)
	tween.parallel().tween_property(_arm_r, "rotation", Vector3(-0.5, 0, 1.2), 0.8)
	tween.parallel().tween_property(_head, "rotation:x", -0.6, 0.8)
	tween.tween_method(set_belly, _belly, 0.0, 1.6)
	tween.tween_property(_rig, "scale", Vector3.ONE * 0.24, 2.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	if _body_shader != null:
		tween.parallel().tween_method(func(c: Color) -> void: _body_shader.set_shader_parameter("albedo_color", c),
			BODY_COLOR, WARM_COLOR, 2.0)
	tween.parallel().tween_property(_eye_material, "emission", Color(1.0, 0.7, 0.35), 2.0)
	tween.parallel().tween_property(_rig, "rotation", Vector3.ZERO, 2.0)
	tween.parallel().tween_property(_arm_l, "rotation", Vector3(-0.3, 0, -0.3), 2.0)
	tween.parallel().tween_property(_arm_r, "rotation", Vector3(-0.3, 0, 0.3), 2.0)
	tween.parallel().tween_property(_head, "rotation:x", 0.15, 2.0)
	tween.parallel().tween_property(_belly_light, "light_color", Color(1.0, 0.7, 0.4), 2.0)
	tween.parallel().tween_property(_belly_material, "emission", Color(1.0, 0.62, 0.32), 2.0)
	tween.tween_callback(func() -> void: _wisps.emitting = false)
	# A small warm glow of its own, like a coal by the fire.
	tween.tween_method(set_belly, 0.0, 0.35, 1.0)
	return 0.8 + 1.6 + 2.0


# --- Model -------------------------------------------------------------------

func _build() -> void:
	_rig = Node3D.new()
	_rig.name = "Rig"
	add_child(_rig)
	_body_material = _painted(BODY_COLOR)
	var bark: StandardMaterial3D = _painted(Color(0.3, 0.2, 0.13))
	var toy: StandardMaterial3D = _painted(Color(0.72, 0.42, 0.24))
	var boot: StandardMaterial3D = _painted(Color(0.38, 0.22, 0.14))
	var lace: StandardMaterial3D = _painted(Color(0.75, 0.2, 0.15))

	# A hunched, pear-shaped body and a big hump of shoulders.
	_part(_rig, _sphere(1.55, 3.7), _body_material, Vector3(0, 1.8, 0), Vector3(1.2, 1.0, 1.0))
	_part(_rig, _sphere(1.3, 2.2), _body_material, Vector3(0, 3.35, -0.15), Vector3(1.35, 0.85, 1.05))
	# Smoky skirts round the base.
	for i in 7:
		var angle: float = TAU * i / 7.0
		var lump: MeshInstance3D = _part(_rig, _sphere(0.6, 1.0), _body_material,
			Vector3(cos(angle) * 1.45, 0.3, sin(angle) * 1.2), Vector3(1.2, 0.7, 1.2))
		lump.rotation.y = angle

	_head = Node3D.new()
	_head.name = "Head"
	_head.position = Vector3(0, 3.9, 0.55)
	_rig.add_child(_head)
	_part(_head, _sphere(0.95, 1.6), _body_material, Vector3.ZERO, Vector3(1.15, 1.0, 1.0))
	# Little horns of tangled twig.
	for side in [-1.0, 1.0]:
		var horn: MeshInstance3D = _part(_head, _cylinder(0.03, 0.09, 0.9), bark, Vector3(0.55 * side, 0.75, -0.1))
		horn.rotation = Vector3(-0.3, 0, -0.55 * side)

	# The hollow belly: a dark rim round the swallowed moon.
	var rim: TorusMesh = TorusMesh.new()
	rim.inner_radius = 0.62
	rim.outer_radius = 0.95
	var rim_mesh: MeshInstance3D = _part(_rig, rim, _body_material, Vector3(0, 1.95, 1.48))
	rim_mesh.rotation.x = PI / 2.0

	# Long, heavy arms from the shoulders.
	_arm_l = _arm(-1.0)
	_arm_r = _arm(1.0)

	# Lost things caught in it: a teddy on the shoulder, a boot in its
	# side, and branches poking out of its back.
	var teddy: Node3D = Node3D.new()
	teddy.position = Vector3(-1.05, 3.85, 0.55)
	teddy.rotation = Vector3(0.3, 0.4, 0.5)
	_rig.add_child(teddy)
	_part(teddy, _sphere(0.24, 0.5), toy, Vector3.ZERO, Vector3(1.0, 1.15, 0.9))
	_part(teddy, _sphere(0.18, 0.36), toy, Vector3(0, 0.36, 0))
	for side in [-1.0, 1.0]:
		_part(teddy, _sphere(0.07, 0.14), toy, Vector3(0.13 * side, 0.52, 0))
	var boot_node: Node3D = Node3D.new()
	boot_node.position = Vector3(1.55, 1.5, 0.45)
	boot_node.rotation = Vector3(0.2, -0.6, -0.7)
	_rig.add_child(boot_node)
	_part(boot_node, _box(Vector3(0.28, 0.5, 0.3)), boot, Vector3(0, 0.15, 0))
	_part(boot_node, _box(Vector3(0.3, 0.2, 0.55)), boot, Vector3(0, -0.15, 0.14))
	_part(boot_node, _box(Vector3(0.3, 0.04, 0.04)), lace, Vector3(0, 0.25, 0.16))
	for spec in [[Vector3(0.5, 3.6, -1.1), Vector3(-0.9, 0.3, 0.2), 1.8], [Vector3(-0.6, 3.2, -1.2), Vector3(-1.1, -0.4, -0.3), 1.5],
			[Vector3(0.1, 4.1, -0.7), Vector3(-0.5, 0.0, 0.1), 1.3], [Vector3(1.2, 2.6, -0.9), Vector3(-1.2, 0.6, 0.6), 1.2]]:
		var branch: MeshInstance3D = _part(_rig, _cylinder(0.025, 0.08, spec[2]), bark, spec[0])
		branch.rotation = spec[1]
		var twig: MeshInstance3D = _part(branch, _cylinder(0.015, 0.035, 0.5), bark, Vector3(0.05, float(spec[2]) * 0.3, 0))
		twig.rotation.z = 0.8
	Stylize.apply(_rig, "shadow")
	_body_shader = _first_material(_rig)

	# The glowing bits stay out of the painted look.
	_eye_material = StandardMaterial3D.new()
	_eye_material.albedo_color = EYE_COLOR
	_eye_material.emission_enabled = true
	_eye_material.emission = EYE_COLOR
	_eye_material.emission_energy_multiplier = 3.0
	for side in [-1.0, 1.0]:
		var eye: MeshInstance3D = _part(_head, _sphere(0.2, 0.4), _eye_material, Vector3(0.36 * side, 0.12, 0.84),
			Vector3(1.25, 0.65, 0.5))
		eye.name = "Eye"
		eye.rotation.z = -0.25 * side

	_belly_material = StandardMaterial3D.new()
	_belly_material.albedo_color = Color(0.75, 0.82, 1.0)
	_belly_material.emission_enabled = true
	_belly_material.emission = UiKit.COLOR_MOON
	_part(_rig, _sphere(0.66, 1.32), _belly_material, Vector3(0, 1.95, 1.18))
	_belly_light = OmniLight3D.new()
	_belly_light.light_color = Color(0.65, 0.75, 1.0)
	_belly_light.omni_range = 7.0
	_belly_light.position = Vector3(0, 2.0, 2.3)
	_belly_light.shadow_enabled = false
	_rig.add_child(_belly_light)
	set_belly(1.0)

	# Shadow smoke trailing off it, like the imps.
	_wisps = CPUParticles3D.new()
	_wisps.amount = 24
	_wisps.lifetime = 2.2
	_wisps.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_wisps.emission_sphere_radius = 1.6
	_wisps.direction = Vector3.UP
	_wisps.spread = 30.0
	_wisps.initial_velocity_min = 0.3
	_wisps.initial_velocity_max = 0.8
	_wisps.gravity = Vector3(0, 0.4, 0)
	_wisps.scale_amount_min = 0.4
	_wisps.scale_amount_max = 0.9
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, Color(0.3, 0.12, 0.5, 0.55))
	ramp.set_color(1, Color(0.05, 0.0, 0.12, 0.0))
	_wisps.color_ramp = ramp
	var quad: QuadMesh = QuadMesh.new()
	quad.material = Fx.particle_material(false)
	_wisps.mesh = quad
	_wisps.position.y = 1.4
	_rig.add_child(_wisps)


func _first_material(root: Node) -> ShaderMaterial:
	for child in root.get_children():
		var mesh: MeshInstance3D = child as MeshInstance3D
		if mesh != null and mesh.get_surface_override_material(0) is ShaderMaterial:
			return mesh.get_surface_override_material(0) as ShaderMaterial
	return null


func _arm(side: float) -> Node3D:
	var pivot: Node3D = Node3D.new()
	pivot.name = "ArmL" if side < 0.0 else "ArmR"
	pivot.position = Vector3(1.6 * side, 3.45, 0.2)
	_rig.add_child(pivot)
	var upper: MeshInstance3D = _part(pivot, _capsule(0.42, 2.9), _body_material, Vector3(0.15 * side, -1.35, 0.15))
	upper.rotation.z = 0.08 * side
	_part(pivot, _sphere(0.62, 1.1), _body_material, Vector3(0.25 * side, -2.85, 0.3), Vector3(1.0, 0.8, 1.15))
	return pivot


## Named like the painted assets, so Stylize gives it the painted
## shading and the imps' purple ink line.
func _painted(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.resource_name = "moon_eater" + Stylize.PAINTED_SUFFIX
	return material


func _sphere(radius: float, height: float) -> SphereMesh:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	mesh.rings = 12
	return mesh


func _capsule(radius: float, height: float) -> CapsuleMesh:
	var mesh: CapsuleMesh = CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	return mesh


func _cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 8
	return mesh


func _box(size: Vector3) -> BoxMesh:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	return mesh


## On the mesh itself (not an override), so Stylize can paint it.
func _part(parent: Node3D, mesh: PrimitiveMesh, material: Material, at: Vector3, stretch: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	mesh.material = material
	instance.mesh = mesh
	instance.position = at
	instance.scale = stretch
	parent.add_child(instance)
	return instance
