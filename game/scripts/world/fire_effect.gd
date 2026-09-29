extends Node3D

## FireEffect
##
## Reusable stylized fire: a few flame shader quads, rising embers,
## soft smoke, and a flickering warm light. Used by the campfire (big)
## and planted torches (small). Built in code so scale is one number.

const FLAME_SHADER: Shader = preload("res://shaders/flame.gdshader")

@export var size: float = 1.0
@export var light_energy: float = 2.6
@export var light_range: float = 9.0
@export var light_color: Color = Color(1.0, 0.62, 0.3)
@export var smoke: bool = true
@export var flame_count: int = 3
## Light height above the flame base, in multiples of `size`.
@export var light_height: float = 0.9
## Loops the campfire crackle here; louder for bigger fires.
@export var crackle: bool = true

var _light: OmniLight3D = null
var _flicker_time: float = 0.0
var _base_energy: float = 0.0
var _flame_materials: Array[ShaderMaterial] = []


func _ready() -> void:
	for i in range(flame_count):
		var quad: QuadMesh = QuadMesh.new()
		quad.size = Vector2(0.9, 1.4) * size * (1.0 if i == 0 else 0.7)
		quad.center_offset = Vector3(0, quad.size.y * 0.5, 0)
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = FLAME_SHADER
		material.set_shader_parameter("seed", float(i) * 1.7)
		material.set_shader_parameter("speed", 1.4 + i * 0.25)
		quad.material = material
		_flame_materials.append(material)
		var flame: MeshInstance3D = MeshInstance3D.new()
		flame.mesh = quad
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var angle: float = TAU * float(i) / maxf(1.0, float(flame_count))
		flame.position = Vector3(cos(angle), 0, sin(angle)) * (0.0 if i == 0 else 0.18 * size)
		flame.set_meta(&"stylized", "skip")
		add_child(flame)

	add_child(_make_particles(
		18, 1.6, Color(1.0, 0.75, 0.3), Color(1.0, 0.3, 0.05, 0.0), 0.07 * size,
		Vector3(0, 0.6 * size, 0), 1.6 * size, true, 0.3 * size))
	if smoke:
		add_child(_make_particles(
			8, 3.2, Color(0.85, 0.82, 0.8, 0.1), Color(0.9, 0.9, 0.92, 0.0), 1.1 * size,
			Vector3(0, 1.9 * size, 0), 0.8 * size, false, 0.2 * size))

	_light = OmniLight3D.new()
	_light.light_color = light_color
	_light.light_energy = light_energy
	_light.omni_range = light_range
	_light.omni_attenuation = 1.2
	_light.shadow_enabled = false
	_light.position = Vector3(0, light_height * size, 0)
	add_child(_light)
	_base_energy = light_energy
	if crackle and AudioManager.library != null:
		var stream: AudioStream = AudioManager.library.ambience_campfire
		add_child(AudioManager.make_ambient_emitter(stream, linear_to_db(clampf(size, 0.05, 2.0)) - 2.0))


func _process(delta: float) -> void:
	if _light == null:
		return
	_flicker_time += delta
	var flicker: float = sin(_flicker_time * 13.0) * 0.06 + sin(_flicker_time * 7.3 + 1.3) * 0.08 \
		+ sin(_flicker_time * 23.0) * 0.03
	_light.light_energy = _base_energy * (1.0 + flicker)


func set_intensity(factor: float) -> void:
	_base_energy = light_energy * factor
	# Flames read hotter at night, softer against a bright day.
	for material in _flame_materials:
		material.set_shader_parameter("intensity", 1.25 * clampf(factor, 0.75, 1.3))


func _make_particles(amount: int, lifetime: float, start: Color, end: Color, particle_size: float,
		offset: Vector3, speed: float, additive: bool, spread_radius: float) -> CPUParticles3D:
	var particles: CPUParticles3D = CPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = lifetime
	particles.position = offset
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = spread_radius
	particles.direction = Vector3.UP
	particles.spread = 12.0
	particles.gravity = Vector3(0.15, 0.0, 0.05)
	particles.initial_velocity_min = speed * 0.5
	particles.initial_velocity_max = speed
	particles.scale_amount_min = particle_size * 0.6
	particles.scale_amount_max = particle_size
	var curve: Curve = Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1, 0.6 if not additive else 0.0))
	particles.scale_amount_curve = curve
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, start)
	ramp.set_color(1, end)
	particles.color_ramp = ramp
	var quad: QuadMesh = QuadMesh.new()
	quad.material = Fx.particle_material(additive)
	particles.mesh = quad
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return particles
