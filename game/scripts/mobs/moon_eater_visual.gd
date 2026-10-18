class_name MoonEaterVisual
extends Node3D

## MoonEaterVisual
##
## The Moon-Eater (feature 038), after the team's character sheet
## (art/reference/concept-2026-10/15_moon_eater_character_sheet.webp): a
## hulking golem of weathered planks and boulders lashed with rope, with
## long ape-like arms and huge wooden fists, a small plank head with two
## amber eyes, and a golden window of swallowed moonlight in its chest
## where its hoard floats (a chair, a teddy, a pocket watch).
##
## The model is art/characters/moon_eater.py, baked and painted like the
## other creatures. It is rigid, like a golem: one node per moving part
## (Body, Head, ArmL, ArmR, Hoard), each with its origin at its pivot,
## and the clips here are tweens on those nodes. They share
## CharacterVisual's calls, so BossController drives either one:
##   rise, idle, move, stomp, sweep, summon, stagger, reach, shrink.
## `reach` holds its pose until another clip (or `idle`) plays.
## The glowing parts (eyes, window, crescent) get materials from here,
## so the shrink can fade and warm them. Front is +Z.

const MODEL: PackedScene = preload("res://assets/custom/moon_eater.glb")
const CHIP_COLOR: Color = Color(0.5, 0.38, 0.27)
const EYE_COLOR: Color = Color(1.0, 0.8, 0.42)
## The swallowed moonlight: warm gold, as on the sheet.
const BELLY_COLOR: Color = Color(1.0, 0.74, 0.34)
## These match art/characters/moon_eater.py: the hunch (how far the body
## leans forward from the hips) and the chest window, which bulges out
## and tips up toward the high game camera.
const LEAN: float = 0.2
const HIP: Vector3 = Vector3(0, 1.45, 0)
const WINDOW: Vector3 = Vector3(0, 2.3, 1.55)
const WINDOW_TILT: float = -0.55
## How far below the ground it starts its rise.
const RISE_DEPTH: float = 5.2
const TURN_SPEED: float = 2.5

## The stand-in is ~5 m tall at scale 1 (the scene uses 0.72).
@export var model_scale: float = 1.0

var _rig: Node3D = null
var _head: Node3D = null
var _arm_l: Node3D = null
var _arm_r: Node3D = null
## The lost things in its chest; they float free in the shrink.
var _hoard: Node3D = null
var _eye_material: StandardMaterial3D = null
var _belly_material: StandardMaterial3D = null
var _moon_material: StandardMaterial3D = null
var _belly_light: OmniLight3D = null
var _motes: CPUParticles3D = null
var _debris: CPUParticles3D = null
var _hoard_home: Vector3 = Vector3.ZERO
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


## How bright the swallowed moonlight in its chest shines (0..1).
func set_belly(glow: float) -> void:
	_belly = clampf(glow, 0.0, 1.0)
	_belly_material.emission_energy_multiplier = 0.2 + 0.9 * _belly
	_moon_material.emission_energy_multiplier = 0.5 + 1.6 * _belly
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
	# Idle: a slow, heavy breath; walking: a lumbering side-to-side sway,
	# swinging the long arms like an ape.
	var walk: float = clampf(_speed / 1.2, 0.0, 1.0)
	var breath: float = sin(_time * TAU * 0.3)
	_rig.scale = Vector3(1.0 - 0.01 * breath, 1.0 + 0.015 * breath, 1.0)
	_rig.rotation.z = sin(_time * TAU * 0.55) * 0.07 * walk
	_rig.position.y = absf(sin(_time * TAU * 0.55)) * 0.12 * walk
	_arm_l.rotation = Vector3(sin(_time * TAU * 0.55) * 0.3 * walk + 0.04 * breath, 0.0, -0.12)
	_arm_r.rotation = Vector3(-sin(_time * TAU * 0.55) * 0.3 * walk + 0.04 * breath, 0.0, 0.12)
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


## Arms wide, head back, the chest flaring: it calls the lost things.
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


## Bent over, both fists forward round the Moon Lantern. Holds until
## the next clip.
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


## It lets the moon go: loose planks and stones tumble off, the lost
## things float up out of its chest and fade, the light streams away,
## and it settles into a small, warm golem.
func _shrink() -> float:
	var tween: Tween = _tween()
	tween.tween_property(_rig, "rotation", Vector3(-0.25, 0, 0), 0.8)
	tween.parallel().tween_property(_arm_l, "rotation", Vector3(-0.5, 0, -1.2), 0.8)
	tween.parallel().tween_property(_arm_r, "rotation", Vector3(-0.5, 0, 1.2), 0.8)
	tween.parallel().tween_property(_head, "rotation:x", -0.6, 0.8)
	tween.tween_callback(func() -> void: _debris.emitting = true)
	tween.tween_method(set_belly, _belly, 0.0, 1.6)
	tween.parallel().tween_property(_hoard, "position", _hoard_home + Vector3(0, 1.4, 1.0), 1.6).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(_hoard, "scale", Vector3.ONE * 0.01, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(_rig, "scale", Vector3.ONE * 0.24, 2.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(_eye_material, "emission", Color(1.0, 0.62, 0.3), 2.0)
	tween.parallel().tween_property(_rig, "rotation", Vector3.ZERO, 2.0)
	tween.parallel().tween_property(_arm_l, "rotation", Vector3(-0.3, 0, -0.3), 2.0)
	tween.parallel().tween_property(_arm_r, "rotation", Vector3(-0.3, 0, 0.3), 2.0)
	tween.parallel().tween_property(_head, "rotation:x", 0.15, 2.0)
	tween.parallel().tween_property(_belly_light, "light_color", Color(1.0, 0.6, 0.32), 2.0)
	tween.parallel().tween_property(_belly_material, "emission", Color(1.0, 0.55, 0.28), 2.0)
	tween.tween_callback(func() -> void: _motes.emitting = false)
	# A small warm glow of its own, like a coal by the fire.
	tween.tween_method(set_belly, 0.0, 0.35, 1.0)
	return 0.8 + 1.6 + 2.0


# --- Model -------------------------------------------------------------------

func _build() -> void:
	_rig = Node3D.new()
	_rig.name = "Rig"
	add_child(_rig)
	var model: Node3D = MODEL.instantiate() as Node3D
	_rig.add_child(model)
	var body: Node3D = _find(model, "Body")
	_head = _find(model, "Head")
	_arm_l = _find(model, "ArmL")
	_arm_r = _find(model, "ArmR")
	_hoard = _find(model, "Hoard")
	_hoard_home = _hoard.position
	# The heroes' warm brown ink line suits wood and stone better than
	# the imps' purple one.
	Stylize.apply(_rig, "hero")

	_eye_material = StandardMaterial3D.new()
	_eye_material.albedo_color = EYE_COLOR
	_eye_material.emission_enabled = true
	_eye_material.emission = EYE_COLOR
	_eye_material.emission_energy_multiplier = 1.2
	_belly_material = StandardMaterial3D.new()
	_belly_material.albedo_color = Color(0.5, 0.32, 0.14)
	_belly_material.emission_enabled = true
	_belly_material.emission = BELLY_COLOR
	_moon_material = StandardMaterial3D.new()
	_moon_material.albedo_color = Color(0.9, 0.86, 0.76)
	_moon_material.emission_enabled = true
	_moon_material.emission = Color(1.0, 0.94, 0.8)
	(_find(model, "Head_Eyes") as MeshInstance3D).material_override = _eye_material
	(_find(model, "Body_Window") as MeshInstance3D).material_override = _belly_material
	(_find(model, "Body_Moon") as MeshInstance3D).material_override = _moon_material

	# Where the window sits once the body leans.
	var lean: Basis = Basis(Vector3.RIGHT, LEAN)
	var window: Vector3 = Transform3D(lean, HIP - lean * HIP) * WINDOW
	var outward: Vector3 = Basis(Vector3.RIGHT, LEAN + WINDOW_TILT) * Vector3.BACK
	_belly_light = OmniLight3D.new()
	_belly_light.light_color = Color(1.0, 0.78, 0.48)
	_belly_light.omni_range = 7.0
	_belly_light.position = window + outward
	_belly_light.shadow_enabled = false
	body.add_child(_belly_light)
	set_belly(1.0)

	# Golden motes drifting up out of the window.
	_motes = CPUParticles3D.new()
	_motes.amount = 16
	_motes.lifetime = 2.4
	_motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_motes.emission_sphere_radius = 0.7
	_motes.direction = Vector3(0, 1, 0.4)
	_motes.spread = 35.0
	_motes.initial_velocity_min = 0.3
	_motes.initial_velocity_max = 0.7
	_motes.gravity = Vector3(0, 0.2, 0)
	_motes.scale_amount_min = 0.08
	_motes.scale_amount_max = 0.18
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, Color(1.0, 0.8, 0.4, 0.9))
	ramp.set_color(1, Color(1.0, 0.6, 0.25, 0.0))
	_motes.color_ramp = ramp
	var quad: QuadMesh = QuadMesh.new()
	quad.material = Fx.particle_material(true)
	_motes.mesh = quad
	_motes.position = window + outward * 0.15
	body.add_child(_motes)

	# Chips of plank and stone that tumble off it in the shrink.
	_debris = CPUParticles3D.new()
	_debris.emitting = false
	_debris.one_shot = true
	_debris.explosiveness = 0.85
	_debris.amount = 28
	_debris.lifetime = 1.6
	_debris.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_debris.emission_sphere_radius = 1.6
	_debris.direction = Vector3.UP
	_debris.spread = 70.0
	_debris.initial_velocity_min = 1.5
	_debris.initial_velocity_max = 3.5
	_debris.gravity = Vector3(0, -9.0, 0)
	_debris.angular_velocity_min = -360.0
	_debris.angular_velocity_max = 360.0
	_debris.scale_amount_min = 0.6
	_debris.scale_amount_max = 1.4
	var chip: BoxMesh = BoxMesh.new()
	chip.size = Vector3(0.22, 0.12, 0.16)
	var chip_material: StandardMaterial3D = StandardMaterial3D.new()
	chip_material.albedo_color = CHIP_COLOR
	chip.material = chip_material
	_debris.mesh = chip
	_debris.position.y = 2.6
	body.add_child(_debris)


func _find(model: Node, part: String) -> Node3D:
	var node: Node3D = model.find_child(part, true, false) as Node3D
	assert(node != null, "moon_eater.glb has no node " + part)
	return node
