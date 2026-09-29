class_name WorldAmbience
extends Node3D

## WorldAmbience
##
## Small living touches over the play area (feature 024):
##   day   - autumn leaves drifting down across the meadow, pollen motes
##           floating around the camp;
##   night - fireflies wandering low over the grass, twinkling.
## Emitters switch with TimeManager's phase; running particles finish
## their lives, so the change is a soft crossfade.

@export var extent: float = 16.0

var leaves: CPUParticles3D = null
var pollen: CPUParticles3D = null
var fireflies: CPUParticles3D = null


func _ready() -> void:
	leaves = _make_leaves()
	pollen = _make_pollen()
	fireflies = _make_fireflies()
	for particles in [leaves, pollen, fireflies]:
		add_child(particles)
	TimeManager.phase_changed.connect(_on_phase_changed)
	_on_phase_changed(TimeManager.current_phase)


func _on_phase_changed(phase: int) -> void:
	var night: bool = phase == TimeManager.Phase.NIGHT
	leaves.emitting = not night
	pollen.emitting = phase == TimeManager.Phase.DAY or phase == TimeManager.Phase.DAWN
	fireflies.emitting = night or phase == TimeManager.Phase.SUNSET


func _base(amount: int, lifetime: float, size: Vector2, additive: bool) -> CPUParticles3D:
	var particles: CPUParticles3D = CPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = lifetime
	particles.preprocess = lifetime  # already in the air on the first frame
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	var quad: QuadMesh = QuadMesh.new()
	quad.size = size
	quad.material = Fx.particle_material(additive)
	particles.mesh = quad
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.set_meta(&"stylized", "skip")
	return particles


func _make_leaves() -> CPUParticles3D:
	var particles: CPUParticles3D = _base(36, 9.0, Vector2(0.32, 0.2), false)
	particles.position = Vector3(0, 7.0, 0)
	particles.emission_box_extents = Vector3(extent, 0.5, extent)
	particles.direction = Vector3(1, -0.2, 0.4)
	particles.spread = 40.0
	particles.initial_velocity_min = 0.2
	particles.initial_velocity_max = 0.6
	particles.gravity = Vector3(0.35, -0.8, 0.15)
	particles.damping_min = 0.3
	particles.damping_max = 0.6
	particles.angle_min = -180.0
	particles.angle_max = 180.0
	particles.angular_velocity_min = -120.0
	particles.angular_velocity_max = 120.0
	var tints: Gradient = Gradient.new()
	tints.set_color(0, Color(0.95, 0.55, 0.18))
	tints.set_color(1, Color(0.6, 0.78, 0.25))
	tints.add_point(0.5, Color(0.9, 0.35, 0.15))
	particles.color_initial_ramp = tints
	var fade: Gradient = Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.add_point(0.1, Color(1, 1, 1, 0.9))
	fade.add_point(0.85, Color(1, 1, 1, 0.9))
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
	particles.color_ramp = fade
	return particles


func _make_pollen() -> CPUParticles3D:
	var particles: CPUParticles3D = _base(40, 7.0, Vector2(0.1, 0.1), true)
	particles.position = Vector3(0, 1.2, 0)
	particles.emission_box_extents = Vector3(9.0, 0.8, 9.0)
	particles.direction = Vector3(0, 1, 0)
	particles.spread = 180.0
	particles.initial_velocity_min = 0.02
	particles.initial_velocity_max = 0.12
	particles.gravity = Vector3(0.05, 0.03, 0.0)
	var glow: Gradient = Gradient.new()
	glow.set_color(0, Color(1.0, 0.95, 0.6, 0.0))
	glow.add_point(0.3, Color(1.0, 0.95, 0.6, 0.6))
	glow.add_point(0.7, Color(1.0, 0.95, 0.6, 0.6))
	glow.set_color(glow.get_point_count() - 1, Color(1.0, 0.95, 0.6, 0.0))
	particles.color_ramp = glow
	return particles


func _make_fireflies() -> CPUParticles3D:
	var particles: CPUParticles3D = _base(80, 6.0, Vector2(0.3, 0.3), true)
	particles.position = Vector3(0, 0.9, 0)
	particles.emission_box_extents = Vector3(extent, 0.6, extent)
	particles.direction = Vector3(0, 0.3, 1)
	particles.spread = 180.0
	particles.initial_velocity_min = 0.15
	particles.initial_velocity_max = 0.45
	particles.gravity = Vector3.ZERO
	particles.damping_min = 0.05
	particles.damping_max = 0.2
	# Twinkle: blink on and off a few times over a life.
	var blink: Gradient = Gradient.new()
	blink.set_color(0, Color(0.85, 1.0, 0.45, 0.0))
	for i in range(1, 6):
		var t: float = float(i) / 6.0
		blink.add_point(t - 0.06, Color(1.0, 1.0, 0.55, 1.0))
		blink.add_point(t, Color(0.75, 1.0, 0.35, 0.15))
	blink.set_color(blink.get_point_count() - 1, Color(0.75, 1.0, 0.35, 0.0))
	particles.color_ramp = blink
	return particles
