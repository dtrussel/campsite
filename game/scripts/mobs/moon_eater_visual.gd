class_name MoonEaterVisual
extends Node3D

## MoonEaterVisual
##
## The Moon-Eater, after the team's character sheet
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
## The heap left behind by the ending (smoke checks it).
const PILE_GROUP: StringName = &"moon_eater_pile"
const CHIP_COLOR: Color = Color(0.5, 0.38, 0.27)
const EYE_COLOR: Color = Color(1.0, 0.6, 0.18)
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
## The eye holes (head-local, before the face tilt), as in moon_eater.py:
## centre and glow size. The halos sit on them.
const FACE_TILT: float = -0.3
const EYES: Array[Vector4] = [Vector4(-0.17, 0.128, 0.45, 0.5), Vector4(0.25, 0.071, 0.45, 0.34)]
## The pile it falls apart into: how wide, and how long the pieces take to land.
const PILE_RADIUS: float = 1.5
const FALL_SECONDS: float = 1.1
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
var _chips: CPUParticles3D = null
var _body: Node3D = null
var _moon: Node3D = null
## The loose planks and stones of the ending (hidden until it falls apart).
var _pile: Node3D = null
var _action: Tween = null
var _action_left: float = 0.0
var _locked: bool = false
var _hold: StringName = &""
var _speed: float = 0.0
var _time: float = 0.0
var _belly: float = 1.0
var _little: LittleGolem = null


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


## It lets the moon go, as on the sheet's "shrink ending": it sags, then
## falls apart into a heap of planks and stones. The crescent rises out
## of the heap into the moonbeam and its hoard floats up and fades. Then
## a small, warm golem climbs out of the rubble (BossController walks it
## to the fire); the heap stays where it fell.
func _shrink() -> float:
	var sag: float = 0.8
	var release: float = 2.2
	var climb: float = 0.9
	var tween: Tween = _tween()
	tween.tween_property(_rig, "rotation", Vector3(-0.25, 0, 0), sag)
	tween.parallel().tween_property(_arm_l, "rotation", Vector3(-0.5, 0, -1.2), sag)
	tween.parallel().tween_property(_arm_r, "rotation", Vector3(-0.5, 0, 1.2), sag)
	tween.parallel().tween_property(_head, "rotation:x", -0.6, sag)
	tween.tween_callback(_fall_apart)
	tween.tween_method(set_belly, _belly, 0.0, 1.0)
	tween.tween_interval(FALL_SECONDS + 0.4 - 1.0)
	# The small golem: the same parts, a quarter the size, warm.
	tween.tween_callback(_reassemble_small)
	tween.tween_property(_rig, "position:y", 0.0, climb).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_eye_material, "emission", Color(1.0, 0.5, 0.25), climb)
	tween.parallel().tween_property(_belly_light, "light_color", Color(1.0, 0.6, 0.32), climb)
	tween.parallel().tween_property(_belly_material, "emission", Color(1.0, 0.55, 0.28), climb)
	# A small warm glow of its own, like a coal by the fire.
	tween.tween_method(set_belly, 0.0, 0.35, 1.0)
	var total: float = sag + FALL_SECONDS + 0.4 + climb + 1.0
	return maxf(total, sag + release + 0.2)


## Hides the golem and drops its loose pieces into a heap where it stood.
func _fall_apart() -> void:
	_chips.emitting = true
	_motes.emitting = false
	var world: Node = _world()
	# The crescent and the hoard float free; the heap stays behind.
	for node in [_moon, _hoard]:
		node.reparent(world, true)
	_pile.visible = true
	_pile.reparent(world, true)
	_pile.name = "MoonEaterPile"
	_pile.add_to_group(PILE_GROUP)
	for part in [_body, _head, _arm_l, _arm_r]:
		part.visible = false
	var centre: Vector3 = global_position
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 38
	var pieces: Array[Node] = _pile.get_children()
	var drop: Tween = create_tween().set_parallel(true)
	for k in pieces.size():
		var piece: Node3D = pieces[k] as Node3D
		var angle: float = TAU * float(k) / float(pieces.size()) + rng.randf_range(-0.3, 0.3)
		var reach: float = sqrt(rng.randf()) * PILE_RADIUS * model_scale
		var target: Vector3 = centre + Vector3(cos(angle) * reach, 0.0, sin(angle) * reach)
		# Higher in the middle: a heap, not a carpet.
		target.y = centre.y + (0.08 + 0.4 * (1.0 - reach / (PILE_RADIUS * model_scale))) * model_scale
		var start_height: float = piece.global_position.y - centre.y
		var delay: float = clampf(0.25 - start_height * 0.04, 0.0, 0.25) + rng.randf_range(0.0, 0.15)
		var land: float = FALL_SECONDS - delay - 0.15
		var spin: Vector3 = piece.rotation + Vector3(rng.randf_range(-1.6, 1.6), rng.randf_range(-2.0, 2.0),
			rng.randf_range(-1.6, 1.6))
		drop.tween_property(piece, "global_position", target, land).set_delay(delay) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		drop.tween_property(piece, "rotation", spin, land).set_delay(delay)
		# A little bounce as it lands.
		drop.tween_property(piece, "global_position:y", target.y + 0.12 * model_scale, 0.08).set_delay(delay + land)
		drop.tween_property(piece, "global_position:y", target.y, 0.08).set_delay(delay + land + 0.08)
	# The crescent rises into the moonbeam and fades away up there.
	var float_up: Tween = create_tween().set_parallel(true)
	float_up.tween_property(_moon, "global_position", _moon.global_position + Vector3(0, 7.0, 0), 2.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	float_up.tween_property(_moon, "scale", _moon.scale * 2.2, 1.4).set_trans(Tween.TRANS_SINE)
	float_up.tween_property(_moon, "scale", Vector3.ONE * 0.01, 0.6).set_delay(1.6)
	# Its hoard drifts up, turning slowly, and fades.
	float_up.tween_property(_hoard, "global_position", _hoard.global_position + Vector3(0.3, 2.6, 0.4), 2.2) \
		.set_trans(Tween.TRANS_SINE)
	float_up.tween_property(_hoard, "rotation:y", _hoard.rotation.y + 1.2, 2.2)
	float_up.tween_property(_hoard, "scale", Vector3.ONE * 0.01, 0.8).set_delay(1.4)
	float_up.chain().tween_callback(_moon.queue_free)
	float_up.tween_callback(_hoard.queue_free)


## The little golem (its own model after the team's sheet),
## under the heap's top, about to climb out. The Moon-Eater's parts stay
## hidden; the golem keeps its real size whatever this visual's scale.
func _reassemble_small() -> void:
	for part in [_body, _head, _arm_l, _arm_r]:
		part.visible = false
	_rig.scale = Vector3.ONE
	_rig.rotation = Vector3.ZERO
	_rig.position.y = -0.5
	_little = LittleGolem.new()
	_little.name = "LittleGolem"
	_little.scale = Vector3.ONE / maxf(0.01, model_scale)
	_rig.add_child(_little)


## The little golem once the Moon-Eater has let the moon go, else null.
func little_golem() -> LittleGolem:
	return _little if _little != null and is_instance_valid(_little) else null


## Where the heap and the floating things go: the boss's own parent, so
## they stay put when the small golem walks off.
func _world() -> Node:
	var boss: Node = get_parent()
	return boss.get_parent() if boss != null and boss.get_parent() != null else self


# --- Model -------------------------------------------------------------------

func _build() -> void:
	_rig = Node3D.new()
	_rig.name = "Rig"
	add_child(_rig)
	var model: Node3D = MODEL.instantiate() as Node3D
	_rig.add_child(model)
	var body: Node3D = _find(model, "Body")
	_body = body
	_moon = _find(model, "Body_Moon")
	_pile = _find(model, "Debris")
	_pile.visible = false
	_head = _find(model, "Head")
	_arm_l = _find(model, "ArmL")
	_arm_r = _find(model, "ArmR")
	_hoard = _find(model, "Hoard")
	# The heroes' warm brown ink line suits wood and stone better than
	# the imps' purple one.
	Stylize.apply(_rig, "hero")

	_eye_material = StandardMaterial3D.new()
	_eye_material.albedo_color = Color(1.0, 0.42, 0.08)
	_eye_material.emission_enabled = true
	_eye_material.emission = EYE_COLOR
	_eye_material.emission_energy_multiplier = 2.2
	_belly_material = StandardMaterial3D.new()
	_belly_material.albedo_color = Color(0.5, 0.32, 0.14)
	_belly_material.emission_enabled = true
	_belly_material.emission = BELLY_COLOR
	_moon_material = StandardMaterial3D.new()
	_moon_material.albedo_color = Color(0.9, 0.86, 0.76)
	_moon_material.emission_enabled = true
	_moon_material.emission = Color(1.0, 0.94, 0.8)
	var eyes: MeshInstance3D = _find(model, "Head_Eyes") as MeshInstance3D
	eyes.material_override = _eye_material
	_add_eye_halos()
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
	_chips = CPUParticles3D.new()
	_chips.emitting = false
	_chips.one_shot = true
	_chips.explosiveness = 0.85
	_chips.amount = 28
	_chips.lifetime = 1.6
	_chips.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_chips.emission_sphere_radius = 1.6
	_chips.direction = Vector3.UP
	_chips.spread = 70.0
	_chips.initial_velocity_min = 1.5
	_chips.initial_velocity_max = 3.5
	_chips.gravity = Vector3(0, -9.0, 0)
	_chips.angular_velocity_min = -360.0
	_chips.angular_velocity_max = 360.0
	_chips.scale_amount_min = 0.6
	_chips.scale_amount_max = 1.4
	var chip: BoxMesh = BoxMesh.new()
	chip.size = Vector3(0.22, 0.12, 0.16)
	var chip_material: StandardMaterial3D = StandardMaterial3D.new()
	chip_material.albedo_color = CHIP_COLOR
	chip.material = chip_material
	_chips.mesh = chip
	_chips.position.y = 2.6
	body.add_child(_chips)


## A soft amber glow round each eye hole, like the sheet's lit eyes.
func _add_eye_halos() -> void:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_texture = Fx.soft_texture()
	material.albedo_color = Color(1.0, 0.55, 0.15, 0.9)
	material.disable_receive_shadows = true
	var tilt: Basis = Basis(Vector3.RIGHT, LEAN + FACE_TILT)
	for eye in EYES:
		var halo: MeshInstance3D = MeshInstance3D.new()
		var quad: QuadMesh = QuadMesh.new()
		quad.size = Vector2.ONE * eye.w
		quad.material = material
		halo.mesh = quad
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		halo.position = tilt * Vector3(eye.x, eye.y, eye.z + 0.14)
		_head.add_child(halo)


func _find(model: Node, part: String) -> Node3D:
	var node: Node3D = model.find_child(part, true, false) as Node3D
	assert(node != null, "moon_eater.glb has no node " + part)
	return node
