extends CPUParticles3D

## ShadowAura
##
## The Shadow Imp's smoky aura (concept 08): glowing
## violet puffs that rise off the imp and trail behind it as it runs, plus a
## few glowing violet motes. Emits in world space, so the smoke is left
## behind on the move. Stops emitting when the imp is defeated.

@export var height: float = 0.55
@export var radius: float = 0.42
@export var motes: int = 8


func _ready() -> void:
	_setup_smoke()
	if motes > 0:
		add_child(_make_motes())
	var mob: Node = get_parent()
	if mob != null and mob.has_signal(&"defeated"):
		mob.connect(&"defeated", _on_defeated)


func _setup_smoke() -> void:
	amount = 24
	lifetime = 1.2
	local_coords = false
	position = Vector3(0, height, 0)
	emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	emission_sphere_radius = radius
	direction = Vector3.UP
	spread = 30.0
	initial_velocity_min = 0.5
	initial_velocity_max = 1.0
	gravity = Vector3(0, 0.7, 0)
	damping_min = 0.4
	damping_max = 0.9
	scale_amount_min = 0.8
	scale_amount_max = 1.2
	var curve: Curve = Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(0.35, 1.0))
	curve.add_point(Vector2(1, 1.3))
	scale_amount_curve = curve
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, Color(0.6, 0.25, 1.0, 0.0))
	ramp.set_color(1, Color(0.2, 0.04, 0.4, 0.0))
	ramp.add_point(0.2, Color(0.55, 0.2, 0.95, 0.6))
	ramp.add_point(0.6, Color(0.36, 0.1, 0.7, 0.35))
	color_ramp = ramp
	# Additive: a glowing violet flare against the night, as in concept 08.
	mesh = _quad(true)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _make_motes() -> CPUParticles3D:
	var sparks: CPUParticles3D = CPUParticles3D.new()
	sparks.amount = motes
	sparks.lifetime = 1.1
	sparks.local_coords = false
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = radius * 1.1
	sparks.direction = Vector3.UP
	sparks.spread = 40.0
	sparks.initial_velocity_min = 0.4
	sparks.initial_velocity_max = 0.9
	sparks.gravity = Vector3(0, 0.3, 0)
	sparks.scale_amount_min = 0.1
	sparks.scale_amount_max = 0.17
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, Color(1.0, 0.55, 1.0, 1.0))
	ramp.set_color(1, Color(0.55, 0.2, 1.0, 0.0))
	sparks.color_ramp = ramp
	sparks.mesh = _quad(true)
	sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return sparks


func _quad(additive: bool) -> QuadMesh:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = Fx.particle_material(additive)
	return quad


func _on_defeated(_mob: Node) -> void:
	emitting = false
	for child in get_children():
		if child is CPUParticles3D:
			(child as CPUParticles3D).emitting = false
