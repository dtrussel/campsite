class_name MoonEaterEyes
extends Node3D

## MoonEaterEyes
##
## The Moon-Eater watching from the treeline: on the
## nights before it comes (Chapter 2, from night 5) a pair of big pale
## eyes glows out in the dark woods. They blink and drift slowly. The spawner adds them at nightfall and calls
## leave() at dawn. They do nothing else.

const HEIGHT: float = 3.4
const SPACING: float = 0.75
const EYE_COLOR: Color = Color(1.0, 0.86, 0.5)

var _eyes: Array[MeshInstance3D] = []
var _material: StandardMaterial3D = null
var _time: float = 0.0
var _blink_in: float = 2.0
var _origin: Vector3 = Vector3.ZERO
var _leaving: bool = false


func _ready() -> void:
	add_to_group("moon_eater_eyes")
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.albedo_color = Color(EYE_COLOR, 0.0)
	for side in [-1.0, 1.0]:
		var eye: MeshInstance3D = MeshInstance3D.new()
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = 0.22
		sphere.height = 0.44
		eye.mesh = sphere
		eye.material_override = _material
		eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		eye.position.x = SPACING * 0.5 * side
		eye.scale = Vector3(1.3, 0.6, 0.4)
		eye.rotation.z = -0.25 * side
		add_child(eye)
		_eyes.append(eye)
	var glow: OmniLight3D = OmniLight3D.new()
	glow.light_color = EYE_COLOR
	glow.light_energy = 0.4
	glow.omni_range = 3.0
	glow.shadow_enabled = false
	add_child(glow)
	var tween: Tween = create_tween()
	tween.tween_property(_material, "albedo_color:a", 1.0, 3.0)
	PlaytestLog.write("moon_eater_eyes night=%d" % TimeManager.day_number)


func _process(delta: float) -> void:
	if _origin == Vector3.ZERO:
		_origin = global_position
	_time += delta
	# A slow drift along the treeline.
	global_position = _origin + Vector3(sin(_time * 0.17) * 2.5, sin(_time * 0.5) * 0.1, 0.0)
	_blink_in -= delta
	if _blink_in <= 0.0 and not _leaving:
		_blink_in = randf_range(2.5, 5.0)
		_blink()


func _blink() -> void:
	for eye in _eyes:
		var tween: Tween = eye.create_tween()
		tween.tween_property(eye, "scale:y", 0.05, 0.08)
		tween.tween_property(eye, "scale:y", 0.6, 0.12)


## Dawn: the eyes close and fade back into the woods.
func leave() -> void:
	_leaving = true
	var tween: Tween = create_tween()
	tween.tween_property(_material, "albedo_color:a", 0.0, 1.5)
	tween.tween_callback(queue_free)
