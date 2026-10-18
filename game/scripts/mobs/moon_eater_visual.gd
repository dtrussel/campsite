class_name MoonEaterVisual
extends Node3D

## MoonEaterVisual
##
## The Moon-Eater's code-built stand-in (feature 038), after the team's
## character sheet (art/reference/concept-2026-10/
## 15_moon_eater_character_sheet.webp): a hulking golem of weathered
## planks and stacked stones, lashed with rope. Short stone legs, long
## ape-like arms ending in huge stone fists, a small plank head set low
## between the shoulders with two amber eyes (one bigger), moss and
## saplings on its shoulders. In its chest is a round window of
## swallowed moonlight, golden, with a crescent and the lost things it
## hoards floating in it (a chair, a teddy, a pocket watch). Lanterns,
## bells, a red scarf and a key hang off it. Its clips are tweens on a
## few pivots and share CharacterVisual's calls, so BossController
## drives either one:
##   rise, idle, move, stomp, sweep, summon, stagger, reach, shrink.
## `reach` holds its pose until another clip (or `idle`) plays.
## Front is +Z, like the imported models.

const WOOD_COLOR: Color = Color(0.4, 0.29, 0.21)
const DARK_WOOD_COLOR: Color = Color(0.27, 0.19, 0.14)
const STONE_COLOR: Color = Color(0.33, 0.31, 0.3)
const MOSS_COLOR: Color = Color(0.4, 0.5, 0.2)
const EYE_COLOR: Color = Color(1.0, 0.8, 0.42)
## The swallowed moonlight: warm gold, as on the sheet.
const BELLY_COLOR: Color = Color(1.0, 0.74, 0.34)
const LANTERN_COLOR: Color = Color(1.0, 0.66, 0.3)
## Where the chest window sits.
const WINDOW: Vector3 = Vector3(0, 2.3, 1.55)
## The window bulges out and tips up toward the high game camera.
const WINDOW_TILT: float = -0.55
## The hunch: how far the body leans forward from the hips (radians).
const LEAN: float = 0.2
const HIP: Vector3 = Vector3(0, 1.45, 0)
## How far below the ground it starts its rise.
const RISE_DEPTH: float = 5.2
const TURN_SPEED: float = 2.5
## Fixed, so the planks and stones fall the same way every run.
const SEED: int = 38

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
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
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
	tween.parallel().tween_property(_hoard, "position", Vector3(0, 1.6, 1.2), 1.6).set_trans(Tween.TRANS_SINE)
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
	_rng.seed = SEED
	_rig = Node3D.new()
	_rig.name = "Rig"
	add_child(_rig)
	var wood: StandardMaterial3D = _painted(WOOD_COLOR)
	var dark_wood: StandardMaterial3D = _painted(DARK_WOOD_COLOR)
	var stone: StandardMaterial3D = _painted(STONE_COLOR)
	var moss: StandardMaterial3D = _painted(MOSS_COLOR)
	var rope: StandardMaterial3D = _painted(Color(0.62, 0.5, 0.32))
	var cloth: StandardMaterial3D = _painted(Color(0.72, 0.18, 0.14))
	var cloth_dark: StandardMaterial3D = _painted(Color(0.45, 0.1, 0.1))
	var brass: StandardMaterial3D = _painted(Color(0.8, 0.6, 0.3))
	var toy: StandardMaterial3D = _painted(Color(0.72, 0.46, 0.26))
	var leaves: StandardMaterial3D = _painted(Color(0.36, 0.52, 0.22))

	# Short, stumpy legs of stacked stones on broad flat feet.
	for side in [-1.0, 1.0]:
		_block(_rig, Vector3(1.15, 0.36, 1.3), stone, Vector3(0.78 * side, 0.18, 0.1))
		_block(_rig, Vector3(0.95, 0.55, 0.9), stone, Vector3(0.76 * side, 0.6, 0.0))
		_block(_rig, Vector3(0.85, 0.5, 0.82), stone, Vector3(0.72 * side, 1.08, 0.0))
	# Hips: one long stone lintel.
	_block(_rig, Vector3(2.1, 0.45, 1.25), stone, Vector3(0, 1.45, 0))

	# Everything above the hips leans forward from them: a hunched,
	# ape-like stance.
	var lean: Basis = Basis(Vector3.RIGHT, LEAN)
	var torso: Transform3D = Transform3D(lean, HIP - lean * HIP)
	var body: Node3D = Node3D.new()
	body.name = "Body"
	body.transform = torso
	_rig.add_child(body)

	# A barrel-chested trunk of upright planks, wider at the shoulders,
	# lashed with two bands of rope. The front stays open for the chest
	# window.
	_part(body, _cylinder(1.45, 1.1, 2.4, 8), dark_wood, Vector3(0, 2.6, 0))
	for i in 15:
		var angle: float = TAU * i / 15.0
		if absf(wrapf(angle, -PI, PI)) < 0.5:
			continue
		var stave: Node3D = Node3D.new()
		stave.rotation.y = angle
		body.add_child(stave)
		var plank: MeshInstance3D = _part(stave, _box(Vector3(0.5, _rng.randf_range(2.2, 2.7), 0.16)),
			wood if i % 3 != 0 else dark_wood, Vector3(0, 2.6 + _rng.randf_range(-0.1, 0.15), 1.3))
		plank.rotation = Vector3(0.14, 0, _rng.randf_range(-0.06, 0.06))
	for band in [[1.75, 1.25], [3.45, 1.52]]:
		var ring: TorusMesh = TorusMesh.new()
		ring.inner_radius = band[1]
		ring.outer_radius = band[1] + 0.13
		_part(body, ring, rope, Vector3(0, band[0], 0))

	# A hunched hump of big stones across the shoulders.
	for spec in [[Vector3(-1.0, 3.85, -0.1), Vector3(0.95, 0.65, 0.95)], [Vector3(1.0, 3.85, -0.1), Vector3(0.95, 0.65, 0.95)],
			[Vector3(0, 3.95, -0.45), Vector3(1.1, 0.7, 0.9)], [Vector3(-0.45, 3.65, -0.9), Vector3(0.9, 0.7, 0.7)],
			[Vector3(0.55, 3.7, -0.85), Vector3(0.8, 0.6, 0.8)]]:
		_block(body, spec[1], stone, spec[0])
	for at in [Vector3(-1.0, 4.2, -0.05), Vector3(1.0, 4.2, -0.05), Vector3(0, 4.32, -0.45)]:
		_part(body, _sphere(0.5, 0.5), moss, at, Vector3(1.1, 0.35, 1.0))

	_head = Node3D.new()
	_head.name = "Head"
	_head.position = Vector3(0, 4.0, 1.1)
	body.add_child(_head)
	# The face tips up a little, so its eyes read from the game camera.
	var face: Node3D = Node3D.new()
	face.rotation.x = -0.3
	_head.add_child(face)
	# A small blocky face of three upright planks under a heavy brow.
	for x in [-0.31, 0.0, 0.31]:
		var slat: MeshInstance3D = _part(face, _box(Vector3(0.34, 1.05 + _rng.randf_range(-0.08, 0.1), 0.75)),
			wood, Vector3(x, _rng.randf_range(-0.04, 0.05), 0.0))
		slat.rotation.z = _rng.randf_range(-0.05, 0.05)
	var brow: MeshInstance3D = _part(face, _box(Vector3(1.18, 0.16, 0.3)), dark_wood, Vector3(0, 0.24, 0.34))
	brow.rotation.z = 0.07
	_part(face, _sphere(0.5, 0.5), moss, Vector3(0, 0.52, -0.05), Vector3(1.05, 0.4, 0.9))

	# A red scarf round the neck, one end hanging down the chest.
	var scarf: TorusMesh = TorusMesh.new()
	scarf.inner_radius = 0.5
	scarf.outer_radius = 0.78
	_part(body, scarf, cloth, Vector3(0, 3.5, 0.6), Vector3(1.2, 0.6, 1.0))
	var tail: MeshInstance3D = _part(body, _box(Vector3(0.32, 0.75, 0.07)), cloth, Vector3(0.95, 3.1, 1.2))
	tail.rotation = Vector3(0.15, -0.5, 0.12)
	_part(tail, _box(Vector3(0.34, 0.08, 0.08)), cloth_dark, Vector3(0, -0.2, 0))

	# The chest window: a plank-and-stone frame round the swallowed moon.
	var window: Node3D = Node3D.new()
	window.name = "Window"
	window.position = WINDOW
	window.rotation.x = WINDOW_TILT
	body.add_child(window)
	var frame: TorusMesh = TorusMesh.new()
	frame.inner_radius = 0.74
	frame.outer_radius = 1.0
	frame.rings = 10
	frame.ring_segments = 6
	var frame_mesh: MeshInstance3D = _part(window, frame, dark_wood, Vector3.ZERO)
	frame_mesh.rotation.x = PI / 2.0
	for i in 6:
		var angle: float = TAU * i / 6.0 + 0.3
		var chunk: MeshInstance3D = _block(window, Vector3(0.32, 0.26, 0.3), stone,
			Vector3(cos(angle) * 0.9, sin(angle) * 0.9, 0.08))
		chunk.rotation.z = angle

	# What it hoards, floating in the moonlight: a little chair, a teddy
	# and a pocket watch.
	_hoard = Node3D.new()
	_hoard.name = "Hoard"
	_hoard.position = Vector3(0, 0, 0.2)
	window.add_child(_hoard)
	var chair: Node3D = Node3D.new()
	chair.position = Vector3(-0.3, -0.1, 0)
	chair.rotation = Vector3(0, 0.3, 0.25)
	_hoard.add_child(chair)
	_part(chair, _box(Vector3(0.28, 0.04, 0.24)), dark_wood, Vector3.ZERO)
	_part(chair, _box(Vector3(0.28, 0.3, 0.04)), dark_wood, Vector3(0, 0.17, -0.1))
	for corner in [Vector3(-0.12, -0.12, -0.1), Vector3(0.12, -0.12, -0.1), Vector3(-0.12, -0.12, 0.1), Vector3(0.12, -0.12, 0.1)]:
		_part(chair, _box(Vector3(0.035, 0.24, 0.035)), dark_wood, corner)
	var teddy: Node3D = Node3D.new()
	teddy.position = Vector3(0.36, -0.28, 0)
	teddy.rotation.z = -0.3
	_hoard.add_child(teddy)
	_part(teddy, _sphere(0.12, 0.26), toy, Vector3.ZERO, Vector3(1.0, 1.1, 0.7))
	_part(teddy, _sphere(0.09, 0.18), toy, Vector3(0, 0.18, 0))
	for side in [-1.0, 1.0]:
		_part(teddy, _sphere(0.035, 0.07), toy, Vector3(0.07 * side, 0.26, 0))
	var watch: MeshInstance3D = _part(_hoard, _cylinder(0.1, 0.1, 0.04, 12), brass, Vector3(0.08, 0.32, 0.02))
	watch.rotation.x = PI / 2.0

	# Long, heavy arms from the shoulders.
	_arm_l = _arm(torso * Vector3(-1.7, 3.7, 0.15), -1.0, wood, dark_wood, stone, rope, moss)
	_arm_r = _arm(torso * Vector3(1.7, 3.7, 0.15), 1.0, wood, dark_wood, stone, rope, moss)

	# Hanging from it: lanterns on chains, brass bells, a big key.
	_lantern(body, Vector3(-1.45, 3.4, 0.95), brass, dark_wood)
	_lantern(body, Vector3(1.25, 1.75, 1.0), brass, dark_wood)
	_lantern(_arm_r, Vector3(0.55, -1.0, 0.4), brass, dark_wood)
	_bell(body, Vector3(1.6, 3.35, 0.6), brass)
	_bell(body, Vector3(-1.15, 1.7, 1.0), brass)
	_bell(_arm_l, Vector3(-0.5, -2.1, 0.45), brass)
	var key: Node3D = Node3D.new()
	key.position = Vector3(-0.75, 2.85, 1.42)
	key.rotation.z = 0.4
	body.add_child(key)
	_part(key, _cylinder(0.02, 0.02, 0.5, 6), brass, Vector3.ZERO)
	var bow: TorusMesh = TorusMesh.new()
	bow.inner_radius = 0.06
	bow.outer_radius = 0.1
	var bow_mesh: MeshInstance3D = _part(key, bow, brass, Vector3(0, 0.3, 0))
	bow_mesh.rotation.x = PI / 2.0
	_part(key, _box(Vector3(0.12, 0.05, 0.03)), brass, Vector3(0.05, -0.2, 0))

	# The forest grows on its back: saplings on the shoulders, fence
	# pickets and branches poking up.
	_sapling(body, Vector3(-1.3, 4.2, -0.3), 0.9, wood, leaves)
	_sapling(body, Vector3(0.75, 4.3, -0.7), 0.65, wood, leaves)
	for spec in [[Vector3(0.2, 4.4, -0.9), Vector3(-0.3, 0, 0.15)], [Vector3(-0.35, 4.3, -1.0), Vector3(-0.4, 0, -0.2)],
			[Vector3(1.3, 4.1, -0.5), Vector3(-0.2, 0, -0.4)]]:
		var picket: MeshInstance3D = _part(body, _box(Vector3(0.16, 1.0, 0.06)), wood, spec[0])
		picket.rotation = spec[1]
	for spec in [[Vector3(-0.9, 4.1, -0.9), Vector3(-0.8, 0.3, 0.5), 1.4], [Vector3(0.4, 4.2, -1.1), Vector3(-1.0, -0.4, -0.4), 1.2]]:
		var branch: MeshInstance3D = _part(body, _cylinder(0.025, 0.07, spec[2], 6), dark_wood, spec[0])
		branch.rotation = spec[1]
		var twig: MeshInstance3D = _part(branch, _cylinder(0.015, 0.03, 0.45, 6), dark_wood, Vector3(0.05, float(spec[2]) * 0.3, 0))
		twig.rotation.z = 0.8
	# The heroes' warm brown ink line suits wood and stone better than
	# the imps' purple one.
	Stylize.apply(_rig, "hero")

	# The glowing bits stay out of the painted look.
	_eye_material = StandardMaterial3D.new()
	_eye_material.albedo_color = EYE_COLOR
	_eye_material.emission_enabled = true
	_eye_material.emission = EYE_COLOR
	_eye_material.emission_energy_multiplier = 2.0
	# One eye a little bigger than the other, as on the sheet.
	for spec in [[-1.0, 0.13], [1.0, 0.17]]:
		var eye: MeshInstance3D = _part(face, _sphere(spec[1], spec[1] * 2.0), _eye_material,
			Vector3(0.27 * spec[0], 0.0, 0.39), Vector3(1.15, 0.85, 0.5))
		eye.name = "Eye"

	_belly_material = StandardMaterial3D.new()
	_belly_material.albedo_color = Color(0.5, 0.32, 0.14)
	_belly_material.emission_enabled = true
	_belly_material.emission = BELLY_COLOR
	_part(window, _sphere(0.8, 1.6), _belly_material, Vector3(0, 0, -0.16), Vector3(1.0, 1.0, 0.3))
	# A pale crescent: a cream disc half hidden by a second disc of the
	# window's own gold.
	_moon_material = StandardMaterial3D.new()
	_moon_material.albedo_color = Color(0.9, 0.86, 0.76)
	_moon_material.emission_enabled = true
	_moon_material.emission = Color(1.0, 0.94, 0.8)
	_part(window, _sphere(0.3, 0.6), _moon_material, Vector3(0.0, 0.1, 0.1), Vector3(1.0, 1.0, 0.15))
	_part(window, _sphere(0.28, 0.56), _belly_material, Vector3(0.13, 0.18, 0.13), Vector3(1.0, 1.0, 0.15))
	_belly_light = OmniLight3D.new()
	_belly_light.light_color = Color(1.0, 0.78, 0.48)
	_belly_light.omni_range = 7.0
	_belly_light.position = Vector3(0, 0, 1.0)
	_belly_light.shadow_enabled = false
	window.add_child(_belly_light)
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
	_motes.position = Vector3(0, 0, 0.15)
	window.add_child(_motes)

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
	chip_material.albedo_color = WOOD_COLOR
	chip.material = chip_material
	_debris.mesh = chip
	_debris.position.y = 2.6
	body.add_child(_debris)


func _arm(shoulder: Vector3, side: float, wood: Material, dark_wood: Material, stone: Material, rope: Material,
		moss: Material) -> Node3D:
	var pivot: Node3D = Node3D.new()
	pivot.name = "ArmL" if side < 0.0 else "ArmR"
	pivot.position = shoulder
	_rig.add_child(pivot)
	# A shoulder stone, a bundle of planks for the upper arm, a thicker
	# one for the forearm, each lashed with rope.
	_block(pivot, Vector3(0.85, 0.7, 0.85), stone, Vector3(0.1 * side, 0.0, 0.0))
	for offset in [Vector3(-0.14, 0, -0.1), Vector3(0.14, 0, -0.1), Vector3(0, 0, 0.14)]:
		_part(pivot, _box(Vector3(0.24, 1.5, 0.24)), wood, Vector3(0.15 * side, -0.9, 0.05) + offset)
	for offset in [Vector3(-0.18, 0, -0.14), Vector3(0.18, 0, -0.14), Vector3(-0.18, 0, 0.18), Vector3(0.18, 0, 0.18)]:
		var slat: MeshInstance3D = _part(pivot, _box(Vector3(0.3, 1.25, 0.3)), wood if offset.z < 0.0 else dark_wood,
			Vector3(0.2 * side, -2.0, 0.15) + offset)
		slat.rotation.y = _rng.randf_range(-0.1, 0.1)
	for band in [[-0.65, 0.27, 0.15], [-1.15, 0.27, 0.15], [-1.75, 0.37, 0.2], [-2.25, 0.37, 0.2]]:
		var ring: TorusMesh = TorusMesh.new()
		ring.inner_radius = band[1]
		ring.outer_radius = band[1] + 0.1
		_part(pivot, ring, rope, Vector3(band[2] * side, band[0], 0.1))
	# A huge stone fist: a block with a row of knuckles and a thumb.
	var fist: Vector3 = Vector3(0.25 * side, -2.9, 0.25)
	_block(pivot, Vector3(1.35, 1.1, 1.25), stone, fist)
	for i in 4:
		_block(pivot, Vector3(0.3, 0.36, 0.32), stone, fist + Vector3(-0.48 + 0.32 * i, -0.2, 0.66))
	_block(pivot, Vector3(0.3, 0.45, 0.32), stone, fist + Vector3(-0.65 * side, 0.05, 0.45))
	_part(pivot, _sphere(0.42, 0.42), moss, fist + Vector3(0, 0.58, 0), Vector3(1.25, 0.35, 1.1))
	return pivot


## A small lantern on a chain; its glass glows (Stylize keeps emissive
## materials bright and unshaded).
func _lantern(parent: Node3D, at: Vector3, metal: Material, cap: Material) -> void:
	var lantern: Node3D = Node3D.new()
	lantern.position = at
	parent.add_child(lantern)
	_part(lantern, _cylinder(0.015, 0.015, 0.4, 6), metal, Vector3(0, 0.38, 0))
	_part(lantern, _cylinder(0.06, 0.17, 0.12, 6), cap, Vector3(0, 0.2, 0))
	_part(lantern, _box(Vector3(0.26, 0.06, 0.26)), cap, Vector3(0, -0.2, 0))
	var glass: StandardMaterial3D = StandardMaterial3D.new()
	glass.albedo_color = LANTERN_COLOR
	glass.emission_enabled = true
	glass.emission = LANTERN_COLOR
	glass.emission_energy_multiplier = 2.5
	glass.resource_name = "moon_eater_lantern" + Stylize.PAINTED_SUFFIX
	_part(lantern, _box(Vector3(0.2, 0.3, 0.2)), glass, Vector3.ZERO)


func _bell(parent: Node3D, at: Vector3, metal: Material) -> void:
	_part(parent, _cylinder(0.05, 0.13, 0.2, 10), metal, at)
	_part(parent, _sphere(0.05, 0.1), metal, at + Vector3(0, 0.12, 0))


func _sapling(parent: Node3D, at: Vector3, height: float, bark: Material, leaves: Material) -> void:
	_part(parent, _cylinder(0.03, 0.06, height, 6), bark, at + Vector3(0, height * 0.5, 0))
	for spec in [[Vector3(0, height, 0), 0.32], [Vector3(0.15, height * 0.8, 0.1), 0.22], [Vector3(-0.14, height * 0.75, -0.08), 0.2]]:
		_part(parent, _sphere(spec[1], spec[1] * 1.7), leaves, at + spec[0])


## A slightly crooked box, so the stones and planks don't line up too neatly.
func _block(parent: Node3D, size: Vector3, material: Material, at: Vector3) -> MeshInstance3D:
	var block: MeshInstance3D = _part(parent, _box(size), material, at)
	block.rotation = Vector3(_rng.randf_range(-0.08, 0.08), _rng.randf_range(-0.15, 0.15), _rng.randf_range(-0.08, 0.08))
	return block


## Named like the painted assets, so Stylize gives it the painted
## shading and an ink line.
func _painted(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.resource_name = "moon_eater" + Stylize.PAINTED_SUFFIX
	return material


func _sphere(radius: float, height: float) -> SphereMesh:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	mesh.rings = 8
	return mesh


func _cylinder(top: float, bottom: float, height: float, segments: int = 8) -> CylinderMesh:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = segments
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
