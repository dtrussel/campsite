class_name LittleGolem
extends Node3D

## LittleGolem
##
## What is left of the Moon-Eater once it lets the moon go
## (art/characters/little_golem.py, after the team's sheet): a knee-high
## golem of planks and round stones with big amber eyes and a warm
## crescent window in its chest. It climbs out of the Moon-Eater's heap in
## the true ending (MoonEaterVisual), curls up by the campfire, and sits
## by the title fire once Mum is home (TitleBackdrop).
##
## Rigid like the Moon-Eater: the GLB's Body, Head, ArmL and ArmR are
## tweened. It breathes while idle: a slow bob and a sleepy head nod.

const MODEL: PackedScene = preload("res://assets/custom/little_golem.glb")
const EYE_COLOR: Color = Color(1.0, 0.62, 0.22)
const WINDOW_COLOR: Color = Color(1.0, 0.56, 0.2)
const MOON_COLOR: Color = Color(1.0, 0.9, 0.62)

var curled: bool = false

var _body: Node3D = null
var _head: Node3D = null
var _arm_l: Node3D = null
var _arm_r: Node3D = null
var _time: float = 0.0
var _head_rest: float = 0.0


func _ready() -> void:
	var model: Node3D = MODEL.instantiate() as Node3D
	model.name = "Model"
	add_child(model)
	_body = model.find_child("Body", true, false) as Node3D
	_head = model.find_child("Head", true, false) as Node3D
	_arm_l = model.find_child("ArmL", true, false) as Node3D
	_arm_r = model.find_child("ArmR", true, false) as Node3D
	Stylize.apply(model, "hero")
	_glow(model, "Head_Eyes", EYE_COLOR, 2.4)
	_glow(model, "Body_Window", WINDOW_COLOR, 1.4)
	_glow(model, "Body_Moon", MOON_COLOR, 2.6)
	var warm: OmniLight3D = OmniLight3D.new()
	warm.light_color = Color(1.0, 0.65, 0.35)
	warm.light_energy = 0.6
	warm.omni_range = 2.0
	warm.shadow_enabled = false
	warm.position = Vector3(0, 0.32, 0.35)
	add_child(warm)
	_time = randf() * TAU


func _process(delta: float) -> void:
	if _body == null:
		return
	_time += delta
	var breath: float = sin(_time * (1.2 if curled else 1.8))
	_body.scale = Vector3(1.0 + breath * 0.015, 1.0 - breath * 0.02, 1.0 + breath * 0.015)
	if _head != null:
		_head.rotation.x = _head_rest + breath * (0.05 if curled else 0.03)


## Settles down by the fire: squats, tucks its arms and lets its head
## droop, eyes half dimmed. `seconds` = 0 snaps straight there (the title).
func curl_up(seconds: float = 0.8) -> void:
	curled = true
	_head_rest = 0.35
	# Forward and in, so the long arms hug its knees.
	var arm_l: Vector3 = Vector3(-0.75, 0, 0.45)
	var arm_r: Vector3 = Vector3(-0.75, 0, -0.45)
	if seconds <= 0.0:
		scale = Vector3(scale.x * 1.05, scale.y * 0.85, scale.z * 1.05)
		_arm_l.rotation = arm_l
		_arm_r.rotation = arm_r
		return
	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(self, "scale", Vector3(scale.x * 1.05, scale.y * 0.85, scale.z * 1.05), seconds)
	tween.tween_property(_arm_l, "rotation", arm_l, seconds)
	tween.tween_property(_arm_r, "rotation", arm_r, seconds)


func _glow(model: Node3D, part: String, color: Color, energy: float) -> void:
	var mesh: MeshInstance3D = model.find_child(part, true, false) as MeshInstance3D
	if mesh == null:
		return
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color.darkened(0.3)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	mesh.material_override = material
	mesh.set_meta(&"stylized", "skip")
